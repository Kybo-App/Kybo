"""
Router per il Matchmaking (Professionisti <-> Utenti).
"""
from typing import Optional, List
import firebase_admin
from firebase_admin import firestore
from fastapi import APIRouter, HTTPException, Depends, Request
from pydantic import BaseModel, Field

from app.core.dependencies import verify_token, verify_professional
from app.core.logging import logger, sanitize_error_message
from app.core.limiter import limiter

router = APIRouter(prefix="/matchmaking", tags=["matchmaking"])


class MatchmakingRequestCreate(BaseModel):
    coach_type: str = Field(..., description="nutritionist o personal_trainer")
    goal: str = Field(..., max_length=500)
    notes: Optional[str] = Field(None, max_length=1000)

class MatchmakingOfferCreate(BaseModel):
    notes: Optional[str] = Field(None, max_length=1000)
    price_info: Optional[str] = Field(None, max_length=200)

class AcceptOfferRequest(BaseModel):
    # [FIX M-7] Aggiunta validazione lunghezza su offer_id
    offer_id: str = Field(..., min_length=1, max_length=128)


@router.post("/requests")
@limiter.limit("10/hour")
async def create_matchmaking_request(
    request: Request,
    body: MatchmakingRequestCreate,
    requester: dict = Depends(verify_token)
):
    """L'utente cerca un professionista."""
    try:
        # [FIX H-2] Solo client/independent possono creare richieste di matchmaking.
        # Un professionista che crea una richiesta come "cliente" inquinerebbe la bacheca
        # e potrebbe causare auto-assegnazioni se l'offerta venisse accettata.
        allowed_client_roles = ('client', 'independent', 'user', None)
        if requester.get('role') not in allowed_client_roles:
            raise HTTPException(
                status_code=403,
                detail="Solo i clienti possono creare richieste di matchmaking."
            )

        if body.coach_type not in ['nutritionist', 'personal_trainer']:
            raise HTTPException(status_code=400, detail="coach_type non valido")

        db = firebase_admin.firestore.client()

        # Controlla se ha già una richiesta aperta per quel ruolo
        open_reqs = db.collection('matchmaking_requests') \
            .where('user_id', '==', requester['uid']) \
            .where('coach_type', '==', body.coach_type) \
            .where('status', '==', 'open').limit(1).stream()

        if len(list(open_reqs)) > 0:
            raise HTTPException(status_code=400, detail="Hai già una richiesta aperta per questa figura.")

        req_data = {
            'user_id': requester['uid'],
            'coach_type': body.coach_type,
            'goal': body.goal,
            'notes': body.notes or '',
            'status': 'open',
            'created_at': firestore.SERVER_TIMESTAMP,
        }
        ref = db.collection('matchmaking_requests').add(req_data)

        logger.info("matchmaking_req_created", user=requester['uid'], type=body.coach_type)
        return {"id": ref[1].id, "message": "Richiesta pubblicata in bacheca!"}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("matchmaking_create_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore interno.")


@router.get("/board")
@limiter.limit("60/minute")
async def get_matchmaking_board(
    request: Request,
    requester: dict = Depends(verify_professional)
):
    """I professionisti leggono la bacheca annunci."""
    try:
        db = firebase_admin.firestore.client()
        role = requester['role']

        query = db.collection('matchmaking_requests').where('status', '==', 'open')
        # Se non è admin, filtra per il suo ruolo specifico
        if role in ('nutritionist', 'personal_trainer'):
            query = query.where('coach_type', '==', role)

        docs = query.order_by('created_at', direction=firestore.Query.DESCENDING).limit(100).stream()

        results = []
        for d in docs:
            data = d.to_dict()
            data['id'] = d.id
            if 'created_at' in data and data['created_at']:
                data['created_at'] = data['created_at'].isoformat()
            # [FIX M-4] Non esporre user_id (UID Firebase) ai professionisti:
            # previene enumerazione di client UID dalla bacheca pubblica.
            data.pop('user_id', None)
            results.append(data)

        return {"board": results}

    except Exception as e:
        logger.error("matchmaking_board_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore nel caricamento bacheca.")


@router.post("/requests/{req_id}/offers")
@limiter.limit("30/hour")
async def make_offer(
    request: Request,
    req_id: str,
    body: MatchmakingOfferCreate,
    requester: dict = Depends(verify_professional)
):
    """Un professionista fa un'offerta a una richiesta."""
    try:
        db = firebase_admin.firestore.client()
        req_ref = db.collection('matchmaking_requests').document(req_id)
        req_doc = req_ref.get()

        if not req_doc.exists or req_doc.to_dict().get('status') != 'open':
            raise HTTPException(status_code=400, detail="Richiesta non disponibile.")

        req_data = req_doc.to_dict()
        role = requester['role']

        # [FIX M-5] Gli admin non devono accettare clienti come coach.
        # Solo nutritionist e personal_trainer possono fare offerte.
        if role == 'admin':
            raise HTTPException(
                status_code=403,
                detail="Gli admin non possono fare offerte come professionisti."
            )

        if role != req_data.get('coach_type'):
            raise HTTPException(status_code=403, detail="Non puoi fare offerte per questo ruolo.")

        # Evita offerte duplicate dello stesso professionista
        existing = req_ref.collection('offers') \
            .where('professional_id', '==', requester['uid']).limit(1).stream()
        if len(list(existing)) > 0:
            raise HTTPException(status_code=400, detail="Hai già fatto un'offerta per questa richiesta.")

        offer_data = {
            'professional_id': requester['uid'],
            'notes': body.notes or '',
            'price_info': body.price_info or '',
            'created_at': firestore.SERVER_TIMESTAMP,
            'status': 'pending'
        }

        req_ref.collection('offers').add(offer_data)
        return {"message": "Offerta inviata con successo!"}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("matchmaking_offer_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore interno.")


@router.get("/my-requests")
@limiter.limit("60/minute")
async def get_my_requests(
    request: Request,
    requester: dict = Depends(verify_token)
):
    """L'utente vede le sue richieste e le eventuali offerte."""
    try:
        db = firebase_admin.firestore.client()
        # [FIX L-4] Aggiunto .limit(50) per evitare reads illimitate
        docs = db.collection('matchmaking_requests') \
            .where('user_id', '==', requester['uid']) \
            .order_by('created_at', direction=firestore.Query.DESCENDING) \
            .limit(50).stream()

        results = []
        for d in docs:
            data = d.to_dict()
            data['id'] = d.id
            if 'created_at' in data and data['created_at']:
                data['created_at'] = data['created_at'].isoformat()

            # [FIX L-4] Aggiunto .limit(20) alle offerte per evitare loop illimitato
            # [FIX M-3] Esponi info professionista solo per offerte ancora pending
            offers = []
            offers_docs = d.reference.collection('offers').limit(20).stream()
            for od in offers_docs:
                odata = od.to_dict()
                odata['id'] = od.id
                if 'created_at' in odata and odata['created_at']:
                    odata['created_at'] = odata['created_at'].isoformat()

                # [FIX M-3] Fetch nome professionista solo se l'offerta è pending/accepted
                if odata.get('status') in ('pending', 'accepted'):
                    try:
                        prof_doc = db.collection('users').document(odata['professional_id']).get()
                        if prof_doc.exists:
                            pdata = prof_doc.to_dict()
                            odata['professional_name'] = f"{pdata.get('first_name','')} {pdata.get('last_name','')}".strip()
                    except Exception as e:
                        logger.warning("prof_name_fetch_error", error=sanitize_error_message(e))
                        odata['professional_name'] = 'Professionista'

                offers.append(odata)

            data['offers'] = offers
            results.append(data)

        return {"requests": results}

    except Exception as e:
        logger.error("matchmaking_myreq_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore interno.")


@router.post("/requests/{req_id}/accept")
@limiter.limit("20/hour")
async def accept_offer(
    request: Request,
    req_id: str,
    body: AcceptOfferRequest,
    requester: dict = Depends(verify_token)
):
    """L'utente accetta un'offerta e viene assegnato al professionista."""
    try:
        db = firebase_admin.firestore.client()
        req_ref = db.collection('matchmaking_requests').document(req_id)
        req_doc = req_ref.get()

        if not req_doc.exists:
            raise HTTPException(status_code=404, detail="Richiesta non trovata.")

        req_data = req_doc.to_dict()
        if req_data.get('user_id') != requester['uid']:
            raise HTTPException(status_code=403, detail="Non sei il proprietario della richiesta.")

        if req_data.get('status') != 'open':
            raise HTTPException(status_code=400, detail="Richiesta già chiusa.")

        offer_ref = req_ref.collection('offers').document(body.offer_id)
        offer_doc = offer_ref.get()
        if not offer_doc.exists:
            raise HTTPException(status_code=404, detail="Offerta non trovata.")

        offer_data = offer_doc.to_dict()
        professional_id = offer_data.get('professional_id')
        coach_type = req_data.get('coach_type')

        # [FIX H-1] Verifica che il professionista esista e abbia il ruolo corretto
        # prima di scrivere il suo UID nel profilo utente.
        if not professional_id:
            raise HTTPException(status_code=400, detail="Offerta non valida: professionista mancante.")

        prof_doc = db.collection('users').document(professional_id).get()
        if not prof_doc.exists:
            raise HTTPException(status_code=400, detail="Il professionista non è più disponibile.")

        prof_data = prof_doc.to_dict()
        prof_role = prof_data.get('role', '')

        # Il ruolo del professionista deve corrispondere al tipo richiesto
        expected_roles = {
            'nutritionist': ('nutritionist',),
            'personal_trainer': ('personal_trainer',),
        }
        if coach_type in expected_roles and prof_role not in expected_roles[coach_type]:
            raise HTTPException(
                status_code=400,
                detail="Il professionista non ha il ruolo richiesto."
            )

        # [FIX M-1] Transazione atomica: update user + close request + reject
        # orfane. Senza transazione, se una delle scritture fallisce resta
        # stato incoerente (es. pt_id settato ma request ancora 'open').
        # [FIX M-2] Le offerte diverse da quella accettata vengono marcate
        # 'rejected' nella stessa transazione così i PT che le hanno fatte
        # non le vedono più come pending.
        user_ref = db.collection('users').document(requester['uid'])

        field_name = 'pt_id' if coach_type == 'personal_trainer' else 'nutritionist_id'

        # Pre-leggi le altre offerte FUORI transazione (Firestore non permette
        # query multi-doc dentro una transazione; leggiamo i doc_id e li
        # aggiorniamo singolarmente nella transazione).
        other_offer_ids = []
        for od in req_ref.collection('offers').stream():
            if od.id != body.offer_id and od.to_dict().get('status') == 'pending':
                other_offer_ids.append(od.id)

        accepted_offer_ref = req_ref.collection('offers').document(body.offer_id)

        @firestore.transactional
        def _accept_txn(transaction):
            # Ri-leggi request dentro la transazione per rilevare race
            # (es. altro tab che ha già accettato un'altra offerta).
            req_snap = req_ref.get(transaction=transaction)
            if not req_snap.exists:
                raise HTTPException(status_code=404, detail="Richiesta non trovata.")
            if req_snap.to_dict().get('status') != 'open':
                raise HTTPException(status_code=409, detail="Richiesta già chiusa.")

            # 1) assegna coach all'utente
            transaction.update(user_ref, {field_name: professional_id})

            # 2) chiudi la richiesta
            transaction.update(req_ref, {
                'status': 'closed',
                'accepted_offer_id': body.offer_id,
                'matched_professional': professional_id,
                'updated_at': firestore.SERVER_TIMESTAMP,
            })

            # 3) marca l'offerta accettata
            transaction.update(accepted_offer_ref, {
                'status': 'accepted',
                'updated_at': firestore.SERVER_TIMESTAMP,
            })

            # 4) rifiuta le altre offerte pending (FIX M-2)
            for oid in other_offer_ids:
                transaction.update(
                    req_ref.collection('offers').document(oid),
                    {'status': 'rejected', 'updated_at': firestore.SERVER_TIMESTAMP},
                )

        _accept_txn(db.transaction())

        logger.info(
            "matchmaking_accepted",
            user=requester['uid'], prof=professional_id, type=coach_type,
            rejected_count=len(other_offer_ids),
        )
        return {"message": "Offerta accettata! Il coach è ora assegnato al tuo profilo."}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("matchmaking_accept_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore interno.")
