"""
Router per il sistema Reward (Shop Premi).
- CRUD catalogo premi (admin only)
- Visualizzazione catalogo (qualsiasi utente autenticato)
- Riscatto premio con spesa XP (utente autenticato)
- Storico premi riscattati
"""
from typing import Optional, List

import firebase_admin
from firebase_admin import firestore
from fastapi import APIRouter, HTTPException, Depends, Request
from pydantic import BaseModel, Field

from app.core.dependencies import verify_admin, verify_token, get_current_uid
from app.core.logging import logger, sanitize_error_message
from app.core.limiter import limiter

router = APIRouter(tags=["rewards"])


# --- Models ---

class CreateRewardRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=200)
    description: str = Field("", max_length=1000)
    xp_cost: int = Field(..., ge=1, le=100_000)
    image_url: Optional[str] = Field(None, max_length=500)
    stock: Optional[int] = Field(None, ge=0, le=100_000)
    is_active: bool = True


class UpdateRewardRequest(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=200)
    description: Optional[str] = Field(None, max_length=1000)
    xp_cost: Optional[int] = Field(None, ge=1, le=100_000)
    image_url: Optional[str] = Field(None, max_length=500)
    stock: Optional[int] = Field(None, ge=0, le=100_000)
    is_active: Optional[bool] = None


# --- Admin CRUD ---

@router.get("/admin/rewards/catalog")
@limiter.limit("60/minute")
async def get_rewards_catalog(
    request: Request,
    requester: dict = Depends(verify_admin),
):
    """Lista completa catalogo premi (admin vede anche i disattivati)."""
    try:
        db = firebase_admin.firestore.client()
        docs = db.collection('rewards_catalog').order_by(
            'created_at', direction=firestore.Query.DESCENDING
        ).stream()

        rewards = []
        for doc in docs:
            data = doc.to_dict()
            data['id'] = doc.id
            # Conta quante volte è stato riscattato
            claimed_count = 0
            try:
                claimed_query = db.collection_group('claimed_rewards').where(
                    'reward_id', '==', doc.id
                ).count()
                claimed_count = claimed_query.get()[0][0].value
            except Exception:
                pass
            data['claimed_count'] = claimed_count
            rewards.append(data)

        return {"rewards": rewards}
    except Exception as e:
        logger.error("get_rewards_catalog_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante il caricamento del catalogo.")


@router.post("/admin/rewards/catalog")
@limiter.limit("30/hour")
async def create_reward(
    request: Request,
    body: CreateRewardRequest,
    requester: dict = Depends(verify_admin),
):
    """Crea un nuovo premio nel catalogo."""
    try:
        db = firebase_admin.firestore.client()
        reward_data = {
            'name': body.name,
            'description': body.description,
            'xp_cost': body.xp_cost,
            'image_url': body.image_url,
            'stock': body.stock,
            'is_active': body.is_active,
            'created_at': firestore.SERVER_TIMESTAMP,
            'created_by': requester['uid'],
        }
        doc_ref = db.collection('rewards_catalog').add(reward_data)
        reward_id = doc_ref[1].id

        logger.info("reward_created", reward_id=reward_id, name=body.name, by=requester['uid'])
        return {"id": reward_id, "message": "Premio creato"}
    except Exception as e:
        logger.error("create_reward_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante la creazione del premio.")


@router.put("/admin/rewards/catalog/{reward_id}")
@limiter.limit("60/minute")
async def update_reward(
    request: Request,
    reward_id: str,
    body: UpdateRewardRequest,
    requester: dict = Depends(verify_admin),
):
    """Modifica un premio esistente."""
    try:
        db = firebase_admin.firestore.client()
        doc_ref = db.collection('rewards_catalog').document(reward_id)
        doc = doc_ref.get()

        if not doc.exists:
            raise HTTPException(status_code=404, detail="Premio non trovato")

        update_data = {}
        if body.name is not None:
            update_data['name'] = body.name
        if body.description is not None:
            update_data['description'] = body.description
        if body.xp_cost is not None:
            update_data['xp_cost'] = body.xp_cost
        if body.image_url is not None:
            update_data['image_url'] = body.image_url
        if body.stock is not None:
            update_data['stock'] = body.stock
        if body.is_active is not None:
            update_data['is_active'] = body.is_active

        if update_data:
            update_data['updated_at'] = firestore.SERVER_TIMESTAMP
            doc_ref.update(update_data)

        logger.info("reward_updated", reward_id=reward_id, by=requester['uid'])
        return {"message": "Premio aggiornato"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("update_reward_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante l'aggiornamento del premio.")


@router.delete("/admin/rewards/catalog/{reward_id}")
@limiter.limit("20/hour")
async def delete_reward(
    request: Request,
    reward_id: str,
    requester: dict = Depends(verify_admin),
):
    """Elimina un premio dal catalogo."""
    try:
        db = firebase_admin.firestore.client()
        doc_ref = db.collection('rewards_catalog').document(reward_id)
        doc = doc_ref.get()

        if not doc.exists:
            raise HTTPException(status_code=404, detail="Premio non trovato")

        doc_ref.delete()
        logger.info("reward_deleted", reward_id=reward_id, by=requester['uid'])
        return {"message": "Premio eliminato"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("delete_reward_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante l'eliminazione del premio.")


# --- Admin: gestione claim ---

@router.get("/admin/rewards/claims")
@limiter.limit("60/minute")
async def get_all_claims(
    request: Request,
    status: Optional[str] = None,
    requester: dict = Depends(verify_admin),
):
    """Lista tutti i premi riscattati (con filtro opzionale per status)."""
    try:
        db = firebase_admin.firestore.client()
        query = db.collection_group('claimed_rewards').order_by(
            'claimed_at', direction=firestore.Query.DESCENDING
        ).limit(200)

        if status:
            query = query.where('status', '==', status)

        claims = []
        for doc in query.stream():
            data = doc.to_dict()
            data['id'] = doc.id
            data['user_uid'] = doc.reference.parent.parent.id
            claims.append(data)

        return {"claims": claims}
    except Exception as e:
        logger.error("get_all_claims_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante il caricamento dei riscatti.")


@router.post("/admin/rewards/claims/{user_uid}/{claim_id}/fulfill")
@limiter.limit("60/minute")
async def fulfill_claim(
    request: Request,
    user_uid: str,
    claim_id: str,
    requester: dict = Depends(verify_admin),
):
    """Segna un premio riscattato come evaso."""
    try:
        db = firebase_admin.firestore.client()
        doc_ref = db.collection('users').document(user_uid).collection(
            'claimed_rewards'
        ).document(claim_id)
        doc = doc_ref.get()

        if not doc.exists:
            raise HTTPException(status_code=404, detail="Riscatto non trovato")

        doc_ref.update({
            'status': 'fulfilled',
            'fulfilled_at': firestore.SERVER_TIMESTAMP,
            'fulfilled_by': requester['uid'],
        })

        logger.info("claim_fulfilled", claim_id=claim_id, user_uid=user_uid, by=requester['uid'])
        return {"message": "Premio evaso"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("fulfill_claim_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante l'evasione del premio.")


# --- Client endpoints ---

@router.get("/rewards/catalog")
@limiter.limit("60/minute")
async def get_public_catalog(
    request: Request,
    token: dict = Depends(verify_token),
):
    """Catalogo premi visibile agli utenti (solo attivi)."""
    try:
        db = firebase_admin.firestore.client()
        docs = db.collection('rewards_catalog').where(
            'is_active', '==', True
        ).order_by('xp_cost').stream()

        rewards = []
        for doc in docs:
            data = doc.to_dict()
            data['id'] = doc.id
            # Non esporre campi interni
            data.pop('created_by', None)
            rewards.append(data)

        return {"rewards": rewards}
    except Exception as e:
        logger.error("get_public_catalog_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante il caricamento del catalogo.")


@router.post("/rewards/claim/{reward_id}")
@limiter.limit("10/hour")
async def claim_reward(
    request: Request,
    reward_id: str,
    uid: str = Depends(get_current_uid),
):
    """Riscatta un premio spendendo XP."""
    try:
        db = firebase_admin.firestore.client()

        # Verifica che il premio esista ed sia attivo
        reward_ref = db.collection('rewards_catalog').document(reward_id)
        reward_doc = reward_ref.get()

        if not reward_doc.exists:
            raise HTTPException(status_code=404, detail="Premio non trovato")

        reward_data = reward_doc.to_dict()
        if not reward_data.get('is_active', False):
            raise HTTPException(status_code=400, detail="Premio non disponibile")

        xp_cost = reward_data.get('xp_cost', 0)
        stock = reward_data.get('stock')

        # Verifica stock
        if stock is not None and stock <= 0:
            raise HTTPException(status_code=400, detail="Premio esaurito")

        # Verifica XP dell'utente
        user_ref = db.collection('users').document(uid)
        user_doc = user_ref.get()

        if not user_doc.exists:
            raise HTTPException(status_code=404, detail="Utente non trovato")

        user_data = user_doc.to_dict()
        user_xp = (user_data.get('xp_total') or 0)

        if user_xp < xp_cost:
            raise HTTPException(
                status_code=400,
                detail=f"XP insufficienti. Hai {user_xp} XP, servono {xp_cost} XP."
            )

        # Transazione atomica: sottrai XP + decrementa stock + crea claim
        @firestore.transactional
        def claim_transaction(transaction):
            # Ri-leggi dentro la transazione
            u_snap = user_ref.get(transaction=transaction)
            r_snap = reward_ref.get(transaction=transaction)

            u_data = u_snap.to_dict()
            r_data = r_snap.to_dict()

            current_xp = u_data.get('xp_total', 0)
            current_stock = r_data.get('stock')

            if current_xp < xp_cost:
                raise HTTPException(status_code=400, detail="XP insufficienti")
            if current_stock is not None and current_stock <= 0:
                raise HTTPException(status_code=400, detail="Premio esaurito")

            # Sottrai XP
            transaction.update(user_ref, {
                'xp_total': current_xp - xp_cost,
            })

            # Decrementa stock se limitato
            if current_stock is not None:
                transaction.update(reward_ref, {
                    'stock': current_stock - 1,
                })

            # Crea il claim
            claim_ref = user_ref.collection('claimed_rewards').document()
            transaction.set(claim_ref, {
                'reward_id': reward_id,
                'reward_name': r_data.get('name', ''),
                'xp_spent': xp_cost,
                'status': 'pending',
                'claimed_at': firestore.SERVER_TIMESTAMP,
            })

            return claim_ref.id

        transaction = db.transaction()
        claim_id = claim_transaction(transaction)

        logger.info("reward_claimed", reward_id=reward_id, uid=uid, xp_spent=xp_cost)
        return {
            "message": "Premio riscattato!",
            "claim_id": claim_id,
            "xp_spent": xp_cost,
            "new_xp_total": user_xp - xp_cost,
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error("claim_reward_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante il riscatto del premio.")


@router.get("/rewards/my-claims")
@limiter.limit("60/minute")
async def get_my_claims(
    request: Request,
    uid: str = Depends(get_current_uid),
):
    """Storico premi riscattati dall'utente corrente."""
    try:
        db = firebase_admin.firestore.client()
        docs = db.collection('users').document(uid).collection(
            'claimed_rewards'
        ).order_by(
            'claimed_at', direction=firestore.Query.DESCENDING
        ).limit(50).stream()

        claims = []
        for doc in docs:
            data = doc.to_dict()
            data['id'] = doc.id
            claims.append(data)

        return {"claims": claims}
    except Exception as e:
        logger.error("get_my_claims_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante il caricamento dei riscatti.")
