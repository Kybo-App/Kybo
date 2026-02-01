import json
import re
import io
import pdfplumber
import os
import hashlib
from google import genai
from google.genai import types
from app.core.config import settings
from app.models.schemas import (
    DietResponse, 
    Dish, 
    Ingredient, 
    SubstitutionGroup, 
    SubstitutionOption
)
import typing_extensions as typing

# --- DATA SCHEMAS (Your Original TypedDicts) ---
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
    giorni: list[str]  # Giorni della settimana nell'ordine del PDF
    pasti: list[str]   # Tipi di pasto nell'ordine del PDF
    alimenti_rilassabili: list[str]  # Frutta/verdura identificati nel piano

class OutputDietaCompleto(typing.TypedDict):
    piano_settimanale: list[GiornoDieta]
    tabella_sostituzioni: list[GruppoSostituzione]
    config: ConfigDieta  # Configurazione dinamica

class DietParser:
    # [OPTIMIZATION] Cache L1 in RAM (condivisa tra richieste)
    # Chiave: content_hash, Valore: (result, timestamp)
    _memory_cache: dict = {}
    _MEMORY_CACHE_MAX_SIZE = 100  # Limita dimensione cache in RAM
    _MEMORY_CACHE_TTL_SECONDS = 3600  # 1 ora TTL per cache RAM

    def __init__(self):
        api_key = settings.GOOGLE_API_KEY
        if not api_key:
            print("❌ CRITICAL ERROR: GOOGLE_API_KEY not found in settings!")
            self.client = None
        else:
            clean_key = api_key.strip().replace('"', '').replace("'", "")
            self.client = genai.Client(api_key=clean_key)

        # [System instruction con supporto config dinamica]
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
1. Weekly Plan Only: Extract every meal.
2. No Substitutions: Return empty list [].
3. No CAD Codes: Set to 0.

CONFIG EXTRACTION (REQUIRED):
Extract the following metadata and include in "config" field:
1. "giorni": List of days of the week AS THEY APPEAR in the document (translated to Italian).
   Example: ["Lunedì", "Martedì", "Mercoledì", "Giovedì", "Venerdì", "Sabato", "Domenica"]
2. "pasti": List of meal types IN THE ORDER they appear in the document (translated to Italian).
   Example: ["Colazione", "Spuntino", "Pranzo", "Merenda", "Cena"]
3. "alimenti_rilassabili": List of fruits and vegetables found in the diet plan.
   - Include common fruits: mela, pera, banana, arancia, kiwi, fragola, etc.
   - Include common vegetables: insalata, pomodoro, zucchina, carota, spinaci, etc.
   - Extract from dish names and ingredients that match fruit/vegetable categories.
   - Keep names in lowercase, singular form when possible.
   Example: ["mela", "banana", "insalata", "pomodoro", "carote", "spinaci"]
"""

    # --- 1.4 SANITIZZAZIONE GDPR (Migliorata) ---
    def _sanitize_text(self, text: str) -> str:
        """
        Rimuove PII sensibile dal testo del PDF prima dell'elaborazione AI.
        Gestisce: email, codici fiscali, telefoni, nomi composti, indirizzi.
        """
        if not text: return ""

        # Rimuove Email (anche parziali)
        text = re.sub(
            r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
            '[EMAIL]',
            text
        )

        # Rimuove Codici Fiscali italiani (16 caratteri alfanumerici)
        text = re.sub(
            r'\b[A-Z]{6}[0-9]{2}[A-Z][0-9]{2}[A-Z][0-9]{3}[A-Z]\b',
            '[CF]',
            text,
            flags=re.IGNORECASE
        )

        # Rimuove Telefoni italiani (fissi e mobili, vari formati)
        text = re.sub(
            r'\b(?:\+39|0039)?\s*[0-9]{2,4}[\s\-\.]?[0-9]{6,7}\b',
            '[TEL]',
            text
        )

        # Rimuove numeri di telefono cellulare (3xx xxx xxxx)
        text = re.sub(
            r'\b3[0-9]{2}[\s\-\.]?[0-9]{3}[\s\-\.]?[0-9]{4}\b',
            '[TEL]',
            text
        )

        # Rimuove Intestazioni con nomi (Paziente, Sig., Dott., etc.)
        # Gestisce anche nomi composti e con apostrofo (D'Angelo, Maria Grazia)
        text = re.sub(
            r'(?i)(Paziente|Sig\.?|Sig\.?ra|Dott\.?|Dr\.?|Nome|Cognome|Spett\.le|Cliente|Assistito)\s*[:\.]?\s*[A-Za-zÀ-ÿ\'\s]+(?=\n|$|[,;])',
            '[ANAGRAFICA]',
            text
        )

        # Rimuove potenziali indirizzi (Via/Piazza + nome + numero)
        text = re.sub(
            r'(?i)(Via|Viale|Piazza|P\.za|Corso|C\.so|Largo)\s+[A-Za-zÀ-ÿ\'\s]+,?\s*\d*',
            '[INDIRIZZO]',
            text
        )

        # Rimuove date di nascita in formato comune (gg/mm/aaaa o gg-mm-aaaa)
        text = re.sub(
            r'\b\d{1,2}[/\-\.]\d{1,2}[/\-\.](19|20)\d{2}\b',
            '[DATA]',
            text
        )

        return text

    # --- 3.1 STREAMING I/O FIX ---
    # Ora accetta 'file_obj' (stream) invece di 'pdf_path' (stringa)
    def _extract_text_from_pdf(self, file_obj) -> str:
        text_buffer = io.StringIO()
        try:
            # Apriamo direttamente l'oggetto in memoria senza toccare il disco
            with pdfplumber.open(file_obj) as pdf:
                if len(pdf.pages) > 50:
                    raise ValueError("Il PDF ha troppe pagine (Max 50).")
                
                for page in pdf.pages:
                    extracted = page.extract_text(layout=True) 
                    if extracted:
                        text_buffer.write(extracted)
                        text_buffer.write("\n")
            
            return text_buffer.getvalue()
        except Exception as e:
            print(f"❌ Errore lettura PDF: {e}")
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

    # [OPTIMIZATION] Metodi per cache L1 in RAM
    def _get_from_memory_cache(self, content_hash: str):
        """Cerca risultato in cache RAM (L1). Ritorna None se non trovato o scaduto."""
        import time
        if content_hash in DietParser._memory_cache:
            result, timestamp = DietParser._memory_cache[content_hash]
            # Verifica TTL
            if time.time() - timestamp < DietParser._MEMORY_CACHE_TTL_SECONDS:
                return result
            else:
                # Cache scaduta, rimuovi
                del DietParser._memory_cache[content_hash]
        return None

    def _save_to_memory_cache(self, content_hash: str, result):
        """Salva risultato in cache RAM (L1) con LRU eviction."""
        import time
        # Eviction se cache piena (rimuovi entry più vecchia)
        if len(DietParser._memory_cache) >= DietParser._MEMORY_CACHE_MAX_SIZE:
            oldest_key = min(DietParser._memory_cache.keys(),
                           key=lambda k: DietParser._memory_cache[k][1])
            del DietParser._memory_cache[oldest_key]

        DietParser._memory_cache[content_hash] = (result, time.time())

    # Ora accetta 'file_obj' come primo parametro
    def parse_complex_diet(self, file_obj, custom_instructions: str = None):
        if not self.client:
            raise ValueError("Client Gemini non inizializzato.")

        # Estrai testo dallo stream (RAM)
        raw_text = self._extract_text_from_pdf(file_obj)
        if not raw_text:
            raise ValueError("PDF vuoto o illeggibile.")

        # Applica sanitizzazione GDPR
        diet_text = self._sanitize_text(raw_text)

        # Calcola hash del contenuto (include custom instructions)
        cache_content = f"{diet_text}||{custom_instructions or 'default'}"
        content_hash = hashlib.sha256(cache_content.encode('utf-8')).hexdigest()

        # ✅ CACHE L1: Check memoria RAM (microsecondi)
        memory_result = self._get_from_memory_cache(content_hash)
        if memory_result:
            print(f"✅ Cache L1 (RAM) HIT per hash {content_hash[:8]}...")
            return memory_result

        # ✅ CACHE L2: Check Firestore (millisecondi)
        cached_result = self._get_cached_response(content_hash)
        if cached_result:
            print(f"✅ Cache L2 (Firestore) HIT per hash {content_hash[:8]}...")
            # Popola anche L1 per future richieste
            self._save_to_memory_cache(content_hash, cached_result)
            return cached_result

        model_name = settings.GEMINI_MODEL
        final_instruction = custom_instructions if custom_instructions else self.system_instruction
        
        try:
            print(f"🤖 Analisi Gemini ({model_name})... Custom Prompt: {bool(custom_instructions)}")
            print(f"🔑 Cache MISS per hash {content_hash[:8]}... (chiamata API)")
            
            prompt = f"""
            Analizza il seguente testo ed estrai i dati della dieta e le sostituzioni CAD.
            <source_document>
            {diet_text}
            </source_document>
            """

            response = self.client.models.generate_content(
                model=model_name,
                contents=prompt,
                config=types.GenerateContentConfig(
                    system_instruction=final_instruction,
                    response_mime_type="application/json",
                    response_schema=OutputDietaCompleto
                )
            )
            
            # Estrai risultato
            if hasattr(response, 'parsed') and response.parsed:
                result = response.parsed
            elif hasattr(response, 'text') and response.text:
                result = self._extract_json_from_text(response.text)
            else:
                raise ValueError("Risposta vuota da Gemini")
            
            # ✅ CACHE L1: Salva in RAM per accesso veloce
            self._save_to_memory_cache(content_hash, result)

            # ✅ CACHE L2: Salva in Firestore per persistenza
            self._save_cached_response(content_hash, result)

            return result

        except Exception as e:
            print(f"⚠️ Errore con Gemini: {e}")
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

                # Verifica che la cache non sia troppo vecchia (es. 30 giorni)
                cached_at = data.get('cached_at')
                if cached_at:
                    cache_time = cached_at
                    if isinstance(cache_time, datetime):
                        # Fix #13: Usa datetime timezone-aware per confronto corretto
                        now = datetime.now(timezone.utc)
                        # Se cache_time è naive, rendilo UTC
                        if cache_time.tzinfo is None:
                            cache_time = cache_time.replace(tzinfo=timezone.utc)
                        age = now - cache_time
                        if age > timedelta(days=30):
                            # Cache scaduta, eliminala
                            cache_ref.delete()
                            return None

                return data.get('result')

            return None

        except Exception as e:
            print(f"⚠️ Errore lettura cache: {e}")
            return None  # Se la cache non funziona, prosegui con Gemini

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
            
            # Salva con timestamp UTC per tracking età cache
            cache_ref.set({
                'result': result,
                'cached_at': datetime.now(timezone.utc),
                'hash': content_hash[:8]  # Solo per debug
            })
            
            print(f"💾 Risultato salvato in cache (hash: {content_hash[:8]}...)")
            
        except Exception as e:
            print(f"⚠️ Errore salvataggio cache: {e}")
            # Non blocchiamo l'operazione se il salvataggio cache fallisce
            pass