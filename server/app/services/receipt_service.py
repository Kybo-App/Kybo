import pytesseract
from PIL import Image, UnidentifiedImageError
import pdfplumber
import os
import json
import typing_extensions as typing
from google import genai
from google.genai import types
from app.core.config import settings

# --- DATA SCHEMAS ---
class ReceiptItem(typing.TypedDict):
    name: str
    quantity: str # Kept as string to allow "1kg", "2pz", etc.

class ReceiptAnalysis(typing.TypedDict):
    items: list[ReceiptItem]

class ReceiptScanner:
    def __init__(self, allowed_foods_list: list[str]):
        # [INIT] Setup Gemini Client (The "Diet Way")
        api_key = settings.GOOGLE_API_KEY
        if not api_key:
            print("❌ CRITICAL ERROR: GOOGLE_API_KEY not found!")
            self.client = None
        else:
            clean_key = api_key.strip().replace('"', '').replace("'", "")
            self.client = genai.Client(api_key=clean_key)

        # Optimize list for Prompt Context
        self.allowed_foods_str = ", ".join([str(f).lower().strip() for f in allowed_foods_list if f])
        print(f"[INFO] Receipt Context: {len(allowed_foods_list)} allowed foods loaded for AI context.")

        self.system_instruction = """
        You are an AI assistant for a diet app. Your task is to analyze receipt text and extract purchased food items.
        
        CRITICAL RULES:
        1. **Filter by Context**: match the extracted items against the provided 'ALLOWED FOODS LIST'.
           - If an item on the receipt closely matches a food in the list (semantically or by name), include it using the name FROM THE LIST.
           - If an item is NOT in the allowed list, IGNORE IT.
        2. **Ignore Non-Food**: Ignore taxes, totals, discounts, store info, payment details.
        3. **Output Format**: Return a strictly structured JSON with a list of items.
        """

    def extract_text_from_file(self, file_path):
        text = ""
        try:
            # DoS Protection: Check file size (Max 10MB)
            if os.path.getsize(file_path) > 10 * 1024 * 1024:
                print("❌ File too large for OCR")
                return ""

            if file_path.lower().endswith('.pdf'):
                print("  📄 Mode: Digital PDF")
                with pdfplumber.open(file_path) as pdf:
                    if len(pdf.pages) > 20:
                        print("❌ PDF exceeds page limit (20)")
                        return ""
                    for page in pdf.pages:
                        extracted = page.extract_text()
                        if extracted: text += extracted + "\n"
            else:
                print("  📷 Mode: Image OCR")
                with Image.open(file_path) as img:
                    img.verify()
                with Image.open(file_path) as img:
                    Image.MAX_IMAGE_PIXELS = 20000000
                    text = pytesseract.image_to_string(img, lang='ita')
        except UnidentifiedImageError:
            print("[FILE ERROR] Invalid image format")
        except Exception as e:
            print(f"[FILE ERROR] {e}")
        return text

    def scan_receipt(self, file_path):
        print(f"\n--- Receipt Analysis (Gemini Powered): {file_path} ---")
        
        # 1. Extract Raw Text (OCR)
        full_text = self.extract_text_from_file(file_path)
        if not full_text: 
            return []
        
        # 2. Prepare Prompt
        if not self.client:
            print("⚠️ Gemini Client missing. Returning empty.")
            return []

        prompt = f"""
        <allowed_foods_list>
        {self.allowed_foods_str}
        </allowed_foods_list>

        <receipt_text>
        {full_text}
        </receipt_text>
        """

        try:
            model_name = settings.GEMINI_MODEL
            print(f"🤖 Sending to Gemini ({model_name})...")

            # 3. Call Gemini
            response = self.client.models.generate_content(
                model=model_name,
                contents=prompt,
                config=types.GenerateContentConfig(
                    system_instruction=self.system_instruction,
                    response_mime_type="application/json",
                    response_schema=ReceiptAnalysis
                )
            )

            # 4. Parse Response
            found_items = []
            if hasattr(response, 'parsed') and response.parsed:
                # The SDK automatically parses into the TypedDict structure
                data = response.parsed
                # data is expected to be a dict matching ReceiptAnalysis or the object directly
                # Adjusting based on SDK behavior (usually returns a Pydantic model or dict)
                items_list = data.get('items', []) if isinstance(data, dict) else data.items
                
                for item in items_list:
                    # Normalize for Frontend
                    # item might be a dict or object depending on Pydantic/TypedDict handling
                    name = item.get('name') if isinstance(item, dict) else item.name
                    qty = item.get('quantity') if isinstance(item, dict) else item.quantity
                    
                    if name:
                        print(f"  ✅ MATCH: {name}")
                        found_items.append({
                            "name": name,
                            "quantity": 1.0, # Default to 1 for fridge logic, or parse 'qty' if needed
                            "original_scan": name # We don't have the raw line anymore, using name
                        })
            
            print(f"[SUCCESS] Extracted {len(found_items)} items.")
            return found_items

        except Exception as e:
            print(f"⚠️ Gemini Error: {e}")
            return []