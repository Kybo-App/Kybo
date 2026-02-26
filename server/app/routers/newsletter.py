"""
Newsletter Router — Kybo API

Questo router e' DISATTIVATO di default.
Per attivarlo:
  1. Togli i commenti dal blocco sottostante
  2. Aggiungi in server/app/main.py:

     from app.routers import newsletter
     app.include_router(newsletter.router)

  3. Assicurati che la collezione Firestore "newsletter_subscribers"
     abbia le regole di sicurezza appropriate (solo admin in lettura).

Funzionalita' coperte:
  POST /newsletter/subscribe    — iscrizione via email
  POST /newsletter/unsubscribe  — disiscrizione via email
"""

# ---------------------------------------------------------------------------
# CODICE COMMENTATO — togli i commenti per attivare il router
# ---------------------------------------------------------------------------

# from fastapi import APIRouter, HTTPException
# from pydantic import BaseModel, EmailStr
# from firebase_admin import firestore
# from app.core.firebase import db
# import re
#
# router = APIRouter(prefix="/newsletter", tags=["newsletter"])
#
#
# class NewsletterSubscribeRequest(BaseModel):
#     email: EmailStr
#
#
# @router.post("/subscribe")
# async def subscribe(req: NewsletterSubscribeRequest):
#     email = req.email.lower().strip()
#
#     # Controlla se gia' iscritto
#     existing = (
#         db.collection("newsletter_subscribers")
#         .where("email", "==", email)
#         .limit(1)
#         .get()
#     )
#     if existing:
#         return {"message": "Gia' iscritto"}
#
#     # Salva in Firestore
#     db.collection("newsletter_subscribers").add({
#         "email": email,
#         "subscribed_at": firestore.SERVER_TIMESTAMP,
#         "active": True,
#         "source": "landing_page",
#     })
#
#     return {"message": "Iscrizione completata"}
#
#
# @router.post("/unsubscribe")
# async def unsubscribe(req: NewsletterSubscribeRequest):
#     email = req.email.lower().strip()
#     docs = (
#         db.collection("newsletter_subscribers")
#         .where("email", "==", email)
#         .get()
#     )
#     for doc in docs:
#         doc.reference.update({"active": False})
#     return {"message": "Disiscrizione completata"}
