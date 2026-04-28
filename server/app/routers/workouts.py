"""
Router per la gestione schede allenamento (Personal Trainer).
- CRUD schede allenamento (professionista)
- Visualizzazione schede (utente assegnato)
- Assegnazione schede a utenti specifici
"""
import datetime
from typing import Optional, List

import firebase_admin
from firebase_admin import firestore
from fastapi import APIRouter, HTTPException, Depends, Request
from pydantic import BaseModel, Field

from app.core.dependencies import verify_professional, get_current_uid
from app.core.logging import logger, sanitize_error_message
from app.core.limiter import limiter

router = APIRouter(tags=["workouts"])


# --- Models ---

class Exercise(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    sets: Optional[int] = Field(None, ge=1, le=100)
    reps: Optional[str] = Field(None, max_length=50)  # e.g. "8-12", "AMRAP"
    rest_seconds: Optional[int] = Field(None, ge=0, le=600)
    notes: Optional[str] = Field(None, max_length=500)
    order: int = Field(0, ge=0)


class WorkoutDay(BaseModel):
    day_name: str = Field(..., min_length=1, max_length=50)  # e.g. "Lunedì", "Push Day"
    exercises: List[Exercise] = []
    notes: Optional[str] = Field(None, max_length=1000)


class CreateWorkoutPlanRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = Field(None, max_length=1000)
    days: List[WorkoutDay] = []
    target_uid: Optional[str] = Field(None, max_length=200)
    # is_template=True crea un piano riutilizzabile (non assegnato a nessuno).
    # Se True, target_uid viene ignorato.
    is_template: bool = False


class UpdateWorkoutPlanRequest(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=200)
    description: Optional[str] = Field(None, max_length=1000)
    days: Optional[List[WorkoutDay]] = None
    is_active: Optional[bool] = None


# --- Professional endpoints ---

@router.get("/workouts/plans")
@limiter.limit("60/minute")
async def get_workout_plans(
    request: Request,
    requester: dict = Depends(verify_professional),
):
    """Lista tutte le schede create dal professionista."""
    try:
        db = firebase_admin.firestore.client()
        # [FIX W-4] .limit(100) evita query illimitata quando un PT accumula
        # centinaia di schede nel tempo. Se serve vedere l'archivio completo
        # aggiungere in futuro paginazione con cursor (startAfter).
        docs = db.collection('workout_plans').where(
            'created_by', '==', requester['uid']
        ).order_by(
            'created_at', direction=firestore.Query.DESCENDING
        ).limit(100).stream()

        plans = []
        for doc in docs:
            data = doc.to_dict()
            data['id'] = doc.id
            # Serializza timestamps per il client
            for ts_field in ('created_at', 'updated_at', 'deleted_at'):
                if data.get(ts_field):
                    data[ts_field] = data[ts_field].isoformat()
            plans.append(data)

        return {"plans": plans}
    except Exception as e:
        logger.error("get_workout_plans_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante il caricamento delle schede.")


@router.post("/workouts/plans")
@limiter.limit("30/hour")
async def create_workout_plan(
    request: Request,
    body: CreateWorkoutPlanRequest,
    requester: dict = Depends(verify_professional),
):
    """Crea una nuova scheda allenamento."""
    try:
        db = firebase_admin.firestore.client()

        # Se target_uid specificato, verifica che sia un utente del professionista
        if effective_target:
            target_doc = db.collection('users').document(body.target_uid).get()
            if not target_doc.exists:
                raise HTTPException(status_code=404, detail="Utente non trovato")
            target_data = target_doc.to_dict()
            if requester['role'] != 'admin':
                if (target_data.get('parent_id') != requester['uid']
                        and target_data.get('created_by') != requester['uid']
                        and target_data.get('pt_id') != requester['uid']):
                    raise HTTPException(status_code=403, detail="Non puoi assegnare schede a questo utente")

        # [FIX W-1] Atomicità: plan_doc + workout/current assegnato devono
        # essere scritti insieme. Senza batch, un fallimento tra le due
        # scritture lasciava il piano esistente ma non assegnato, oppure
        # la current di un utente agganciata a un piano inesistente.
        plan_ref = db.collection('workout_plans').document()
        plan_id = plan_ref.id

        # [FIX W-3] body.dict() → body.model_dump() per Pydantic v2
        days_dump = [day.model_dump() for day in body.days]

        # I template non hanno target_uid: ignoriamo eventuale valore inviato
        # per evitare inconsistenze (template assegnato non è più un template).
        effective_target = None if body.is_template else body.target_uid
        plan_data = {
            'name': body.name,
            'description': body.description or '',
            'days': days_dump,
            'created_by': requester['uid'],
            'created_at': firestore.SERVER_TIMESTAMP,
            'is_active': True,
            'is_template': body.is_template,
            'target_uid': effective_target,
        }

        batch = db.batch()
        batch.set(plan_ref, plan_data)

        if effective_target:
            current_ref = db.collection('users').document(effective_target).collection(
                'workout'
            ).document('current')
            current_payload = {
                'plan_id': plan_id,
                'plan_name': body.name,
                'assigned_at': firestore.SERVER_TIMESTAMP,
                'assigned_by': requester['uid'],
                'days': days_dump,
            }
            batch.set(current_ref, current_payload)
            # Storico per-utente (mirror del pattern diete): ogni scheda assegnata
            # lascia traccia in users/{uid}/workouts_history/{plan_id} così il
            # client può mostrare lo storico anche quando il PT sostituisce la current.
            history_ref = db.collection('users').document(effective_target).collection(
                'workouts_history'
            ).document(plan_id)
            batch.set(history_ref, {
                **current_payload,
                'name': body.name,
                'description': body.description or '',
            })

        batch.commit()

        logger.info("workout_plan_created", plan_id=plan_id, by=requester['uid'],
                     target=effective_target, is_template=body.is_template)
        return {"id": plan_id, "message": "Scheda creata"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("create_workout_plan_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante la creazione della scheda.")


@router.put("/workouts/plans/{plan_id}")
@limiter.limit("60/minute")
async def update_workout_plan(
    request: Request,
    plan_id: str,
    body: UpdateWorkoutPlanRequest,
    requester: dict = Depends(verify_professional),
):
    """Modifica una scheda allenamento esistente."""
    try:
        db = firebase_admin.firestore.client()
        doc_ref = db.collection('workout_plans').document(plan_id)
        doc = doc_ref.get()

        if not doc.exists:
            raise HTTPException(status_code=404, detail="Scheda non trovata")

        plan_data = doc.to_dict()
        if plan_data.get('created_by') != requester['uid'] and requester['role'] != 'admin':
            raise HTTPException(status_code=403, detail="Non puoi modificare questa scheda")

        update_data = {'updated_at': firestore.SERVER_TIMESTAMP}
        if body.name is not None:
            update_data['name'] = body.name
        if body.description is not None:
            update_data['description'] = body.description
        if body.days is not None:
            update_data['days'] = [day.model_dump() for day in body.days]
        if body.is_active is not None:
            update_data['is_active'] = body.is_active

        doc_ref.update(update_data)

        # [FIX M-8] Aggiorna workout/current SOLO se è ancora questo il piano attivo
        # [FIX W-7] Propaga anche rinomine (body.name) non solo cambi di body.days,
        # altrimenti il client vedeva il nome stale sul doc 'current'.
        target_uid = plan_data.get('target_uid')
        needs_current_sync = target_uid and (body.days is not None or body.name is not None)
        if needs_current_sync:
            current_ref = db.collection('users').document(target_uid).collection(
                'workout'
            ).document('current')
            current_doc = current_ref.get()
            if current_doc.exists and current_doc.to_dict().get('plan_id') == plan_id:
                current_update = {'updated_at': firestore.SERVER_TIMESTAMP}
                if body.days is not None:
                    current_update['days'] = [day.model_dump() for day in body.days]
                if body.name is not None:
                    current_update['plan_name'] = body.name
                current_ref.update(current_update)
                # Sync anche il record di storico (mirror pattern diete)
                history_ref = db.collection('users').document(target_uid).collection(
                    'workouts_history'
                ).document(plan_id)
                history_update = dict(current_update)
                if body.name is not None:
                    history_update['name'] = body.name
                if body.description is not None:
                    history_update['description'] = body.description
                history_ref.set(history_update, merge=True)

        logger.info("workout_plan_updated", plan_id=plan_id, by=requester['uid'])
        return {"message": "Scheda aggiornata"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("update_workout_plan_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante l'aggiornamento della scheda.")


@router.delete("/workouts/plans/{plan_id}")
@limiter.limit("20/hour")
async def delete_workout_plan(
    request: Request,
    plan_id: str,
    requester: dict = Depends(verify_professional),
):
    """Elimina una scheda allenamento."""
    try:
        db = firebase_admin.firestore.client()
        doc_ref = db.collection('workout_plans').document(plan_id)
        doc = doc_ref.get()

        if not doc.exists:
            raise HTTPException(status_code=404, detail="Scheda non trovata")

        plan_data = doc.to_dict()
        if plan_data.get('created_by') != requester['uid'] and requester['role'] != 'admin':
            raise HTTPException(status_code=403, detail="Non puoi eliminare questa scheda")

        # [FIX W-5] Soft-delete: mantieni storico (utenti che hanno completato
        # allenamenti di questo piano devono poter consultare i dati anche
        # dopo la cancellazione). Rimuoviamo solo l'assegnazione attiva.
        target_uid = plan_data.get('target_uid')
        batch = db.batch()

        batch.update(doc_ref, {
            'is_active': False,
            'deleted_at': firestore.SERVER_TIMESTAMP,
            'deleted_by': requester['uid'],
        })

        # [FIX L-6] Rimuovi workout/current se corrisponde a questo piano
        if target_uid:
            current_ref = db.collection('users').document(target_uid).collection(
                'workout'
            ).document('current')
            current_doc = current_ref.get()
            if current_doc.exists and current_doc.to_dict().get('plan_id') == plan_id:
                batch.delete(current_ref)

        batch.commit()

        logger.info("workout_plan_deleted", plan_id=plan_id, by=requester['uid'])
        return {"message": "Scheda eliminata"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("delete_workout_plan_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante l'eliminazione della scheda.")


@router.post("/workouts/plans/{plan_id}/assign/{target_uid}")
@limiter.limit("30/hour")
async def assign_workout_plan(
    request: Request,
    plan_id: str,
    target_uid: str,
    requester: dict = Depends(verify_professional),
):
    """Assegna una scheda esistente a un utente."""
    try:
        db = firebase_admin.firestore.client()

        # Verifica piano
        plan_ref = db.collection('workout_plans').document(plan_id)
        plan_doc = plan_ref.get()
        if not plan_doc.exists:
            raise HTTPException(status_code=404, detail="Scheda non trovata")

        plan_data = plan_doc.to_dict()
        if plan_data.get('created_by') != requester['uid'] and requester['role'] != 'admin':
            raise HTTPException(status_code=403, detail="Non puoi assegnare questa scheda")

        # Verifica utente
        target_doc = db.collection('users').document(target_uid).get()
        if not target_doc.exists:
            raise HTTPException(status_code=404, detail="Utente non trovato")

        if requester['role'] != 'admin':
            target_data = target_doc.to_dict()
            if (target_data.get('parent_id') != requester['uid']
                    and target_data.get('created_by') != requester['uid']
                    and target_data.get('pt_id') != requester['uid']):
                raise HTTPException(status_code=403, detail="Non puoi assegnare schede a questo utente")

        # [FIX W-2] Se il piano era già assegnato a un altro utente, puliamo
        # la sua workout/current se ancora punta a questo plan_id. Senza
        # questo cleanup, il vecchio target continuerebbe a vedere la
        # scheda in "my-plan" anche dopo la riassegnazione, e le successive
        # modifiche/cancellazioni del piano (che guardano solo target_uid)
        # non toccherebbero più quel documento stale.
        # [FIX W-8] Wrap in transaction: ri-legge il piano sotto lock per
        # prevenire race tra due riassegnazioni concorrenti (es. admin + PT
        # che assegnano insieme) che lasciavano workout/current intermedi
        # orfani. Il pre-check di permission sopra è ancora valido perché
        # created_by non cambia mai.
        previous_target_precheck = plan_data.get('target_uid')
        prev_current_ref = None
        if previous_target_precheck and previous_target_precheck != target_uid:
            prev_current_ref = db.collection('users').document(previous_target_precheck).collection(
                'workout'
            ).document('current')

        new_current_ref = db.collection('users').document(target_uid).collection(
            'workout'
        ).document('current')

        @firestore.transactional
        def _assign_txn(transaction):
            # Ri-leggi piano per avere target_uid autoritativo
            plan_snap = plan_ref.get(transaction=transaction)
            if not plan_snap.exists:
                raise HTTPException(status_code=404, detail="Scheda non trovata")
            current_target = plan_snap.to_dict().get('target_uid')

            # Leggi prev_current dentro la txn se il precheck aveva rilevato un previous target
            if prev_current_ref is not None and current_target == previous_target_precheck:
                prev_snap = prev_current_ref.get(transaction=transaction)
                if prev_snap.exists and prev_snap.to_dict().get('plan_id') == plan_id:
                    transaction.delete(prev_current_ref)

            # Salva come scheda corrente del nuovo utente
            current_payload = {
                'plan_id': plan_id,
                'plan_name': plan_snap.to_dict().get('name', ''),
                'assigned_at': firestore.SERVER_TIMESTAMP,
                'assigned_by': requester['uid'],
                'days': plan_snap.to_dict().get('days', []),
            }
            transaction.set(new_current_ref, current_payload)
            # Storico per-utente (mirror pattern diete)
            history_ref = db.collection('users').document(target_uid).collection(
                'workouts_history'
            ).document(plan_id)
            transaction.set(history_ref, {
                **current_payload,
                'name': plan_snap.to_dict().get('name', ''),
                'description': plan_snap.to_dict().get('description', ''),
            })

            # Aggiorna il piano con il nuovo target_uid
            transaction.update(plan_ref, {
                'target_uid': target_uid,
                'updated_at': firestore.SERVER_TIMESTAMP,
            })

            return current_target

        previous_target = _assign_txn(db.transaction())

        logger.info(
            "workout_assigned",
            plan_id=plan_id, target=target_uid, by=requester['uid'],
            previous_target=previous_target,
        )
        return {"message": "Scheda assegnata"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("assign_workout_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante l'assegnazione della scheda.")


@router.post("/workouts/plans/{plan_id}/clone-and-assign/{target_uid}")
@limiter.limit("30/hour")
async def clone_and_assign_workout_plan(
    request: Request,
    plan_id: str,
    target_uid: str,
    requester: dict = Depends(verify_professional),
):
    """Clona una scheda (tipicamente un template) e assegna la copia a un utente.
    A differenza di /assign che mutava il target_uid del piano originale, qui
    creiamo un nuovo plan_doc così il template resta intatto e riutilizzabile.
    """
    try:
        db = firebase_admin.firestore.client()

        # Carica la scheda sorgente
        src_ref = db.collection('workout_plans').document(plan_id)
        src_doc = src_ref.get()
        if not src_doc.exists:
            raise HTTPException(status_code=404, detail="Scheda non trovata")

        src_data = src_doc.to_dict()
        if src_data.get('created_by') != requester['uid'] and requester['role'] != 'admin':
            raise HTTPException(status_code=403, detail="Non puoi clonare questa scheda")

        # Verifica che il target esista e sia gestito dal requester (se non admin)
        target_doc = db.collection('users').document(target_uid).get()
        if not target_doc.exists:
            raise HTTPException(status_code=404, detail="Utente non trovato")
        if requester['role'] != 'admin':
            target_data = target_doc.to_dict()
            if (target_data.get('parent_id') != requester['uid']
                    and target_data.get('created_by') != requester['uid']
                    and target_data.get('pt_id') != requester['uid']):
                raise HTTPException(status_code=403, detail="Non puoi assegnare schede a questo utente")

        new_ref = db.collection('workout_plans').document()
        new_id = new_ref.id

        new_plan = {
            'name': src_data.get('name', ''),
            'description': src_data.get('description', ''),
            'days': src_data.get('days', []),
            'created_by': requester['uid'],
            'created_at': firestore.SERVER_TIMESTAMP,
            'is_active': True,
            'is_template': False,
            'target_uid': target_uid,
            'cloned_from': plan_id,
        }

        current_ref = db.collection('users').document(target_uid).collection(
            'workout'
        ).document('current')
        history_ref = db.collection('users').document(target_uid).collection(
            'workouts_history'
        ).document(new_id)

        current_payload = {
            'plan_id': new_id,
            'plan_name': new_plan['name'],
            'assigned_at': firestore.SERVER_TIMESTAMP,
            'assigned_by': requester['uid'],
            'days': new_plan['days'],
        }

        batch = db.batch()
        batch.set(new_ref, new_plan)
        batch.set(current_ref, current_payload)
        batch.set(history_ref, {
            **current_payload,
            'name': new_plan['name'],
            'description': new_plan['description'],
        })
        batch.commit()

        logger.info(
            "workout_template_cloned",
            source=plan_id, new=new_id, target=target_uid, by=requester['uid'],
        )
        return {"id": new_id, "message": "Template clonato e assegnato"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("clone_workout_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante il clone della scheda.")


# --- Client endpoints ---

@router.get("/workouts/my-plan")
@limiter.limit("60/minute")
async def get_my_workout(
    request: Request,
    uid: str = Depends(get_current_uid),
):
    """Ritorna la scheda allenamento corrente dell'utente."""
    try:
        db = firebase_admin.firestore.client()
        doc = db.collection('users').document(uid).collection(
            'workout'
        ).document('current').get()

        if not doc.exists:
            return {"plan": None}

        data = doc.to_dict()
        # [FIX W-6] Serializza Timestamp Firestore per il client Flutter
        for ts_field in ('assigned_at', 'updated_at'):
            if data.get(ts_field):
                data[ts_field] = data[ts_field].isoformat()
        return {"plan": data}
    except Exception as e:
        logger.error("get_my_workout_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante il caricamento della scheda.")


@router.get("/workouts/history")
@limiter.limit("60/minute")
async def get_workout_history(
    request: Request,
    uid: str = Depends(get_current_uid),
):
    """Storico schede allenamento assegnate all'utente (mirror del pattern diete)."""
    try:
        db = firebase_admin.firestore.client()
        docs = db.collection('users').document(uid).collection(
            'workouts_history'
        ).order_by('assigned_at', direction=firestore.Query.DESCENDING).limit(50).stream()

        history = []
        for doc in docs:
            data = doc.to_dict()
            data['id'] = doc.id
            for ts_field in ('assigned_at', 'updated_at'):
                if data.get(ts_field) and hasattr(data[ts_field], 'isoformat'):
                    data[ts_field] = data[ts_field].isoformat()
            history.append(data)

        return {"history": history}
    except Exception as e:
        logger.error("get_workout_history_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante il caricamento dello storico.")


_WORKOUT_XP = 30  # XP assegnati per ogni allenamento completato


@router.post("/workouts/complete-day")
@limiter.limit("5/day")
async def complete_workout_day(
    request: Request,
    uid: str = Depends(get_current_uid),
):
    """Segna l'allenamento del giorno come completato e assegna XP.
    Può essere chiamato una sola volta per giorno solare (UTC).
    Usa una transazione Firestore per prevenire doppi crediti concorrenti.
    """
    try:
        db = firebase_admin.firestore.client()

        # [FIX M-2] Usa sempre UTC per evitare ambiguità di timezone
        today = datetime.datetime.now(datetime.timezone.utc).date().isoformat()

        # Verifica che l'utente abbia una scheda assegnata
        plan_doc = db.collection('users').document(uid).collection(
            'workout'
        ).document('current').get()
        if not plan_doc.exists:
            raise HTTPException(status_code=404, detail="Nessuna scheda allenamento assegnata.")

        user_ref = db.collection('users').document(uid)
        completion_ref = user_ref.collection('workout_completions').document(today)

        # [FIX C-1] Usa transazione atomica invece di batch+pre-check separato.
        # Senza transazione, due richieste concorrenti possono entrambe passare
        # il check "non esiste" e assegnare XP doppi.
        @firestore.transactional
        def _complete_txn(transaction):
            snap = completion_ref.get(transaction=transaction)
            if snap.exists:
                return False  # già completato oggi

            xp_history_ref = user_ref.collection('xp_history').document()

            transaction.set(completion_ref, {
                'completed_at': firestore.SERVER_TIMESTAMP,
                'xp_awarded': _WORKOUT_XP,
            })
            # [FIX C-3] Usa xp_total — campo canonico usato dal client (XpService.dart)
            transaction.update(user_ref, {'xp_total': firestore.Increment(_WORKOUT_XP)})
            transaction.set(xp_history_ref, {
                'amount': _WORKOUT_XP,
                'reason': 'workout_completed',
                'created_at': firestore.SERVER_TIMESTAMP,
            })
            return True

        txn = db.transaction()
        completed = _complete_txn(txn)

        if not completed:
            raise HTTPException(status_code=409, detail="Allenamento già completato oggi!")

        logger.info("workout_completed", uid=uid, date=today, xp=_WORKOUT_XP)
        return {"message": "Ottimo lavoro!", "xp_awarded": _WORKOUT_XP}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("complete_workout_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante il completamento.")


class WorkoutFeedbackBody(BaseModel):
    rating: str = Field(..., description="easy | ok | hard")
    note: Optional[str] = Field(None, max_length=300)


@router.post("/workouts/feedback")
@limiter.limit("10/day")
async def submit_workout_feedback(
    request: Request,
    body: WorkoutFeedbackBody,
    uid: str = Depends(get_current_uid),
):
    """Salva il feedback (3 livelli emoji) sull'allenamento di oggi.
    Viene scritto sul documento workout_completions/{YYYY-MM-DD} così che
    il PT possa vedere il rating insieme al completamento.
    """
    if body.rating not in ("easy", "ok", "hard"):
        raise HTTPException(status_code=400, detail="Rating non valido.")
    try:
        db = firebase_admin.firestore.client()
        today = datetime.datetime.now(datetime.timezone.utc).date().isoformat()
        completion_ref = (
            db.collection('users').document(uid)
            .collection('workout_completions').document(today)
        )
        snap = completion_ref.get()
        if not snap.exists:
            raise HTTPException(status_code=404, detail="Nessun allenamento completato oggi.")

        update_data = {
            'feedback': body.rating,
            'feedback_at': firestore.SERVER_TIMESTAMP,
        }
        if body.note:
            update_data['feedback_note'] = body.note
        completion_ref.update(update_data)

        logger.info("workout_feedback_saved", uid=uid, date=today, rating=body.rating)
        return {"message": "Grazie per il feedback!"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("workout_feedback_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante il salvataggio del feedback.")
