"""
Router per gli endpoint di gestione diete.
- Upload dieta (utente e admin)
- Scansione scontrino
"""
import uuid
from typing import Optional, List

import firebase_admin
from fastapi import APIRouter, UploadFile, File, HTTPException, Form, Depends, Request
from fastapi.responses import JSONResponse
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
from app.models.schemas import DietResponse, Dish, Ingredient, SubstitutionGroup, SubstitutionOption

router = APIRouter(tags=["diet"])

# Services
diet_parser = DietParser()
notification_service = NotificationService()

MEAL_ORDER = [
    "Colazione", "Seconda Colazione", "Spuntino", "Pranzo",
    "Merenda", "Cena", "Spuntino Serale", "Nell'Arco Della Giornata"
]


def _convert_to_app_format(gemini_output) -> DietResponse:
    """Converte l'output Gemini nel formato dell'app."""
    if not gemini_output:
        return DietResponse(plan={}, substitutions={})

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

    # Ordina pasti
    for d, meals in app_plan.items():
        app_plan[d] = {k: meals[k] for k in MEAL_ORDER if k in meals}
        for k in meals:
            if k not in app_plan[d]:
                app_plan[d][k] = meals[k]

    return DietResponse(plan=app_plan, substitutions=app_substitutions)


@router.post("/upload-diet", response_model=DietResponse)
async def upload_diet(
    request: Request,
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
                'activeSwaps': {},
                'uploadedBy': 'user_upload',
                'fileName': file.filename
            }

            user_diets_ref.document('current').set(diet_payload)
            user_diets_ref.add(diet_payload)

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
    request: Request,
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
            'uploadedBy': 'nutritionist'
        })

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
    request: Request,
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
