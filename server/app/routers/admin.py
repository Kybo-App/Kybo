"""
Router per endpoint amministrativi.
- Sincronizzazione utenti
- Configurazione parser
- Gateway sicuro per accesso dati
- Modalità manutenzione
"""
import asyncio
from typing import Optional

import firebase_admin
from firebase_admin import auth, firestore
from fastapi import APIRouter, UploadFile, File, HTTPException, Depends, Request
from fastapi.concurrency import run_in_threadpool
from pydantic import BaseModel

from app.core.dependencies import verify_admin, verify_professional
from app.core.logging import logger, sanitize_error_message
from app.broadcast import broadcast_message

router = APIRouter(prefix="/admin", tags=["admin"])


# --- SCHEMAS ---
class MaintenanceRequest(BaseModel):
    enabled: bool
    message: Optional[str] = None


class ScheduleMaintenanceRequest(BaseModel):
    scheduled_time: str
    message: str
    notify: bool


class LogAccessRequest(BaseModel):
    target_uid: str
    reason: str


# --- SYNC USERS ---
@router.post("/sync-users")
async def admin_sync_users(request: Request, requester: dict = Depends(verify_admin)):
    """Sincronizza utenti Firebase Auth con Firestore."""
    try:
        db = firebase_admin.firestore.client()
        users_ref = db.collection('users')
        firestore_docs = users_ref.stream()

        firestore_map = {}
        firestore_emails = {}

        for doc in firestore_docs:
            data = doc.to_dict()
            firestore_map[doc.id] = data
            email = data.get('email', '').lower()
            if email:
                if email not in firestore_emails:
                    firestore_emails[email] = []
                firestore_emails[email].append(doc.id)

        batch = db.batch()
        batch_operations = 0
        MAX_BATCH_SIZE = 500
        claims_to_update = []

        auth_users = auth.list_users().users

        for user in auth_users:
            email_lower = user.email.lower() if user.email else ''

            if email_lower in firestore_emails:
                for uid in firestore_emails[email_lower]:
                    if uid != user.uid:
                        batch.delete(users_ref.document(uid))
                        batch_operations += 1
                        if batch_operations >= MAX_BATCH_SIZE:
                            batch.commit()
                            batch = db.batch()
                            batch_operations = 0

            if user.uid in firestore_map:
                current_role = firestore_map[user.uid].get('role', 'independent')
            else:
                current_role = 'independent'
                batch.set(users_ref.document(user.uid), {
                    'uid': user.uid,
                    'email': user.email,
                    'role': 'independent',
                    'first_name': 'App',
                    'last_name': '',
                    'created_at': firebase_admin.firestore.SERVER_TIMESTAMP
                })
                batch_operations += 1
                if batch_operations >= MAX_BATCH_SIZE:
                    batch.commit()
                    batch = db.batch()
                    batch_operations = 0

            claims_to_update.append((user.uid, current_role))

        if batch_operations > 0:
            batch.commit()

        # Parallelizza aggiornamento claims
        CLAIMS_CHUNK_SIZE = 10

        async def update_claim(uid: str, role: str):
            await run_in_threadpool(auth.set_custom_user_claims, uid, {'role': role})

        for i in range(0, len(claims_to_update), CLAIMS_CHUNK_SIZE):
            chunk = claims_to_update[i:i + CLAIMS_CHUNK_SIZE]
            tasks = [update_claim(uid, role) for uid, role in chunk]
            await asyncio.gather(*tasks)

        return {"message": f"Synced {len(claims_to_update)} users efficiently (parallelized)"}

    except Exception as e:
        logger.error("sync_users_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante la sincronizzazione degli utenti.")


@router.post("/upload-parser/{target_uid}")
async def upload_parser_config(
    target_uid: str,
    file: UploadFile = File(...),
    requester: dict = Depends(verify_admin)
):
    """Carica configurazione parser personalizzata per un nutrizionista."""
    requester_id = requester['uid']
    try:
        content = (await file.read()).decode("utf-8")
        db = firebase_admin.firestore.client()
        db.collection('users').document(target_uid).update({
            'custom_parser_prompt': content,
            'has_custom_parser': True,
            'parser_updated_at': firebase_admin.firestore.SERVER_TIMESTAMP
        })
        db.collection('users').document(target_uid).collection('parser_history').add({
            'content': content,
            'uploadedAt': firebase_admin.firestore.SERVER_TIMESTAMP,
            'uploadedBy': requester_id
        })
        return {"message": "Updated"}
    except Exception as e:
        logger.error("upload_parser_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante l'aggiornamento del parser.")


# --- SECURE GATEWAY ---
@router.post("/log-access")
async def log_access(body: LogAccessRequest, requester: dict = Depends(verify_professional)):
    """Logga un accesso ai dati sensibili."""
    try:
        firebase_admin.firestore.client().collection('access_logs').add({
            'requester_id': requester['uid'],
            'target_uid': body.target_uid,
            'action': 'UNLOCK_PII',
            'reason': body.reason or 'User Unlock',
            'timestamp': firebase_admin.firestore.SERVER_TIMESTAMP,
            'user_agent': 'kybo_admin_panel'
        })
        return {"status": "logged"}
    except Exception:
        raise HTTPException(status_code=500, detail="Failed to log access")


@router.get("/user-history/{target_uid}")
async def get_secure_user_history(target_uid: str, requester: dict = Depends(verify_professional)):
    """Ottiene lo storico diete di un utente."""
    requester_id = requester['uid']
    requester_role = requester['role']

    try:
        db = firebase_admin.firestore.client()

        if requester_role == 'nutritionist':
            user_doc = db.collection('users').document(target_uid).get()
            if not user_doc.exists:
                raise HTTPException(status_code=404, detail="User not found")
            data = user_doc.to_dict()
            if data.get('parent_id') != requester_id and data.get('created_by') != requester_id:
                raise HTTPException(status_code=403, detail="Access denied")

        db.collection('access_logs').add({
            'requester_id': requester_id,
            'target_uid': target_uid,
            'action': 'READ_HISTORY_FULL',
            'reason': 'Diet Review',
            'timestamp': firebase_admin.firestore.SERVER_TIMESTAMP
        })

        history_ref = db.collection('diet_history') \
            .where('userId', '==', target_uid) \
            .order_by('uploadedAt', direction=firestore.Query.DESCENDING) \
            .limit(50)

        results = []
        for doc in history_ref.stream():
            data = doc.to_dict()
            if 'uploadedAt' in data and data['uploadedAt']:
                data['uploadedAt'] = data['uploadedAt'].isoformat()
            data['id'] = doc.id
            results.append(data)

        return results

    except HTTPException:
        raise
    except Exception as e:
        logger.error("secure_gateway_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Error fetching history")


@router.get("/users-secure")
async def list_users_secure(requester: dict = Depends(verify_professional)):
    """Lista utenti con log di accesso."""
    requester_id = requester['uid']
    requester_role = requester['role']

    try:
        db = firebase_admin.firestore.client()
        db.collection('access_logs').add({
            'requester_id': requester_id,
            'action': 'READ_USER_DIRECTORY',
            'reason': 'User List View',
            'timestamp': firebase_admin.firestore.SERVER_TIMESTAMP
        })

        users_ref = db.collection('users')
        if requester_role == 'nutritionist':
            docs = users_ref.where('parent_id', '==', requester_id).stream()
        else:
            docs = users_ref.stream()

        return [d.to_dict() for d in docs]
    except Exception:
        raise HTTPException(status_code=500, detail="Error fetching users")


@router.get("/user-details-secure/{target_uid}")
async def get_user_details_secure(target_uid: str, requester: dict = Depends(verify_professional)):
    """Dettagli utente con log di accesso."""
    requester_id = requester['uid']
    requester_role = requester['role']

    try:
        db = firebase_admin.firestore.client()

        if requester_role == 'nutritionist':
            user_doc = db.collection('users').document(target_uid).get()
            if not user_doc.exists:
                raise HTTPException(status_code=404, detail="User not found")
            if user_doc.to_dict().get('parent_id') != requester_id:
                raise HTTPException(status_code=403, detail="Access denied")

        db.collection('access_logs').add({
            'requester_id': requester_id,
            'target_uid': target_uid,
            'action': 'READ_USER_PROFILE',
            'reason': 'Detail View',
            'timestamp': firebase_admin.firestore.SERVER_TIMESTAMP
        })

        doc = db.collection('users').document(target_uid).get()
        if not doc.exists:
            raise HTTPException(status_code=404, detail="User not found")

        return doc.to_dict()

    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=500, detail="Error fetching profile")


# --- MAINTENANCE ---
@router.get("/config/maintenance")
async def get_maintenance_status(requester: dict = Depends(verify_admin)):
    """Stato modalità manutenzione."""
    doc = firebase_admin.firestore.client().collection('config').document('global').get()
    if doc.exists:
        return {"enabled": doc.to_dict().get('maintenance_mode', False)}
    return {"enabled": False}


@router.post("/config/maintenance")
async def set_maintenance_status(body: MaintenanceRequest, requester: dict = Depends(verify_admin)):
    """Attiva/disattiva modalità manutenzione."""
    data = {'maintenance_mode': body.enabled, 'updated_by': requester['uid']}
    if body.message:
        data['maintenance_message'] = body.message
    firebase_admin.firestore.client().collection('config').document('global').set(data, merge=True)
    return {"message": "Updated"}


@router.post("/schedule-maintenance")
async def schedule_maintenance(req: ScheduleMaintenanceRequest, requester: dict = Depends(verify_admin)):
    """Programma una manutenzione futura."""
    firebase_admin.firestore.client().collection('config').document('global').set({
        "scheduled_maintenance_start": req.scheduled_time,
        "maintenance_message": req.message,
        "is_scheduled": True
    }, merge=True)

    if req.notify:
        try:
            broadcast_message(
                title="System Update",
                body=req.message,
                data={"type": "maintenance_alert"}
            )
        except Exception as broadcast_err:
            logger.error("broadcast_maintenance_error", error=sanitize_error_message(broadcast_err))

    return {"status": "scheduled"}


@router.post("/cancel-maintenance")
async def cancel_maintenance_schedule(requester: dict = Depends(verify_admin)):
    """Annulla una manutenzione programmata."""
    firebase_admin.firestore.client().collection('config').document('global').update({
        "is_scheduled": False,
        "scheduled_maintenance_start": firestore.DELETE_FIELD,
        "maintenance_message": firestore.DELETE_FIELD
    })
    return {"status": "cancelled"}
