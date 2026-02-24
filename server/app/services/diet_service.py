"""
Servizio di parsing diete da PDF con Gemini AI.
Estrae piano settimanale, sostituzioni CAD, config e allergeni.
Implementa cache a tre livelli: RAM (L1), Redis (L1.5), Firestore (L2).
Prima di inviare il testo a Gemini, applica sanitizzazione GDPR per rimuovere PII.
"""
import json
import re
import io
import logging
import pdfplumber
import hashlib
from google import genai

logger = logging.getLogger(__name__)
from google.genai import types
from app.core.config import settings
from app.services.app_config_service import get_app_config
from app.core.metrics import (
    diet_gemini_calls_total,
    diet_gemini_errors_total,
    diet_cache_hits_total,
    diet_cache_misses_total,
    diet_parse_duration_seconds,
    diet_uploads_total,
)
from app.models.schemas import (
    DietResponse, 
    Dish, 
    Ingredient, 
    SubstitutionGroup, 
    SubstitutionOption
)
import typing_extensions as typing

class Ingrediente(typing.TypedDict):
    nome: str
    quantita: str

class Piatto(typing.TypedDict):
    nome_piatto: str
    tipo: str
    cad_code: int
    quantita_totale: str
    ingredienti: list[Ingrediente]

class Pasto(typing.TypedDict):
    tipo_pasto: str
    elenco_piatti: list[Piatto]

class GiornoDieta(typing.TypedDict):
    giorno: str
    settimana: int
    pasti: list[Pasto]

class OpzioneSostituzione(typing.TypedDict):
    nome: str
    quantita: str

class GruppoSostituzione(typing.TypedDict):
    cad_code: int
    titolo: str
    opzioni: list[OpzioneSostituzione]

class ConfigDieta(typing.TypedDict):
    """Configurazione dinamica estratta dalla dieta."""
    giorni: list[str]
    pasti: list[str]
    alimenti_rilassabili: list[str]
    num_settimane: int

class OutputDietaCompleto(typing.TypedDict):
    piano_settimanale: list[GiornoDieta]
    tabella_sostituzioni: list[GruppoSostituzione]
    config: ConfigDieta
    allergeni: list[str]

class DietParser:
    _memory_cache: dict = {}
    _MEMORY_CACHE_MAX_SIZE = settings.MEMORY_CACHE_SIZE
    _MEMORY_CACHE_TTL_SECONDS = settings.MEMORY_CACHE_TTL

    _redis_sync = None
    _redis_checked = False

    def __init__(self):
        api_key = settings.GOOGLE_API_KEY
        if not api_key:
            logger.critical("GOOGLE_API_KEY not found in settings!")
            self.client = None
        else:
            clean_key = api_key.strip().replace('"', '').replace("'", "")
            self.client = genai.Client(api_key=clean_key)

        self.system_instruction = """
You are an expert AI Nutritionist and Data Analyst capable of understanding any language.
YOUR TASK: Extract the weekly diet plan from the provided document.

CRITICAL RULES FOR MULTI-LANGUAGE SUPPORT:
1. Detect Language: Read the document in its original language.
2. Translate Structure (Required):
   - Translate Day of the Week into Italian.
   - Translate Meal Category into Italian.
3. Preserve Content: Keep Dish Names, Ingredients, and Quantities in ORIGINAL LANGUAGE.

SIMPLIFIED SCHEMA RULES:
1. Extract every meal from the entire document.
2. No Substitutions: Return empty list [].
3. No CAD Codes: Set to 0.

MULTI-WEEK DETECTION (CRITICAL):
- Inspect the document for multiple weeks. Signs include: "Settimana 1"/"Settimana 2", "Week 1"/"Week 2", "Lunedì 1"/"Lunedì 2", repeated day blocks, or explicit week headers.
- For each day entry, set the "settimana" field to the correct week number (1 for the first week, 2 for the second, etc.).
- If the document contains only one week, set "settimana": 1 for all days.
- Days from different weeks MUST be separate entries in "piano_settimanale" even if they have the same day name (e.g., two "Lunedì" entries, one with settimana:1 and one with settimana:2).
- NEVER merge or overwrite days from different weeks.

CONFIG EXTRACTION (REQUIRED):
Extract the following metadata and include in "config" field:
1. "giorni": List of UNIQUE days of the week AS THEY APPEAR in the document (translated to Italian). Do NOT repeat the same day for multiple weeks.
   Example: ["Lunedì", "Martedì", "Mercoledì", "Giovedì", "Venerdì", "Sabato", "Domenica"]
2. "pasti": List of meal types IN THE ORDER they appear in the document (translated to Italian).
   Example: ["Colazione", "Spuntino", "Pranzo", "Merenda", "Cena"]
3. "alimenti_rilassabili": List of SIMPLE fruits and vegetables found in the diet plan.
4. "num_settimane": Total number of weeks in the document. Set to 1 if single week, 2 if two weeks, etc.
   - STRICTLY ONLY fresh, whole fruits and vegetables.
   - DO NOT INCLUDE: Oils (olio di oliva), fats, jams (marmellata), honey, bread, pasta, meat, fish, dairy, eggs.
   - DO NOT extract fruits/vegetables that appear ONLY in processed forms (e.g., do NOT add "mela" if it only appears in "marmellata di mele").
   - ONLY extract if the fruit/vegetable appears as a standalone ingredient or fresh dish component.
   - Include common fruits: mela, pera, banana, arancia, kiwi, fragola, etc.
   - Include common vegetables: insalata, pomodoro, zucchina, carota, spinaci, etc.
   - Keep names in lowercase, singular form when possible.
   Example: ["mela", "banana", "arancia", "insalata", "pomodoro", "carote", "spinaci"]

ALLERGEN EXTRACTION (REQUIRED):
Extract any allergens or intolerances EXPLICITLY mentioned in the document header, notes, or introduction.
- Look for keywords like: "Intolleranze", "Allergie", "Allergeni", "No a...".
- Return as a simple list of strings.
- Example: ["Glutine", "Lattosio", "Nichel"]
- If none found, return empty list [].
"""

    def _sanitize_text(self, text: str) -> str:
        """
        Rimuove PII sensibile dal testo del PDF prima dell'elaborazione AI.
        Gestisce: email, codici fiscali, telefoni, nomi composti, indirizzi.
        """
        if not text: return ""

        text = re.sub(
            r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
            '[EMAIL]',
            text
        )

        text = re.sub(
            r'\b[A-Z]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9]{3}[A-Z]\b',
            '[CF]',
            text,
            flags=re.IGNORECASE
        )

        text = re.sub(
            r'\b(?:\+39|0039)?\s*[0-9]{2,4}[\s\-\.]?[0-9]{6,7}\b',
            '[TEL]',
            text
        )

        text = re.sub(
            r'\b3[0-9]{2}[\s\-\.]?[0-9]{3}[\s\-\.]?[0-9]{4}\b',
            '[TEL]',
            text
        )

        text = re.sub(
            r'(?i)(Paziente|Sig\.?|Sig\.?ra|Dott\.?|Dr\.?|Nome|Cognome|Spett\.le|Cliente|Assistito)\s*[:\.]?\s*[A-Za-zÀ-ÿ\'\s]+(?=\n|$|[,;])',
            '[ANAGRAFICA]',
            text
        )

        text = re.sub(
            r'(?i)(Via|Viale|Piazza|P\.za|Corso|C\.so|Largo)\s+[A-Za-zÀ-ÿ\'\s]+,?\s*\d*',
            '[INDIRIZZO]',
            text
        )

        text = re.sub(
            r'\b\d{1,2}[/\-\.]\d{1,2}[/\-\.](19|20)\d{2}\b',
            '[DATA]',
            text
        )

        return text

    def _extract_text_from_pdf(self, file_obj) -> str:
        text_buffer = io.StringIO()
        try:
            with pdfplumber.open(file_obj) as pdf:
                max_pages = get_app_config().get("max_pdf_pages", settings.MAX_PDF_PAGES)
                if len(pdf.pages) > max_pages:
                    raise ValueError(f"Il PDF ha troppe pagine (Max {max_pages}).")
                
                for page in pdf.pages:
                    extracted = page.extract_text(layout=True) 
                    if extracted:
                        text_buffer.write(extracted)
                        text_buffer.write("\n")
            
            return text_buffer.getvalue()
        except Exception as e:
            logger.error("Errore lettura PDF: %s", e)
            raise e
        finally:
            text_buffer.close()

    def _extract_json_from_text(self, text: str):
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            pass
        match = re.search(r'\{.*\}', text, re.DOTALL)
        if match:
            clean_text = match.group(0)
            try:
                return json.loads(clean_text)
            except json.JSONDecodeError:
                pass
        raise ValueError("Impossibile estrarre JSON valido.")

    def _get_from_memory_cache(self, content_hash: str):
        """Cerca risultato in cache RAM (L1). Ritorna None se non trovato o scaduto."""
        import time
        if content_hash in DietParser._memory_cache:
            result, timestamp = DietParser._memory_cache[content_hash]
            if time.time() - timestamp < DietParser._MEMORY_CACHE_TTL_SECONDS:
                return result
            else:
                del DietParser._memory_cache[content_hash]
        return None

    def _save_to_memory_cache(self, content_hash: str, result):
        """Salva risultato in cache RAM (L1) con LRU eviction."""
        import time
        if len(DietParser._memory_cache) >= DietParser._MEMORY_CACHE_MAX_SIZE:
            oldest_key = min(DietParser._memory_cache.keys(),
                           key=lambda k: DietParser._memory_cache[k][1])
            del DietParser._memory_cache[oldest_key]

        DietParser._memory_cache[content_hash] = (result, time.time())

    def _get_redis_sync(self):
        """Lazy init del client Redis sincrono. Ritorna None se non disponibile."""
        if DietParser._redis_checked:
            return DietParser._redis_sync
        DietParser._redis_checked = True
        if not settings.REDIS_URL:
            return None
        try:
            import redis as redis_sync
            DietParser._redis_sync = redis_sync.from_url(
                settings.REDIS_URL,
                decode_responses=True,
                socket_connect_timeout=2,
                socket_timeout=2,
            )
            DietParser._redis_sync.ping()
            logger.info("Redis sincrono connesso per DietParser")
        except Exception as e:
            logger.warning("Redis non disponibile per DietParser: %s", e)
            DietParser._redis_sync = None
        return DietParser._redis_sync

    def _get_from_redis_cache(self, content_hash: str):
        """Cerca risultato in Redis (L1.5). Ritorna None se miss o Redis non disponibile."""
        import json
        r = self._get_redis_sync()
        if r is None:
            return None
        try:
            raw = r.get(f"kybo:diet:{content_hash}")
            if raw:
                return json.loads(raw)
        except Exception as e:
            logger.warning("Redis GET error: %s", e)
        return None

    def _save_to_redis_cache(self, content_hash: str, result):
        """Salva risultato in Redis (L1.5) con TTL configurabile."""
        import json
        r = self._get_redis_sync()
        if r is None:
            return
        try:
            r.setex(
                f"kybo:diet:{content_hash}",
                settings.REDIS_DIET_TTL,
                json.dumps(result, default=str),
            )
        except Exception as e:
            logger.warning("Redis SET error: %s", e)

    def parse_complex_diet(self, file_obj, custom_instructions: str = None):
        if not self.client:
            raise ValueError("Client Gemini non inizializzato.")

        raw_text = self._extract_text_from_pdf(file_obj)
        if not raw_text:
            raise ValueError("PDF vuoto o illeggibile.")

        diet_text = self._sanitize_text(raw_text)

        instruction_part = custom_instructions if custom_instructions else self.system_instruction
        cache_content = f"{diet_text}||{instruction_part}"
        content_hash = hashlib.sha256(cache_content.encode('utf-8')).hexdigest()

        memory_result = self._get_from_memory_cache(content_hash)
        if memory_result:
            logger.debug("Cache L1 (RAM) HIT per hash %s...", content_hash[:8])
            diet_cache_hits_total.labels(layer="L1_ram").inc()
            return memory_result
        diet_cache_misses_total.labels(layer="L1_ram").inc()

        redis_result = self._get_from_redis_cache(content_hash)
        if redis_result:
            logger.debug("Cache L1.5 (Redis) HIT per hash %s...", content_hash[:8])
            diet_cache_hits_total.labels(layer="L1.5_redis").inc()
            self._save_to_memory_cache(content_hash, redis_result)
            return redis_result
        diet_cache_misses_total.labels(layer="L1.5_redis").inc()

        cached_result = self._get_cached_response(content_hash)
        if cached_result:
            logger.debug("Cache L2 (Firestore) HIT per hash %s...", content_hash[:8])
            diet_cache_hits_total.labels(layer="L2_firestore").inc()
            self._save_to_memory_cache(content_hash, cached_result)
            self._save_to_redis_cache(content_hash, cached_result)
            return cached_result
        diet_cache_misses_total.labels(layer="L2_firestore").inc()

        model_name = get_app_config().get("gemini_model", settings.GEMINI_MODEL)
        final_instruction = custom_instructions if custom_instructions else self.system_instruction

        diet_gemini_calls_total.inc()
        try:
            logger.info("Analisi Gemini (%s)... Custom Prompt: %s", model_name, bool(custom_instructions))
            logger.debug("Cache MISS per hash %s... (chiamata API)", content_hash[:8])

            prompt = f"""
            Analizza il seguente testo ed estrai i dati della dieta e le sostituzioni CAD.
            <source_document>
            {diet_text}
            </source_document>
            """

            with diet_parse_duration_seconds.time():
                response = self.client.models.generate_content(
                    model=model_name,
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        system_instruction=final_instruction,
                        response_mime_type="application/json",
                        response_schema=OutputDietaCompleto
                    )
                )

            if hasattr(response, 'parsed') and response.parsed:
                result = response.parsed
            elif hasattr(response, 'text') and response.text:
                result = self._extract_json_from_text(response.text)
            else:
                raise ValueError("Risposta vuota da Gemini")

            self._save_to_memory_cache(content_hash, result)
            self._save_to_redis_cache(content_hash, result)
            self._save_cached_response(content_hash, result)

            return result

        except Exception as e:
            diet_gemini_errors_total.inc()
            logger.error("Errore con Gemini: %s", e)
            raise e
    
    def _get_cached_response(self, content_hash: str):
        """
        Cerca il risultato in cache Firestore.
        Ritorna il risultato se esiste, altrimenti None.
        """
        try:
            import firebase_admin
            from firebase_admin import firestore
            from datetime import datetime, timedelta, timezone

            db = firestore.client()
            cache_ref = db.collection('gemini_cache').document(content_hash)
            cache_doc = cache_ref.get()

            if cache_doc.exists:
                data = cache_doc.to_dict()

                cached_at = data.get('cached_at')
                if cached_at:
                    cache_time = cached_at
                    if isinstance(cache_time, datetime):
                        now = datetime.now(timezone.utc)
                        if cache_time.tzinfo is None:
                            cache_time = cache_time.replace(tzinfo=timezone.utc)
                        age = now - cache_time
                        if age > timedelta(days=settings.FIRESTORE_CACHE_DAYS):
                            cache_ref.delete()
                            return None

                return data.get('result')

            return None

        except Exception as e:
            logger.warning("Errore lettura cache Firestore: %s", e)
            return None

    def _save_cached_response(self, content_hash: str, result):
        """
        Salva il risultato in cache Firestore per riutilizzo futuro.
        Cache valida per 30 giorni.
        """
        try:
            import firebase_admin
            from firebase_admin import firestore
            from datetime import datetime, timezone
            
            db = firestore.client()
            cache_ref = db.collection('gemini_cache').document(content_hash)
            cache_ref.set({
                'result': result,
                'cached_at': datetime.now(timezone.utc),
                'hash': content_hash[:8]
            })
            logger.debug("Risultato salvato in cache (hash: %s...)", content_hash[:8])
        except Exception as e:
            logger.warning("Errore salvataggio cache Firestore: %s", e)
            pass