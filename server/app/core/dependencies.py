"""
Dipendenze di autenticazione e sicurezza condivise tra i routers.
"""
import os
import re
import asyncio

from fastapi import Header, HTTPException, Depends
from fastapi.concurrency import run_in_threadpool
from firebase_admin import auth

# Semaforo per limitare operazioni pesanti
heavy_tasks_semaphore = asyncio.Semaphore(2)

# Costanti di sicurezza
MAX_FILE_SIZE = 10 * 1024 * 1024
ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".pdf", ".webp"}

# Magic bytes per validazione file
PDF_MAGIC_BYTES = b'%PDF'

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
    """Verifica il token JWT Firebase."""
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid auth header")
    token = authorization.split("Bearer ")[1].strip()
    if not token:
        raise HTTPException(status_code=401, detail="Empty token")
    try:
        decoded_token = await run_in_threadpool(auth.verify_id_token, token)
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
