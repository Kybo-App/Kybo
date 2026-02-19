"""
Kybo API Server - Entry Point

Struttura modulare:
- routers/diet.py     - Upload diete e scansione scontrini
- routers/users.py    - Gestione utenti (CRUD)
- routers/admin.py    - Funzioni admin (sync, manutenzione, gateway sicuro)
- core/dependencies.py - Autenticazione e dipendenze condivise
- core/logging.py     - Logging con sanitizzazione dati sensibili
"""
import os
import re
import asyncio
import base64
import json
from datetime import datetime, timezone

import firebase_admin
from firebase_admin import credentials, firestore
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from app.core.config import settings
from app.core.logging import logger, sanitize_error_message

# Import routers
from app.routers.diet import router as diet_router
from app.routers.users import router as users_router
from app.routers.admin import router as admin_router
from app.routers.gdpr import router as gdpr_router
from app.routers.chat import router as chat_router
from app.routers.analytics import router as analytics_router
from app.routers.reports import router as reports_router
from app.routers.twofa import router as twofa_router
from app.routers.communication import router as communication_router
from app.workers.unread_notifier import unread_notification_worker

# --- SENTRY ERROR TRACKING ---
import sentry_sdk
from sentry_sdk.integrations.fastapi import FastApiIntegration
from sentry_sdk.integrations.starlette import StarletteIntegration

if settings.SENTRY_DSN:
    sentry_sdk.init(
        dsn=settings.SENTRY_DSN,
        environment=settings.ENV,  # DEV, STAGING, PROD
        integrations=[
            FastApiIntegration(),
            StarletteIntegration(),
        ],
        traces_sample_rate=0.1,  # 10% delle richieste per performance monitoring
        send_default_pii=False,  # Non inviare dati personali
    )
    logger.info("sentry_init_success", environment=settings.ENV)


# --- FIREBASE INIT ---
if not firebase_admin._apps:
    try:
        key_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")

        if key_path and os.path.exists(key_path):
            cred = credentials.Certificate(key_path)
            firebase_admin.initialize_app(cred, {
                'storageBucket': settings.STORAGE_BUCKET
            })
            logger.info("firebase_init_success", method="service_account_file", path=key_path, bucket=settings.STORAGE_BUCKET)
        else:
            cred = credentials.ApplicationDefault()
            firebase_admin.initialize_app(cred, {
                'storageBucket': settings.STORAGE_BUCKET
            })
            logger.info("firebase_init_success", method="adc", bucket=settings.STORAGE_BUCKET)

    except Exception as e:
        error_msg = str(e)
        error_msg = re.sub(r'Bearer\s+[A-Za-z0-9\-_\.]+', 'Bearer ***', error_msg)
        error_msg = re.sub(r'token["\']?\s*:\s*["\']?[A-Za-z0-9\-_\.]+', 'token: ***', error_msg, flags=re.IGNORECASE)
        logger.error("firebase_init_error", error=error_msg)


# --- RATE LIMITING ---
def get_rate_limit_key(request: Request) -> str:
    """
    Genera chiave per rate limiting combinando IP e User ID.
    Se l'utente è autenticato, usa IP:UID per rate limit più preciso.
    """
    ip = get_remote_address(request)
    auth_header = request.headers.get("Authorization", "")

    if auth_header.startswith("Bearer "):
        try:
            token_parts = auth_header.split(" ")[1].split(".")
            if len(token_parts) >= 2:
                payload = base64.urlsafe_b64decode(token_parts[1] + "==")
                data = json.loads(payload)
                user_id = data.get("user_id") or data.get("sub") or data.get("uid")
                if user_id:
                    return f"{ip}:{user_id}"
        except Exception:
            pass
    return ip


limiter = Limiter(key_func=get_rate_limit_key)


# --- APP SETUP ---
app = FastAPI(
    title="Kybo API",
    description="Backend per l'applicazione Kybo - Gestione diete",
    version="2.0.0"
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS", "DELETE", "PUT"],
    allow_headers=["Authorization", "Content-Type"],
)


# --- INCLUDE ROUTERS ---
app.include_router(diet_router)
app.include_router(users_router)
app.include_router(admin_router)
app.include_router(gdpr_router)
app.include_router(chat_router)
app.include_router(analytics_router)
app.include_router(reports_router)
app.include_router(twofa_router)
app.include_router(communication_router)


# --- BACKGROUND WORKER ---
async def maintenance_worker():
    """Worker che controlla e attiva manutenzioni programmate."""
    logger.info("maintenance_worker_started")

    while True:
        try:
            db = firebase_admin.firestore.client()
            doc_ref = db.collection('config').document('global')
            doc = doc_ref.get()

            if doc.exists:
                data = doc.to_dict()
                is_scheduled = data.get('is_scheduled', False)
                start_str = data.get('scheduled_maintenance_start')

                if is_scheduled and start_str:
                    try:
                        clean_str = start_str.replace('Z', '+00:00')
                        scheduled_time = datetime.fromisoformat(clean_str)
                        if scheduled_time.tzinfo is None:
                            scheduled_time = scheduled_time.replace(tzinfo=timezone.utc)

                        now = datetime.now(timezone.utc)
                        if now >= scheduled_time:
                            logger.info("maintenance_triggered", scheduled_for=start_str)
                            doc_ref.update({
                                "maintenance_mode": True,
                                "is_scheduled": False,
                                "scheduled_maintenance_start": firestore.DELETE_FIELD,
                                "updated_by": "system_scheduler"
                            })
                    except Exception as e:
                        logger.error("scheduler_error", error=sanitize_error_message(e))

        except Exception as e:
            logger.error("maintenance_worker_error", error=sanitize_error_message(e))

        await asyncio.sleep(settings.MAINTENANCE_POLL_INTERVAL)


@app.on_event("startup")
async def start_background_tasks():
    """Avvia task in background all'avvio del server."""
    asyncio.create_task(maintenance_worker())
    asyncio.create_task(unread_notification_worker())


# --- HEALTH CHECK ---
@app.get("/health")
async def health_check():
    """Endpoint di health check base per load balancer."""
    return {"status": "healthy", "version": "2.0.0"}


@app.get("/health/detailed")
async def health_check_detailed():
    """
    Health check avanzato che verifica tutti i servizi dipendenti.
    Usato per debugging e monitoring dettagliato.
    """
    import subprocess
    import shutil
    from google import genai
    
    checks = {
        "firebase": {"status": "unknown", "message": ""},
        "gemini": {"status": "unknown", "message": ""},
        "tesseract": {"status": "unknown", "message": ""},
        "sentry": {"status": "unknown", "message": ""},
    }
    
    # Check Firebase
    try:
        db = firestore.client()
        # Prova a leggere il documento config
        doc = db.collection("config").document("global").get()
        if doc.exists:
            checks["firebase"] = {"status": "ok", "message": "Connected"}
        else:
            checks["firebase"] = {"status": "ok", "message": "Connected (no config doc)"}
    except Exception as e:
        checks["firebase"] = {"status": "error", "message": str(e)[:100]}
    
    # Check Gemini API
    try:
        client = genai.Client(api_key=settings.GOOGLE_API_KEY)
        # Prova a listare i modelli (operazione leggera)
        models = list(client.models.list())
        if models:
            checks["gemini"] = {"status": "ok", "message": f"{len(models)} models available"}
        else:
            checks["gemini"] = {"status": "warning", "message": "No models found"}
    except Exception as e:
        checks["gemini"] = {"status": "error", "message": str(e)[:100]}
    
    # Check Tesseract
    try:
        tesseract_path = shutil.which("tesseract")
        if tesseract_path:
            result = subprocess.run(
                ["tesseract", "--version"],
                capture_output=True,
                text=True,
                timeout=5
            )
            version = result.stdout.split('\n')[0] if result.stdout else "unknown"
            checks["tesseract"] = {"status": "ok", "message": version}
        else:
            checks["tesseract"] = {"status": "error", "message": "Not found in PATH"}
    except Exception as e:
        checks["tesseract"] = {"status": "error", "message": str(e)[:100]}
    
    # Check Sentry
    checks["sentry"] = {
        "status": "ok" if settings.SENTRY_DSN else "disabled",
        "message": "Configured" if settings.SENTRY_DSN else "No DSN set"
    }
    
    # Overall status
    errors = [k for k, v in checks.items() if v["status"] == "error"]
    overall = "unhealthy" if errors else "healthy"
    
    return {
        "status": overall,
        "version": "2.0.0",
        "environment": settings.ENV,
        "checks": checks,
        "errors": errors if errors else None
    }
