"""
Router per Two-Factor Authentication (2FA).

Endpoint per setup, verifica e gestione 2FA.
"""
from typing import Optional

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel

from firebase_admin import firestore

from app.core.dependencies import verify_token, verify_professional
from app.core.logging import logger, sanitize_error_message
from app.services.totp_service import TOTPService

router = APIRouter(prefix="/admin/2fa", tags=["2fa"])


# --- SCHEMAS ---
class SetupResponse(BaseModel):
    secret: str
    qr_uri: str
    message: str


class VerifyRequest(BaseModel):
    code: str
    secret: str  # The secret from setup (not yet saved)


class VerifyResponse(BaseModel):
    success: bool
    backup_codes: Optional[list[str]] = None
    message: str


class CodeRequest(BaseModel):
    code: str


class StatusResponse(BaseModel):
    enabled: bool
    user_id: str


# --- ENDPOINTS ---

@router.post("/setup", response_model=SetupResponse)
async def setup_2fa(
    user_data: dict = Depends(verify_professional)
):
    """
    Inizia il setup di 2FA.

    Genera un secret TOTP e restituisce:
    - secret: Da salvare temporaneamente nel client
    - qr_uri: URI otpauth:// per generare QR code

    Il secret NON viene salvato finché l'utente non verifica con /verify.
    """
    try:
        user_id = user_data['uid']

        # Get user email from Firestore
        db = firestore.client()
        user_doc = db.collection('users').document(user_id).get()
        if not user_doc.exists:
            raise HTTPException(status_code=404, detail="Utente non trovato")

        email = user_doc.to_dict().get('email', f"user_{user_id[:8]}")

        # Check if 2FA already enabled
        if user_doc.to_dict().get('two_factor_enabled'):
            raise HTTPException(
                status_code=400,
                detail="2FA già abilitato. Disabilita prima di riconfigurare."
            )

        service = TOTPService()
        secret, qr_uri = await service.setup_2fa(user_id, email)

        return SetupResponse(
            secret=secret,
            qr_uri=qr_uri,
            message="Scansiona il QR code con la tua app authenticator"
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error("2fa_setup_error", error=sanitize_error_message(e))
        raise HTTPException(
            status_code=500,
            detail="Errore durante il setup 2FA"
        )


@router.post("/verify", response_model=VerifyResponse)
async def verify_and_enable_2fa(
    body: VerifyRequest,
    user_data: dict = Depends(verify_professional)
):
    """
    Verifica il codice TOTP e abilita 2FA.

    Richiede:
    - code: Codice a 6 cifre dalla app authenticator
    - secret: Secret ricevuto durante il setup

    Se la verifica ha successo, 2FA viene abilitato e vengono
    generati i codici di backup.
    """
    try:
        user_id = user_data['uid']

        service = TOTPService()
        success, backup_codes = await service.verify_and_enable(
            user_id=user_id,
            code=body.code,
            secret=body.secret
        )

        if success:
            return VerifyResponse(
                success=True,
                backup_codes=backup_codes,
                message="2FA abilitato con successo! Salva i codici di backup."
            )
        else:
            return VerifyResponse(
                success=False,
                message="Codice non valido. Riprova."
            )

    except Exception as e:
        logger.error("2fa_verify_error", error=sanitize_error_message(e))
        raise HTTPException(
            status_code=500,
            detail="Errore durante la verifica 2FA"
        )


@router.post("/validate")
async def validate_2fa_code(
    body: CodeRequest,
    user_data: dict = Depends(verify_token)
):
    """
    Valida un codice 2FA per il login.

    Chiamato dopo l'autenticazione Firebase se l'utente ha 2FA abilitato.

    Accetta sia codici TOTP che codici di backup.
    """
    try:
        user_id = user_data['uid']

        service = TOTPService()
        valid = await service.verify_code(user_id, body.code)

        if valid:
            logger.info("2fa_validated", user_id=user_id)
            return {"valid": True, "message": "Codice valido"}
        else:
            logger.warning("2fa_validation_failed", user_id=user_id)
            raise HTTPException(status_code=401, detail="Codice 2FA non valido")

    except HTTPException:
        raise
    except Exception as e:
        logger.error("2fa_validate_error", error=sanitize_error_message(e))
        raise HTTPException(
            status_code=500,
            detail="Errore durante la validazione 2FA"
        )


@router.post("/disable")
async def disable_2fa(
    body: CodeRequest,
    user_data: dict = Depends(verify_professional)
):
    """
    Disabilita 2FA per l'utente corrente.

    Richiede verifica del codice 2FA corrente per sicurezza.
    """
    try:
        user_id = user_data['uid']

        service = TOTPService()

        # Verify current code first
        if not await service.verify_code(user_id, body.code):
            raise HTTPException(status_code=401, detail="Codice 2FA non valido")

        # Disable 2FA
        success = await service.disable_2fa(user_id)

        if success:
            return {"success": True, "message": "2FA disabilitato"}
        else:
            raise HTTPException(status_code=500, detail="Impossibile disabilitare 2FA")

    except HTTPException:
        raise
    except Exception as e:
        logger.error("2fa_disable_error", error=sanitize_error_message(e))
        raise HTTPException(
            status_code=500,
            detail="Errore durante la disabilitazione 2FA"
        )


@router.get("/status", response_model=StatusResponse)
async def get_2fa_status(
    user_data: dict = Depends(verify_token)
):
    """
    Controlla se 2FA è abilitato per l'utente corrente.

    Utile per il client per sapere se mostrare il prompt 2FA dopo login.
    """
    try:
        user_id = user_data['uid']

        service = TOTPService()
        enabled = await service.is_2fa_enabled(user_id)

        return StatusResponse(enabled=enabled, user_id=user_id)

    except Exception as e:
        logger.error("2fa_status_error", error=sanitize_error_message(e))
        raise HTTPException(
            status_code=500,
            detail="Errore durante il controllo stato 2FA"
        )


@router.post("/backup-codes/regenerate")
async def regenerate_backup_codes(
    body: CodeRequest,
    user_data: dict = Depends(verify_professional)
):
    """
    Rigenera i codici di backup.

    Richiede verifica del codice 2FA corrente.
    I vecchi codici di backup vengono invalidati.
    """
    try:
        user_id = user_data['uid']

        service = TOTPService()

        # Verify current code first
        if not await service.verify_code(user_id, body.code):
            raise HTTPException(status_code=401, detail="Codice 2FA non valido")

        # Regenerate backup codes
        new_codes = await service.regenerate_backup_codes(user_id)

        if new_codes:
            return {
                "success": True,
                "backup_codes": new_codes,
                "message": "Nuovi codici di backup generati. Salva questi codici!"
            }
        else:
            raise HTTPException(
                status_code=400,
                detail="2FA non abilitato o errore durante la rigenerazione"
            )

    except HTTPException:
        raise
    except Exception as e:
        logger.error("2fa_backup_regen_error", error=sanitize_error_message(e))
        raise HTTPException(
            status_code=500,
            detail="Errore durante la rigenerazione codici di backup"
        )
