"""
Rate limiter condiviso tra tutti i router FastAPI.
Usa solo l'IP come chiave di rate limiting.

SECURITY NOTE: il payload JWT non viene usato per la chiave perché non è
verificato qui (la firma non è controllata). Un attaccante potrebbe forgiare
payload con UID diversi per bypassare i limiti per-utente. L'IP è l'unica
fonte attendibile in questo contesto. La verifica del token avviene separatamente
in verify_token() tramite Firebase Auth SDK.
"""
from slowapi import Limiter
from slowapi.util import get_remote_address
from fastapi import Request


def get_rate_limit_key(request: Request) -> str:
    """Chiave rate limit basata solo sull'IP — sicura contro JWT forgery."""
    return get_remote_address(request)


limiter = Limiter(key_func=get_rate_limit_key)
