"""
Worker per le notifiche email dei messaggi non letti.

Logica:
- Si avvia all'avvio del server come asyncio task
- Ogni UNREAD_NOTIFY_INTERVAL secondi scorre tutte le chat
- Per ogni chat dove unreadCount.nutritionist > 0:
    - Controlla se l'ultimo messaggio è più vecchio di X giorni
      (X è configurabile per-nutrizionista in config/email_alerts/{uid})
    - Evita di rinviare la stessa notifica: usa il campo last_unread_notify_at
    - Se condizioni soddisfatte → invia email al nutrizionista

Configurazione per-nutrizionista in Firestore:
  config/email_alerts/{nutritionist_uid}:
    enabled: bool          (default False)
    threshold_days: int    (default 3)
    last_notified_chats: dict  {chatId: ISO timestamp ultima notifica}
"""
import asyncio
from datetime import datetime, timezone, timedelta
from typing import Optional

import firebase_admin
from firebase_admin import firestore

from app.core.config import settings
from app.core.logging import logger
from app.services.email_service import send_unread_messages_alert


async def unread_notification_worker():
    """Worker asincrono che gira in background e invia notifiche email."""
    logger.info("unread_notifier_started")

    while True:
        try:
            await _check_and_notify()
        except Exception as e:
            logger.error("unread_notifier_error", error=str(e)[:300])

        await asyncio.sleep(settings.UNREAD_NOTIFY_INTERVAL)


async def _check_and_notify():
    """Controlla le chat con messaggi non letti e invia notifiche se necessario."""
    db = firebase_admin.firestore.client()

    # Recupera le configurazioni degli alert attivi
    alert_configs = _get_active_alert_configs(db)
    if not alert_configs:
        return

    now = datetime.now(timezone.utc)

    for nutritionist_uid, config in alert_configs.items():
        threshold_days = config.get("threshold_days", settings.UNREAD_NOTIFY_DEFAULT_DAYS)
        last_notified = config.get("last_notified_chats", {})

        # Cerca le chat del nutrizionista con messaggi non letti
        chats = db.collection("chats") \
            .where("chatType", "==", "nutritionist-client") \
            .where("participants.nutritionistId", "==", nutritionist_uid) \
            .stream()

        for chat_doc in chats:
            chat_data = chat_doc.to_dict()
            unread = chat_data.get("unreadCount", {}).get("nutritionist", 0)
            if unread <= 0:
                continue

            last_msg_time = chat_data.get("lastMessageTime")
            if not last_msg_time:
                continue

            # Normalizza a datetime aware
            if hasattr(last_msg_time, "seconds"):
                last_msg_dt = datetime.fromtimestamp(last_msg_time.seconds, tz=timezone.utc)
            elif isinstance(last_msg_time, datetime):
                last_msg_dt = last_msg_time if last_msg_time.tzinfo else last_msg_time.replace(tzinfo=timezone.utc)
            else:
                continue

            days_unread = (now - last_msg_dt).days
            if days_unread < threshold_days:
                continue

            # Evita notifiche duplicate: controlla l'ultima notifica per questa chat
            last_chat_notify = last_notified.get(chat_doc.id)
            if last_chat_notify:
                try:
                    last_notify_dt = datetime.fromisoformat(last_chat_notify)
                    if last_notify_dt.tzinfo is None:
                        last_notify_dt = last_notify_dt.replace(tzinfo=timezone.utc)
                    # Non re-notificare prima di threshold_days giorni dall'ultima notifica
                    if (now - last_notify_dt).days < threshold_days:
                        continue
                except ValueError:
                    pass

            # Recupera dati nutrizionista e cliente
            nutritionist_data = _get_user_data(db, nutritionist_uid)
            if not nutritionist_data or not nutritionist_data.get("email"):
                continue

            client_uid = chat_data.get("participants", {}).get("clientId", "")
            client_data = _get_user_data(db, client_uid)
            client_name = _format_name(client_data) if client_data else "un tuo cliente"

            nutritionist_name = _format_name(nutritionist_data)
            nutritionist_email = nutritionist_data["email"]

            # Invia email
            sent = await send_unread_messages_alert(
                nutritionist_email=nutritionist_email,
                nutritionist_name=nutritionist_name,
                client_name=client_name,
                unread_count=unread,
                days_unread=days_unread,
            )

            if sent:
                logger.info(
                    "unread_alert_sent",
                    nutritionist=nutritionist_uid,
                    chat=chat_doc.id,
                    unread=unread,
                    days=days_unread,
                )
                # Aggiorna il timestamp dell'ultima notifica per questa chat
                _update_last_notified(db, nutritionist_uid, chat_doc.id, now)


def _get_active_alert_configs(db) -> dict:
    """Restituisce tutte le configurazioni di alert email attive."""
    try:
        configs = {}
        docs = db.collection("config").document("email_alerts") \
            .collection("nutritionists").stream()
        for doc in docs:
            data = doc.to_dict()
            if data.get("enabled", False):
                configs[doc.id] = data
        return configs
    except Exception as e:
        logger.error("get_alert_configs_error", error=str(e)[:200])
        return {}


def _get_user_data(db, uid: str) -> Optional[dict]:
    """Recupera i dati di un utente da Firestore."""
    try:
        doc = db.collection("users").document(uid).get()
        return doc.to_dict() if doc.exists else None
    except Exception:
        return None


def _format_name(user_data: dict) -> str:
    first = user_data.get("first_name", "")
    last = user_data.get("last_name", "")
    name = f"{first} {last}".strip()
    return name if name else user_data.get("email", "Utente")


def _update_last_notified(db, nutritionist_uid: str, chat_id: str, now: datetime):
    """Aggiorna il timestamp dell'ultima notifica per una chat."""
    try:
        db.collection("config").document("email_alerts") \
            .collection("nutritionists").document(nutritionist_uid) \
            .set({
                "last_notified_chats": {chat_id: now.isoformat()}
            }, merge=True)
    except Exception as e:
        logger.error("update_last_notified_error", error=str(e)[:200])
