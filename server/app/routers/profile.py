"""
Router per il profilo utente self-service (foto profilo).
"""
import uuid
import firebase_admin
from firebase_admin import storage, firestore
from fastapi import APIRouter, UploadFile, File, HTTPException, Depends, Request
from datetime import timedelta

from app.core.dependencies import (
    verify_token,
    MAX_FILE_SIZE,
    validate_extension,
    validate_file_content,
)
from app.core.logging import logger, sanitize_error_message
from app.core.limiter import limiter

router = APIRouter(prefix="/profile", tags=["profile"])


@router.post("/upload-photo")
@limiter.limit("20/hour")
async def upload_profile_photo(
    request: Request,
    file: UploadFile = File(...),
    requester: dict = Depends(verify_token),
):
    """Carica la foto profilo dell'utente e aggiorna il doc users/{uid}.photo_url."""
    allowed_types = ["image/jpeg", "image/png"]
    if file.content_type not in allowed_types:
        raise HTTPException(status_code=400, detail="Usa JPG o PNG.")

    ext = validate_extension(file.filename)
    try:
        content = await file.read()
        if len(content) > MAX_FILE_SIZE:
            max_mb = MAX_FILE_SIZE // (1024 * 1024)
            raise HTTPException(status_code=413, detail=f"File troppo grande. Massimo {max_mb}MB.")
        if not validate_file_content(content, ext):
            raise HTTPException(status_code=400, detail="Contenuto del file non valido.")

        from app.core.config import settings
        bucket = storage.bucket(name=settings.STORAGE_BUCKET)

        uid = requester['uid']
        # Nome univoco per invalidare cache CDN quando l'utente cambia foto.
        blob_path = f"profile_photos/{uid}/{uuid.uuid4().hex}{ext}"
        blob = bucket.blob(blob_path)
        blob.upload_from_string(content, content_type=file.content_type)

        signed_url = blob.generate_signed_url(expiration=timedelta(days=7))

        db = firebase_admin.firestore.client()
        db.collection('users').document(uid).update({
            'photo_url': signed_url,
            'photo_path': blob_path,
            'photo_updated_at': firestore.SERVER_TIMESTAMP,
        })

        return {"url": signed_url}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("profile_photo_upload_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore nel caricamento della foto.")


@router.delete("/photo")
@limiter.limit("20/hour")
async def delete_profile_photo(
    request: Request,
    requester: dict = Depends(verify_token),
):
    """Rimuove la foto profilo corrente."""
    try:
        uid = requester['uid']
        db = firebase_admin.firestore.client()
        doc = db.collection('users').document(uid).get()
        if doc.exists:
            data = doc.to_dict() or {}
            path = data.get('photo_path')
            if path:
                try:
                    from app.core.config import settings
                    bucket = storage.bucket(name=settings.STORAGE_BUCKET)
                    bucket.blob(path).delete()
                except Exception:
                    pass
        db.collection('users').document(uid).update({
            'photo_url': firestore.DELETE_FIELD,
            'photo_path': firestore.DELETE_FIELD,
        })
        return {"ok": True}
    except Exception as e:
        logger.error("profile_photo_delete_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore nella rimozione della foto.")
