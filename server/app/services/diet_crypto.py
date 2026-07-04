"""
Decrittazione lato server del formato AES-256-CBC usato dal client per
`users/{uid}/diets/*` (vedi client/lib/services/encryption_service.dart).

Contesto (audit SRV-DIET1): il client cifra `plan`/`substitutions`/
`activeSwaps`/`weeks` in campi `*_encrypted` + `encrypted: true` e CANCELLA
i campi in chiaro. Diverse feature server (export-diet-pdf, suggestions,
analytics) leggevano solo il campo `plan` in chiaro, quindi tornavano vuote
non appena il client toccava la dieta (swap giorno, modifica pasto, sync).

Questo modulo NON cambia il path di scrittura server (diet_save_service.py
continua a scrivere `plan` in chiaro per compatibilità con l'upload
nutrizionista): decifra solo in lettura, con fallback al campo in chiaro se
il documento non è nel formato cifrato. La chiave è derivata dall'UID con lo
stesso algoritmo del client — non è un segreto (vedi il commento in
encryption_service.dart): è la stessa protezione "offuscamento" già
documentata, non cifratura forte con chiave server-side.
"""
import base64
import hashlib
import json
import os
from typing import Any, Optional

from cryptography.hazmat.primitives import padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

from app.core.logging import logger, sanitize_error_message


def _derive_key(uid: str) -> bytes:
    uid_hash = hashlib.sha256(uid.encode('utf-8')).hexdigest()
    salt = f"kybo_v2_{uid_hash[:16]}"
    key_material = f"{uid}:{salt}"
    return hashlib.sha256(key_material.encode('utf-8')).digest()


def encrypt_field(data: Any, uid: str) -> str:
    """Cifra un valore nello stesso formato v2 del client (1 byte versione +
    16 byte IV random + ciphertext AES-256-CBC/PKCS7, tutto base64), così i
    documenti scritti dal server sono decifrabili dal client e viceversa.
    Verificato con un round-trip incrociato Python↔Dart durante lo sviluppo
    di questa fix (vedi commit SRV-DIET1)."""
    key = _derive_key(uid)
    iv = os.urandom(16)
    plaintext = json.dumps(data, separators=(',', ':')).encode('utf-8')

    padder = padding.PKCS7(algorithms.AES.block_size).padder()
    padded = padder.update(plaintext) + padder.finalize()

    encryptor = Cipher(algorithms.AES(key), modes.CBC(iv)).encryptor()
    ciphertext = encryptor.update(padded) + encryptor.finalize()

    combined = bytes([2]) + iv + ciphertext
    return base64.b64encode(combined).decode('ascii')


def decrypt_field(encrypted_b64: str, uid: str) -> Any:
    """Decifra un campo `*_encrypted` (formato v2: 1 byte versione + 16 byte
    IV + ciphertext AES-256-CBC, tutto base64). Solleva ValueError se il
    formato non è v2 o il payload è corrotto."""
    combined = base64.b64decode(encrypted_b64)
    if len(combined) <= 17 or combined[0] != 2:
        raise ValueError("Formato cifrato non supportato (solo v2)")

    iv = combined[1:17]
    ciphertext = combined[17:]

    key = _derive_key(uid)
    decryptor = Cipher(algorithms.AES(key), modes.CBC(iv)).decryptor()
    padded = decryptor.update(ciphertext) + decryptor.finalize()

    unpadder = padding.PKCS7(algorithms.AES.block_size).unpadder()
    plaintext = unpadder.update(padded) + unpadder.finalize()

    return json.loads(plaintext.decode('utf-8'))


def load_diet_plan(diet_data: dict, uid: str) -> dict:
    """Ritorna il piano dieta in chiaro da un doc `diets/*`, indipendentemente
    dal formato di salvataggio (server in chiaro o client cifrato). Ritorna
    {} se assente o se la decrittazione fallisce (stesso comportamento
    "dieta vuota" già presente prima di questa fix, non un peggioramento)."""
    if diet_data.get('encrypted') and diet_data.get('plan_encrypted'):
        try:
            decrypted = decrypt_field(diet_data['plan_encrypted'], uid)
            return decrypted if isinstance(decrypted, dict) else {}
        except Exception as e:
            logger.warning("diet_plan_decrypt_failed", uid=uid, error=sanitize_error_message(e))
            return {}
    return diet_data.get('plan') or {}


def load_diet_field(diet_data: dict, uid: str, plain_key: str, encrypted_key: Optional[str] = None) -> Any:
    """Variante generica di load_diet_plan per altri campi cifrati
    (substitutions/activeSwaps/weeks)."""
    enc_key = encrypted_key or f"{plain_key}_encrypted"
    if diet_data.get('encrypted') and diet_data.get(enc_key):
        try:
            return decrypt_field(diet_data[enc_key], uid)
        except Exception as e:
            logger.warning("diet_field_decrypt_failed", uid=uid, field=plain_key, error=sanitize_error_message(e))
            return None
    return diet_data.get(plain_key)
