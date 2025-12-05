from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
import shutil
import os
import json

# Import moduli locali
from diet_parser import DietParser
from receipt_scanner import ReceiptScanner

app = FastAPI()

# Percorsi file
DIET_PDF_PATH = "temp_dieta.pdf"
RECEIPT_PATH = "temp_scontrino"
DIET_JSON_PATH = "dieta.json"

@app.get("/")
def read_root():
    return {"status": "Server Attivo (Gemini Edition)! 🚀", "message": "Usa /upload-diet"}

@app.post("/upload-diet")
async def upload_diet(file: UploadFile = File(...)):
    try:
        print(f"📥 Ricevuto file dieta: {file.filename}")
        
        with open(DIET_PDF_PATH, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
            
        # 1. Inizializza Parser
        parser = DietParser() 
        
        # 2. Ottieni i dati (Ora restituisce direttamente una lista/dict, non un modello Pydantic)
        final_data = parser.parse_complex_diet(DIET_PDF_PATH)
        
        # 3. Salva su disco (per debug o uso futuro)
        # Nota: final_data è già un oggetto Python, possiamo dumpare direttamente
        with open(DIET_JSON_PATH, "w", encoding="utf-8") as f:
            json.dump(final_data, f, indent=2, ensure_ascii=False)
            
        print("✅ Dieta elaborata da Gemini e salvata.")
        
        # 4. Restituisci al frontend
        # Avvolgiamo in un oggetto "plan" per compatibilità con il frontend se necessario
        # Se il tuo frontend si aspetta direttamente la lista dei giorni, usa: return JSONResponse(content=final_data)
        # Se il frontend si aspetta {"plan": ...}, usa questo:
        return JSONResponse(content={"plan": final_data})

    except Exception as e:
        print(f"❌ Errore: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/scan-receipt")
async def scan_receipt(file: UploadFile = File(...)):
    try:
        print(f"📥 Ricevuto scontrino: {file.filename}")
        if not os.path.exists(DIET_JSON_PATH):
            raise HTTPException(status_code=400, detail="Carica prima la dieta!")

        ext = os.path.splitext(file.filename)[1]
        temp_filename = f"{RECEIPT_PATH}{ext}"
        
        with open(temp_filename, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        scanner = ReceiptScanner(DIET_JSON_PATH)
        found_items = scanner.scan_receipt(temp_filename)
        
        print(f"✅ Scontrino analizzato: trovati {len(found_items)} prodotti.")
        return JSONResponse(content=found_items)

    except Exception as e:
        print(f"❌ Errore: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    print("🌐 Avvio server su http://0.0.0.0:8000")
    uvicorn.run(app, host="0.0.0.0", port=8000)