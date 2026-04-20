"""
Router per il sistema Reward (Shop Premi).
- CRUD catalogo premi (admin only)
- Visualizzazione catalogo (qualsiasi utente autenticato)
- Riscatto premio con spesa XP (utente autenticato)
- Storico premi riscattati
"""
from typing import Optional, List, Literal

import firebase_admin
from firebase_admin import firestore
from fastapi import APIRouter, HTTPException, Depends, Request
from pydantic import BaseModel, Field, AnyHttpUrl

from app.core.dependencies import verify_admin, verify_token, get_current_uid
from app.core.logging import logger, sanitize_error_message
from app.core.limiter import limiter

router = APIRouter(tags=["rewards"])


# --- Models ---

class CreateRewardRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    description: str = Field("", max_length=1000)
    xp_cost: int = Field(..., ge=1, le=100_000)
    # [FIX H-3] AnyHttpUrl richiede schema https/http valido — previene XSS e SSRF
    image_url: Optional[AnyHttpUrl] = Field(None)
    # URL esterno opzionale aperto dal client dopo il riscatto
    # (es. pagina sconto, shop partner). Stessa validazione di image_url.
    redirect_url: Optional[AnyHttpUrl] = Field(None)
    stock: Optional[int] = Field(None, ge=0, le=100_000)
    is_active: bool = True


class UpdateRewardRequest(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=200)
    description: Optional[str] = Field(None, max_length=1000)
    xp_cost: Optional[int] = Field(None, ge=1, le=100_000)
    # [FIX H-3] Stessa validazione URL per gli update
    image_url: Optional[AnyHttpUrl] = Field(None)
    redirect_url: Optional[AnyHttpUrl] = Field(None)
    stock: Optional[int] = Field(None, ge=0, le=100_000)
    is_active: Optional[bool] = None


# --- Admin CRUD ---

@router.get("/admin/rewards/catalog")
@limiter.limit("60/minute")
async def get_rewards_catalog(
    request: Request,
    requester: dict = Depends(verify_admin),
):
    """Lista completa catalogo premi (admin vede anche i disattivati)."""
    try:
        db = firebase_admin.firestore.client()
        # [FIX R-7] .limit(500) per evitare reads illimitate se il catalogo cresce.
        docs = db.collection('rewards_catalog').order_by(
            'created_at', direction=firestore.Query.DESCENDING
        ).limit(500).stream()

        rewards = []
        for doc in docs:
            data = doc.to_dict()
            data['id'] = doc.id
            # [FIX M-6] claim_count è mantenuto sul documento stesso (aggiornato atomicamente
            # durante ogni claim) — evita N+1 collection_group queries per ogni vista admin.
            rewards.append(data)

        return {"rewards": rewards}
    except Exception as e:
        logger.error("get_rewards_catalog_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante il caricamento del catalogo.")


@router.post("/admin/rewards/catalog")
@limiter.limit("30/hour")
async def create_reward(
    request: Request,
    body: CreateRewardRequest,
    requester: dict = Depends(verify_admin),
):
    """Crea un nuovo premio nel catalogo."""
    try:
        db = firebase_admin.firestore.client()
        reward_data = {
            'name': body.name,
            'description': body.description,
            'xp_cost': body.xp_cost,
            # AnyHttpUrl → str (Firestore non serializza Pydantic Url types)
            'image_url': str(body.image_url) if body.image_url else None,
            'redirect_url': str(body.redirect_url) if body.redirect_url else None,
            'stock': body.stock,
            'is_active': body.is_active,
            'created_at': firestore.SERVER_TIMESTAMP,
            'created_by': requester['uid'],
        }
        doc_ref = db.collection('rewards_catalog').add(reward_data)
        reward_id = doc_ref[1].id

        logger.info("reward_created", reward_id=reward_id, name=body.name, by=requester['uid'])
        return {"id": reward_id, "message": "Premio creato"}
    except Exception as e:
        logger.error("create_reward_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante la creazione del premio.")


@router.put("/admin/rewards/catalog/{reward_id}")
@limiter.limit("60/minute")
async def update_reward(
    request: Request,
    reward_id: str,
    body: UpdateRewardRequest,
    requester: dict = Depends(verify_admin),
):
    """Modifica un premio esistente."""
    try:
        db = firebase_admin.firestore.client()
        doc_ref = db.collection('rewards_catalog').document(reward_id)
        doc = doc_ref.get()

        if not doc.exists:
            raise HTTPException(status_code=404, detail="Premio non trovato")

        update_data = {}
        if body.name is not None:
            update_data['name'] = body.name
        if body.description is not None:
            update_data['description'] = body.description
        if body.xp_cost is not None:
            update_data['xp_cost'] = body.xp_cost
        if body.image_url is not None:
            # Pydantic AnyHttpUrl non è serializzabile direttamente da Firestore
            update_data['image_url'] = str(body.image_url)
        if body.redirect_url is not None:
            update_data['redirect_url'] = str(body.redirect_url)
        if body.stock is not None:
            update_data['stock'] = body.stock
        if body.is_active is not None:
            update_data['is_active'] = body.is_active
            # [FIX R-6] Se riattiviamo un reward soft-deleted, ripuliamo i
            # marcatori di cancellazione altrimenti filtri tipo
            # "deleted_at == null" darebbero risultati incoerenti.
            if body.is_active is True:
                update_data['deleted_at'] = firestore.DELETE_FIELD
                update_data['deleted_by'] = firestore.DELETE_FIELD

        if update_data:
            update_data['updated_at'] = firestore.SERVER_TIMESTAMP
            doc_ref.update(update_data)

        logger.info("reward_updated", reward_id=reward_id, by=requester['uid'])
        return {"message": "Premio aggiornato"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("update_reward_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante l'aggiornamento del premio.")


@router.delete("/admin/rewards/catalog/{reward_id}")
@limiter.limit("20/hour")
async def delete_reward(
    request: Request,
    reward_id: str,
    requester: dict = Depends(verify_admin),
):
    """Disattiva (soft-delete) un premio dal catalogo.
    [FIX H-5] Non cancella fisicamente: i claim pending rimangono consultabili.
    Usa PUT per disattivare, non cancella dati storici.
    """
    try:
        db = firebase_admin.firestore.client()
        doc_ref = db.collection('rewards_catalog').document(reward_id)
        doc = doc_ref.get()

        if not doc.exists:
            raise HTTPException(status_code=404, detail="Premio non trovato")

        # Soft-delete: disattiva e segna come eliminato invece di cancellare
        doc_ref.update({
            'is_active': False,
            'deleted_at': firestore.SERVER_TIMESTAMP,
            'deleted_by': requester['uid'],
        })
        logger.info("reward_soft_deleted", reward_id=reward_id, by=requester['uid'])
        return {"message": "Premio disattivato"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("delete_reward_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante la disattivazione del premio.")


# --- Admin: gestione claim ---

@router.get("/admin/rewards/claims")
@limiter.limit("60/minute")
async def get_all_claims(
    request: Request,
    # [FIX R-5] Validazione strict del parametro status
    status: Optional[Literal['pending', 'fulfilled']] = None,
    requester: dict = Depends(verify_admin),
):
    """Lista tutti i premi riscattati (con filtro opzionale per status)."""
    try:
        db = firebase_admin.firestore.client()
        query = db.collection_group('claimed_rewards').order_by(
            'claimed_at', direction=firestore.Query.DESCENDING
        ).limit(200)

        if status:
            query = query.where('status', '==', status)

        claims = []
        for doc in query.stream():
            data = doc.to_dict()
            data['id'] = doc.id
            data['user_uid'] = doc.reference.parent.parent.id
            claims.append(data)

        return {"claims": claims}
    except Exception as e:
        logger.error("get_all_claims_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante il caricamento dei riscatti.")


@router.post("/admin/rewards/claims/{user_uid}/{claim_id}/fulfill")
@limiter.limit("60/minute")
async def fulfill_claim(
    request: Request,
    user_uid: str,
    claim_id: str,
    requester: dict = Depends(verify_admin),
):
    """Segna un premio riscattato come evaso."""
    try:
        db = firebase_admin.firestore.client()
        doc_ref = db.collection('users').document(user_uid).collection(
            'claimed_rewards'
        ).document(claim_id)

        # [FIX R-8] Ri-verifica status dentro transazione per evitare di
        # sovrascrivere fulfilled_at/fulfilled_by di un claim già evaso
        # (idempotency + preservazione dati storici).
        @firestore.transactional
        def _fulfill_txn(transaction):
            snap = doc_ref.get(transaction=transaction)
            if not snap.exists:
                raise HTTPException(status_code=404, detail="Riscatto non trovato")
            current_status = snap.to_dict().get('status')
            if current_status != 'pending':
                raise HTTPException(
                    status_code=409,
                    detail=f"Riscatto non evadibile (status: {current_status}).",
                )
            transaction.update(doc_ref, {
                'status': 'fulfilled',
                'fulfilled_at': firestore.SERVER_TIMESTAMP,
                'fulfilled_by': requester['uid'],
            })

        _fulfill_txn(db.transaction())

        logger.info("claim_fulfilled", claim_id=claim_id, user_uid=user_uid, by=requester['uid'])
        return {"message": "Premio evaso"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("fulfill_claim_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante l'evasione del premio.")


# --- Client endpoints ---

@router.get("/rewards/catalog")
@limiter.limit("60/minute")
async def get_public_catalog(
    request: Request,
    token: dict = Depends(verify_token),
):
    """Catalogo premi visibile agli utenti (solo attivi)."""
    try:
        db = firebase_admin.firestore.client()
        # [FIX R-7] .limit(200) per evitare reads illimitate lato client.
        docs = db.collection('rewards_catalog').where(
            'is_active', '==', True
        ).order_by('xp_cost').limit(200).stream()

        rewards = []
        for doc in docs:
            data = doc.to_dict()
            data['id'] = doc.id
            # Non esporre campi interni
            data.pop('created_by', None)
            rewards.append(data)

        return {"rewards": rewards}
    except Exception as e:
        logger.error("get_public_catalog_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante il caricamento del catalogo.")


@router.post("/rewards/claim/{reward_id}")
@limiter.limit("10/hour")
async def claim_reward(
    request: Request,
    reward_id: str,
    uid: str = Depends(get_current_uid),
):
    """Riscatta un premio spendendo XP."""
    try:
        db = firebase_admin.firestore.client()

        # Verifica che il premio esista ed sia attivo
        reward_ref = db.collection('rewards_catalog').document(reward_id)
        reward_doc = reward_ref.get()

        if not reward_doc.exists:
            raise HTTPException(status_code=404, detail="Premio non trovato")

        reward_data = reward_doc.to_dict()
        if not reward_data.get('is_active', False):
            raise HTTPException(status_code=400, detail="Premio non disponibile")

        xp_cost = reward_data.get('xp_cost', 0)
        stock = reward_data.get('stock')

        # Verifica stock (pre-check ottimistico, ri-verificato dentro la transazione)
        if stock is not None and stock <= 0:
            raise HTTPException(status_code=400, detail="Premio esaurito")

        # Verifica XP dell'utente (pre-check ottimistico)
        user_ref = db.collection('users').document(uid)
        user_doc = user_ref.get()

        if not user_doc.exists:
            raise HTTPException(status_code=404, detail="Utente non trovato")

        user_data = user_doc.to_dict()
        user_xp = (user_data.get('xp_total') or 0)

        if user_xp < xp_cost:
            raise HTTPException(
                status_code=400,
                detail=f"XP insufficienti. Hai {user_xp} XP, servono {xp_cost} XP."
            )

        # Transazione atomica: sottrai XP + decrementa stock + crea claim
        @firestore.transactional
        def claim_transaction(transaction):
            # Ri-leggi dentro la transazione (valori autoritativi)
            u_snap = user_ref.get(transaction=transaction)
            r_snap = reward_ref.get(transaction=transaction)

            u_data = u_snap.to_dict()
            r_data = r_snap.to_dict()

            current_xp = u_data.get('xp_total', 0)
            current_stock = r_data.get('stock')

            if current_xp < xp_cost:
                raise HTTPException(status_code=400, detail="XP insufficienti")
            if current_stock is not None and current_stock <= 0:
                raise HTTPException(status_code=400, detail="Premio esaurito")

            # [FIX L-2] Ri-verifica is_active dentro la transazione
            if not r_data.get('is_active', False):
                raise HTTPException(status_code=400, detail="Premio non più disponibile")

            # Ogni claim è un record storico indipendente (document ID random).
            # I premi sono riscattabili più volte se l'utente ha XP sufficienti e
            # lo stock lo permette — non c'è dedup per (user, reward) a design.
            # La protezione da race-condition è garantita dalla transazione atomica
            # su xp_total e stock; i rate limit (10/hour) attenuano i click multipli.
            claim_ref = user_ref.collection('claimed_rewards').document()

            new_xp = current_xp - xp_cost

            # Sottrai XP
            transaction.update(user_ref, {'xp_total': new_xp})

            # Decrementa stock se limitato
            if current_stock is not None:
                transaction.update(reward_ref, {
                    'stock': current_stock - 1,
                    # [FIX M-6] Mantieni claim_count sul documento per evitare N+1 queries
                    'claim_count': firestore.Increment(1),
                })
            else:
                transaction.update(reward_ref, {
                    'claim_count': firestore.Increment(1),
                })

            # Crea il claim
            transaction.set(claim_ref, {
                'reward_id': reward_id,
                'reward_name': r_data.get('name', ''),
                'xp_spent': xp_cost,
                'status': 'pending',
                'claimed_at': firestore.SERVER_TIMESTAMP,
            })

            return claim_ref.id, new_xp

        transaction = db.transaction()
        claim_id, actual_new_xp = claim_transaction(transaction)

        logger.info("reward_claimed", reward_id=reward_id, uid=uid, xp_spent=xp_cost)
        return {
            "message": "Premio riscattato!",
            "claim_id": claim_id,
            "xp_spent": xp_cost,
            # [FIX L-5] Usa il valore XP reale post-transazione, non il pre-check
            "new_xp_total": actual_new_xp,
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error("claim_reward_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante il riscatto del premio.")


@router.get("/rewards/my-claims")
@limiter.limit("60/minute")
async def get_my_claims(
    request: Request,
    uid: str = Depends(get_current_uid),
):
    """Storico premi riscattati dall'utente corrente."""
    try:
        db = firebase_admin.firestore.client()
        docs = db.collection('users').document(uid).collection(
            'claimed_rewards'
        ).order_by(
            'claimed_at', direction=firestore.Query.DESCENDING
        ).limit(50).stream()

        claims = []
        for doc in docs:
            data = doc.to_dict()
            data['id'] = doc.id
            claims.append(data)

        return {"claims": claims}
    except Exception as e:
        logger.error("get_my_claims_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante il caricamento dei riscatti.")
