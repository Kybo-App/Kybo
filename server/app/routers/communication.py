"""
Router per funzionalità di comunicazione avanzata.
- Broadcast messaggi a tutti i clienti di un nutrizionista
- Note interne CRUD (visibili solo al professionista)
"""
from typing import Optional, List

import firebase_admin
from firebase_admin import firestore
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel

from app.core.dependencies import verify_professional
from app.core.logging import logger, sanitize_error_message

router = APIRouter(prefix="/admin/communication", tags=["communication"])


# --- SCHEMAS ---

class BroadcastRequest(BaseModel):
    message: str
    subject: Optional[str] = None


class NoteCreateRequest(BaseModel):
    content: str
    category: Optional[str] = "general"  # general, medical, dietary, follow-up


class NoteUpdateRequest(BaseModel):
    content: Optional[str] = None
    category: Optional[str] = None
    pinned: Optional[bool] = None


# ══════════════════════════════════════════════════════════════════════
# BROADCAST - Invia messaggio a tutti i clienti del nutrizionista
# ══════════════════════════════════════════════════════════════════════

@router.post("/broadcast")
async def broadcast_to_clients(
    body: BroadcastRequest,
    requester: dict = Depends(verify_professional)
):
    """
    Invia un messaggio broadcast a tutti i clienti del nutrizionista.
    - Nutritionist: invia solo ai propri clienti (parent_id == uid)
    - Admin: invia a tutti gli utenti con ruolo 'user'

    Crea un messaggio in ogni chat nutritionist-client esistente.
    """
    requester_id = requester['uid']
    requester_role = requester['role']

    if not body.message.strip():
        raise HTTPException(status_code=400, detail="Il messaggio non può essere vuoto.")

    try:
        db = firebase_admin.firestore.client()

        # Find all chats for this professional
        if requester_role == 'nutritionist':
            chats_query = db.collection('chats') \
                .where('chatType', '==', 'nutritionist-client') \
                .where('participants.nutritionistId', '==', requester_id)
        else:
            # Admin broadcasts to all nutritionist-client chats
            chats_query = db.collection('chats') \
                .where('chatType', '==', 'nutritionist-client')

        chats = list(chats_query.stream())

        if not chats:
            return {"message": "Nessun cliente trovato.", "sent_count": 0}

        sent_count = 0
        batch = db.batch()
        batch_ops = 0
        MAX_BATCH = 400  # Leave room for 2 ops per chat

        for chat_doc in chats:
            chat_id = chat_doc.id

            # Add message to chat
            msg_ref = db.collection('chats').document(chat_id).collection('messages').document()
            batch.set(msg_ref, {
                'senderId': requester_id,
                'senderType': 'nutritionist' if requester_role == 'nutritionist' else 'admin',
                'message': body.message.strip(),
                'timestamp': firestore.SERVER_TIMESTAMP,
                'read': False,
                'isBroadcast': True,
            })
            batch_ops += 1

            # Update chat metadata
            batch.set(db.collection('chats').document(chat_id), {
                'lastMessage': body.message.strip()[:100],
                'lastMessageTime': firestore.SERVER_TIMESTAMP,
                'lastMessageSender': 'nutritionist' if requester_role == 'nutritionist' else 'admin',
                'unreadCount': {
                    'client': firestore.Increment(1),
                    'nutritionist': 0,
                },
            }, merge=True)
            batch_ops += 1

            sent_count += 1

            if batch_ops >= MAX_BATCH:
                batch.commit()
                batch = db.batch()
                batch_ops = 0

        if batch_ops > 0:
            batch.commit()

        # Log the broadcast
        db.collection('access_logs').add({
            'requester_id': requester_id,
            'action': 'BROADCAST_MESSAGE',
            'reason': f"Broadcast to {sent_count} chats",
            'timestamp': firestore.SERVER_TIMESTAMP,
        })

        logger.info("broadcast_sent", sender=requester_id, count=sent_count)
        return {"message": f"Messaggio inviato a {sent_count} clienti.", "sent_count": sent_count}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("broadcast_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante l'invio del broadcast.")


# ══════════════════════════════════════════════════════════════════════
# INTERNAL NOTES - Note private sul cliente
# ══════════════════════════════════════════════════════════════════════

@router.get("/notes/{client_uid}")
async def get_client_notes(
    client_uid: str,
    requester: dict = Depends(verify_professional)
):
    """
    Ottiene le note interne di un cliente.
    Solo il professionista proprietario può vederle.
    """
    requester_id = requester['uid']
    requester_role = requester['role']

    try:
        db = firebase_admin.firestore.client()

        # Verify access
        if requester_role == 'nutritionist':
            user_doc = db.collection('users').document(client_uid).get()
            if not user_doc.exists:
                raise HTTPException(status_code=404, detail="Utente non trovato")
            user_data = user_doc.to_dict()
            if user_data.get('parent_id') != requester_id and user_data.get('created_by') != requester_id:
                raise HTTPException(status_code=403, detail="Accesso negato")

        # Fetch notes
        notes_ref = db.collection('users').document(client_uid) \
            .collection('internal_notes') \
            .order_by('updated_at', direction=firestore.Query.DESCENDING)

        notes = []
        for doc in notes_ref.stream():
            note = doc.to_dict()
            note['id'] = doc.id
            # Convert timestamps to ISO strings
            for ts_field in ['created_at', 'updated_at']:
                if ts_field in note and note[ts_field]:
                    note[ts_field] = note[ts_field].isoformat()
            notes.append(note)

        return {"notes": notes}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("get_notes_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante il recupero delle note.")


@router.post("/notes/{client_uid}")
async def create_client_note(
    client_uid: str,
    body: NoteCreateRequest,
    requester: dict = Depends(verify_professional)
):
    """Crea una nuova nota interna per un cliente."""
    requester_id = requester['uid']
    requester_role = requester['role']

    if not body.content.strip():
        raise HTTPException(status_code=400, detail="La nota non può essere vuota.")

    try:
        db = firebase_admin.firestore.client()

        # Verify access
        if requester_role == 'nutritionist':
            user_doc = db.collection('users').document(client_uid).get()
            if not user_doc.exists:
                raise HTTPException(status_code=404, detail="Utente non trovato")
            user_data = user_doc.to_dict()
            if user_data.get('parent_id') != requester_id and user_data.get('created_by') != requester_id:
                raise HTTPException(status_code=403, detail="Accesso negato")

        # Create note
        note_data = {
            'content': body.content.strip(),
            'category': body.category or 'general',
            'author_id': requester_id,
            'pinned': False,
            'created_at': firestore.SERVER_TIMESTAMP,
            'updated_at': firestore.SERVER_TIMESTAMP,
        }

        note_ref = db.collection('users').document(client_uid) \
            .collection('internal_notes').add(note_data)

        logger.info("note_created", author=requester_id, client=client_uid)
        return {"id": note_ref[1].id, "message": "Nota creata."}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("create_note_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante la creazione della nota.")


@router.put("/notes/{client_uid}/{note_id}")
async def update_client_note(
    client_uid: str,
    note_id: str,
    body: NoteUpdateRequest,
    requester: dict = Depends(verify_professional)
):
    """Aggiorna una nota interna."""
    requester_id = requester['uid']

    try:
        db = firebase_admin.firestore.client()
        note_ref = db.collection('users').document(client_uid) \
            .collection('internal_notes').document(note_id)

        note_doc = note_ref.get()
        if not note_doc.exists:
            raise HTTPException(status_code=404, detail="Nota non trovata")

        # Only the author can update
        note_data = note_doc.to_dict()
        if note_data.get('author_id') != requester_id and requester.get('role') != 'admin':
            raise HTTPException(status_code=403, detail="Solo l'autore può modificare questa nota")

        update = {'updated_at': firestore.SERVER_TIMESTAMP}
        if body.content is not None:
            update['content'] = body.content.strip()
        if body.category is not None:
            update['category'] = body.category
        if body.pinned is not None:
            update['pinned'] = body.pinned

        note_ref.update(update)
        return {"message": "Nota aggiornata."}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("update_note_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante l'aggiornamento della nota.")


@router.delete("/notes/{client_uid}/{note_id}")
async def delete_client_note(
    client_uid: str,
    note_id: str,
    requester: dict = Depends(verify_professional)
):
    """Elimina una nota interna."""
    requester_id = requester['uid']

    try:
        db = firebase_admin.firestore.client()
        note_ref = db.collection('users').document(client_uid) \
            .collection('internal_notes').document(note_id)

        note_doc = note_ref.get()
        if not note_doc.exists:
            raise HTTPException(status_code=404, detail="Nota non trovata")

        note_data = note_doc.to_dict()
        if note_data.get('author_id') != requester_id and requester.get('role') != 'admin':
            raise HTTPException(status_code=403, detail="Solo l'autore può eliminare questa nota")

        note_ref.delete()

        logger.info("note_deleted", author=requester_id, note_id=note_id)
        return {"message": "Nota eliminata."}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("delete_note_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante l'eliminazione della nota.")
