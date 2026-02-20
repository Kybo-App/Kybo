"""
Redis Cache Layer per Kybo API.

Implementa un cache layer distribuito (L1.5) tra la cache RAM locale (L1)
e Firestore (L2). Funziona in modalità graceful degradation: se Redis non
è configurato o non è raggiungibile, tutte le operazioni diventano no-op
e il sistema cade di silenzio sui layer L1/L2 esistenti.

Livelli di cache:
  L1  — RAM in-process        (microsecondi, locale)
  L1.5 — Redis                (millisecondi, condiviso tra istanze)
  L2  — Firestore             (decine ms, persistente 30 giorni)

Utilizzo:
    from app.core.cache import redis_cache

    # Scrittura
    await redis_cache.set("chiave", {"dato": 1}, ttl=3600)

    # Lettura
    value = await redis_cache.get("chiave")  # None se non trovato

    # Invalidazione
    await redis_cache.delete("chiave")
    await redis_cache.delete_pattern("uid:*")
"""
import json
import asyncio
from typing import Any, Optional
from app.core.logging import logger
from app.core.config import settings


class RedisCache:
    """
    Wrapper asincrono attorno a Redis con:
    - Connessione lazy (primo utilizzo)
    - Graceful fallback se Redis non disponibile
    - Serializzazione JSON automatica
    - Prefisso namespace per evitare collisioni chiavi
    """

    _client = None           # redis.asyncio.Redis
    _initialized = False     # True dopo primo tentativo di connessione
    _available = False       # True solo se Redis è davvero raggiungibile

    NAMESPACE = "kybo"

    # ─── Init & connessione ──────────────────────────────────────────────────

    async def _ensure_connected(self) -> bool:
        """
        Connette a Redis al primo utilizzo.
        Ritorna True se Redis è disponibile, False altrimenti.
        """
        if self._initialized:
            return self._available

        self._initialized = True

        if not settings.REDIS_URL:
            logger.info("redis_disabled", reason="REDIS_URL not configured")
            self._available = False
            return False

        try:
            import redis.asyncio as aioredis
            self._client = aioredis.from_url(
                settings.REDIS_URL,
                encoding="utf-8",
                decode_responses=True,
                socket_connect_timeout=2,
                socket_timeout=2,
                retry_on_timeout=False,
                max_connections=20,
            )
            # Verifica connessione
            await self._client.ping()
            self._available = True
            logger.info("redis_connected", url=settings.REDIS_URL.split("@")[-1])
        except Exception as e:
            self._available = False
            logger.warning("redis_unavailable", error=str(e))

        return self._available

    # ─── Chiave con namespace ────────────────────────────────────────────────

    def _key(self, key: str) -> str:
        return f"{self.NAMESPACE}:{key}"

    # ─── API pubblica ─────────────────────────────────────────────────────────

    async def get(self, key: str) -> Optional[Any]:
        """
        Legge un valore da Redis.
        Ritorna il valore deserializzato o None se non trovato / Redis non disponibile.
        """
        if not await self._ensure_connected():
            return None
        try:
            raw = await self._client.get(self._key(key))
            if raw is None:
                return None
            return json.loads(raw)
        except Exception as e:
            logger.warning("redis_get_error", key=key, error=str(e))
            return None

    async def set(self, key: str, value: Any, ttl: int = 3600) -> bool:
        """
        Scrive un valore in Redis con TTL in secondi.
        Ritorna True se successo, False altrimenti.
        """
        if not await self._ensure_connected():
            return False
        try:
            serialized = json.dumps(value, default=str)
            await self._client.setex(self._key(key), ttl, serialized)
            return True
        except Exception as e:
            logger.warning("redis_set_error", key=key, error=str(e))
            return False

    async def delete(self, key: str) -> bool:
        """Elimina una chiave da Redis."""
        if not await self._ensure_connected():
            return False
        try:
            await self._client.delete(self._key(key))
            return True
        except Exception as e:
            logger.warning("redis_delete_error", key=key, error=str(e))
            return False

    async def delete_pattern(self, pattern: str) -> int:
        """
        Elimina tutte le chiavi che corrispondono al pattern (glob-style).
        Usa SCAN per evitare di bloccare Redis su grandi dataset.
        Ritorna il numero di chiavi eliminate.
        """
        if not await self._ensure_connected():
            return 0
        try:
            full_pattern = self._key(pattern)
            deleted = 0
            cursor = 0
            while True:
                cursor, keys = await self._client.scan(
                    cursor=cursor, match=full_pattern, count=100
                )
                if keys:
                    await self._client.delete(*keys)
                    deleted += len(keys)
                if cursor == 0:
                    break
            return deleted
        except Exception as e:
            logger.warning("redis_delete_pattern_error", pattern=pattern, error=str(e))
            return 0

    async def exists(self, key: str) -> bool:
        """Verifica se una chiave esiste in Redis."""
        if not await self._ensure_connected():
            return False
        try:
            return bool(await self._client.exists(self._key(key)))
        except Exception as e:
            logger.warning("redis_exists_error", key=key, error=str(e))
            return False

    async def ttl(self, key: str) -> int:
        """Ritorna il TTL restante in secondi (-1 se no TTL, -2 se non esiste)."""
        if not await self._ensure_connected():
            return -2
        try:
            return await self._client.ttl(self._key(key))
        except Exception as e:
            logger.warning("redis_ttl_error", key=key, error=str(e))
            return -2

    async def flush_namespace(self) -> int:
        """Elimina tutte le chiavi del namespace kybo:*. Usare con cautela."""
        return await self.delete_pattern("*")

    async def ping(self) -> bool:
        """Verifica che Redis sia raggiungibile."""
        if not await self._ensure_connected():
            return False
        try:
            return await self._client.ping()
        except Exception:
            return False

    async def close(self) -> None:
        """Chiude la connessione a Redis (da chiamare allo shutdown del server)."""
        if self._client is not None:
            try:
                await self._client.aclose()
            except Exception:
                pass

    @property
    def is_available(self) -> bool:
        """True se Redis è stato connesso con successo."""
        return self._available


# ─── Singleton globale ────────────────────────────────────────────────────────

redis_cache = RedisCache()
