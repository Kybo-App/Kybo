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
from fastapi import APIRouter, HTTPException, Depends, Request
from pydantic import BaseModel

from app.core.dependencies import verify_token, verify_professional, verify_admin
from app.core.logging import logger, sanitize_error_message
from app.core.limiter import limiter
from app.services.gdpr_retention_service import GDPRRetentionService

router = APIRouter(prefix="/gdpr", tags=["gdpr"])


class ConsentRequest(BaseModel):
    consent_type: str
    granted: bool
    version: str


class ConsentResponse(BaseModel):
    consent_type: str
    granted: bool
    version: str
    timestamp: str
    ip_address: Optional[str] = None


@router.post("/consent")
@limiter.limit("60/minute")
async def record_consent(
    request: Request,
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
        
        db.collection('users').document(user_id).set({
            f"consent_{body.consent_type}": consent_record
        }, merge=True)
        
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
@limiter.limit("120/minute")
async def get_consents(request: Request, user_data: dict = Depends(verify_token)):
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

def _collect_export_data(db, user_id: str) -> dict:
    """
    Raccoglie tutti i dati Firestore dell'utente per l'export GDPR.
    [SECURITY] Funzione pura separata dall'endpoint HTTP: elimina il pattern
    fake_user_data che bypassava la dependency injection di FastAPI.
    """
    export_data = {
        "export_date": datetime.now(timezone.utc).isoformat(),
        "user_id": user_id,
        "profile": None,
        "diets": [],
        "diet_history": [],
        "consent_logs": []
    }

    user_doc = db.collection('users').document(user_id).get()
    if user_doc.exists:
        profile = user_doc.to_dict()
        for key in ['requires_password_change', 'created_by']:
            profile.pop(key, None)
        export_data["profile"] = profile

    for doc in db.collection('users').document(user_id).collection('diets').get():
        data = doc.to_dict()
        data['_doc_id'] = doc.id
        export_data["diets"].append(data)

    for doc in db.collection('diet_history').where('userId', '==', user_id).stream():
        data = doc.to_dict()
        data['_doc_id'] = doc.id
        if 'uploadedAt' in data and hasattr(data['uploadedAt'], 'isoformat'):
            data['uploadedAt'] = data['uploadedAt'].isoformat()
        export_data["diet_history"].append(data)

    for doc in db.collection('consent_logs').where('user_id', '==', user_id).stream():
        data = doc.to_dict()
        if 'recorded_at' in data and hasattr(data['recorded_at'], 'isoformat'):
            data['recorded_at'] = data['recorded_at'].isoformat()
        export_data["consent_logs"].append(data)

    return export_data


@router.get("/export")
@limiter.limit("10/hour")
async def export_user_data(request: Request, user_data: dict = Depends(verify_token)):
    """
    Esporta tutti i dati dell'utente in formato JSON (GDPR Art. 20).
    Include: profilo, diete, storico, log.
    """
    try:
        db = firebase_admin.firestore.client()
        user_id = user_data['uid']
        export_data = _collect_export_data(db, user_id)
        logger.info("data_export_completed", user_id=user_id)
        return export_data
    except Exception as e:
        logger.error("export_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante l'export dei dati")


@router.get("/export/{target_uid}")
@limiter.limit("30/minute")
async def admin_export_user_data(
    request: Request,
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

        if requester_role == 'nutritionist':
            user_doc = db.collection('users').document(target_uid).get()
            if not user_doc.exists:
                raise HTTPException(status_code=404, detail="User not found")
            if user_doc.to_dict().get('parent_id') != requester_id:
                raise HTTPException(status_code=403, detail="Not authorized to export this user's data")

        db.collection('access_logs').add({
            'requester_id': requester_id,
            'target_uid': target_uid,
            'action': 'GDPR_DATA_EXPORT',
            'reason': 'GDPR Art. 20 Data Portability Request',
            'timestamp': firebase_admin.firestore.SERVER_TIMESTAMP
        })

        export_data = _collect_export_data(db, target_uid)
        logger.info("admin_data_export_completed", requester_id=requester_id, target_uid=target_uid)
        return export_data

    except HTTPException:
        raise
    except Exception as e:
        logger.error("admin_export_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante l'export dei dati")


class RetentionConfigRequest(BaseModel):
    retention_months: int
    is_enabled: bool
    dry_run: bool = True
    exclude_roles: list[str] = ["admin", "nutritionist"]


class PurgeRequest(BaseModel):
    dry_run: bool = True
    target_uid: Optional[str] = None


@router.get("/admin/dashboard")
@limiter.limit("60/minute")
async def get_retention_dashboard(
    request: Request,
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


@router.get("/admin/retention-config")
@limiter.limit("120/minute")
async def get_retention_config(
    request: Request,
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
@limiter.limit("30/minute")
async def set_retention_config(
    request: Request,
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


@router.post("/admin/purge-inactive")
@limiter.limit("5/hour")
async def purge_inactive_users(
    request: Request,
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
