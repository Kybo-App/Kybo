"""
Worker per l'invio automatico del report PDF mensile ai nutrizionisti.

Logica:
- Gira ogni ora (stesso ciclo di altri worker)
- Il giorno 1 di ogni mese, alle 08:00 UTC, invia il PDF del mese precedente
- Traccia i report già inviati in Firestore: config/report_mailer/{uid}/{YYYY-MM}
- Salta se SMTP non è configurato o se il report è già stato inviato

Dati PDF inclusi:
- Riepilogo clienti (totali, nuovi, attivi)
- Diete caricate
- Messaggi scambiati
- Tempo di risposta medio
"""
import asyncio
import io
from datetime import datetime, timezone, timedelta
from typing import Optional

import firebase_admin
from firebase_admin import firestore

from app.core.config import settings
from app.core.logging import logger
from app.services.report_service import ReportService
from app.services.email_service import send_email


async def monthly_report_mailer_worker():
    """Worker che invia il PDF del report mensile il giorno 1 di ogni mese."""
    logger.info("monthly_report_mailer_started")

    while True:
        try:
            now = datetime.now(timezone.utc)
            # Invia solo il giorno 1 del mese, tra le 07:00 e le 09:00 UTC
            if now.day == 1 and 7 <= now.hour < 9:
                await _send_monthly_reports(now)
        except Exception as e:
            logger.error("monthly_report_mailer_error", error=str(e)[:300])

        # Controlla ogni ora
        await asyncio.sleep(3600)


async def _send_monthly_reports(now: datetime):
    """Genera e invia i report del mese precedente a tutti i nutrizionisti."""
    # Mese precedente
    first_of_this_month = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    last_month = first_of_this_month - timedelta(days=1)
    year = last_month.year
    month = last_month.month
    month_str = f"{year}-{month:02d}"

    db = firebase_admin.firestore.client()

    # Recupera tutti i nutrizionisti
    nutritionists = db.collection("users") \
        .where("role", "in", ["nutritionist", "admin"]) \
        .stream()

    service = ReportService()

    for doc in nutritionists:
        uid = doc.id
        data = doc.to_dict()
        email = data.get("email", "")
        if not email:
            continue

        # Controlla se già inviato
        if _already_sent(db, uid, month_str):
            continue

        try:
            # Genera report
            report = await service.generate_monthly_report(
                nutritionist_id=uid,
                year=year,
                month=month,
            )

            # Crea PDF in memoria
            pdf_bytes = _generate_pdf(report.to_dict(), month_str)

            # Invia email con PDF allegato
            sent = await _send_report_email(
                to_email=email,
                nutritionist_name=report.nutritionist_name or email,
                month_str=month_str,
                pdf_bytes=pdf_bytes,
            )

            if sent:
                _mark_sent(db, uid, month_str)
                logger.info("monthly_report_emailed", uid=uid, month=month_str)

        except Exception as e:
            logger.error("monthly_report_email_error", uid=uid, month=month_str, error=str(e)[:200])


def _generate_pdf(report: dict, month_str: str) -> bytes:
    """Genera il PDF del report usando fpdf2. Restituisce bytes."""
    from fpdf import FPDF

    pdf = FPDF()
    pdf.add_page()
    pdf.set_auto_page_break(auto=True, margin=15)

    # ── Header ──────────────────────────────────────────────────────────────
    pdf.set_fill_color(46, 125, 50)  # Kybo green
    pdf.rect(0, 0, 210, 30, 'F')
    pdf.set_font("Helvetica", "B", 20)
    pdf.set_text_color(255, 255, 255)
    pdf.set_xy(10, 8)
    pdf.cell(0, 12, "Kybo — Report Mensile", ln=True)
    pdf.set_font("Helvetica", "", 11)
    pdf.set_xy(10, 19)
    pdf.cell(0, 8, f"Periodo: {month_str}  |  Nutrizionista: {report.get('nutritionist_name', '')}", ln=True)

    pdf.set_text_color(30, 30, 30)
    pdf.ln(12)

    def section_title(title: str):
        pdf.set_font("Helvetica", "B", 13)
        pdf.set_fill_color(232, 245, 233)
        pdf.set_text_color(46, 125, 50)
        pdf.cell(0, 9, title, ln=True, fill=True)
        pdf.set_text_color(30, 30, 30)
        pdf.ln(2)

    def row(label: str, value: str):
        pdf.set_font("Helvetica", "", 11)
        pdf.set_x(14)
        pdf.cell(90, 7, label)
        pdf.set_font("Helvetica", "B", 11)
        pdf.cell(0, 7, value, ln=True)

    # ── Clienti ─────────────────────────────────────────────────────────────
    section_title("  Clienti")
    row("Clienti totali:", str(report.get("total_clients", 0)))
    row("Nuovi clienti nel mese:", str(report.get("new_clients", 0)))
    row("Clienti attivi nel mese:", str(report.get("active_clients", 0)))
    pdf.ln(4)

    # ── Diete ───────────────────────────────────────────────────────────────
    section_title("  Diete")
    row("Diete caricate:", str(report.get("diets_uploaded", 0)))
    pdf.ln(4)

    # ── Chat & Messaggi ──────────────────────────────────────────────────────
    section_title("  Messaggi")
    row("Messaggi inviati:", str(report.get("total_messages_sent", 0)))
    row("Messaggi ricevuti:", str(report.get("total_messages_received", 0)))
    avg_resp = report.get("average_response_time_hours")
    avg_str = f"{avg_resp:.1f} ore" if avg_resp is not None else "N/D"
    row("Tempo risposta medio:", avg_str)
    pdf.ln(4)

    # ── Footer ───────────────────────────────────────────────────────────────
    pdf.set_font("Helvetica", "I", 9)
    pdf.set_text_color(120, 120, 120)
    generated = report.get("generated_at", "")
    pdf.cell(0, 6, f"Report generato il {generated[:10] if generated else 'N/D'}  —  Kybo", ln=True)

    return bytes(pdf.output())


async def _send_report_email(
    to_email: str,
    nutritionist_name: str,
    month_str: str,
    pdf_bytes: bytes,
) -> bool:
    """Invia l'email con il PDF allegato tramite aiosmtplib."""
    import email as email_lib
    from email.mime.multipart import MIMEMultipart
    from email.mime.text import MIMEText
    from email.mime.application import MIMEApplication
    import aiosmtplib

    if not (settings.SMTP_HOST and settings.SMTP_USERNAME and settings.SMTP_PASSWORD):
        return False

    subject = f"[Kybo] Report mensile {month_str}"

    body_html = f"""
<html><body style="font-family:Arial,sans-serif;color:#1a202c;">
  <div style="max-width:520px;margin:auto;padding:32px;">
    <h2 style="color:#2E7D32;">Report mensile — {month_str}</h2>
    <p>Ciao {nutritionist_name},</p>
    <p>In allegato trovi il report con le metriche del mese <strong>{month_str}</strong>.</p>
    <p>Accedi al pannello per i dettagli completi:<br>
      <a href="https://app.kybo.it" style="color:#2E7D32;">app.kybo.it</a>
    </p>
    <p style="color:#888;font-size:12px;margin-top:24px;">
      Hai ricevuto questa email perché sei registrato come professionista su Kybo.
    </p>
  </div>
</body></html>
"""

    msg = MIMEMultipart("mixed")
    msg["Subject"] = subject
    msg["From"] = f"{settings.SMTP_FROM_NAME} <{settings.SMTP_FROM_EMAIL}>"
    msg["To"] = to_email

    msg.attach(MIMEText(body_html, "html", "utf-8"))

    attachment = MIMEApplication(pdf_bytes, _subtype="pdf")
    attachment.add_header(
        "Content-Disposition",
        "attachment",
        filename=f"kybo_report_{month_str}.pdf",
    )
    msg.attach(attachment)

    try:
        await aiosmtplib.send(
            msg,
            hostname=settings.SMTP_HOST,
            port=settings.SMTP_PORT,
            username=settings.SMTP_USERNAME,
            password=settings.SMTP_PASSWORD,
            start_tls=True,
            timeout=20,
        )
        logger.info("report_email_sent", to=to_email, month=month_str)
        return True
    except Exception as e:
        logger.error("report_email_send_error", to=to_email, error=str(e)[:200])
        return False


def _already_sent(db, uid: str, month_str: str) -> bool:
    doc = db.collection("config").document("report_mailer") \
        .collection("sent").document(f"{uid}_{month_str}").get()
    return doc.exists


def _mark_sent(db, uid: str, month_str: str):
    db.collection("config").document("report_mailer") \
        .collection("sent").document(f"{uid}_{month_str}") \
        .set({"sent_at": firestore.SERVER_TIMESTAMP, "uid": uid, "month": month_str})
