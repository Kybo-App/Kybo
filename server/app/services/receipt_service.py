import pytesseract
from PIL import Image, ImageFilter, ImageOps, ImageEnhance
import io
from google import genai
from google.genai import types
from pydantic import BaseModel, Field
from app.core.config import settings

# [FIX 3.2] Modelli Pydantic per validazione rigorosa
class ReceiptItem(BaseModel):
    name: str = Field(description="Nome del prodotto alimentare trovato nello scontrino")
    quantity: str = Field(description="Quantità indicata (es. '1kg', '2pz', '300g')")

class ReceiptAnalysis(BaseModel):
    items: list[ReceiptItem]

class ReceiptScanner:
    def __init__(self, allowed_foods_list: list[str]):
        api_key = settings.GOOGLE_API_KEY
        if not api_key:
            print("❌ CRITICAL: GOOGLE_API_KEY not found!")
            self.client = None
        else:
            clean_key = api_key.strip().replace('"', '').replace("'", "")
            self.client = genai.Client(api_key=clean_key)

        # [FIX COSTI] Limitiamo il contesto a max 500 elementi per evitare token overflow
        # Se la lista è enorme, l'AI si confonde ("Lost in the Middle") e i costi esplodono.
        max_context_items = 500
        clean_list = [str(f).lower().strip() for f in allowed_foods_list if f]
        
        if len(clean_list) > max_context_items:
            # Prendiamo i primi N (o si potrebbe implementare una logica più smart)
            clean_list = clean_list[:max_context_items]
            print(f"⚠️ Context Truncated: Using top {max_context_items} foods.")
            
        self.allowed_foods_str = ", ".join(clean_list)

        self.system_instruction = """
        Sei un assistente per un'app di dieta. Analizza il testo OCR di uno scontrino.
        
        OBIETTIVO:
        Estrai SOLO i prodotti alimentari che corrispondono (anche vagamente) alla lista fornita.
        
        REGOLE:
        1. Ignora prodotti non alimentari (detersivi, sacchetti, etc).
        2. Cerca di normalizzare i nomi basandoti sulla lista di riferimento.
        3. Estrai la quantità se presente, altrimenti metti "1".
        """

    @staticmethod
    def _preprocess_image(image: Image.Image) -> Image.Image:
        """
        Pre-processa l'immagine per migliorare l'accuratezza dell'OCR:
        - Conversione in scala di grigi
        - Aumento del contrasto
        - Sharpening
        - Ridimensionamento se troppo piccola (Tesseract lavora meglio con DPI ≥ 200)
        """
        # Convert to grayscale
        image = image.convert('L')

        # Auto-level (stretch histogram to full range)
        image = ImageOps.autocontrast(image, cutoff=2)

        # Increase contrast
        enhancer = ImageEnhance.Contrast(image)
        image = enhancer.enhance(2.0)

        # Sharpen to make text crisper
        image = image.filter(ImageFilter.SHARPEN)

        # Upscale if too small (Tesseract prefers ≥ 1000px wide)
        min_width = 1000
        if image.width < min_width:
            scale = min_width / image.width
            new_size = (min_width, int(image.height * scale))
            image = image.resize(new_size, Image.LANCZOS)

        return image

    # [FIX I/O] Accetta file_obj (stream) invece di path
    def scan_receipt(self, file_obj) -> list[dict]:
        if not self.client:
            print("⚠️ Gemini Client missing.")
            return []

        try:
            # 1. OCR con Tesseract e pre-processing immagine
            image = Image.open(file_obj)
            processed = self._preprocess_image(image)
            # PSM 6 = assume a single uniform block of text (good for receipts)
            custom_config = r'--oem 3 --psm 6'
            text = pytesseract.image_to_string(processed, lang='ita', config=custom_config)
            
            if not text or len(text.strip()) < 5:
                print("⚠️ OCR vuoto o illeggibile.")
                return []
            
            # 2. Prepare Prompt
            prompt = f"""
            Analizza questo scontrino e estrai gli alimenti.
            
            <ocr_text>
            {text}
            </ocr_text>
            
            <allowed_foods_context>
            {self.allowed_foods_str}
            </allowed_foods_context>
            """

            # 3. Call Gemini con Pydantic Schema
            response = self.client.models.generate_content(
                model=settings.GEMINI_MODEL,
                contents=prompt,
                config=types.GenerateContentConfig(
                    system_instruction=self.system_instruction,
                    response_mime_type="application/json",
                    response_schema=ReceiptAnalysis # <--- VALIDAZIONE FORTE
                )
            )

            # 4. Parsing Robusto (Niente più "guesswork")
            found_items = []
            
            if response.parsed:
                # response.parsed è garantito essere un'istanza di ReceiptAnalysis
                for item in response.parsed.items:
                    if item.name:
                        print(f"  ✅ MATCH: {item.name} ({item.quantity})")
                        found_items.append({
                            "name": item.name,
                            "quantity": item.quantity
                        })
            
            return found_items

        except Exception as e:
            print(f"⚠️ Receipt Scan Error: {e}")
            return []