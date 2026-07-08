"""
Creazione server-side del documento chat nutritionist-client.

[FIX CHAT-1 2026-07-07] Prima il doc `chats/{uid}_chat` veniva creato SOLO
dall'app client (ChatProvider.initializeChat, lazy al primo avvio con login
già attivo). Conseguenza: il professionista non vedeva la chat dei clienti
che non avevano mai (ri)aperto l'app — con 2 clienti ne appariva 1 sola.
Ora la chat nasce quando il cliente viene creato/assegnato (create-user,
assign-user) e un backfill in sync-users ripara il pregresso. Il client
resta compatibile: il suo _ensureChatDocument trova il doc esistente e non
lo ricrea (stesso ID deterministico `{clientUid}_chat`, stesso shape).
"""
from firebase_admin import firestore

from app.core.logging import logger, sanitize_error_message


def ensure_client_chat(
    db,
    client_uid: str,
    professional_id: str,
    client_name: str = "",
    client_email: str = "",
) -> bool:
    """Crea (se assente) il doc chat nutritionist-client per un cliente.

    Idempotente. Se il doc esiste già ma punta a un professionista diverso
    (riassegnazione), aggiorna solo participants.nutritionistId — stessa
    auto-riparazione che fa il client in _ensureChatDocument.
    Ritorna True se il documento è stato CREATO.
    """
    chat_ref = db.collection('chats').document(f"{client_uid}_chat")
    snap = chat_ref.get()

    if snap.exists:
        data = snap.to_dict() or {}
        existing = (data.get('participants') or {}).get('nutritionistId')
        if existing != professional_id:
            chat_ref.update({
                'participants.nutritionistId': professional_id,
                'chatType': 'nutritionist-client',
            })
        return False

    # Stesso shape scritto dal client (chat_provider._ensureChatDocument):
    # i due percorsi devono restare interscambiabili.
    chat_ref.set({
        'chatType': 'nutritionist-client',
        'participants': {
            'clientId': client_uid,
            'nutritionistId': professional_id,
        },
        'clientName': client_name or 'Utente',
        'clientEmail': client_email or '',
        'lastMessage': '',
        'lastMessageTime': firestore.SERVER_TIMESTAMP,
        'lastMessageSender': '',
        'unreadCount': {
            'client': 0,
            'nutritionist': 0,
        },
    })
    return True


def ensure_client_chat_safe(db, client_uid: str, professional_id: str,
                            client_name: str = "", client_email: str = "") -> bool:
    """Variante non-fatale: la creazione dell'utente/assegnazione NON deve
    fallire se la chat non si crea (verrà comunque creata dal client al
    prossimo avvio o dal backfill di sync-users)."""
    try:
        return ensure_client_chat(
            db, client_uid, professional_id, client_name, client_email
        )
    except Exception as e:
        logger.warning(
            "ensure_client_chat_failed",
            client=client_uid,
            error=sanitize_error_message(e),
        )
        return False
