"""
Servizio email asincrono per Kybo.
Usa aiosmtplib per invio email non bloccante.
Le email sono abilitate solo se SMTP_HOST è configurato in .env
"""
import asyncio
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Optional

import aiosmtplib

from app.core.config import settings
from app.core.logging import logger


def _is_email_configured() -> bool:
    """True se SMTP è configurato correttamente."""
    return bool(settings.SMTP_HOST and settings.SMTP_USERNAME and settings.SMTP_PASSWORD)


async def send_email(
    to_email: str,
    subject: str,
    body_html: str,
    body_text: Optional[str] = None,
) -> bool:
    """
    Invia una email in modo asincrono.
    Restituisce True se inviata con successo, False altrimenti.
    Non solleva eccezioni per non bloccare il chiamante.
    """
    if not _is_email_configured():
        logger.warning("email_not_configured", to=to_email, subject=subject)
        return False

    try:
        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"] = f"{settings.SMTP_FROM_NAME} <{settings.SMTP_FROM_EMAIL}>"
        msg["To"] = to_email

        if body_text:
            msg.attach(MIMEText(body_text, "plain", "utf-8"))
        msg.attach(MIMEText(body_html, "html", "utf-8"))

        await aiosmtplib.send(
            msg,
            hostname=settings.SMTP_HOST,
            port=settings.SMTP_PORT,
            username=settings.SMTP_USERNAME,
            password=settings.SMTP_PASSWORD,
            start_tls=True,
            timeout=15,
        )
        logger.info("email_sent", to=to_email, subject=subject)
        return True

    except Exception as e:
        logger.error("email_send_error", to=to_email, error=str(e)[:200])
        return False


async def send_unread_messages_alert(
    nutritionist_email: str,
    nutritionist_name: str,
    client_name: str,
    unread_count: int,
    days_unread: int,
) -> bool:
    """
    Invia notifica email al nutrizionista per messaggi non letti.
    """
    subject = f"[Kybo] Hai {unread_count} messaggi non letti da {client_name}"

    body_html = f"""
<!DOCTYPE html>
<html lang="it">
<head>
  <meta charset="UTF-8">
  <style>
    body {{ font-family: Arial, sans-serif; background: #f8fafc; margin: 0; padding: 0; }}
    .container {{ max-width: 560px; margin: 40px auto; background: #fff;
                  border-radius: 16px; padding: 36px; box-shadow: 0 2px 12px rgba(0,0,0,0.08); }}
    .logo {{ color: #2E7D32; font-size: 22px; font-weight: 700; margin-bottom: 24px; }}
    .badge {{ display: inline-block; background: #2E7D32; color: #fff;
              border-radius: 999px; padding: 4px 14px; font-size: 13px; font-weight: 600; }}
    h2 {{ color: #1a202c; font-size: 18px; margin: 16px 0 8px; }}
    p {{ color: #4a5568; font-size: 14px; line-height: 1.6; margin: 0 0 12px; }}
    .cta {{ display: inline-block; margin-top: 20px; background: #2E7D32; color: #fff;
            padding: 12px 28px; border-radius: 999px; text-decoration: none;
            font-weight: 600; font-size: 14px; }}
    .footer {{ margin-top: 32px; font-size: 12px; color: #a0aec0; text-align: center; }}
  </style>
</head>
<body>
  <div class="container">
    <div class="logo">🥗 Kybo</div>
    <span class="badge">{unread_count} messaggi non letti</span>
    <h2>Ciao {nutritionist_name},</h2>
    <p>
      Il tuo cliente <strong>{client_name}</strong> ti ha inviato
      <strong>{unread_count} messaggi</strong> che non hai ancora letto.
    </p>
    <p>
      L'ultimo messaggio risale a <strong>{days_unread} giorni fa</strong>.
      Accedi al pannello per rispondere.
    </p>
    <a class="cta" href="https://app.kybo.it">Apri Kybo Admin</a>
    <div class="footer">
      Hai ricevuto questa email perché hai attivato gli alert per messaggi non letti.<br>
      Puoi disattivarli dal pannello Kybo → Impostazioni → Notifiche Email.
    </div>
  </div>
</body>
</html>
"""

    body_text = (
        f"Ciao {nutritionist_name},\n\n"
        f"Il tuo cliente {client_name} ti ha inviato {unread_count} messaggi "
        f"non letti. L'ultimo risale a {days_unread} giorni fa.\n\n"
        f"Accedi al pannello: https://app.kybo.it\n\n"
        f"-- Kybo"
    )

    return await send_email(nutritionist_email, subject, body_html, body_text)
