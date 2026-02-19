"""
Router per gli endpoint di gestione diete.
- Upload dieta (utente e admin)
- Scansione scontrino
"""
import uuid
from typing import Optional, List

import firebase_admin
from fastapi import APIRouter, UploadFile, File, HTTPException, Form, Depends
from fastapi.responses import JSONResponse, StreamingResponse
from fastapi.concurrency import run_in_threadpool
from pydantic import Json
from slowapi import Limiter
from slowapi.util import get_remote_address

from app.core.dependencies import (
    verify_token, verify_professional, get_current_uid,
    heavy_tasks_semaphore, MAX_FILE_SIZE, validate_file_content, validate_extension
)
from app.core.logging import logger, sanitize_error_message
from app.services.diet_service import DietParser
from app.services.receipt_service import ReceiptScanner
from app.services.notification_service import NotificationService
from app.services.normalization import normalize_meal_name, normalize_quantity
from app.models.schemas import DietResponse, DietConfig, Dish, Ingredient, SubstitutionGroup, SubstitutionOption

router = APIRouter(tags=["diet"])

# Services
diet_parser = DietParser()
notification_service = NotificationService()

# MEAL_ORDER rimosso per supportare config dinamica completamente


def _convert_to_app_format(gemini_output) -> DietResponse:
    """Converte l'output Gemini nel formato dell'app."""
    if not gemini_output:
        return DietResponse(plan={}, substitutions={}, config=None)

    app_plan, app_substitutions = {}, {}
    cad_map = {}

    # 1. Mappatura Sostituzioni
    for g in gemini_output.get('tabella_sostituzioni', []):
        if g.get('cad_code', 0) > 0:
            cad_map[g.get('titolo', '').strip().lower()] = g['cad_code']

            clean_options = []
            for o in g.get('opzioni', []):
                raw_qty = o.get('quantita', '')
                clean_qty = normalize_quantity(raw_qty)
                clean_options.append(SubstitutionOption(name=o.get('nome', ''), qty=clean_qty))

            app_substitutions[str(g['cad_code'])] = SubstitutionGroup(
                name=g.get('titolo', ''),
                options=clean_options
            )

    day_map = {
        "lun": "Lunedì", "mar": "Martedì", "mer": "Mercoledì",
        "gio": "Giovedì", "ven": "Venerdì", "sab": "Sabato", "dom": "Domenica"
    }

    # 2. Costruzione Piano
    for day in gemini_output.get('piano_settimanale', []):
        raw_name = day.get('giorno', '').lower().strip()
        day_name = day_map.get(raw_name[:3], raw_name.capitalize())
        app_plan[day_name] = {}

        for meal in day.get('pasti', []):
            m_name = normalize_meal_name(meal.get('tipo_pasto', ''))
            dishes = []

            for d in meal.get('elenco_piatti', []):
                d_name = d.get('nome_piatto') or 'Piatto'
                raw_dish_qty = str(d.get('quantita_totale') or '')
                clean_dish_qty = normalize_quantity(raw_dish_qty)

                clean_ingredients = []
                for i in d.get('ingredienti', []):
                    raw_ing_qty = str(i.get('quantita', ''))
                    clean_ing_qty = normalize_quantity(raw_ing_qty)
                    clean_ingredients.append(Ingredient(name=str(i.get('nome', '')), qty=clean_ing_qty))

                new_dish = Dish(
                    instance_id=str(uuid.uuid4()),
                    name=d_name,
                    qty=clean_dish_qty,
                    cad_code=d.get('cad_code', 0) or cad_map.get(d_name.lower(), 0),
                    is_composed=(d.get('tipo') == 'composto'),
                    ingredients=clean_ingredients
                )
                dishes.append(new_dish)

            if m_name in app_plan[day_name]:
                app_plan[day_name][m_name].extend(dishes)
            else:
                app_plan[day_name][m_name] = dishes

    # Ordina pasti: Rimosso forzatura MEAL_ORDER. Ci fidiamo dell'ordine del parser (cioè del PDF)
    # se l'IA rispetta l'ordine di apparizione, il dizionario lo mantiene (Python 3.7+)

    # 3. Estrazione Config dinamica
    app_config = None
    raw_config = gemini_output.get('config')
    if raw_config:
        # Traduci giorni se necessario
        config_days = []
        for g in raw_config.get('giorni', []):
            g_lower = g.lower().strip()
            config_days.append(day_map.get(g_lower[:3], g.capitalize()))

        # Normalizza pasti
        config_meals = []
        for p in raw_config.get('pasti', []):
            normalized = normalize_meal_name(p)
            if normalized and normalized not in config_meals:
                config_meals.append(normalized)

        # Alimenti rilassabili (lowercase, deduplicated)
        config_relaxable = list(set(
            item.lower().strip()
            for item in raw_config.get('alimenti_rilassabili', [])
            if item and item.strip()
        ))

        app_config = DietConfig(
            days=config_days if config_days else list(app_plan.keys()),
            meals=config_meals, # Rimosso fallback a MEAL_ORDER
            relaxable_foods=config_relaxable
        )

    # 4. Allergeni
    allergens = gemini_output.get('allergeni', [])

    return DietResponse(plan=app_plan, substitutions=app_substitutions, config=app_config, allergens=allergens)


@router.post("/upload-diet", response_model=DietResponse)
async def upload_diet(
    file: UploadFile = File(...),
    fcm_token: Optional[str] = Form(None),
    token: dict = Depends(verify_token)
):
    """Upload dieta PDF per utente self-service."""
    user_id = token['uid']
    user_role = token.get('role', 'user')

    if user_role not in ['independent', 'admin', 'nutritionist']:
        raise HTTPException(
            status_code=403,
            detail="Solo utenti indipendenti, nutrizionisti e admin possono caricare diete."
        )

    if not file.filename.lower().endswith('.pdf'):
        raise HTTPException(status_code=400, detail="Only PDF allowed")

    file_content = await file.read()
    if len(file_content) > MAX_FILE_SIZE:
        raise HTTPException(status_code=413, detail="File troppo grande. Massimo 10MB.")

    if not validate_file_content(file_content, '.pdf'):
        raise HTTPException(status_code=400, detail="Il file non è un PDF valido.")

    await file.seek(0)

    async with heavy_tasks_semaphore:
        try:
            raw_data = await run_in_threadpool(diet_parser.parse_complex_diet, file.file)
            formatted_data = _convert_to_app_format(raw_data)
            dict_data = formatted_data.dict()

            db = firebase_admin.firestore.client()
            user_diets_ref = db.collection('users').document(user_id).collection('diets')

            diet_payload = {
                'uploadedAt': firebase_admin.firestore.SERVER_TIMESTAMP,
                'lastUpdated': firebase_admin.firestore.SERVER_TIMESTAMP,
                'plan': dict_data.get('plan'),
                'substitutions': dict_data.get('substitutions'),
                'config': dict_data.get('config'),  # Config dinamica
                'activeSwaps': {},
                'uploadedBy': 'user_upload',
                'fileName': file.filename
            }

            user_diets_ref.document('current').set(diet_payload)
            user_diets_ref.add(diet_payload)

            # Update user's main doc
            db.collection('users').document(user_id).set({
                'last_diet_update': firebase_admin.firestore.SERVER_TIMESTAMP,
                'allergies': dict_data.get('allergens', [])
            }, merge=True)

            db.collection('diet_history').add({
                'userId': user_id,
                'uploadedAt': firebase_admin.firestore.SERVER_TIMESTAMP,
                'fileName': file.filename,
                'parsedData': dict_data,
                'uploadedBy': user_id
            })

            if fcm_token:
                await run_in_threadpool(notification_service.send_diet_ready, fcm_token)

            return formatted_data

        except Exception as e:
            logger.error("upload_diet_error", error=sanitize_error_message(e))
            raise HTTPException(status_code=500, detail="Errore durante l'elaborazione della dieta.")
        finally:
            await file.close()


@router.post("/upload-diet/{target_uid}", response_model=DietResponse)
async def upload_diet_admin(
    target_uid: str,
    file: UploadFile = File(...),
    fcm_token: Optional[str] = Form(None),
    requester: dict = Depends(verify_professional)
):
    """Upload dieta PDF per un altro utente (admin/nutrizionista)."""
    requester_id = requester['uid']
    requester_role = requester['role']

    if not file.filename.lower().endswith('.pdf'):
        raise HTTPException(status_code=400, detail="Only PDF allowed")

    file_content = await file.read()
    if len(file_content) > MAX_FILE_SIZE:
        raise HTTPException(status_code=413, detail="File troppo grande. Massimo 10MB.")

    if not validate_file_content(file_content, '.pdf'):
        raise HTTPException(status_code=400, detail="Il file non è un PDF valido.")

    await file.seek(0)

    db = firebase_admin.firestore.client()

    # Verifica permessi nutrizionista
    if requester_role == 'nutritionist':
        target_doc = db.collection('users').document(target_uid).get()
        if not target_doc.exists:
            raise HTTPException(status_code=404, detail="User not found")
        data = target_doc.to_dict()
        if data.get('parent_id') != requester_id and data.get('created_by') != requester_id:
            raise HTTPException(status_code=403, detail="Non puoi caricare diete per questo utente")

    try:
        custom_prompt = None
        target_doc = db.collection('users').document(target_uid).get()
        target_data = target_doc.to_dict() if target_doc.exists else {}

        if requester_role == 'nutritionist':
            # Nutrizionista: usa il proprio parser
            requester_doc = db.collection('users').document(requester_id).get()
            if requester_doc.exists:
                custom_prompt = requester_doc.to_dict().get('custom_parser_prompt')
        else:
            # Admin: cerca il parser appropriato in base al target
            parent_id = target_data.get('parent_id')
            if parent_id:
                # Target ha un parent (nutrizionista) -> usa parser del parent
                parent_doc = db.collection('users').document(parent_id).get()
                if parent_doc.exists:
                    custom_prompt = parent_doc.to_dict().get('custom_parser_prompt')
            else:
                # Target è indipendente/nutrizionista/admin -> usa il suo parser
                custom_prompt = target_data.get('custom_parser_prompt')

        raw_data = await run_in_threadpool(diet_parser.parse_complex_diet, file.file, custom_prompt)
        formatted_data = _convert_to_app_format(raw_data)
        dict_data = formatted_data.dict()

        db.collection('diet_history').add({
            'userId': target_uid,
            'uploadedAt': firebase_admin.firestore.SERVER_TIMESTAMP,
            'fileName': file.filename,
            'parsedData': dict_data,
            'uploadedBy': requester_id
        })

        db.collection('users').document(target_uid).collection('diets').add({
            'uploadedAt': firebase_admin.firestore.SERVER_TIMESTAMP,
            'plan': dict_data.get('plan'),
            'substitutions': dict_data.get('substitutions'),
            'config': dict_data.get('config'),  # Config dinamica
            'uploadedBy': 'nutritionist'
        })

        # Update user's main doc for "expiring diet" alerts AND allergens
        db.collection('users').document(target_uid).set({
            'last_diet_update': firebase_admin.firestore.SERVER_TIMESTAMP,
            'allergies': dict_data.get('allergens', [])
        }, merge=True)

        if fcm_token:
            await run_in_threadpool(notification_service.send_diet_ready, fcm_token)

        return formatted_data

    except Exception as e:
        logger.error("admin_upload_diet_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante l'elaborazione della dieta.")
    finally:
        await file.close()


@router.post("/scan-receipt")
async def scan_receipt(
    file: UploadFile = File(...),
    allowed_foods: Json[List[str]] = Form(...),
    user_id: str = Depends(get_current_uid)
):
    """Scansiona uno scontrino e trova gli alimenti."""
    ext = validate_extension(file.filename or "")

    file_content = await file.read()
    if len(file_content) > MAX_FILE_SIZE:
        raise HTTPException(status_code=413, detail="File troppo grande. Massimo 10MB.")

    if not validate_file_content(file_content, ext):
        raise HTTPException(status_code=400, detail="Il file non è un'immagine valida.")

    await file.seek(0)

    if len(allowed_foods) > 5000:
        raise HTTPException(status_code=400, detail="Lista alimenti troppo grande.")

    try:
        current_scanner = ReceiptScanner(allowed_foods_list=allowed_foods)

        async with heavy_tasks_semaphore:
            found_items = await run_in_threadpool(current_scanner.scan_receipt, file.file)

        return JSONResponse(content=found_items)
    except Exception as e:
        logger.error("scan_receipt_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante la scansione dello scontrino")
    finally:
        await file.close()


@router.get("/export-diet-pdf")
async def export_diet_pdf(uid: str = Depends(get_current_uid)):
    """
    Genera e scarica un PDF della dieta corrente dell'utente.
    Richiede autenticazione. Il PDF include il piano settimanale completo.
    """
    try:
        db = firebase_admin.firestore.client()
        diet_doc = db.collection('users').document(uid).collection('diets').document('current').get()

        if not diet_doc.exists:
            raise HTTPException(status_code=404, detail="Nessuna dieta trovata.")

        diet_data = diet_doc.to_dict() or {}
        plan = diet_data.get('plan', {})

        pdf_bytes = await run_in_threadpool(_generate_diet_pdf, plan, uid)

        return StreamingResponse(
            iter([pdf_bytes]),
            media_type="application/pdf",
            headers={"Content-Disposition": 'attachment; filename="dieta-kybo.pdf"'}
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error("export_diet_pdf_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante l'esportazione della dieta.")


def _generate_diet_pdf(plan: dict, uid: str) -> bytes:
    """Genera un PDF della dieta settimanale."""
    from fpdf import FPDF

    pdf = FPDF()
    pdf.set_auto_page_break(auto=True, margin=15)
    pdf.add_page()

    # Header
    pdf.set_font("Helvetica", "B", size=20)
    pdf.set_text_color(46, 125, 50)  # Kybo green
    pdf.cell(0, 12, "Piano Alimentare - Kybo", ln=True, align="C")
    pdf.set_font("Helvetica", size=10)
    pdf.set_text_color(100, 100, 100)
    from datetime import datetime
    pdf.cell(0, 6, f"Esportato il {datetime.now().strftime('%d/%m/%Y')}", ln=True, align="C")
    pdf.ln(8)

    if not plan:
        pdf.set_font("Helvetica", size=12)
        pdf.set_text_color(0, 0, 0)
        pdf.cell(0, 10, "Nessun piano alimentare disponibile.", ln=True)
        return bytes(pdf.output())

    for day, meals in plan.items():
        if not isinstance(meals, dict):
            continue

        # Day header
        pdf.set_font("Helvetica", "B", size=14)
        pdf.set_text_color(46, 125, 50)
        pdf.cell(0, 8, day.upper(), ln=True)
        pdf.set_draw_color(46, 125, 50)
        pdf.line(10, pdf.get_y(), 200, pdf.get_y())
        pdf.ln(4)

        for meal_name, dishes in meals.items():
            if not isinstance(dishes, list) or not dishes:
                continue

            # Meal name
            pdf.set_font("Helvetica", "B", size=11)
            pdf.set_text_color(50, 50, 50)
            pdf.cell(0, 7, f"  {meal_name}", ln=True)

            for dish in dishes:
                if not isinstance(dish, dict):
                    continue
                name = dish.get('name', '')
                qty = dish.get('qty', '')
                if name:
                    pdf.set_font("Helvetica", size=10)
                    pdf.set_text_color(80, 80, 80)
                    qty_str = f" ({qty})" if qty and qty != 'N/A' else ""
                    pdf.cell(10)  # indent
                    pdf.cell(0, 6, f"- {name}{qty_str}", ln=True)

            pdf.ln(3)

        pdf.ln(5)

    return bytes(pdf.output())


@router.post("/import-diet")
async def import_diet_from_file(
    file: UploadFile = File(...),
    uid: str = Depends(get_current_uid)
):
    """
    Importa una dieta da un file CSV (formato MyFitnessPal/Yazio export).
    Converte in formato Kybo e salva come dieta corrente.

    Formato CSV atteso (MyFitnessPal):
      Date,Meal,Food Name,Quantity,Unit,Calories,...

    Formato CSV alternativo (generico):
      Giorno,Pasto,Alimento,Quantità,Unità
    """
    if not file.filename:
        raise HTTPException(status_code=400, detail="Nome file mancante.")

    ext = file.filename.rsplit('.', 1)[-1].lower()
    if ext not in ('csv', 'txt', 'json'):
        raise HTTPException(status_code=400, detail="Formato non supportato. Usa CSV, TXT o JSON.")

    content = await file.read()
    if len(content) > 5 * 1024 * 1024:  # 5MB max
        raise HTTPException(status_code=413, detail="File troppo grande. Massimo 5MB.")

    try:
        text = content.decode('utf-8', errors='replace')
        plan = await run_in_threadpool(_parse_import_file, text, ext)

        if not plan:
            raise HTTPException(status_code=422, detail="Impossibile leggere il file. Verifica il formato.")

        db = firebase_admin.firestore.client()
        db.collection('users').document(uid).collection('diets').document('current').set({
            'plan': plan,
            'source': 'import',
            'imported_at': firebase_admin.firestore.SERVER_TIMESTAMP,
            'original_filename': file.filename,
        }, merge=True)

        days = len(plan)
        meals = sum(len(v) for v in plan.values() if isinstance(v, dict))
        logger.info("diet_imported", uid=uid, days=days, meals=meals)
        return {"message": f"Dieta importata con successo: {days} giorni, {meals} pasti."}

    except HTTPException:
        raise
    except Exception as e:
        logger.error("import_diet_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore durante l'importazione.")


def _parse_import_file(text: str, ext: str) -> dict:
    """
    Parsa un file di import e ritorna un piano dieta nel formato Kybo.
    Supporta CSV (MyFitnessPal/Yazio/generico) e JSON.
    """
    import csv
    import io
    import json as json_mod

    plan: dict = {}

    if ext == 'json':
        try:
            data = json_mod.loads(text)
            # Se è già in formato Kybo (dict di giorni)
            if isinstance(data, dict) and all(isinstance(v, dict) for v in data.values()):
                return data
        except Exception:
            return {}

    # CSV parsing
    reader = csv.DictReader(io.StringIO(text))
    if reader.fieldnames is None:
        return {}

    # Detect format
    fieldnames_lower = [f.lower().strip() for f in reader.fieldnames]

    # MyFitnessPal format: Date, Meal, Food Name, Quantity, Unit
    is_mfp = 'date' in fieldnames_lower and 'meal' in fieldnames_lower and 'food name' in fieldnames_lower

    italian_days = {
        'monday': 'Lunedì', 'tuesday': 'Martedì', 'wednesday': 'Mercoledì',
        'thursday': 'Giovedì', 'friday': 'Venerdì', 'saturday': 'Sabato', 'sunday': 'Domenica',
    }

    from datetime import datetime

    for row in reader:
        if is_mfp:
            # Try to get weekday from date
            raw_date = row.get('Date', '') or row.get('date', '')
            meal = row.get('Meal', '') or row.get('meal', '')
            food = row.get('Food Name', '') or row.get('food name', '')
            qty = row.get('Quantity', '') or row.get('quantity', '1')
            unit = row.get('Unit', '') or row.get('unit', '')

            if not food or not meal:
                continue

            # Derive day name from date
            day = 'Lunedì'
            try:
                for fmt in ('%Y-%m-%d', '%m/%d/%Y', '%d/%m/%Y'):
                    try:
                        dt = datetime.strptime(raw_date.strip(), fmt)
                        wd = dt.strftime('%A').lower()
                        day = italian_days.get(wd, f"Giorno {raw_date}")
                        break
                    except ValueError:
                        continue
            except Exception:
                pass
        else:
            # Generic Italian format: Giorno, Pasto, Alimento, Quantità, Unità
            day = row.get('Giorno', '') or row.get('giorno', '') or row.get('Day', 'Lunedì')
            meal = row.get('Pasto', '') or row.get('pasto', '') or row.get('Meal', '')
            food = row.get('Alimento', '') or row.get('alimento', '') or row.get('Food', '')
            qty = row.get('Quantità', '') or row.get('quantita', '') or row.get('Quantity', '1')
            unit = row.get('Unità', '') or row.get('unita', '') or row.get('Unit', '')

            if not food or not meal:
                continue

        qty_str = f"{qty} {unit}".strip() if unit else str(qty)
        dish = {'name': food.strip(), 'qty': qty_str, 'cadCode': 0, 'isComposed': False, 'ingredients': [], 'instance_id': ''}

        plan.setdefault(day, {}).setdefault(meal, []).append(dish)

    return plan
