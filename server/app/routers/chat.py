"""
Router per funzionalità chat (es. upload allegati).
"""
import uuid
from typing import Optional
from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from firebase_admin import storage
from app.core.dependencies import verify_professional
from app.core.logging import logger, sanitize_error_message

router = APIRouter(prefix="/chat", tags=["chat"])

@router.post("/upload-attachment")
async def upload_attachment(
    file: UploadFile = File(...),
    requester: dict = Depends(verify_professional)
):
    """
    Carica un allegato (immagine/PDF) su Firebase Storage per la chat.
    Ritorna l'URL pubblico (o firmato) del file.
    """
    allowed_types = ["image/jpeg", "image/png", "application/pdf"]
    if file.content_type not in allowed_types:
        raise HTTPException(status_code=400, detail="Formato file non supportato. Usa JPG, PNG o PDF.")

    # Limite dimensione (es. 5MB) - Idealmente da gestire prima ma ok qui
    # Per ora ci fidiamo del client o gestiamo eccezioni stream

    try:
        bucket = storage.bucket()
        
        # Genera nome file univoco
        ext = file.filename.split('.')[-1].lower() if '.' in file.filename else "bin"
        filename = f"{uuid.uuid4()}.{ext}"
        blob_path = f"chat_uploads/{filename}"
        
        blob = bucket.blob(blob_path)
        
        # Upload
        blob.upload_from_file(file.file, content_type=file.content_type)
        
        # Make public (semplificazione per task #10)
        blob.make_public()
        
        return {
            "url": blob.public_url,
            "fileName": file.filename,
            "fileType": "pdf" if file.content_type == "application/pdf" else "image"
        }

    except Exception as e:
        logger.error("chat_upload_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante l'upload del file.")
