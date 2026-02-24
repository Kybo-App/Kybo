"""
Configurazione centralizzata dell'applicazione tramite pydantic-settings.
Legge variabili d'ambiente e .env automaticamente.
ALLOWED_ORIGINS varia per ambiente: PROD usa solo domini di produzione,
STAGING aggiunge localhost, DEV usa solo localhost.
"""
import os
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    GOOGLE_API_KEY: str = ""
    GEMINI_MODEL: str = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
    ENV: str = os.getenv("ENV", "DEV")
    SENTRY_DSN: str = os.getenv("SENTRY_DSN", "")
    STORAGE_BUCKET: str = os.getenv("STORAGE_BUCKET", "mydiet-6d55b.appspot.com")

    _dev_origins: list[str] = [
        "http://localhost:3000",
        "http://localhost:8080",
        "http://localhost:4000",
        "http://localhost:5000",
    ]

    _prod_origins: list[str] = [
        "https://app.kybo.it",
        "https://kybo.it"
    ]

    @property
    def ALLOWED_ORIGINS(self) -> list[str]:
        """
        CORS più restrittivo per ambiente:
        - PROD: Solo domini di produzione
        - STAGING: Localhost + produzione (per test pre-deploy)
        - DEV: Solo localhost (evita test accidentali con dati prod)
        """
        if self.ENV == "PROD":
            return self._prod_origins
        elif self.ENV == "STAGING":
            return self._dev_origins + self._prod_origins
        else:
            return self._dev_origins

    REDIS_URL: str = os.getenv("REDIS_URL", "")
    REDIS_DIET_TTL: int = 3600
    REDIS_SUGGESTIONS_TTL: int = 1800
    REDIS_TOKEN_TTL: int = 1500

    MAX_FILE_SIZE: int = 10 * 1024 * 1024
    MAX_PDF_PAGES: int = 50
    MEMORY_CACHE_SIZE: int = 100
    MEMORY_CACHE_TTL: int = 3600
    FIRESTORE_CACHE_DAYS: int = 30
    DEFAULT_MAX_CLIENTS: int = 50
    MAX_CONCURRENT_HEAVY_TASKS: int = 2
    MAINTENANCE_POLL_INTERVAL: int = 60

    RQ_QUEUE_NAME: str = os.getenv("RQ_QUEUE_NAME", "diet_parsing")
    RQ_JOB_TIMEOUT: int = 300
    RQ_RESULT_TTL: int = 3600
    RQ_FAILURE_TTL: int = 86400
    RQ_INLINE_WORKER: bool = os.getenv("RQ_INLINE_WORKER", "true").lower() == "true"

    GDPR_RETENTION_MONTHS: int = 24
    GDPR_RETENTION_WARNING_DAYS: int = 30

    SMTP_HOST: str = os.getenv("SMTP_HOST", "")
    SMTP_PORT: int = int(os.getenv("SMTP_PORT", "587"))
    SMTP_USERNAME: str = os.getenv("SMTP_USERNAME", "")
    SMTP_PASSWORD: str = os.getenv("SMTP_PASSWORD", "")
    SMTP_FROM_EMAIL: str = os.getenv("SMTP_FROM_EMAIL", "noreply@kybo.it")
    SMTP_FROM_NAME: str = os.getenv("SMTP_FROM_NAME", "Kybo")

    UNREAD_NOTIFY_INTERVAL: int = 3600
    UNREAD_NOTIFY_DEFAULT_DAYS: int = 3

    DIET_PDF_PATH: str = "temp_dieta.pdf"
    RECEIPT_PATH_PREFIX: str = "temp_scontrino"
    DIET_JSON_PATH: str = "dieta.json"

    MEAL_MAPPING: dict = {
        "prima colazione": "Colazione",
        "seconda colazione": "Seconda Colazione",
        "spuntino mattina": "Seconda Colazione",
        "pranzo": "Pranzo",
        "merenda": "Merenda",
        "cena": "Cena",
        "spuntino serale": "Spuntino Serale"
    }

    class Config:
        env_file = ".env"

settings = Settings()
