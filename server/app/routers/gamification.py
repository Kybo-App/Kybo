"""
Router per l'economia XP/gamification (badge, sfide, streak).

Prima di questo router, XpService/ChallengeService/BadgeService lato client
scrivevano xp_total/badge_counters/unlocked_badges/challenges DIRETTAMENTE
su Firestore: un utente poteva forgiare qualsiasi valore (le rules lo
permettevano in whitelist) e ottenere premi reali gratis via
POST /rewards/claim (vedi audit SRV-RW1/XP1/BS1/SV1/SV2).

Ogni scrittura di XP/gamification passa ora da qui (Admin SDK, bypassa le
rules) con importi fissi decisi dal server, idempotenza e cap giornalieri.
Non c'è verifica crittografica che l'evento sottostante sia realmente
avvenuto (stesso livello di fiducia già accettato per
workouts.complete-day) — ma non è più possibile scrivere un valore XP
arbitrario, e il farming è limitato a un cap plausibile per evento/giorno.
"""
import datetime
import re
from typing import Literal, Optional

import firebase_admin
from firebase_admin import firestore
from fastapi import APIRouter, HTTPException, Depends, Request
from pydantic import BaseModel, Field

from app.core.dependencies import get_current_uid
from app.core.logging import logger, sanitize_error_message
from app.core.limiter import limiter

router = APIRouter(tags=["gamification"])

# ─── XP eventi: importo fisso deciso dal server, mai dal client ───
_XP_EVENT_TABLE = {
    'meal_consumed': 10,
    'all_meals_complete': 50,
    'weight_logged': 15,
}
# Cap giornaliero per evento — limita il farming quando non è possibile
# verificare crittograficamente l'evento sottostante.
_XP_DAILY_CAPS = {
    'meal_consumed': 8,
    'all_meals_complete': 1,
    'weight_logged': 5,
}

# ─── Sfide: porting esatto del pool/algoritmo di selezione di
# ChallengeService (client Dart) — il server rigenera in modo indipendente
# le sfide valide per una data invece di fidarsi della lista del client.
_CHALLENGE_POOL = [
    {'id': 'complete_2_meals', 'xp_reward': 20, 'type': 'meals'},
    {'id': 'complete_all_meals', 'xp_reward': 30, 'type': 'meals'},
    {'id': 'log_weight', 'xp_reward': 15, 'type': 'weight'},
    {'id': 'visit_stats', 'xp_reward': 10, 'type': 'explore'},
    {'id': 'use_timer', 'xp_reward': 15, 'type': 'explore'},
    {'id': 'share_list', 'xp_reward': 20, 'type': 'social'},
    {'id': 'add_pantry', 'xp_reward': 10, 'type': 'explore'},
    {'id': 'use_ai', 'xp_reward': 15, 'type': 'explore'},
    {'id': 'complete_1_meal', 'xp_reward': 10, 'type': 'meals'},
]
_CHALLENGE_BONUS_XP = 30
_CHALLENGE_ID_RE = re.compile(r'^(?P<base>[a-z0-9_]+)_(?P<date>\d{4}-\d{2}-\d{2})$')

# ─── Badge: registro dei contatori progressivi, porting di badge_model.dart ───
_BADGE_COUNTER_REGISTRY = {
    'streak_days': [('streak_3', 3), ('streak_7', 7), ('streak_30', 30)],
    'weight_logs': [('weight_log_1', 1), ('weight_log_10', 10), ('weight_log_50', 50)],
    'meals_complete_days': [('diet_complete', 1), ('diet_complete_7', 7), ('diet_complete_30', 30)],
    'shopping_shares': [('shopping_list_shared', 1), ('shopping_shared_5', 5), ('shopping_shared_20', 20)],
    'pantry_items_added': [('pantry_10', 10)],
    'stats_views': [('stats_viewed_5', 5)],
}
_VALID_COUNTER_KEYS = set(_BADGE_COUNTER_REGISTRY.keys())
_VALID_STANDALONE_BADGES = {
    'first_login', 'holiday_spirit', 'night_owl',
    'cooking_timer_used', 'ai_explorer', 'first_chat_message', 'scale_connected',
    'weight_goal_25', 'weight_goal_50', 'weight_goal_100',
}
_ALL_VALID_BADGE_IDS = set(_VALID_STANDALONE_BADGES)
for _entries in _BADGE_COUNTER_REGISTRY.values():
    for _badge_id, _ in _entries:
        _ALL_VALID_BADGE_IDS.add(_badge_id)


def _generate_challenge_ids(date_str: str) -> list:
    """Porting di ChallengeService._generateChallenges (client): stessa
    selezione pseudo-casuale deterministica basata sul giorno dell'anno."""
    try:
        date = datetime.date.fromisoformat(date_str)
    except ValueError:
        return []
    day_of_year = (date - datetime.date(date.year, 1, 1)).days

    pool = list(_CHALLENGE_POOL)
    selected = []
    used_types = []
    i = 0
    while i < 3 and pool:
        index = (day_of_year * 7 + i * 13 + day_of_year // 3) % len(pool)
        challenge = pool[index]
        if used_types.count(challenge['type']) >= 2 and len(pool) > 1:
            pool.pop(index)
            continue
        selected.append(challenge)
        used_types.append(challenge['type'])
        pool.pop(index)
        i += 1
    return selected


def _compute_xp_delta(user_data: dict, today_str: str, amount: int):
    """Applica il reset giornaliero e calcola i nuovi totali XP. Pura (nessuna I/O)."""
    xp_total = int(user_data.get('xp_total') or 0)
    xp_today = int(user_data.get('xp_today') or 0)
    if user_data.get('xp_today_date') != today_str:
        xp_today = 0
    return xp_total + amount, xp_today + amount


# ─────────────────────────────────────────────────────────────────────────
# XP
# ─────────────────────────────────────────────────────────────────────────

class XpEventRequest(BaseModel):
    event_type: Literal['meal_consumed', 'all_meals_complete', 'weight_logged']


@router.post("/gamification/xp/event")
@limiter.limit("60/minute")
async def award_xp_event(
    request: Request,
    body: XpEventRequest,
    uid: str = Depends(get_current_uid),
):
    """Assegna XP per un evento client-riportato, con importo fisso e cap
    giornaliero server-side. Sostituisce XpService.addXp (scrittura diretta)."""
    try:
        db = firebase_admin.firestore.client()
        today_str = datetime.date.today().isoformat()
        amount = _XP_EVENT_TABLE[body.event_type]
        cap = _XP_DAILY_CAPS[body.event_type]

        user_ref = db.collection('users').document(uid)
        xp_daily_ref = user_ref.collection('xp_daily').document(today_str)

        @firestore.transactional
        def _txn(transaction):
            daily_snap = xp_daily_ref.get(transaction=transaction)
            user_snap = user_ref.get(transaction=transaction)

            count = int((daily_snap.to_dict() or {}).get(body.event_type, 0))
            user_data = user_snap.to_dict() or {}

            if count >= cap:
                return user_data.get('xp_total', 0), user_data.get('xp_today', 0), True

            new_total, new_today = _compute_xp_delta(user_data, today_str, amount)

            transaction.update(user_ref, {
                'xp_total': new_total,
                'xp_today': new_today,
                'xp_today_date': today_str,
            })
            transaction.set(xp_daily_ref, {body.event_type: firestore.Increment(1)}, merge=True)
            hist_ref = user_ref.collection('xp_history').document()
            transaction.set(hist_ref, {
                'amount': amount,
                'reason': body.event_type,
                'created_at': firestore.SERVER_TIMESTAMP,
            })
            return new_total, new_today, False

        txn = db.transaction()
        xp_total, xp_today, capped = _txn(txn)

        return {"xp_total": xp_total, "xp_today": xp_today, "capped": capped}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("xp_event_error", error=sanitize_error_message(e), uid=uid)
        raise HTTPException(status_code=500, detail="Errore durante l'assegnazione XP.")


# ─────────────────────────────────────────────────────────────────────────
# Sfide giornaliere
# ─────────────────────────────────────────────────────────────────────────

@router.get("/gamification/challenges/today")
@limiter.limit("60/minute")
async def get_todays_challenges(
    request: Request,
    uid: str = Depends(get_current_uid),
):
    """Ritorna le 3 sfide di oggi (rigenerate server-side) con lo stato di
    completamento autoritativo."""
    try:
        today_str = datetime.date.today().isoformat()
        todays_pool = _generate_challenge_ids(today_str)

        db = firebase_admin.firestore.client()
        challenge_ref = db.collection('users').document(uid).collection('challenges').document(today_str)
        data = challenge_ref.get().to_dict() or {}
        completed = set(data.get('completed_ids', []))

        challenges = [{
            'id': f"{c['id']}_{today_str}",
            'base_id': c['id'],
            'xp_reward': c['xp_reward'],
            'is_completed': c['id'] in completed,
        } for c in todays_pool]

        return {
            'date': today_str,
            'challenges': challenges,
            'challenge_streak': int(data.get('challenge_streak', 0)),
        }
    except Exception as e:
        logger.error("get_challenges_error", error=sanitize_error_message(e), uid=uid)
        raise HTTPException(status_code=500, detail="Errore nel caricamento delle sfide.")


class ChallengeCompleteRequest(BaseModel):
    challenge_id: str = Field(..., min_length=1, max_length=100)


@router.post("/gamification/challenge/complete")
@limiter.limit("30/minute")
async def complete_challenge(
    request: Request,
    body: ChallengeCompleteRequest,
    uid: str = Depends(get_current_uid),
):
    """Completa una sfida e assegna XP server-side, idempotente per
    (data, sfida). Chiude SV1 (XP farmabile riavviando l'app: le scritture
    su `challenges` venivano negate dalle rules, quindi ogni riavvio
    resettava il completamento visibile e permetteva di ri-guadagnare XP)."""
    try:
        match = _CHALLENGE_ID_RE.match(body.challenge_id)
        if not match:
            raise HTTPException(status_code=400, detail="ID sfida non valido.")

        date_str = match.group('date')
        base_id = match.group('base')

        try:
            challenge_date = datetime.date.fromisoformat(date_str)
        except ValueError:
            raise HTTPException(status_code=400, detail="Data sfida non valida.")

        today = datetime.date.today()
        if abs((challenge_date - today).days) > 1:
            raise HTTPException(status_code=400, detail="Sfida non valida per questa data.")

        todays_pool = _generate_challenge_ids(date_str)
        pool_entry = next((c for c in todays_pool if c['id'] == base_id), None)
        if pool_entry is None:
            raise HTTPException(status_code=400, detail="Sfida non prevista per questa data.")

        db = firebase_admin.firestore.client()
        user_ref = db.collection('users').document(uid)
        challenge_ref = user_ref.collection('challenges').document(date_str)

        @firestore.transactional
        def _txn(transaction):
            challenge_snap = challenge_ref.get(transaction=transaction)
            user_snap = user_ref.get(transaction=transaction)

            c_data = challenge_snap.to_dict() or {}
            u_data = user_snap.to_dict() or {}

            completed = set(c_data.get('completed_ids', []))
            streak = int(c_data.get('challenge_streak', 0))
            bonus_given = bool(c_data.get('bonus_given', False))

            if base_id in completed:
                return {
                    'already_completed': True,
                    'completed_ids': sorted(completed),
                    'challenge_streak': streak,
                    'xp_total': u_data.get('xp_total', 0),
                    'xp_today': u_data.get('xp_today', 0),
                }

            completed.add(base_id)
            xp_total, xp_today = _compute_xp_delta(u_data, today.isoformat(), pool_entry['xp_reward'])
            xp_history_entries = [('challenge_completed', pool_entry['xp_reward'])]

            all_ids = {c['id'] for c in todays_pool}
            if all_ids.issubset(completed) and not bonus_given:
                xp_total += _CHALLENGE_BONUS_XP
                xp_today += _CHALLENGE_BONUS_XP
                xp_history_entries.append(('all_challenges_bonus', _CHALLENGE_BONUS_XP))
                bonus_given = True
                streak += 1

            transaction.update(user_ref, {
                'xp_total': xp_total,
                'xp_today': xp_today,
                'xp_today_date': today.isoformat(),
            })
            for reason, amt in xp_history_entries:
                hist_ref = user_ref.collection('xp_history').document()
                transaction.set(hist_ref, {
                    'amount': amt,
                    'reason': reason,
                    'created_at': firestore.SERVER_TIMESTAMP,
                })
            transaction.set(challenge_ref, {
                'date': date_str,
                'completed_ids': sorted(completed),
                'challenge_streak': streak,
                'bonus_given': bonus_given,
            }, merge=True)

            return {
                'already_completed': False,
                'completed_ids': sorted(completed),
                'challenge_streak': streak,
                'xp_total': xp_total,
                'xp_today': xp_today,
            }

        txn = db.transaction()
        result = _txn(txn)
        return result
    except HTTPException:
        raise
    except Exception as e:
        logger.error("challenge_complete_error", error=sanitize_error_message(e), uid=uid)
        raise HTTPException(status_code=500, detail="Errore durante il completamento della sfida.")


# ─────────────────────────────────────────────────────────────────────────
# Badge
# ─────────────────────────────────────────────────────────────────────────

class BadgeUnlockRequest(BaseModel):
    badge_id: str = Field(..., min_length=1, max_length=50)


@router.post("/gamification/badge/unlock")
@limiter.limit("60/minute")
async def unlock_badge(
    request: Request,
    body: BadgeUnlockRequest,
    uid: str = Depends(get_current_uid),
):
    """Sblocca un badge (idempotente, solo ID noti). Sostituisce la
    scrittura diretta unlocked_badges.* del client (SV2/XP1)."""
    try:
        if body.badge_id not in _ALL_VALID_BADGE_IDS:
            raise HTTPException(status_code=400, detail="Badge non valido.")

        if body.badge_id == 'holiday_spirit':
            now = datetime.date.today()
            if not (now.month == 12 and now.day == 25):
                raise HTTPException(status_code=400, detail="Badge non disponibile oggi.")

        db = firebase_admin.firestore.client()
        user_ref = db.collection('users').document(uid)

        @firestore.transactional
        def _txn(transaction):
            snap = user_ref.get(transaction=transaction)
            data = snap.to_dict() or {}
            unlocked = data.get('unlocked_badges') or {}
            if body.badge_id in unlocked:
                return False
            transaction.update(user_ref, {
                f'unlocked_badges.{body.badge_id}': firestore.SERVER_TIMESTAMP,
            })
            return True

        txn = db.transaction()
        newly_unlocked = _txn(txn)

        return {"badge_id": body.badge_id, "newly_unlocked": newly_unlocked}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("badge_unlock_error", error=sanitize_error_message(e), uid=uid)
        raise HTTPException(status_code=500, detail="Errore durante lo sblocco badge.")


class BadgeCounterRequest(BaseModel):
    key: str = Field(..., min_length=1, max_length=50)
    mode: Literal['increment', 'set']
    value: Optional[int] = Field(None, ge=0, le=1_000_000)


@router.post("/gamification/badge/counter")
@limiter.limit("60/minute")
async def update_badge_counter(
    request: Request,
    body: BadgeCounterRequest,
    uid: str = Depends(get_current_uid),
):
    """Aggiorna un contatore badge (chiave da whitelist, +1 per increment)
    e sblocca automaticamente i badge progressivi che superano la soglia.
    Sostituisce la scrittura diretta badge_counters.* del client (SV2)."""
    try:
        if body.key not in _VALID_COUNTER_KEYS:
            raise HTTPException(status_code=400, detail="Contatore non valido.")
        if body.mode == 'set' and body.value is None:
            raise HTTPException(status_code=400, detail="Valore mancante per 'set'.")

        db = firebase_admin.firestore.client()
        user_ref = db.collection('users').document(uid)

        @firestore.transactional
        def _txn(transaction):
            snap = user_ref.get(transaction=transaction)
            data = snap.to_dict() or {}
            counters = data.get('badge_counters') or {}
            current = int(counters.get(body.key, 0))

            new_value = body.value if body.mode == 'set' else current + 1
            new_value = max(0, min(int(new_value), 1_000_000))

            unlocked = data.get('unlocked_badges') or {}
            newly_unlocked = []
            update_payload = {f'badge_counters.{body.key}': new_value}
            for badge_id, required in _BADGE_COUNTER_REGISTRY[body.key]:
                if badge_id not in unlocked and new_value >= required:
                    update_payload[f'unlocked_badges.{badge_id}'] = firestore.SERVER_TIMESTAMP
                    newly_unlocked.append(badge_id)

            transaction.update(user_ref, update_payload)
            return new_value, newly_unlocked

        txn = db.transaction()
        new_value, newly_unlocked = _txn(txn)

        return {"key": body.key, "value": new_value, "unlocked": newly_unlocked}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("badge_counter_error", error=sanitize_error_message(e), uid=uid)
        raise HTTPException(status_code=500, detail="Errore durante l'aggiornamento del contatore.")


# ─────────────────────────────────────────────────────────────────────────
# Streak di accesso
# ─────────────────────────────────────────────────────────────────────────

@router.post("/gamification/streak/checkin")
@limiter.limit("20/minute")
async def streak_checkin(
    request: Request,
    uid: str = Depends(get_current_uid),
):
    """Calcola/aggiorna lo streak di accesso giornaliero interamente
    lato server (usa la data del server invece dell'orologio del device,
    non manipolabile dal client). Sostituisce BadgeService.checkLoginStreak."""
    try:
        db = firebase_admin.firestore.client()
        user_ref = db.collection('users').document(uid)
        today = datetime.date.today()
        today_str = today.isoformat()

        @firestore.transactional
        def _txn(transaction):
            snap = user_ref.get(transaction=transaction)
            data = snap.to_dict() or {}

            last_login_str = data.get('streak_last_login')
            current_streak = int(data.get('streak_count') or 0)
            unlocked = data.get('unlocked_badges') or {}

            if last_login_str == today_str:
                return {'streak_count': current_streak, 'unlocked': [], 'unchanged': True}

            if last_login_str is None:
                new_streak = 1
            else:
                try:
                    last_login = datetime.date.fromisoformat(last_login_str)
                    diff = (today - last_login).days
                    new_streak = current_streak + 1 if diff == 1 else 1
                except ValueError:
                    new_streak = 1

            update_payload = {
                'streak_last_login': today_str,
                'streak_count': new_streak,
                'badge_counters.streak_days': new_streak,
            }

            newly_unlocked = []
            if 'first_login' not in unlocked:
                update_payload['unlocked_badges.first_login'] = firestore.SERVER_TIMESTAMP
                newly_unlocked.append('first_login')
            if today.month == 12 and today.day == 25 and 'holiday_spirit' not in unlocked:
                update_payload['unlocked_badges.holiday_spirit'] = firestore.SERVER_TIMESTAMP
                newly_unlocked.append('holiday_spirit')
            for badge_id, required in _BADGE_COUNTER_REGISTRY['streak_days']:
                if badge_id not in unlocked and new_streak >= required:
                    update_payload[f'unlocked_badges.{badge_id}'] = firestore.SERVER_TIMESTAMP
                    newly_unlocked.append(badge_id)

            transaction.update(user_ref, update_payload)
            return {'streak_count': new_streak, 'unlocked': newly_unlocked, 'unchanged': False}

        txn = db.transaction()
        result = _txn(txn)
        return result
    except Exception as e:
        logger.error("streak_checkin_error", error=sanitize_error_message(e), uid=uid)
        raise HTTPException(status_code=500, detail="Errore durante l'aggiornamento streak.")
