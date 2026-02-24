"""
Router per analytics e metriche del pannello admin.
- Overview metriche generali
- Trend upload diete
- Attivita nutrizionisti
- Utenti inattivi
- Completamento pasti
"""
from datetime import datetime, timezone, timedelta
from typing import Optional

import firebase_admin
from firebase_admin import firestore
from fastapi import APIRouter, HTTPException, Depends, Query, Request

from app.core.dependencies import verify_professional
from app.core.logging import logger, sanitize_error_message
from app.core.limiter import limiter

router = APIRouter(prefix="/admin/analytics", tags=["analytics"])


def _serialize_timestamp(ts) -> Optional[str]:
    """Converte un Firestore timestamp in stringa ISO."""
    if ts is None:
        return None
    if hasattr(ts, 'isoformat'):
        return ts.isoformat()
    return str(ts)


@router.get("/overview")
@limiter.limit("60/minute")
async def get_overview(request: Request, requester: dict = Depends(verify_professional)):
    """
    Metriche generali: utenti attivi, diete caricate, messaggi.
    Admin vede tutto, nutritionist vede solo i propri clienti.
    """
    try:
        db = firebase_admin.firestore.client()
        role = requester['role']
        uid = requester['uid']

        if role == 'admin':
            users_query = db.collection('users')
        else:
            users_query = db.collection('users').where('parent_id', '==', uid)

        users_docs = list(users_query.stream())
        total_users = len(users_docs)

        role_counts = {}
        active_last_30 = 0
        now = datetime.now(timezone.utc)
        cutoff_30d = now - timedelta(days=30)

        for doc in users_docs:
            data = doc.to_dict()
            r = data.get('role', 'unknown')
            role_counts[r] = role_counts.get(r, 0) + 1

            last_login = data.get('last_login')
            if last_login and hasattr(last_login, 'timestamp'):
                if last_login.replace(tzinfo=timezone.utc) > cutoff_30d:
                    active_last_30 += 1
            elif last_login and isinstance(last_login, str):
                try:
                    parsed = datetime.fromisoformat(last_login.replace('Z', '+00:00'))
                    if parsed > cutoff_30d:
                        active_last_30 += 1
                except (ValueError, TypeError):
                    pass

        if role == 'admin':
            diet_history_query = db.collection('diet_history')
        else:
            diet_history_query = db.collection('diet_history').where('uploadedBy', '==', uid)

        diet_docs = list(diet_history_query.stream())
        total_diets = len(diet_docs)

        diets_last_30 = 0
        for doc in diet_docs:
            data = doc.to_dict()
            uploaded_at = data.get('uploadedAt')
            if uploaded_at and hasattr(uploaded_at, 'timestamp'):
                if uploaded_at.replace(tzinfo=timezone.utc) > cutoff_30d:
                    diets_last_30 += 1

        if role == 'admin':
            chats_query = db.collection('chats')
        else:
            chats_query = db.collection('chats').where(
                'participants.nutritionistId', '==', uid
            )

        chats_docs = list(chats_query.stream())
        total_chats = len(chats_docs)

        total_messages = 0
        for chat_doc in chats_docs:
            data = chat_doc.to_dict()
            total_messages += data.get('messageCount', 0)

        return {
            "total_users": total_users,
            "active_last_30_days": active_last_30,
            "role_counts": role_counts,
            "total_diets": total_diets,
            "diets_last_30_days": diets_last_30,
            "total_chats": total_chats,
            "total_messages": total_messages,
        }

    except Exception as e:
        logger.error("analytics_overview_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante il recupero delle metriche")


@router.get("/diet-trend")
@limiter.limit("60/minute")
async def get_diet_trend(
    request: Request,
    period: str = Query("weekly", regex="^(daily|weekly|monthly)$"),
    months: int = Query(3, ge=1, le=12),
    requester: dict = Depends(verify_professional),
):
    """
    Trend upload diete nel tempo, raggruppato per periodo.
    """
    try:
        db = firebase_admin.firestore.client()
        role = requester['role']
        uid = requester['uid']

        now = datetime.now(timezone.utc)
        start_date = now - timedelta(days=months * 30)

        if role == 'admin':
            query = db.collection('diet_history').where(
                'uploadedAt', '>=', start_date
            )
        else:
            query = db.collection('diet_history').where(
                'uploadedBy', '==', uid
            ).where('uploadedAt', '>=', start_date)

        docs = list(query.stream())

        buckets = {}
        for doc in docs:
            data = doc.to_dict()
            uploaded_at = data.get('uploadedAt')
            if not uploaded_at or not hasattr(uploaded_at, 'date'):
                continue

            dt = uploaded_at
            if period == 'daily':
                key = dt.strftime('%Y-%m-%d')
            elif period == 'weekly':
                monday = dt - timedelta(days=dt.weekday())
                key = monday.strftime('%Y-%m-%d')
            else:  # monthly
                key = dt.strftime('%Y-%m')

            buckets[key] = buckets.get(key, 0) + 1

        sorted_trend = sorted(buckets.items(), key=lambda x: x[0])

        return {
            "period": period,
            "months": months,
            "total": len(docs),
            "trend": [{"date": k, "count": v} for k, v in sorted_trend],
        }

    except Exception as e:
        logger.error("analytics_diet_trend_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante il recupero del trend diete")


@router.get("/nutritionist-activity")
@limiter.limit("60/minute")
async def get_nutritionist_activity(request: Request, requester: dict = Depends(verify_professional)):
    """
    Mappa attivita per nutrizionista: clienti, diete, messaggi.
    Admin vede tutti i nutrizionisti, nutritionist vede solo se stesso.
    """
    try:
        db = firebase_admin.firestore.client()
        role = requester['role']
        uid = requester['uid']

        if role == 'admin':
            nuts_query = db.collection('users').where('role', '==', 'nutritionist')
            nuts_docs = list(nuts_query.stream())
        else:
            nut_doc = db.collection('users').document(uid).get()
            nuts_docs = [nut_doc] if nut_doc.exists else []

        result = []
        for nut in nuts_docs:
            nut_data = nut.to_dict()
            nut_id = nut.id

            clients_query = db.collection('users').where('parent_id', '==', nut_id)
            clients = list(clients_query.stream())
            client_count = len(clients)

            diets_query = db.collection('diet_history').where('uploadedBy', '==', nut_id)
            diets = list(diets_query.stream())
            diet_count = len(diets)

            chats_query = db.collection('chats').where(
                'participants.nutritionistId', '==', nut_id
            )
            chats = list(chats_query.stream())
            chat_count = len(chats)

            message_count = 0
            for chat_doc in chats:
                chat_data = chat_doc.to_dict()
                message_count += chat_data.get('messageCount', 0)

            result.append({
                "uid": nut_id,
                "name": f"{nut_data.get('first_name', '')} {nut_data.get('last_name', '')}".strip(),
                "email": nut_data.get('email', ''),
                "client_count": client_count,
                "diet_count": diet_count,
                "chat_count": chat_count,
                "message_count": message_count,
                "max_clients": nut_data.get('max_clients', 50),
                "specializations": nut_data.get('specializations', ''),
            })

        return {"nutritionists": result}

    except Exception as e:
        logger.error("analytics_nutritionist_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante il recupero attivita nutrizionisti")


@router.get("/inactive-users")
@limiter.limit("60/minute")
async def get_inactive_users(
    request: Request,
    days: int = Query(30, ge=7, le=365),
    requester: dict = Depends(verify_professional),
):
    """
    Lista utenti che non accedono all'app da X giorni.
    """
    try:
        db = firebase_admin.firestore.client()
        role = requester['role']
        uid = requester['uid']

        now = datetime.now(timezone.utc)
        cutoff = now - timedelta(days=days)

        if role == 'admin':
            users_query = db.collection('users')
        else:
            users_query = db.collection('users').where('parent_id', '==', uid)

        users_docs = list(users_query.stream())

        inactive = []
        for doc in users_docs:
            data = doc.to_dict()
            user_role = data.get('role', '')

            if user_role in ('admin', 'nutritionist'):
                continue

            last_login = data.get('last_login')
            is_inactive = False
            last_login_str = None

            if last_login is None:
                is_inactive = True
                last_login_str = "Mai"
            elif hasattr(last_login, 'isoformat'):
                ts = last_login
                if ts.tzinfo is None:
                    ts = ts.replace(tzinfo=timezone.utc)
                if ts < cutoff:
                    is_inactive = True
                last_login_str = ts.isoformat()
            elif isinstance(last_login, str):
                try:
                    parsed = datetime.fromisoformat(last_login.replace('Z', '+00:00'))
                    if parsed < cutoff:
                        is_inactive = True
                    last_login_str = last_login
                except (ValueError, TypeError):
                    is_inactive = True
                    last_login_str = "Non valido"

            if is_inactive:
                inactive.append({
                    "uid": doc.id,
                    "name": f"{data.get('first_name', '')} {data.get('last_name', '')}".strip(),
                    "email": data.get('email', ''),
                    "role": user_role,
                    "last_login": last_login_str,
                    "parent_id": data.get('parent_id'),
                })

        inactive.sort(key=lambda x: x['last_login'] or '')

        return {
            "days": days,
            "count": len(inactive),
            "users": inactive,
        }

    except Exception as e:
        logger.error("analytics_inactive_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante il recupero utenti inattivi")


@router.get("/meal-completion/{target_uid}")
@limiter.limit("60/minute")
async def get_meal_completion(
    request: Request,
    target_uid: str,
    requester: dict = Depends(verify_professional),
):
    """
    Tasso di completamento pasti per un cliente specifico.
    Confronta pasti pianificati nella dieta vs pasti registrati nel tracking.
    """
    try:
        db = firebase_admin.firestore.client()
        role = requester['role']
        uid = requester['uid']

        if role == 'nutritionist':
            user_doc = db.collection('users').document(target_uid).get()
            if not user_doc.exists:
                raise HTTPException(status_code=404, detail="Utente non trovato")
            if user_doc.to_dict().get('parent_id') != uid:
                raise HTTPException(status_code=403, detail="Accesso negato")

        diet_docs = list(
            db.collection('users').document(target_uid)
            .collection('diets').limit_to_last(1)
            .order_by('uploadedAt')
            .stream()
        )

        planned_meals_per_day = 0
        if diet_docs:
            diet_data = diet_docs[0].to_dict()
            plan = diet_data.get('plan', {})
            planned_meals_per_day = len(plan) if isinstance(plan, dict) else 0

        now = datetime.now(timezone.utc)
        start_date = now - timedelta(days=30)

        tracking_query = db.collection('users').document(target_uid) \
            .collection('meal_tracking') \
            .where('date', '>=', start_date)

        tracking_docs = list(tracking_query.stream())

        days_tracked = set()
        total_meals_logged = 0
        for doc in tracking_docs:
            data = doc.to_dict()
            date = data.get('date')
            if date and hasattr(date, 'date'):
                days_tracked.add(date.date())
            total_meals_logged += 1

        days_count = len(days_tracked) if days_tracked else 1
        total_planned = planned_meals_per_day * days_count if planned_meals_per_day > 0 else total_meals_logged

        completion_rate = 0.0
        if total_planned > 0:
            completion_rate = round((total_meals_logged / total_planned) * 100, 1)

        return {
            "target_uid": target_uid,
            "period_days": 30,
            "planned_meals_per_day": planned_meals_per_day,
            "days_tracked": days_count,
            "total_meals_logged": total_meals_logged,
            "total_meals_planned": total_planned,
            "completion_rate": completion_rate,
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error("analytics_meal_completion_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante il recupero completamento pasti")
