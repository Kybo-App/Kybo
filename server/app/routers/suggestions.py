"""
Router per suggerimenti pasti personalizzati con Gemini AI.
Genera suggerimenti basati sulla dieta corrente, allergeni e preferenze storiche.
"""
from typing import Optional, List
from fastapi import APIRouter, HTTPException, Depends, Query
from pydantic import BaseModel
from google import genai
from google.genai import types
import typing_extensions as typing
import json
import hashlib
import time

from app.core.dependencies import verify_token, get_current_uid
from app.core.config import settings
from app.core.logging import logger
from app.core.cache import redis_cache
from app.core.metrics import (
    suggestions_gemini_calls_total,
    suggestions_gemini_errors_total,
    suggestions_cache_hits_total,
    suggestions_cache_misses_total,
    suggestions_duration_seconds,
)

router = APIRouter(tags=["suggestions"])


# ─── Pydantic schemas per la risposta ────────────────────────────────────────

class SuggestedDish(BaseModel):
    name: str
    qty: str
    meal_type: str          # "Colazione", "Pranzo", etc.
    description: str        # Breve descrizione/perché è adatto
    ingredients: List[str]  # Lista ingredienti principali
    calories_estimate: Optional[str] = None  # "~350 kcal" approssimativo


class MealSuggestionsResponse(BaseModel):
    suggestions: List[SuggestedDish]
    context_used: str       # Cosa ha usato Gemini per generare ("dieta attuale", "preferenze", ecc.)
    generated_at: int       # Unix timestamp


# ─── TypedDicts per Gemini structured output ─────────────────────────────────

class SuggeritoDish(typing.TypedDict):
    name: str
    qty: str
    meal_type: str
    description: str
    ingredients: list[str]
    calories_estimate: str


class SuggerimentiOutput(typing.TypedDict):
    suggestions: list[SuggeritoDish]


# ─── Cache L1 in-memory (fallback quando Redis non disponibile) ───────────────

_suggestions_cache: dict = {}
_CACHE_TTL = 1800  # 30 minuti


def _get_from_memory_cache(key: str):
    entry = _suggestions_cache.get(key)
    if entry and (time.time() - entry["ts"]) < _CACHE_TTL:
        return entry["data"]
    return None


def _save_to_memory_cache(key: str, data: dict):
    # Mantieni max 200 entry (LRU eviction)
    if len(_suggestions_cache) >= 200:
        oldest = min(_suggestions_cache, key=lambda k: _suggestions_cache[k]["ts"])
        del _suggestions_cache[oldest]
    _suggestions_cache[key] = {"data": data, "ts": time.time()}


# ─── Endpoint principale ──────────────────────────────────────────────────────

@router.get("/meal-suggestions", response_model=MealSuggestionsResponse)
async def get_meal_suggestions(
    meal_type: Optional[str] = Query(None, description="Filtra per tipo pasto: Colazione, Pranzo, Cena..."),
    count: int = Query(6, ge=1, le=12, description="Numero di suggerimenti da generare"),
    token: dict = Depends(verify_token),
    uid: str = Depends(get_current_uid),
):
    """
    Genera suggerimenti di pasti personalizzati basati su:
    - Dieta corrente dell'utente (piatti già presenti, config, allergeni)
    - Tipo pasto richiesto (opzionale)
    - Varietà rispetto ai piatti già presenti

    I suggerimenti sono cachati 30 minuti per evitare chiamate ridondanti a Gemini.
    """
    if not settings.GOOGLE_API_KEY:
        raise HTTPException(503, "Servizio AI non disponibile")

    # Carica dati utente da Firestore
    import firebase_admin
    from firebase_admin import firestore as fb_firestore
    db = fb_firestore.client()

    user_data = _load_user_context(db, uid)

    # Chiave cache: uid + meal_type + count + hash contesto dieta
    context_hash = hashlib.md5(
        json.dumps(user_data, sort_keys=True, default=str).encode()
    ).hexdigest()[:8]
    cache_key = f"suggestions:{uid}:{meal_type or 'all'}:{count}:{context_hash}"

    # ✅ CACHE L1: RAM locale (microsecondi)
    cached = _get_from_memory_cache(cache_key)
    if cached:
        logger.info("suggestions_cache_hit", layer="L1_ram", uid=uid)
        suggestions_cache_hits_total.labels(layer="L1_ram").inc()
        return MealSuggestionsResponse(**cached)
    suggestions_cache_misses_total.labels(layer="L1_ram").inc()

    # ✅ CACHE L1.5: Redis (millisecondi, condiviso tra istanze)
    redis_cached = await redis_cache.get(cache_key)
    if redis_cached:
        logger.info("suggestions_cache_hit", layer="L1.5_redis", uid=uid)
        suggestions_cache_hits_total.labels(layer="L1.5_redis").inc()
        _save_to_memory_cache(cache_key, redis_cached)
        return MealSuggestionsResponse(**redis_cached)
    suggestions_cache_misses_total.labels(layer="L1.5_redis").inc()

    # Genera con Gemini
    suggestions_gemini_calls_total.inc()
    try:
        with suggestions_duration_seconds.time():
            result = await _generate_suggestions(
                user_data=user_data,
                meal_type=meal_type,
                count=count,
            )
    except Exception as e:
        suggestions_gemini_errors_total.inc()
        logger.error(f"Errore generazione suggerimenti: {e}", uid=uid, meal_type=meal_type, count=count)
        error_detail = str(e)[:200] if str(e) else "Errore sconosciuto"
        raise HTTPException(500, f"Errore nella generazione dei suggerimenti: {error_detail}")

    response_data = {
        "suggestions": result,
        "context_used": _build_context_description(user_data, meal_type),
        "generated_at": int(time.time()),
    }

    # Salva in L1 (RAM) e L1.5 (Redis)
    _save_to_memory_cache(cache_key, response_data)
    await redis_cache.set(cache_key, response_data, ttl=settings.REDIS_SUGGESTIONS_TTL)

    return MealSuggestionsResponse(**response_data)


# ─── Helpers ─────────────────────────────────────────────────────────────────

def _load_user_context(db, uid: str) -> dict:
    """
    Carica dalla Firestore:
    - Dieta corrente (piano, config, allergeni)
    - Ultime note pasti (mood, preferenze)
    """
    context = {
        "current_dishes": [],       # Piatti già presenti nella dieta
        "meals_config": [],         # Tipi di pasto (Colazione, Pranzo...)
        "allergens": [],            # Allergeni dell'utente
        "relaxable_foods": [],      # Frutta/verdura rilassabili
        "recent_moods": [],         # Mood dalle note pasti recenti
    }

    try:
        # Dieta corrente
        diet_doc = db.collection("users").document(uid).collection("diets").document("current").get()
        if diet_doc.exists:
            diet_data = diet_doc.to_dict() or {}
            plan = diet_data.get("plan", {})

            # Estrai tutti i nomi dei piatti (prime 30 per non sovraccaricare il prompt)
            dishes = []
            for day_meals in plan.values():
                for meal_dishes in day_meals.values():
                    if isinstance(meal_dishes, list):
                        for dish in meal_dishes:
                            if isinstance(dish, dict):
                                name = dish.get("name", "")
                                if name and name not in dishes:
                                    dishes.append(name)
            context["current_dishes"] = dishes[:30]

            # Config dieta
            cfg = diet_data.get("config", {})
            if cfg:
                context["meals_config"] = cfg.get("meals", [])
                context["relaxable_foods"] = cfg.get("relaxable_foods", [])

            # Allergeni
            context["allergens"] = diet_data.get("allergens", [])

        # Ultime note pasti (mood tracking) — query separata per non bloccare
        # il resto del contesto se l'indice Firestore non esiste
        try:
            from firebase_admin import firestore as _fs
            notes_query = (
                db.collection("users")
                .document(uid)
                .collection("meal_notes")
                .order_by("date", direction=_fs.Query.DESCENDING)
                .limit(10)
                .stream()
            )
            moods = []
            for note_doc in notes_query:
                note = note_doc.to_dict() or {}
                mood = note.get("mood")
                meal = note.get("meal_type")
                if mood and meal:
                    moods.append(f"{meal}: {mood}")
            context["recent_moods"] = moods
        except Exception as notes_err:
            logger.warning(f"meal_notes query fallita: {notes_err}")
            context["recent_moods"] = []

    except Exception as e:
        logger.warning(f"Errore caricamento contesto utente {uid}: {e}")

    return context


async def _generate_suggestions(
    user_data: dict,
    meal_type: Optional[str],
    count: int,
) -> List[dict]:
    """Chiama Gemini per generare suggerimenti strutturati."""

    client = genai.Client(api_key=settings.GOOGLE_API_KEY.strip())

    # Costruisci il prompt con il contesto utente
    current_dishes_str = (
        ", ".join(user_data["current_dishes"])
        if user_data["current_dishes"]
        else "nessuna dieta caricata"
    )
    allergens_str = (
        ", ".join(user_data["allergens"])
        if user_data["allergens"]
        else "nessun allergene noto"
    )
    meals_str = (
        ", ".join(user_data["meals_config"])
        if user_data["meals_config"]
        else "Colazione, Pranzo, Merenda, Cena"
    )
    moods_str = (
        "; ".join(user_data["recent_moods"])
        if user_data["recent_moods"]
        else "nessuna nota recente"
    )

    meal_filter = f"Genera SOLO suggerimenti per: {meal_type}." if meal_type else f"Distribuisci i suggerimenti tra i pasti: {meals_str}."

    prompt = f"""Sei un nutrizionista AI che aiuta un utente italiano a variare la propria alimentazione.

CONTESTO UTENTE:
- Piatti già presenti nella dieta attuale: {current_dishes_str}
- Allergeni/intolleranze: {allergens_str}
- Tipi di pasto della dieta: {meals_str}
- Umore recente dai pasti: {moods_str}

ISTRUZIONI:
{meal_filter}
- Genera esattamente {count} suggerimenti di piatti/pasti NUOVI e DIVERSI da quelli già presenti.
- I piatti devono essere tipici della cucina italiana o mediterranea, sani e bilanciati.
- NON suggerire piatti che contengono gli allergeni indicati.
- Per ogni piatto indica: nome, quantità tipica (es. "80g" o "1 porzione"), tipo di pasto, breve descrizione motivazionale (max 15 parole), ingredienti principali (max 5), stima calorica approssimativa.
- Varia tra: piatti proteici, carboidrati complessi, verdure, frutta, latticini.
- Sii specifico con le quantità (grammi o unità).

Rispondi SOLO con il JSON strutturato richiesto."""

    from fastapi.concurrency import run_in_threadpool

    def _call_gemini():
        return client.models.generate_content(
            model=settings.GEMINI_MODEL,
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=SuggerimentiOutput,
                temperature=0.8,   # Un po' di creatività
                max_output_tokens=2048,
            ),
        )

    response = await run_in_threadpool(_call_gemini)

    # Parsing risposta — multi-tentativo robusto
    raw = response.text or "{}"
    logger.info(f"[suggestions] Gemini raw response (primi 500 char): {raw[:500]!r}")
    suggestions_raw = _parse_gemini_response(raw)
    logger.info(f"[suggestions] suggestions_raw count: {len(suggestions_raw)}, primo elemento: {suggestions_raw[0] if suggestions_raw else 'nessuno'}")

    # Normalizza in lista di dict
    result = []
    for s in suggestions_raw:
        if isinstance(s, dict) and s.get("name"):
            result.append({
                "name": s.get("name", ""),
                "qty": s.get("qty", ""),
                "meal_type": s.get("meal_type", meal_type or ""),
                "description": s.get("description", ""),
                "ingredients": s.get("ingredients", []),
                "calories_estimate": s.get("calories_estimate", None),
            })

    return result


def _parse_gemini_response(raw: str) -> list:
    """
    Parser robusto multi-tentativo per la risposta di Gemini.
    Gestisce: JSON puro, markdown ```json...```, array nudo, testo misto.
    """
    import re

    if not raw or not raw.strip():
        return []

    # Normalizza: rimuovi BOM, whitespace iniziale/finale
    cleaned = raw.strip().lstrip('\ufeff')

    # Tentativo 1: JSON diretto sul testo pulito
    try:
        parsed = json.loads(cleaned)
        if isinstance(parsed, dict):
            return parsed.get("suggestions", [])
        if isinstance(parsed, list):
            return parsed
    except json.JSONDecodeError as e:
        logger.debug(f"[parser T1] json.loads fallito: {e}")

    # Tentativo 2: estrai da blocco markdown ```json ... ```
    md_match = re.search(r'```(?:json)?\s*([\s\S]*?)```', cleaned)
    if md_match:
        try:
            parsed = json.loads(md_match.group(1).strip())
            if isinstance(parsed, dict):
                return parsed.get("suggestions", [])
            if isinstance(parsed, list):
                return parsed
        except json.JSONDecodeError as e:
            logger.debug(f"[parser T2] markdown block fallito: {e}")

    # Tentativo 3: trova il PRIMO { e l'ULTIMO } per catturare tutto l'oggetto
    first_brace = cleaned.find('{')
    last_brace = cleaned.rfind('}')
    if first_brace != -1 and last_brace > first_brace:
        try:
            candidate = cleaned[first_brace:last_brace + 1]
            parsed = json.loads(candidate)
            if isinstance(parsed, dict):
                return parsed.get("suggestions", [])
        except json.JSONDecodeError as e:
            logger.debug(f"[parser T3] brace extraction fallito: {e}")

    # Tentativo 4: trova il PRIMO [ e l'ULTIMO ] per catturare l'array
    first_bracket = cleaned.find('[')
    last_bracket = cleaned.rfind(']')
    if first_bracket != -1 and last_bracket > first_bracket:
        try:
            candidate = cleaned[first_bracket:last_bracket + 1]
            parsed = json.loads(candidate)
            if isinstance(parsed, list):
                return parsed
        except json.JSONDecodeError as e:
            logger.debug(f"[parser T4] bracket extraction fallito: {e}")

    logger.warning(f"_parse_gemini_response: tutti i tentativi falliti. Raw (primi 400 char): {raw[:400]!r}")
    return []


def _build_context_description(user_data: dict, meal_type: Optional[str]) -> str:
    parts = []
    if user_data["current_dishes"]:
        parts.append("dieta corrente")
    if user_data["allergens"]:
        parts.append(f"allergeni ({', '.join(user_data['allergens'])})")
    if user_data["recent_moods"]:
        parts.append("preferenze recenti")
    if meal_type:
        parts.append(f"filtro: {meal_type}")
    return ", ".join(parts) if parts else "dati generali"
