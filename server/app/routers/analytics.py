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
from fastapi import APIRouter, HTTPException, Depends, Query

from app.core.dependencies import verify_professional
from app.core.logging import logger, sanitize_error_message

router = APIRouter(prefix="/admin/analytics", tags=["analytics"])


def _serialize_timestamp(ts) -> Optional[str]:
    """Converte un Firestore timestamp in stringa ISO."""
    if ts is None:
        return None
    if hasattr(ts, 'isoformat'):
        return ts.isoformat()
    return str(ts)


# --- OVERVIEW ---
@router.get("/overview")
async def get_overview(requester: dict = Depends(verify_professional)):
    """
    Metriche generali: utenti attivi, diete caricate, messaggi.
    Admin vede tutto, nutritionist vede solo i propri clienti.
    """
    try:
        db = firebase_admin.firestore.client()
        role = requester['role']
        uid = requester['uid']

        # --- Conteggio utenti ---
        if role == 'admin':
            users_query = db.collection('users')
        else:
            users_query = db.collection('users').where('parent_id', '==', uid)

        users_docs = list(users_query.stream())
        total_users = len(users_docs)

        # Conta per ruolo
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

        # --- Conteggio diete ---
        if role == 'admin':
            diet_history_query = db.collection('diet_history')
        else:
            diet_history_query = db.collection('diet_history').where('uploadedBy', '==', uid)

        diet_docs = list(diet_history_query.stream())
        total_diets = len(diet_docs)

        # Diete ultimo mese
        diets_last_30 = 0
        for doc in diet_docs:
            data = doc.to_dict()
            uploaded_at = data.get('uploadedAt')
            if uploaded_at and hasattr(uploaded_at, 'timestamp'):
                if uploaded_at.replace(tzinfo=timezone.utc) > cutoff_30d:
                    diets_last_30 += 1

        # --- Conteggio messaggi chat ---
        if role == 'admin':
            chats_query = db.collection('chats')
        else:
            chats_query = db.collection('chats').where(
                'participants.nutritionistId', '==', uid
            )

        chats_docs = list(chats_query.stream())
        total_chats = len(chats_docs)

        # Conta messaggi totali (ultimo mese) dalle subcollection
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


# --- DIET TREND ---
@router.get("/diet-trend")
async def get_diet_trend(
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

        # Raggruppa per periodo
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
                # Lunedi della settimana
                monday = dt - timedelta(days=dt.weekday())
                key = monday.strftime('%Y-%m-%d')
            else:  # monthly
                key = dt.strftime('%Y-%m')

            buckets[key] = buckets.get(key, 0) + 1

        # Ordina per data
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


# --- NUTRITIONIST ACTIVITY ---
@router.get("/nutritionist-activity")
async def get_nutritionist_activity(requester: dict = Depends(verify_professional)):
    """
    Mappa attivita per nutrizionista: clienti, diete, messaggi.
    Admin vede tutti i nutrizionisti, nutritionist vede solo se stesso.
    """
    try:
        db = firebase_admin.firestore.client()
        role = requester['role']
        uid = requester['uid']

        # Prendi i nutrizionisti
        if role == 'admin':
            nuts_query = db.collection('users').where('role', '==', 'nutritionist')
            nuts_docs = list(nuts_query.stream())
        else:
            # Nutritionist vede solo se stesso
            nut_doc = db.collection('users').document(uid).get()
            nuts_docs = [nut_doc] if nut_doc.exists else []

        result = []
        for nut in nuts_docs:
            nut_data = nut.to_dict()
            nut_id = nut.id

            # Conta clienti
            clients_query = db.collection('users').where('parent_id', '==', nut_id)
            clients = list(clients_query.stream())
            client_count = len(clients)

            # Conta diete caricate
            diets_query = db.collection('diet_history').where('uploadedBy', '==', nut_id)
            diets = list(diets_query.stream())
            diet_count = len(diets)

            # Conta chat attive
            chats_query = db.collection('chats').where(
                'participants.nutritionistId', '==', nut_id
            )
            chats = list(chats_query.stream())
            chat_count = len(chats)

            # Messaggi totali
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


# --- INACTIVE USERS ---
@router.get("/inactive-users")
async def get_inactive_users(
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

            # Salta admin e nutritionist - interessano solo i clienti
            if user_role in ('admin', 'nutritionist'):
                continue

            last_login = data.get('last_login')
            is_inactive = False
            last_login_str = None

            if last_login is None:
                # Mai fatto login
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

        # Ordina: chi non ha mai fatto login prima, poi per data
        inactive.sort(key=lambda x: x['last_login'] or '')

        return {
            "days": days,
            "count": len(inactive),
            "users": inactive,
        }

    except Exception as e:
        logger.error("analytics_inactive_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante il recupero utenti inattivi")


# --- MEAL COMPLETION ---
@router.get("/meal-completion/{target_uid}")
async def get_meal_completion(
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

        # Verifica permessi
        if role == 'nutritionist':
            user_doc = db.collection('users').document(target_uid).get()
            if not user_doc.exists:
                raise HTTPException(status_code=404, detail="Utente non trovato")
            if user_doc.to_dict().get('parent_id') != uid:
                raise HTTPException(status_code=403, detail="Accesso negato")

        # Pasti pianificati dalla dieta attiva
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
            # Conta i pasti giornalieri dal piano
            planned_meals_per_day = len(plan) if isinstance(plan, dict) else 0

        # Tracking pasti ultimi 30 giorni
        now = datetime.now(timezone.utc)
        start_date = now - timedelta(days=30)

        tracking_query = db.collection('users').document(target_uid) \
            .collection('meal_tracking') \
            .where('date', '>=', start_date)

        tracking_docs = list(tracking_query.stream())

        # Conta pasti registrati
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
