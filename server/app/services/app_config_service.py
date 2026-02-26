"""
Servizio per leggere la configurazione app da Firestore config/global.
Usa una cache in-memory con TTL di 5 minuti per ridurre le letture Firestore.
Fornisce valori di default per tutte le chiavi configurabili in modo che il
server funzioni anche senza un documento config/global in Firestore.

Chiavi gestite: gemini_model, gemini_global_prompt_prefix,
notification_diet_title, notification_diet_body,
max_file_size_mb, max_pdf_pages.
"""
import time
import logging

logger = logging.getLogger(__name__)

_DEFAULTS = {
    "gemini_model": "gemini-2.5-flash",
    "gemini_global_prompt_prefix": "",
    "notification_diet_title": "Dieta Pronta! 🥗",
    "notification_diet_body": "Il tuo piano nutrizionale è stato elaborato.",
    "max_file_size_mb": 10,
    "max_pdf_pages": 50,
}

_CACHE_TTL = 300

_cache: dict = {}
_cache_expiry: float = 0.0


def get_app_config() -> dict:
    global _cache, _cache_expiry
    now = time.time()
    if _cache and now < _cache_expiry:
        # [SECURITY] Restituisce copia, non il riferimento diretto alla cache.
        # Se il chiamante modifica il dict ritornato, non altera la cache globale.
        return dict(_cache)

    try:
        import firebase_admin
        db = firebase_admin.firestore.client()
        doc = db.collection("config").document("global").get()
        merged = dict(_DEFAULTS)
        if doc.exists:
            data = doc.to_dict()
            for key in _DEFAULTS:
                if key in data and data[key] is not None:
                    merged[key] = data[key]
        _cache = merged
    except Exception as e:
        logger.warning("app_config_read_failed: %s", e)
        if not _cache:
            _cache = dict(_DEFAULTS)

    _cache_expiry = now + _CACHE_TTL
    return dict(_cache)


def invalidate_app_config_cache() -> None:
    global _cache, _cache_expiry
    _cache = {}
    _cache_expiry = 0.0
