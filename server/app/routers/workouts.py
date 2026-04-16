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

from app.core.dependencies import verify_professional, verify_token, get_current_uid
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
        docs = db.collection('workout_plans').where(
            'created_by', '==', requester['uid']
        ).order_by(
            'created_at', direction=firestore.Query.DESCENDING
        ).stream()

        plans = []
        for doc in docs:
            data = doc.to_dict()
            data['id'] = doc.id
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
        if body.target_uid:
            target_doc = db.collection('users').document(body.target_uid).get()
            if not target_doc.exists:
                raise HTTPException(status_code=404, detail="Utente non trovato")
            target_data = target_doc.to_dict()
            if requester['role'] != 'admin':
                if target_data.get('parent_id') != requester['uid'] and target_data.get('created_by') != requester['uid'] and target_data.get('pt_id') != requester['uid']:
                    raise HTTPException(status_code=403, detail="Non puoi assegnare schede a questo utente")

        plan_data = {
            'name': body.name,
            'description': body.description or '',
            'days': [day.dict() for day in body.days],
            'created_by': requester['uid'],
            'created_at': firestore.SERVER_TIMESTAMP,
            'is_active': True,
            'target_uid': body.target_uid,
        }

        doc_ref = db.collection('workout_plans').add(plan_data)
        plan_id = doc_ref[1].id

        # Se assegnato a un utente, salva anche come scheda corrente
        if body.target_uid:
            db.collection('users').document(body.target_uid).collection(
                'workout'
            ).document('current').set({
                'plan_id': plan_id,
                'plan_name': body.name,
                'assigned_at': firestore.SERVER_TIMESTAMP,
                'assigned_by': requester['uid'],
                'days': [day.dict() for day in body.days],
            })

        logger.info("workout_plan_created", plan_id=plan_id, by=requester['uid'],
                     target=body.target_uid)
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
            update_data['days'] = [day.dict() for day in body.days]
        if body.is_active is not None:
            update_data['is_active'] = body.is_active

        doc_ref.update(update_data)

        # Aggiorna anche la scheda assegnata se presente
        target_uid = plan_data.get('target_uid')
        if target_uid and body.days is not None:
            db.collection('users').document(target_uid).collection(
                'workout'
            ).document('current').update({
                'days': [day.dict() for day in body.days],
                'plan_name': body.name or plan_data.get('name', ''),
                'updated_at': firestore.SERVER_TIMESTAMP,
            })

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

        doc_ref.delete()

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
            if target_data.get('parent_id') != requester['uid'] and target_data.get('created_by') != requester['uid'] and target_data.get('pt_id') != requester['uid']:
                raise HTTPException(status_code=403, detail="Non puoi assegnare schede a questo utente")

        # Salva come scheda corrente dell'utente
        db.collection('users').document(target_uid).collection(
            'workout'
        ).document('current').set({
            'plan_id': plan_id,
            'plan_name': plan_data.get('name', ''),
            'assigned_at': firestore.SERVER_TIMESTAMP,
            'assigned_by': requester['uid'],
            'days': plan_data.get('days', []),
        })

        # Aggiorna il piano con il target_uid
        plan_ref.update({
            'target_uid': target_uid,
            'updated_at': firestore.SERVER_TIMESTAMP,
        })

        logger.info("workout_assigned", plan_id=plan_id, target=target_uid, by=requester['uid'])
        return {"message": "Scheda assegnata"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("assign_workout_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante l'assegnazione della scheda.")


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
        return {"plan": data}
    except Exception as e:
        logger.error("get_my_workout_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante il caricamento della scheda.")


_WORKOUT_XP = 30  # XP assegnati per ogni allenamento completato


@router.post("/workouts/complete-day")
@limiter.limit("5/day")
async def complete_workout_day(
    request: Request,
    uid: str = Depends(get_current_uid),
):
    """Segna l'allenamento del giorno come completato e assegna XP.
    Può essere chiamato una sola volta per giorno solare."""
    try:
        db = firebase_admin.firestore.client()
        today = datetime.date.today().isoformat()  # es. "2026-04-16"

        # Verifica che l'utente abbia una scheda assegnata
        plan_doc = db.collection('users').document(uid).collection(
            'workout'
        ).document('current').get()
        if not plan_doc.exists:
            raise HTTPException(status_code=404, detail="Nessuna scheda allenamento assegnata.")

        # Controlla se già completato oggi
        completion_ref = db.collection('users').document(uid).collection(
            'workout_completions'
        ).document(today)
        if completion_ref.get().exists:
            raise HTTPException(status_code=409, detail="Allenamento già completato oggi!")

        # Registra completamento e aggiungi XP in batch
        batch = db.batch()

        # Salva il completamento
        batch.set(completion_ref, {
            'completed_at': firestore.SERVER_TIMESTAMP,
            'xp_awarded': _WORKOUT_XP,
        })

        # Incrementa total_xp nel documento utente
        user_ref = db.collection('users').document(uid)
        batch.update(user_ref, {'total_xp': firestore.Increment(_WORKOUT_XP)})

        # Aggiungi voce allo storico XP
        xp_history_ref = db.collection('users').document(uid).collection(
            'xp_history'
        ).document()
        batch.set(xp_history_ref, {
            'amount': _WORKOUT_XP,
            'reason': 'workout_completed',
            'created_at': firestore.SERVER_TIMESTAMP,
        })

        batch.commit()

        logger.info("workout_completed", uid=uid, date=today, xp=_WORKOUT_XP)
        return {"message": "Ottimo lavoro!", "xp_awarded": _WORKOUT_XP}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("complete_workout_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante il completamento.")
