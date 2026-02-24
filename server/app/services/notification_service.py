"""
Servizio notifiche push per Kybo.
Invia messaggi FCM tramite Firebase Messaging.
NotificationService è un singleton che inizializza Firebase se non già fatto.
"""
import logging
import firebase_admin
from firebase_admin import credentials, messaging
import os

from app.services.app_config_service import get_app_config

logger = logging.getLogger(__name__)

class NotificationService:
    _initialized = False

    def __init__(self):
        if not NotificationService._initialized:
            self._init_firebase()
            NotificationService._initialized = True

    def _init_firebase(self):
        if firebase_admin._apps:
            return

        key_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")

        try:
            if key_path and os.path.exists(key_path):
                cred = credentials.Certificate(key_path)
                firebase_admin.initialize_app(cred)
                logger.info("Firebase Admin Initialized (File: %s)", key_path)
            else:
                logger.warning("GOOGLE_APPLICATION_CREDENTIALS non settata o file mancante.")

        except Exception as e:
            logger.error("Firebase Init Error: %s", e)

    def send_diet_ready(self, fcm_token: str) -> None:
        if not fcm_token or not isinstance(fcm_token, str):
            logger.warning("Skipping notification: Invalid FCM token")
            return

        try:
            cfg = get_app_config()
            message = messaging.Message(
                notification=messaging.Notification(
                    title=cfg["notification_diet_title"],
                    body=cfg["notification_diet_body"],
                ),
                token=fcm_token,
            )
            response = messaging.send(message)
            logger.info("Notification sent: %s", response)
        except Exception as e:
            logger.error("Notification Error: %s", e)
