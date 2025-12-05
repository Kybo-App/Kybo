import google.generativeai as genai
import typing_extensions as typing
import os

# --- DEFINIZIONE DELLA STRUTTURA DATI (Schema) ---
class Ingrediente(typing.TypedDict):
    nome: str
    quantita: str

class Piatto(typing.TypedDict):
    nome_piatto: str
    tipo: str  # "composto" o "singolo"
    quantita_totale: str # Solo se è singolo (es. "200 gr")
    ingredienti: list[Ingrediente] # Solo se è composto

class Pasto(typing.TypedDict):
    tipo_pasto: str # "Colazione", "Pranzo", "Cena", etc.
    elenco_piatti: list[Piatto]

class GiornoDieta(typing.TypedDict):
    giorno: str # "Lunedì", "Martedì", etc.
    pasti: list[Pasto]

class DietParser:
    def __init__(self):
        # Configura la tua API Key qui se non è nelle variabili d'ambiente
        # genai.configure(api_key=os.environ["GOOGLE_API_KEY"])
        
        self.system_instruction = """
        Sei un assistente nutrizionista esperto in parsing di documenti dietetici.
        Il tuo compito è estrarre il piano alimentare dal testo fornito e strutturarlo in JSON.

        **REGOLE FONDAMENTALI DI PARSING (CRUCIALE):**

        1.  **Analisi Riga per Riga:** Leggi attentamente ogni riga di alimento.
        2.  **Rilevamento PIATTO COMPOSTO:**
            * Se una riga contiene il nome di un piatto ma **NON contiene alcuna quantità** (es. numeri seguiti da gr, g, ml, vasetti, cucchiaini), consideralo un "Titolo di Piatto Composto".
            * Gli alimenti nelle righe immediatamente successive sono i suoi **Ingredienti** SOLO SE iniziano con un pallino (•) o sono chiaramente indentati sotto il titolo.
        3.  **Rilevamento ALIMENTO SINGOLO:**
            * Se una riga contiene un nome alimento E **contiene una quantità** (es. "Tonno 100 gr", "Pane 50 gr"), questo è un "Alimento Singolo".
            * **ECCEZIONE IMPORTANTE:** Se trovi un alimento con quantità (es. "Tonno 100 gr") subito dopo un "Piatto Composto" (es. "Pasta alle melanzane"), ma questo alimento **NON ha il pallino (•)** davanti, NON fa parte del piatto composto. È un secondo piatto separato.
        
        Restituisci solo il JSON strutturato secondo lo schema fornito.
        """

    def parse(self, text: str):
        """
        Metodo principale chiamato dal server per analizzare il testo.
        """
        model = genai.GenerativeModel(
            model_name="gemini-1.5-flash",
            system_instruction=self.system_instruction,
            generation_config={
                "response_mime_type": "application/json",
                "response_schema": list[GiornoDieta]
            }
        )

        prompt = f"""
        Analizza il seguente testo estratto da una dieta e applica RIGOROSAMENTE le regole sui piatti composti vs alimenti singoli.
        
        TESTO DIETA:
        {text}
        """

        try:
            response = model.generate_content(prompt)
            return response.text
        except Exception as e:
            print(f"Errore durante la generazione con Gemini: {e}")
            # Restituisce un JSON vuoto o un errore gestibile in caso di fallimento
            return "[]"