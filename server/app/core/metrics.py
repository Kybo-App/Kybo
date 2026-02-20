"""
Metriche custom Prometheus per Kybo API.

Espone counter e histogram per:
- Parsing diete (Gemini AI calls, cache hit/miss per layer)
- Suggerimenti pasti (Gemini calls, cache hit/miss)
- Token autenticazione (cache hit/miss)
- Errori per tipo/router

Utilizzo:
    from app.core.metrics import (
        diet_gemini_calls_total,
        diet_cache_hits_total,
        diet_parse_duration_seconds,
        suggestions_gemini_calls_total,
        suggestions_cache_hits_total,
        record_cache_hit,
        record_cache_miss,
    )

    # In diet_service.py
    diet_gemini_calls_total.inc()
    with diet_parse_duration_seconds.time():
        result = call_gemini(...)

    # Cache hit/miss helpers
    record_cache_hit("diet", "L1_ram")
    record_cache_miss("suggestions", "L1.5_redis")
"""
from prometheus_client import Counter, Histogram, Gauge, Info

# ─── Info applicazione ────────────────────────────────────────────────────────

app_info = Info(
    "kybo_app",
    "Informazioni sull'applicazione Kybo API",
)
app_info.info({
    "version": "2.0.0",
    "service": "kybo-api",
})

# ─── Parsing diete (Gemini AI) ────────────────────────────────────────────────

diet_gemini_calls_total = Counter(
    "kybo_diet_gemini_calls_total",
    "Numero totale di chiamate a Gemini AI per il parsing diete",
)

diet_gemini_errors_total = Counter(
    "kybo_diet_gemini_errors_total",
    "Numero totale di errori nelle chiamate Gemini per il parsing diete",
)

diet_cache_hits_total = Counter(
    "kybo_diet_cache_hits_total",
    "Cache hit nel parsing diete, per layer",
    ["layer"],  # L1_ram, L1.5_redis, L2_firestore
)

diet_cache_misses_total = Counter(
    "kybo_diet_cache_misses_total",
    "Cache miss nel parsing diete, per layer",
    ["layer"],
)

diet_parse_duration_seconds = Histogram(
    "kybo_diet_parse_duration_seconds",
    "Durata parsing dieta (solo chiamate Gemini, escluse cache hit)",
    buckets=[1, 5, 10, 20, 30, 45, 60, 90, 120],
)

diet_uploads_total = Counter(
    "kybo_diet_uploads_total",
    "Numero totale di upload diete",
)

diet_upload_size_bytes = Histogram(
    "kybo_diet_upload_size_bytes",
    "Dimensione in byte dei PDF caricati",
    buckets=[50_000, 100_000, 250_000, 500_000, 1_000_000, 5_000_000, 10_000_000],
)

# ─── Suggerimenti pasti ───────────────────────────────────────────────────────

suggestions_gemini_calls_total = Counter(
    "kybo_suggestions_gemini_calls_total",
    "Numero totale di chiamate a Gemini AI per i suggerimenti pasti",
)

suggestions_gemini_errors_total = Counter(
    "kybo_suggestions_gemini_errors_total",
    "Numero totale di errori nelle chiamate Gemini per i suggerimenti pasti",
)

suggestions_cache_hits_total = Counter(
    "kybo_suggestions_cache_hits_total",
    "Cache hit nei suggerimenti pasti, per layer",
    ["layer"],  # L1_ram, L1.5_redis
)

suggestions_cache_misses_total = Counter(
    "kybo_suggestions_cache_misses_total",
    "Cache miss nei suggerimenti pasti, per layer",
    ["layer"],
)

suggestions_duration_seconds = Histogram(
    "kybo_suggestions_duration_seconds",
    "Durata generazione suggerimenti pasti (solo Gemini, escluse cache hit)",
    buckets=[2, 5, 10, 15, 20, 30],
)

# ─── Token / Autenticazione ───────────────────────────────────────────────────

auth_token_cache_hits_total = Counter(
    "kybo_auth_token_cache_hits_total",
    "Token JWT trovati in cache RAM",
)

auth_token_cache_misses_total = Counter(
    "kybo_auth_token_cache_misses_total",
    "Token JWT non trovati in cache (verifica Firebase richiesta)",
)

auth_errors_total = Counter(
    "kybo_auth_errors_total",
    "Errori di autenticazione",
    ["reason"],  # invalid_token, expired, missing
)

# ─── Redis ───────────────────────────────────────────────────────────────────

redis_operations_total = Counter(
    "kybo_redis_operations_total",
    "Operazioni Redis totali",
    ["operation", "result"],  # operation: get/set/delete; result: ok/error
)

# ─── OCR / Scontrino ─────────────────────────────────────────────────────────

ocr_scans_total = Counter(
    "kybo_ocr_scans_total",
    "Numero totale di scansioni scontrino via OCR",
)

ocr_errors_total = Counter(
    "kybo_ocr_errors_total",
    "Numero totale di errori OCR",
)

ocr_duration_seconds = Histogram(
    "kybo_ocr_duration_seconds",
    "Durata scansione scontrino OCR",
    buckets=[0.5, 1, 2, 5, 10, 20],
)

# ─── Gauge in tempo reale ────────────────────────────────────────────────────

diet_memory_cache_size = Gauge(
    "kybo_diet_memory_cache_size",
    "Numero di entry nella cache RAM del parser diete",
)

suggestions_memory_cache_size = Gauge(
    "kybo_suggestions_memory_cache_size",
    "Numero di entry nella cache RAM dei suggerimenti pasti",
)

# ─── Helper functions ─────────────────────────────────────────────────────────


def record_cache_hit(service: str, layer: str) -> None:
    """
    Registra un cache hit per il servizio e layer specificati.

    Args:
        service: "diet" | "suggestions"
        layer:   "L1_ram" | "L1.5_redis" | "L2_firestore"
    """
    if service == "diet":
        diet_cache_hits_total.labels(layer=layer).inc()
    elif service == "suggestions":
        suggestions_cache_hits_total.labels(layer=layer).inc()


def record_cache_miss(service: str, layer: str) -> None:
    """
    Registra un cache miss per il servizio e layer specificati.

    Args:
        service: "diet" | "suggestions"
        layer:   "L1_ram" | "L1.5_redis" | "L2_firestore"
    """
    if service == "diet":
        diet_cache_misses_total.labels(layer=layer).inc()
    elif service == "suggestions":
        suggestions_cache_misses_total.labels(layer=layer).inc()


def update_cache_size_gauges(diet_size: int, suggestions_size: int) -> None:
    """Aggiorna i gauge delle dimensioni cache RAM."""
    diet_memory_cache_size.set(diet_size)
    suggestions_memory_cache_size.set(suggestions_size)
