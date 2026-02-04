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

from app.core.dependencies import verify_token, verify_professional, verify_admin
from app.core.logging import logger, sanitize_error_message
from app.services.gdpr_retention_service import GDPRRetentionService

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
        
        data = user_doc.to_dict() or {}
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
        current_diet = db.collection('users').document(user_id).collection('diets').get()
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


# =============================================================================
# GDPR RETENTION POLICY ENDPOINTS (Admin Only)
# =============================================================================

# --- SCHEMAS RETENTION ---
class RetentionConfigRequest(BaseModel):
    retention_months: int  # Mesi di inattività prima della purge
    is_enabled: bool  # Se la retention automatica è attiva
    dry_run: bool = True  # Se True, simula senza eliminare
    exclude_roles: list[str] = ["admin", "nutritionist"]  # Ruoli esclusi


class PurgeRequest(BaseModel):
    dry_run: bool = True  # Se True, simula senza eliminare
    target_uid: Optional[str] = None  # Se specificato, elimina solo questo utente


# --- RETENTION DASHBOARD ---
@router.get("/admin/dashboard")
async def get_retention_dashboard(
    admin: dict = Depends(verify_admin)
):
    """
    Ritorna la dashboard GDPR con statistiche retention.
    Include: configurazione, utenti inattivi, utenti prossimi alla scadenza.

    Solo Admin.
    """
    try:
        service = GDPRRetentionService()
        dashboard = await service.get_retention_dashboard()

        logger.info(
            "gdpr_dashboard_accessed",
            admin_id=admin['uid'],
            inactive_count=dashboard['statistics']['inactive_users_count']
        )

        return dashboard

    except Exception as e:
        logger.error("gdpr_dashboard_error", error=sanitize_error_message(e))
        raise HTTPException(
            status_code=500,
            detail="Errore durante il caricamento della dashboard GDPR"
        )


# --- RETENTION CONFIG ---
@router.get("/admin/retention-config")
async def get_retention_config(
    admin: dict = Depends(verify_admin)
):
    """
    Ritorna la configurazione retention corrente.

    Solo Admin.
    """
    try:
        service = GDPRRetentionService()
        config = await service.get_retention_config()

        return {
            "retention_months": config.retention_months,
            "is_enabled": config.is_enabled,
            "dry_run": config.dry_run,
            "exclude_roles": config.exclude_roles
        }

    except Exception as e:
        logger.error("gdpr_config_get_error", error=sanitize_error_message(e))
        raise HTTPException(
            status_code=500,
            detail="Errore durante il recupero della configurazione"
        )


@router.post("/admin/retention-config")
async def set_retention_config(
    body: RetentionConfigRequest,
    admin: dict = Depends(verify_admin)
):
    """
    Configura la retention policy GDPR.

    Args:
        retention_months: Mesi di inattività dopo cui eliminare i dati
        is_enabled: Se la retention automatica è attiva
        dry_run: Se True, simula l'eliminazione senza cancellare
        exclude_roles: Ruoli esclusi dalla purge (default: admin, nutritionist)

    Solo Admin.
    """
    try:
        # Validazione
        if body.retention_months < 6:
            raise HTTPException(
                status_code=400,
                detail="Il periodo di retention deve essere almeno 6 mesi"
            )
        if body.retention_months > 120:
            raise HTTPException(
                status_code=400,
                detail="Il periodo di retention non può superare 10 anni"
            )

        service = GDPRRetentionService()
        success = await service.set_retention_config(
            retention_months=body.retention_months,
            is_enabled=body.is_enabled,
            dry_run=body.dry_run,
            exclude_roles=body.exclude_roles,
            updated_by=admin['uid']
        )

        if not success:
            raise HTTPException(
                status_code=500,
                detail="Errore durante il salvataggio della configurazione"
            )

        logger.info(
            "gdpr_config_updated",
            admin_id=admin['uid'],
            retention_months=body.retention_months,
            is_enabled=body.is_enabled
        )

        return {
            "message": "Configurazione retention aggiornata",
            "config": {
                "retention_months": body.retention_months,
                "is_enabled": body.is_enabled,
                "dry_run": body.dry_run,
                "exclude_roles": body.exclude_roles
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error("gdpr_config_set_error", error=sanitize_error_message(e))
        raise HTTPException(
            status_code=500,
            detail="Errore durante l'aggiornamento della configurazione"
        )


# --- PURGE INACTIVE USERS ---
@router.post("/admin/purge-inactive")
async def purge_inactive_users(
    body: PurgeRequest,
    admin: dict = Depends(verify_admin)
):
    """
    Elimina manualmente i dati degli utenti inattivi (GDPR Art. 17).

    Se target_uid è specificato, elimina solo quell'utente.
    Altrimenti, elimina tutti gli utenti inattivi oltre il periodo di retention.

    ATTENZIONE: Operazione irreversibile se dry_run=False!

    Solo Admin.
    """
    try:
        service = GDPRRetentionService()
        admin_id = admin['uid']

        # Purge singolo utente
        if body.target_uid:
            result = await service.purge_user(
                uid=body.target_uid,
                reason="Manual GDPR purge by admin",
                requester_id=admin_id,
                dry_run=body.dry_run
            )

            logger.info(
                "gdpr_single_purge",
                admin_id=admin_id,
                target_uid=body.target_uid,
                dry_run=body.dry_run,
                success=result.success
            )

            return {
                "message": "Purge completato" if not body.dry_run else "Simulazione purge completata",
                "dry_run": body.dry_run,
                "result": {
                    "uid": result.uid,
                    "success": result.success,
                    "deleted_collections": result.deleted_collections,
                    "error": result.error
                }
            }

        # Purge batch di tutti gli utenti inattivi
        results = await service.purge_inactive_users(
            dry_run=body.dry_run,
            requester_id=admin_id
        )

        successful = sum(1 for r in results if r.success)
        failed = len(results) - successful

        logger.info(
            "gdpr_batch_purge",
            admin_id=admin_id,
            dry_run=body.dry_run,
            total=len(results),
            successful=successful,
            failed=failed
        )

        return {
            "message": "Purge batch completato" if not body.dry_run else "Simulazione purge batch completata",
            "dry_run": body.dry_run,
            "summary": {
                "total_processed": len(results),
                "successful": successful,
                "failed": failed
            },
            "results": [
                {
                    "uid": r.uid,
                    "success": r.success,
                    "deleted_collections": r.deleted_collections,
                    "error": r.error
                }
                for r in results
            ]
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error("gdpr_purge_error", error=sanitize_error_message(e))
        raise HTTPException(
            status_code=500,
            detail="Errore durante la purge dei dati"
        )
