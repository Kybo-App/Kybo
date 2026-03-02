"""
Newsletter & Contact Router — Kybo API

Newsletter:
  POST /newsletter/subscribe    — iscrizione via email
  POST /newsletter/unsubscribe  — disiscrizione via email

Contact:
  POST /contact/submit          — invio modulo di contatto (no auth richiesta)
  I messaggi vengono salvati in Firestore: contact_requests/{id}
"""

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, EmailStr
from firebase_admin import firestore
from app.core.firebase import db
from app.core.limiter import limiter

# ---------------------------------------------------------------------------
# Newsletter
# ---------------------------------------------------------------------------

router = APIRouter(prefix="/newsletter", tags=["newsletter"])


class NewsletterSubscribeRequest(BaseModel):
    email: EmailStr


@router.post("/subscribe")
@limiter.limit("10/hour")
async def subscribe(request: Request, req: NewsletterSubscribeRequest):
    email = req.email.lower().strip()

    existing = (
        db.collection("newsletter_subscribers")
        .where("email", "==", email)
        .limit(1)
        .get()
    )
    if existing:
        return {"message": "Già iscritto"}

    db.collection("newsletter_subscribers").add({
        "email": email,
        "subscribed_at": firestore.SERVER_TIMESTAMP,
        "active": True,
        "source": "landing_page",
    })

    return {"message": "Iscrizione completata"}


@router.post("/unsubscribe")
@limiter.limit("10/hour")
async def unsubscribe(request: Request, req: NewsletterSubscribeRequest):
    email = req.email.lower().strip()
    docs = (
        db.collection("newsletter_subscribers")
        .where("email", "==", email)
        .get()
    )
    for doc in docs:
        doc.reference.update({"active": False})
    return {"message": "Disiscrizione completata"}


# ---------------------------------------------------------------------------
# Contact form
# ---------------------------------------------------------------------------

contact_router = APIRouter(prefix="/contact", tags=["contact"])


class ContactFormRequest(BaseModel):
    name: str
    email: EmailStr
    message: str


@contact_router.post("/submit")
@limiter.limit("5/hour")
async def submit_contact(request: Request, req: ContactFormRequest):
    name = req.name.strip()[:100]
    message = req.message.strip()[:2000]

    if not name or not message:
        raise HTTPException(
            status_code=422,
            detail="Nome e messaggio sono obbligatori.",
        )

    db.collection("contact_requests").add({
        "name": name,
        "email": req.email.lower().strip(),
        "message": message,
        "submitted_at": firestore.SERVER_TIMESTAMP,
        "status": "new",
    })

    return {"message": "Messaggio ricevuto. Ti risponderemo entro 24 ore!"}
