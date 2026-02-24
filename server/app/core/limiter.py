"""
Rate limiter condiviso tra tutti i router FastAPI.
Usa slowapi con chiave composita IP:UID quando l'utente è autenticato,
altrimenti solo IP. Importare `limiter` nei router per applicare @limiter.limit().
"""
import base64
import json

from slowapi import Limiter
from slowapi.util import get_remote_address
from fastapi import Request


def get_rate_limit_key(request: Request) -> str:
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
