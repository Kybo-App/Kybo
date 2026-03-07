"""
Shopping List Share Router — Kybo API

POST /shopping-list/share          — crea snapshot condiviso, ritorna URL
GET  /shopping-list/share/{id}     — legge snapshot (pubblico, no auth)

La lista viene salvata in Firestore (shared_lists/{share_id}) con TTL di 7 giorni.
L'ID è generato con secrets.token_urlsafe (8 caratteri URL-safe, ~48 bit di entropia).
"""

import firebase_admin
import secrets
import re
from datetime import datetime, timezone, timedelta
from app.core.config import settings

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel
from firebase_admin import firestore
from app.core.limiter import limiter
from app.core.logging import logger

router = APIRouter(prefix="/shopping-list", tags=["shopping-list"])

SHARE_TTL_DAYS = 7
MAX_ITEMS = 200
SHARE_ID_RE = re.compile(r'^[A-Za-z0-9_-]{6,20}$')


class ShareListRequest(BaseModel):
    items: list[str]
    title: str = "Lista della Spesa"


@router.post("/share")
@limiter.limit("10/hour")
async def create_share(request: Request, req: ShareListRequest):
    """Crea uno snapshot condiviso della lista della spesa."""
    if not req.items:
        raise HTTPException(status_code=422, detail="La lista è vuota.")

    items = req.items[:MAX_ITEMS]
    items = [item.strip()[:200] for item in items if item.strip()]

    if not items:
        raise HTTPException(status_code=422, detail="La lista non contiene articoli validi.")

    share_id = secrets.token_urlsafe(6)
    expires_at = datetime.now(timezone.utc) + timedelta(days=SHARE_TTL_DAYS)

    db = firebase_admin.firestore.client()
    db.collection("shared_lists").document(share_id).set({
        "items": items,
        "title": req.title.strip()[:100] or "Lista della Spesa",
        "created_at": firestore.SERVER_TIMESTAMP,
        "expires_at": expires_at.isoformat(),
    })

    logger.info("shared_list_created", share_id=share_id, item_count=len(items))

    return {
        "share_id": share_id,
        "url": f"https://kybo.it/list?id={share_id}" + ("&dev=1" if settings.ENV != "PROD" else ""),
        "expires_in_days": SHARE_TTL_DAYS,
    }


@router.get("/share/{share_id}")
@limiter.limit("60/minute")
async def get_share(request: Request, share_id: str):
    """Recupera uno snapshot condiviso (pubblico, nessuna autenticazione)."""
    if not SHARE_ID_RE.match(share_id):
        raise HTTPException(status_code=404, detail="Lista non trovata.")

    db = firebase_admin.firestore.client()
    doc = db.collection("shared_lists").document(share_id).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Lista non trovata o scaduta.")

    data = doc.to_dict()

    # Controlla scadenza
    expires_at_str = data.get("expires_at")
    if expires_at_str:
        try:
            exp = datetime.fromisoformat(expires_at_str)
            if datetime.now(timezone.utc) > exp:
                raise HTTPException(
                    status_code=410,
                    detail="Link scaduto. Chiedi all'utente Kybo di generare un nuovo link.",
                )
        except ValueError:
            pass

    return {
        "items": data.get("items", []),
        "title": data.get("title", "Lista della Spesa"),
    }
