"""
Router per la gestione utenti.
- Creazione, modifica, eliminazione utenti
- Assegnazione/rimozione da nutrizionista
"""
from typing import Optional

import firebase_admin
from firebase_admin import auth, firestore
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, EmailStr, field_validator
from slowapi import Limiter
from slowapi.util import get_remote_address

from app.core.dependencies import verify_admin, verify_professional
from app.core.logging import logger, sanitize_error_message

router = APIRouter(prefix="/admin", tags=["users"])


# --- SCHEMAS ---
class CreateUserRequest(BaseModel):
    email: EmailStr
    password: str
    role: str
    first_name: str
    last_name: str
    parent_id: Optional[str] = None

    @field_validator('password')
    @classmethod
    def validate_password(cls, v):
        if len(v) < 12:
            raise ValueError('La password deve avere almeno 12 caratteri')
        if not any(c.isupper() for c in v):
            raise ValueError('La password deve contenere almeno una maiuscola')
        if not any(c.islower() for c in v):
            raise ValueError('La password deve contenere almeno una minuscola')
        if not any(c.isdigit() for c in v):
            raise ValueError('La password deve contenere almeno un numero')
        return v

    @field_validator('role')
    @classmethod
    def validate_role(cls, v):
        allowed_roles = ['user', 'independent', 'nutritionist', 'admin']
        if v not in allowed_roles:
            raise ValueError(f'Ruolo non valido. Ruoli permessi: {allowed_roles}')
        return v


class UpdateUserRequest(BaseModel):
    email: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    bio: Optional[str] = None
    specializations: Optional[str] = None
    phone: Optional[str] = None
    max_clients: Optional[int] = None


class AssignUserRequest(BaseModel):
    target_uid: str
    nutritionist_id: str


class UnassignUserRequest(BaseModel):
    target_uid: str


def _delete_collection_documents(coll_ref, batch_size=500):
    """Helper per cancellare documenti in batch."""
    db = firebase_admin.firestore.client()
    total_deleted = 0

    while True:
        docs = list(coll_ref.limit(batch_size).stream())
        if not docs:
            break

        batch = db.batch()
        for doc in docs:
            batch.delete(doc.reference)
        batch.commit()
        total_deleted += len(docs)

        if len(docs) < batch_size:
            break

    return total_deleted


@router.post("/create-user")
async def admin_create_user(
    body: CreateUserRequest,
    requester: dict = Depends(verify_professional)
):
    """Crea un nuovo utente."""
    try:
        if requester['role'] == 'nutritionist':
            body.role = 'user'
            body.parent_id = requester['uid']

        db = firebase_admin.firestore.client()
        existing_docs = db.collection('users').where('email', '==', body.email).stream()
        for doc in existing_docs:
            doc.reference.delete()

        user = auth.create_user(
            email=body.email,
            password=body.password,
            display_name=f"{body.first_name} {body.last_name}",
            email_verified=True
        )
        auth.set_custom_user_claims(user.uid, {'role': body.role})

        db.collection('users').document(user.uid).set({
            'uid': user.uid,
            'email': body.email,
            'role': body.role,
            'first_name': body.first_name,
            'last_name': body.last_name,
            'parent_id': body.parent_id,
            'is_active': True,
            'created_at': firebase_admin.firestore.SERVER_TIMESTAMP,
            'created_by': requester['uid'],
            'requires_password_change': True
        })
        return {"uid": user.uid, "message": "User created"}
    except Exception as e:
        logger.error("create_user_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante la creazione dell'utente.")


@router.put("/update-user/{target_uid}")
async def admin_update_user(
    target_uid: str,
    body: UpdateUserRequest,
    requester: dict = Depends(verify_admin)
):
    """Aggiorna i dati di un utente."""
    try:
        db = firebase_admin.firestore.client()
        update_args = {}

        if body.email:
            update_args['email'] = body.email

        if body.first_name or body.last_name:
            user = auth.get_user(target_uid)
            names = user.display_name.split(' ') if user.display_name else ["", ""]
            new_first = body.first_name if body.first_name else names[0]
            new_last = body.last_name if body.last_name else (names[1] if len(names) > 1 else "")
            update_args['display_name'] = f"{new_first} {new_last}".strip()

        if update_args:
            auth.update_user(target_uid, **update_args)

        fs_update = {}
        if body.email:
            fs_update['email'] = body.email
        if body.first_name:
            fs_update['first_name'] = body.first_name
        if body.last_name:
            fs_update['last_name'] = body.last_name
        if body.bio is not None:
            fs_update['bio'] = body.bio
        if body.specializations is not None:
            fs_update['specializations'] = body.specializations
        if body.phone is not None:
            fs_update['phone'] = body.phone
        if body.max_clients is not None:
            fs_update['max_clients'] = body.max_clients

        if fs_update:
            db.collection('users').document(target_uid).update(fs_update)

        return {"message": "User updated"}
    except Exception as e:
        logger.error("update_user_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante l'aggiornamento dell'utente.")


@router.post("/assign-user")
async def admin_assign_user(
    body: AssignUserRequest,
    requester: dict = Depends(verify_admin)
):
    """Assegna un utente a un nutrizionista."""
    try:
        db = firebase_admin.firestore.client()

        # --- CHECK CLIENT LIMIT ---
        nut_doc = db.collection('users').document(body.nutritionist_id).get()
        if nut_doc.exists:
            nut_data = nut_doc.to_dict()
            max_clients = nut_data.get('max_clients', 50)  # Default limit 50
            
            # Count current clients
            clients_query = db.collection('users').where('parent_id', '==', body.nutritionist_id).count()
            current_clients = clients_query.get()[0][0].value
            
            if current_clients >= max_clients:
               raise HTTPException(
                   status_code=400, 
                   detail=f"Nutrizionista pieno! ({current_clients}/{max_clients} clienti)"
               )

        db.collection('users').document(body.target_uid).update({
            'role': 'user',
            'parent_id': body.nutritionist_id,
            'updated_at': firebase_admin.firestore.SERVER_TIMESTAMP
        })
        auth.set_custom_user_claims(body.target_uid, {'role': 'user'})
        return {"message": "User assigned"}
    except Exception as e:
        logger.error("assign_user_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante l'assegnazione dell'utente.")


@router.post("/unassign-user")
async def admin_unassign_user(
    body: UnassignUserRequest,
    requester: dict = Depends(verify_admin)
):
    """Rimuove l'assegnazione di un utente da un nutrizionista."""
    try:
        db = firebase_admin.firestore.client()
        db.collection('access_logs').add({
            'requester_id': requester['uid'],
            'target_uid': body.target_uid,
            'action': 'UNASSIGN_USER',
            'reason': "Restored to Independent",
            'timestamp': firebase_admin.firestore.SERVER_TIMESTAMP
        })
        db.collection('users').document(body.target_uid).update({
            'role': 'independent',
            'parent_id': firestore.DELETE_FIELD,
            'updated_at': firebase_admin.firestore.SERVER_TIMESTAMP
        })
        auth.set_custom_user_claims(body.target_uid, {'role': 'independent'})
        return {"message": "User unassigned"}
    except Exception as e:
        logger.error("unassign_user_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante la rimozione dell'assegnazione.")


@router.delete("/delete-user/{target_uid}")
async def admin_delete_user(
    target_uid: str,
    requester: dict = Depends(verify_professional)
):
    """Elimina un utente e tutti i suoi dati (GDPR)."""
    requester_id = requester['uid']
    requester_role = requester['role']

    try:
        db = firebase_admin.firestore.client()
        user_ref = db.collection('users').document(target_uid)

        if requester_role == 'nutritionist':
            user_doc = user_ref.get()
            if not user_doc.exists:
                return {"message": "User already deleted"}
            data = user_doc.to_dict()
            if data.get('parent_id') != requester_id and data.get('created_by') != requester_id:
                raise HTTPException(status_code=403, detail="Cannot delete this user")

        db.collection('access_logs').add({
            'requester_id': requester_id,
            'target_uid': target_uid,
            'action': 'DELETE_USER_FULL',
            'reason': 'GDPR Permanent Deletion',
            'timestamp': firebase_admin.firestore.SERVER_TIMESTAMP
        })

        diet_history_query = db.collection('diet_history').where('userId', '==', target_uid)
        _delete_collection_documents(diet_history_query)

        subcollections = user_ref.collections()
        for sub in subcollections:
            _delete_collection_documents(sub)

        user_ref.delete()

        try:
            auth.delete_user(target_uid)
        except auth.UserNotFoundError:
            logger.warning("delete_user_auth_not_found", target_uid=target_uid)
        except Exception as auth_err:
            logger.error("delete_user_auth_error", error=sanitize_error_message(auth_err))

        return {"message": "User and all related data permanently deleted"}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("delete_user_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante l'eliminazione dell'utente.")


@router.delete("/delete-diet/{diet_id}")
async def admin_delete_diet(
    diet_id: str,
    requester: dict = Depends(verify_professional)
):
    """Elimina una dieta dallo storico."""
    requester_id = requester['uid']
    requester_role = requester['role']

    try:
        db = firebase_admin.firestore.client()
        diet_doc = db.collection('diet_history').document(diet_id).get()

        if not diet_doc.exists:
            return {"message": "Already deleted"}

        diet_data = diet_doc.to_dict()
        user_id = diet_data.get('userId')

        if requester_role == 'nutritionist':
            if diet_data.get('uploadedBy') != requester_id:
                if user_id:
                    user_doc = db.collection('users').document(user_id).get()
                    if user_doc.exists and user_doc.to_dict().get('parent_id') != requester_id:
                        raise HTTPException(status_code=403, detail="Not authorized")

        db.collection('access_logs').add({
            'requester_id': requester_id,
            'target_uid': user_id,
            'action': 'DELETE_DIET_HISTORY',
            'reason': f"Deleted file: {diet_data.get('fileName')}",
            'timestamp': firebase_admin.firestore.SERVER_TIMESTAMP
        })

        db.collection('diet_history').document(diet_id).delete()
        return {"message": "Diet deleted"}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("delete_diet_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante l'eliminazione della dieta.")
