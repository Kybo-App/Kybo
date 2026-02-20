"""
Dipendenze di autenticazione e sicurezza condivise tra i routers.
"""
import os
import re
import time
import asyncio
from typing import Dict, Tuple

from fastapi import Header, HTTPException, Depends
from fastapi.concurrency import run_in_threadpool
from firebase_admin import auth

from app.core.config import settings

# Semaforo per limitare operazioni pesanti
heavy_tasks_semaphore = asyncio.Semaphore(settings.MAX_CONCURRENT_HEAVY_TASKS)

# Costanti di sicurezza
MAX_FILE_SIZE = settings.MAX_FILE_SIZE
ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".pdf", ".webp"}

# Magic bytes per validazione file
PDF_MAGIC_BYTES = b'%PDF'

# ─────────────────────────────────────────────────────────────────────────────
# TOKEN CACHE in-memory
# Evita di chiamare Firebase Auth per ogni richiesta.
# TTL: 25 minuti (i token Firebase scadono dopo 60 min, usiamo 25 per sicurezza).
# Struttura: { token_hash → (decoded_token, expire_at) }
# ─────────────────────────────────────────────────────────────────────────────
_TOKEN_CACHE: Dict[str, Tuple[dict, float]] = {}
_TOKEN_CACHE_TTL = 25 * 60  # 25 minuti in secondi
_TOKEN_CACHE_MAX_SIZE = 500  # max token in cache (evita memory leak)

def _cache_get(token: str) -> dict | None:
    """Ritorna il decoded token dalla cache se valido, altrimenti None."""
    entry = _TOKEN_CACHE.get(token)
    if entry is None:
        return None
    decoded, expire_at = entry
    if time.monotonic() > expire_at:
        # Scaduto — rimuovi
        _TOKEN_CACHE.pop(token, None)
        return None
    return decoded

def _cache_set(token: str, decoded: dict) -> None:
    """Salva il decoded token in cache con TTL."""
    # Evita crescita illimitata: se piena, svuota i più vecchi
    if len(_TOKEN_CACHE) >= _TOKEN_CACHE_MAX_SIZE:
        now = time.monotonic()
        expired_keys = [k for k, (_, exp) in _TOKEN_CACHE.items() if now > exp]
        for k in expired_keys:
            _TOKEN_CACHE.pop(k, None)
        # Se ancora piena dopo pulizia expired, rimuovi i primi 100
        if len(_TOKEN_CACHE) >= _TOKEN_CACHE_MAX_SIZE:
            keys_to_remove = list(_TOKEN_CACHE.keys())[:100]
            for k in keys_to_remove:
                _TOKEN_CACHE.pop(k, None)
    _TOKEN_CACHE[token] = (decoded, time.monotonic() + _TOKEN_CACHE_TTL)

def validate_file_content(file_content: bytes, expected_type: str) -> bool:
    """Verifica che il contenuto del file corrisponda al tipo dichiarato."""
    if expected_type == '.pdf':
        return file_content[:4] == PDF_MAGIC_BYTES
    elif expected_type in ['.jpg', '.jpeg']:
        return file_content[:3] == b'\xff\xd8\xff'
    elif expected_type == '.png':
        return file_content[:8] == b'\x89PNG\r\n\x1a\n'
    elif expected_type == '.webp':
        return file_content[:4] == b'RIFF' and file_content[8:12] == b'WEBP'
    return False

def validate_extension(filename: str) -> str:
    """Valida e ritorna l'estensione del file."""
    ext = os.path.splitext(filename)[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=400, detail="Invalid file type")
    return ext

async def verify_token(authorization: str = Header(...)):
    """
    Verifica il token JWT Firebase con cache in-memory (TTL 25 min).
    La prima verifica chiama Firebase Auth (~300ms), le successive sono istantanee.
    """
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid auth header")
    token = authorization.split("Bearer ")[1].strip()
    if not token:
        raise HTTPException(status_code=401, detail="Empty token")

    # Cache hit → risposta immediata, nessuna chiamata Firebase
    cached = _cache_get(token)
    if cached is not None:
        return cached

    # Cache miss → verifica con Firebase Auth e salva in cache
    try:
        decoded_token = await run_in_threadpool(auth.verify_id_token, token)
        _cache_set(token, decoded_token)
        return decoded_token
    except Exception:
        raise HTTPException(status_code=401, detail="Authentication failed")

async def verify_admin(token: dict = Depends(verify_token)):
    """Verifica che l'utente sia admin."""
    role = token.get('role')
    uid = token.get('uid')
    if role == 'admin':
        return {'uid': uid, 'role': 'admin'}
    raise HTTPException(status_code=403, detail="Admin privileges required")

async def verify_professional(token: dict = Depends(verify_token)):
    """Verifica che l'utente sia admin o nutrizionista."""
    role = token.get('role')
    uid = token.get('uid')
    if role in ['admin', 'nutritionist']:
        return {'uid': uid, 'role': role}
    raise HTTPException(status_code=403, detail="Professional privileges required")

async def get_current_uid(token: dict = Depends(verify_token)):
    """Ritorna l'UID dell'utente corrente."""
    return token['uid']
