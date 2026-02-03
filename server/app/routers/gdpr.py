"""
Router GDPR per la gestione della privacy e dei dati personali.
- Registrazione consenso
- Export dati (data portability)
- Revoca consenso
"""
from datetime import datetime, timezone
from typing import Optional

import firebase_admin
from firebase_admin import firestore
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel

from app.core.dependencies import verify_token, verify_professional
from app.core.logging import logger, sanitize_error_message

router = APIRouter(prefix="/gdpr", tags=["gdpr"])


# --- SCHEMAS ---
class ConsentRequest(BaseModel):
    consent_type: str  # "privacy_policy", "marketing", "analytics"
    granted: bool
    version: str  # Versione del documento accettato (es. "1.0")


class ConsentResponse(BaseModel):
    consent_type: str
    granted: bool
    version: str
    timestamp: str
    ip_address: Optional[str] = None


# --- CONSENT ENDPOINTS ---
@router.post("/consent")
async def record_consent(
    body: ConsentRequest,
    user_data: dict = Depends(verify_token)
):
    """
    Registra il consenso dell'utente (GDPR Art. 7).
    Tracciata con timestamp, versione e IP per compliance.
    """
    try:
        db = firebase_admin.firestore.client()
        user_id = user_data['uid']
        timestamp = datetime.now(timezone.utc).isoformat()
        
        consent_record = {
            "consent_type": body.consent_type,
            "granted": body.granted,
            "version": body.version,
            "timestamp": timestamp,
            "recorded_at": firebase_admin.firestore.SERVER_TIMESTAMP,
        }
        
        # Salva nel documento utente
        db.collection('users').document(user_id).set({
            f"consent_{body.consent_type}": consent_record
        }, merge=True)
        
        # Log immutabile per audit trail
        db.collection('consent_logs').add({
            "user_id": user_id,
            **consent_record
        })
        
        logger.info("consent_recorded", 
                   user_id=user_id, 
                   consent_type=body.consent_type, 
                   granted=body.granted)
        
        return {"message": "Consent recorded", "timestamp": timestamp}
        
    except Exception as e:
        logger.error("consent_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante la registrazione del consenso")


@router.get("/consent")
async def get_consents(user_data: dict = Depends(verify_token)):
    """
    Restituisce lo stato dei consensi dell'utente.
    """
    try:
        db = firebase_admin.firestore.client()
        user_id = user_data['uid']
        
        user_doc = db.collection('users').document(user_id).get()
        if not user_doc.exists:
            raise HTTPException(status_code=404, detail="User not found")
        
        data = user_doc.to_dict()
        consents = {}
        
        for key, value in data.items():
            if key.startswith("consent_") and isinstance(value, dict):
                consent_type = key.replace("consent_", "")
                consents[consent_type] = value
        
        return {"consents": consents}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error("get_consent_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante il recupero dei consensi")


# --- DATA EXPORT (GDPR Art. 20 - Portabilità) ---
@router.get("/export")
async def export_user_data(user_data: dict = Depends(verify_token)):
    """
    Esporta tutti i dati dell'utente in formato JSON (GDPR Art. 20).
    Include: profilo, diete, storico, log.
    """
    try:
        db = firebase_admin.firestore.client()
        user_id = user_data['uid']
        
        export_data = {
            "export_date": datetime.now(timezone.utc).isoformat(),
            "user_id": user_id,
            "profile": None,
            "diets": [],
            "diet_history": [],
            "consent_logs": []
        }
        
        # 1. Profilo utente
        user_doc = db.collection('users').document(user_id).get()
        if user_doc.exists:
            profile = user_doc.to_dict()
            # Rimuovi campi interni/sensibili
            for key in ['requires_password_change', 'created_by']:
                profile.pop(key, None)
            export_data["profile"] = profile
        
        # 2. Dieta corrente (subcollection)
        current_diet = db.collection('users').document(user_id).collection('diet').get()
        for doc in current_diet:
            data = doc.to_dict()
            data['_doc_id'] = doc.id
            export_data["diets"].append(data)
        
        # 3. Storico diete
        diet_history = db.collection('diet_history').where('userId', '==', user_id).stream()
        for doc in diet_history:
            data = doc.to_dict()
            data['_doc_id'] = doc.id
            # Converti timestamp in stringa
            if 'uploadedAt' in data and hasattr(data['uploadedAt'], 'isoformat'):
                data['uploadedAt'] = data['uploadedAt'].isoformat()
            export_data["diet_history"].append(data)
        
        # 4. Log consensi
        consent_logs = db.collection('consent_logs').where('user_id', '==', user_id).stream()
        for doc in consent_logs:
            data = doc.to_dict()
            if 'recorded_at' in data and hasattr(data['recorded_at'], 'isoformat'):
                data['recorded_at'] = data['recorded_at'].isoformat()
            export_data["consent_logs"].append(data)
        
        logger.info("data_export_completed", user_id=user_id)
        
        return export_data
        
    except Exception as e:
        logger.error("export_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante l'export dei dati")


# --- ADMIN: EXPORT DATI CLIENTE ---
@router.get("/export/{target_uid}")
async def admin_export_user_data(
    target_uid: str,
    requester: dict = Depends(verify_professional)
):
    """
    Admin/Nutrizionista esporta i dati di un cliente (per richieste GDPR).
    """
    try:
        db = firebase_admin.firestore.client()
        requester_role = requester['role']
        requester_id = requester['uid']
        
        # Verifica permessi
        if requester_role == 'nutritionist':
            user_doc = db.collection('users').document(target_uid).get()
            if not user_doc.exists:
                raise HTTPException(status_code=404, detail="User not found")
            user_data = user_doc.to_dict()
            if user_data.get('parent_id') != requester_id:
                raise HTTPException(status_code=403, detail="Not authorized to export this user's data")
        
        # Log accesso dati (audit trail)
        db.collection('access_logs').add({
            'requester_id': requester_id,
            'target_uid': target_uid,
            'action': 'GDPR_DATA_EXPORT',
            'reason': 'GDPR Art. 20 Data Portability Request',
            'timestamp': firebase_admin.firestore.SERVER_TIMESTAMP
        })
        
        # Riusa la logica di export
        fake_user_data = {'uid': target_uid}
        return await export_user_data(fake_user_data)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error("admin_export_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante l'export dei dati")
