"""
Configurazione logging centralizzata con sanitizzazione dati sensibili.
"""
import re
import structlog


def sanitize_error_message(error) -> str:
    """
    Rimuove dati sensibili (token, email) dai messaggi di errore prima di loggarli.
    """
    sanitized = str(error)
    # Rimuovi token Bearer
    sanitized = re.sub(r'Bearer\s+[A-Za-z0-9\-_\.]+', 'Bearer ***', sanitized)
    # Rimuovi token generici
    sanitized = re.sub(r'token["\']?\s*:\s*["\']?[A-Za-z0-9\-_\.]+', 'token: ***', sanitized, flags=re.IGNORECASE)
    # Rimuovi email
    sanitized = re.sub(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b', '***@***.***', sanitized)
    return sanitized


def sensitive_data_filter(logger, method_name, event_dict):
    """
    Filtra automaticamente token e dati sensibili dai log (structlog processor).
    Applica sanitizzazione a TUTTI i campi del log, non solo 'error'.
    """
    sensitive_keys = ['error', 'message', 'detail', 'data', 'token', 'authorization', 'password', 'secret']

    for key, value in list(event_dict.items()):
        if isinstance(value, str):
            if key.lower() in sensitive_keys or 'token' in key.lower() or 'auth' in key.lower():
                event_dict[key] = sanitize_error_message(value)
            elif 'eyJ' in value:  # JWT tokens start with eyJ
                event_dict[key] = re.sub(
                    r'eyJ[A-Za-z0-9\-_]+\.eyJ[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+',
                    '[JWT_REDACTED]',
                    value
                )

    if 'error' in event_dict:
        event_dict['error'] = sanitize_error_message(str(event_dict['error']))

    return event_dict


# Configura structlog
structlog.configure(
    processors=[
        structlog.processors.TimeStamper(fmt="iso"),
        sensitive_data_filter,
        structlog.processors.JSONRenderer()
    ],
    logger_factory=structlog.stdlib.LoggerFactory(),
)

logger = structlog.get_logger()
