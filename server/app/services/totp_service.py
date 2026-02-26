"""
TOTP (Time-based One-Time Password) Service

Implementa Two-Factor Authentication (2FA) usando algoritmo TOTP (RFC 6238).
Compatibile con Google Authenticator, Authy, Microsoft Authenticator, etc.
"""

import hmac
import hashlib
import struct
import time
import base64
import secrets
from typing import Optional
from urllib.parse import quote

from firebase_admin import firestore
from google.cloud import firestore as gcloud_firestore

from app.core.logging import logger, sanitize_error_message


@gcloud_firestore.transactional
def _consume_backup_code_txn(transaction, user_ref, code_hash: str) -> bool:
    """
    Verifica e consuma atomicamente un backup code 2FA.
    [SECURITY] La transazione Firestore previene la race condition dove due richieste
    simultanée con lo stesso codice potrebbero entrambe riuscire (leggi-controlla-scrivi
    non atomico). Con la transazione, la seconda request ottiene un conflitto e ritorna False.
    """
    snapshot = user_ref.get(transaction=transaction)
    if not snapshot.exists:
        return False
    codes = snapshot.to_dict().get('two_factor_backup_codes', [])
    if code_hash not in codes:
        return False
    new_codes = [c for c in codes if c != code_hash]
    transaction.update(user_ref, {'two_factor_backup_codes': new_codes})
    return True


class TOTPService:
    """
    Service for managing TOTP-based Two-Factor Authentication.

    Usage:
        service = TOTPService()

        # Setup 2FA for user
        secret, qr_uri = await service.setup_2fa(user_id="xxx", email="user@example.com")

        # Verify code and enable 2FA
        success = await service.verify_and_enable(user_id="xxx", code="123456", secret=secret)

        # Verify code for login
        valid = await service.verify_code(user_id="xxx", code="123456")

        # Disable 2FA
        await service.disable_2fa(user_id="xxx")
    """

    ISSUER = "Kybo"
    SECRET_LENGTH = 20
    CODE_DIGITS = 6
    TIME_STEP = 30
    BACKUP_CODES_COUNT = 10

    def __init__(self):
        self.db = firestore.client()

    def _generate_secret(self) -> str:
        """Genera un secret casuale per TOTP."""
        random_bytes = secrets.token_bytes(self.SECRET_LENGTH)
        return base64.b32encode(random_bytes).decode('utf-8').rstrip('=')

    def _get_totp_code(self, secret: str, timestamp: Optional[int] = None) -> str:
        """
        Genera il codice TOTP per un dato timestamp.

        Args:
            secret: Base32-encoded secret
            timestamp: Unix timestamp (default: now)

        Returns:
            6-digit TOTP code
        """
        if timestamp is None:
            timestamp = int(time.time())

        secret = secret.upper()
        padding = 8 - (len(secret) % 8)
        if padding != 8:
            secret += '=' * padding

        try:
            key = base64.b32decode(secret)
        except Exception:
            raise ValueError("Invalid secret")

        counter = timestamp // self.TIME_STEP

        counter_bytes = struct.pack('>Q', counter)
        hmac_hash = hmac.new(key, counter_bytes, hashlib.sha1).digest()

        offset = hmac_hash[-1] & 0x0F
        code_int = struct.unpack('>I', hmac_hash[offset:offset+4])[0] & 0x7FFFFFFF
        code = code_int % (10 ** self.CODE_DIGITS)

        return str(code).zfill(self.CODE_DIGITS)

    def _verify_totp(self, secret: str, code: str, window: int = 1) -> bool:
        """
        Verifica un codice TOTP con finestra temporale.

        Args:
            secret: Base32-encoded secret
            code: 6-digit code to verify
            window: Number of time steps to check before/after (default: 1)

        Returns:
            True if code is valid
        """
        if len(code) != self.CODE_DIGITS:
            return False

        current_time = int(time.time())

        for offset in range(-window, window + 1):
            timestamp = current_time + (offset * self.TIME_STEP)
            expected_code = self._get_totp_code(secret, timestamp)
            if hmac.compare_digest(code, expected_code):
                return True

        return False

    def _generate_qr_uri(self, secret: str, email: str) -> str:
        """
        Genera URI otpauth:// per QR code.

        Format: otpauth://totp/Kybo:user@example.com?secret=XXX&issuer=Kybo
        """
        label = f"{self.ISSUER}:{email}"
        params = {
            'secret': secret,
            'issuer': self.ISSUER,
            'algorithm': 'SHA1',
            'digits': str(self.CODE_DIGITS),
            'period': str(self.TIME_STEP),
        }
        param_str = '&'.join(f"{k}={quote(v)}" for k, v in params.items())
        return f"otpauth://totp/{quote(label)}?{param_str}"

    def _generate_backup_codes(self) -> list[str]:
        """Genera codici di backup per recovery."""
        codes = []
        for _ in range(self.BACKUP_CODES_COUNT):
            code = secrets.token_hex(4).upper()
            codes.append(code)
        return codes

    async def setup_2fa(self, user_id: str, email: str) -> tuple[str, str]:
        """
        Inizia il setup di 2FA per un utente.

        Args:
            user_id: UID dell'utente
            email: Email dell'utente (per QR code label)

        Returns:
            Tuple of (secret, qr_uri)

        Note:
            Il secret NON viene salvato finché non viene verificato con verify_and_enable.
        """
        try:
            secret = self._generate_secret()
            qr_uri = self._generate_qr_uri(secret, email)

            logger.info("2fa_setup_initiated", user_id=user_id)

            return secret, qr_uri

        except Exception as e:
            logger.error("2fa_setup_error", user_id=user_id, error=sanitize_error_message(e))
            raise

    async def verify_and_enable(
        self,
        user_id: str,
        code: str,
        secret: str
    ) -> tuple[bool, Optional[list[str]]]:
        """
        Verifica il codice TOTP e abilita 2FA.

        Args:
            user_id: UID dell'utente
            code: Codice TOTP inserito dall'utente
            secret: Secret generato durante setup

        Returns:
            Tuple of (success, backup_codes)
            - success: True se verificato e abilitato
            - backup_codes: Lista di codici di backup (solo se success=True)
        """
        try:
            if not self._verify_totp(secret, code):
                logger.warning("2fa_verify_failed", user_id=user_id)
                return False, None

            backup_codes = self._generate_backup_codes()
            hashed_backups = [
                hashlib.sha256(c.encode()).hexdigest()
                for c in backup_codes
            ]

            user_ref = self.db.collection('users').document(user_id)
            user_ref.update({
                'two_factor_enabled': True,
                'two_factor_secret': secret,
                'two_factor_backup_codes': hashed_backups,
                'two_factor_enabled_at': firestore.SERVER_TIMESTAMP,
            })

            logger.info("2fa_enabled", user_id=user_id)

            return True, backup_codes

        except Exception as e:
            logger.error("2fa_enable_error", user_id=user_id, error=sanitize_error_message(e))
            raise

    async def verify_code(self, user_id: str, code: str) -> bool:
        """
        Verifica un codice TOTP per un utente.

        Args:
            user_id: UID dell'utente
            code: Codice TOTP o backup code

        Returns:
            True se il codice è valido
        """
        try:
            user_doc = self.db.collection('users').document(user_id).get()
            if not user_doc.exists:
                return False

            user_data = user_doc.to_dict()
            if not user_data.get('two_factor_enabled'):
                return True

            secret = user_data.get('two_factor_secret')
            if not secret:
                logger.warning("2fa_no_secret", user_id=user_id)
                return False

            if self._verify_totp(secret, code):
                return True

            code_hash = hashlib.sha256(code.upper().encode()).hexdigest()
            user_ref = self.db.collection('users').document(user_id)
            transaction = self.db.transaction()
            if _consume_backup_code_txn(transaction, user_ref, code_hash):
                logger.info("2fa_backup_code_used", user_id=user_id)
                return True

            logger.warning("2fa_verify_failed", user_id=user_id)
            return False

        except Exception as e:
            logger.error("2fa_verify_error", user_id=user_id, error=sanitize_error_message(e))
            return False

    async def disable_2fa(self, user_id: str) -> bool:
        """
        Disabilita 2FA per un utente.

        Args:
            user_id: UID dell'utente

        Returns:
            True se disabilitato con successo
        """
        try:
            user_ref = self.db.collection('users').document(user_id)
            user_ref.update({
                'two_factor_enabled': False,
                'two_factor_secret': firestore.DELETE_FIELD,
                'two_factor_backup_codes': firestore.DELETE_FIELD,
                'two_factor_enabled_at': firestore.DELETE_FIELD,
            })

            logger.info("2fa_disabled", user_id=user_id)
            return True

        except Exception as e:
            logger.error("2fa_disable_error", user_id=user_id, error=sanitize_error_message(e))
            return False

    async def is_2fa_enabled(self, user_id: str) -> bool:
        """
        Controlla se 2FA è abilitato per un utente.

        Args:
            user_id: UID dell'utente

        Returns:
            True se 2FA è abilitato
        """
        try:
            user_doc = self.db.collection('users').document(user_id).get()
            if not user_doc.exists:
                return False

            return user_doc.to_dict().get('two_factor_enabled', False)

        except Exception as e:
            logger.error("2fa_check_error", user_id=user_id, error=sanitize_error_message(e))
            return False

    async def regenerate_backup_codes(self, user_id: str) -> Optional[list[str]]:
        """
        Rigenera i codici di backup per un utente.

        Args:
            user_id: UID dell'utente

        Returns:
            Lista di nuovi codici di backup, o None se errore
        """
        try:
            if not await self.is_2fa_enabled(user_id):
                return None

            backup_codes = self._generate_backup_codes()
            hashed_backups = [
                hashlib.sha256(c.encode()).hexdigest()
                for c in backup_codes
            ]

            self.db.collection('users').document(user_id).update({
                'two_factor_backup_codes': hashed_backups,
            })

            logger.info("2fa_backup_regenerated", user_id=user_id)
            return backup_codes

        except Exception as e:
            logger.error("2fa_backup_regen_error", user_id=user_id, error=sanitize_error_message(e))
            return None
