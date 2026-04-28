"""
Router per i template di dieta riutilizzabili (creati da nutrizionisti/admin).
Pattern speculare ai workout templates: il template è un piano dieta parsato
e salvato in Firestore senza target user. L'endpoint clone-and-assign copia
il payload nel sotto-collection diets dell'utente di destinazione.

Modello Firestore: diet_templates/{auto_id}
  {
    name: str,
    description: str,
    parsed_data: { plan, substitutions, config, allergens, ... },
    file_name: str,
    created_by: str (uid),
    created_at: server_ts,
    updated_at: server_ts,
  }

Endpoints:
  GET    /diet-templates                              → lista template del professionista
  POST   /diet-templates                              → upload PDF + parse + salva come template
  DELETE /diet-templates/{template_id}                → elimina template
  POST   /diet-templates/{template_id}/clone-and-assign/{target_uid} → clona e assegna
"""
from typing import Optional

import firebase_admin
from firebase_admin import firestore
from fastapi import APIRouter, UploadFile, File, HTTPException, Form, Depends, Request
from fastapi.concurrency import run_in_threadpool

from app.core.dependencies import (
    verify_professional, validate_file_content
)
from app.core.limiter import limiter
from app.core.logging import logger, sanitize_error_message
from app.services.app_config_service import get_app_config
from app.services.diet_save_service import save_diet_to_firestore
from app.services.diet_service import DietParser

router = APIRouter(tags=["diet-templates"])

diet_parser = DietParser()


@router.get("/diet-templates")
@limiter.limit("60/minute")
async def list_diet_templates(
    request: Request,
    requester: dict = Depends(verify_professional),
):
    """Lista i template di dieta del professionista (admin vede tutti)."""
    try:
        db = firebase_admin.firestore.client()
        col = db.collection('diet_templates')
        if requester['role'] == 'admin':
            docs = col.order_by('created_at', direction=firestore.Query.DESCENDING).limit(200).stream()
        else:
            docs = col.where('created_by', '==', requester['uid']).order_by(
                'created_at', direction=firestore.Query.DESCENDING
            ).limit(200).stream()

        templates = []
        for d in docs:
            data = d.to_dict()
            data['id'] = d.id
            for ts in ('created_at', 'updated_at'):
                if data.get(ts):
                    try:
                        data[ts] = data[ts].isoformat()
                    except Exception:
                        pass
            # Non inviamo parsed_data nel listing per risparmiare bandwidth.
            data.pop('parsed_data', None)
            templates.append(data)

        return {"templates": templates}
    except Exception as e:
        logger.error("list_diet_templates_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore caricamento template diete.")


@router.post("/diet-templates")
@limiter.limit("10/hour")
async def create_diet_template(
    request: Request,
    file: UploadFile = File(...),
    name: str = Form(...),
    description: Optional[str] = Form(None),
    requester: dict = Depends(verify_professional),
):
    """Upload PDF + parse + salva come template riutilizzabile (no target)."""
    if not file.filename or not file.filename.lower().endswith('.pdf'):
        raise HTTPException(status_code=400, detail="Solo PDF consentito.")
    if not name or len(name.strip()) == 0:
        raise HTTPException(status_code=400, detail="Nome template obbligatorio.")
    if len(name) > 200:
        raise HTTPException(status_code=400, detail="Nome troppo lungo (max 200).")

    file_content = await file.read()
    max_mb = get_app_config().get("max_file_size_mb", 10)
    if len(file_content) > max_mb * 1024 * 1024:
        raise HTTPException(status_code=413, detail="File troppo grande.")
    if not validate_file_content(file_content, '.pdf'):
        raise HTTPException(status_code=400, detail="Il file non è un PDF valido.")

    await file.seek(0)

    try:
        # Riutilizziamo il parser + converter del modulo diet.py per coerenza
        # con il flusso normale di upload (così i template hanno la stessa
        # struttura dei dati che si vedrebbe in un upload diretto).
        from app.routers.diet import _convert_to_app_format
        raw_data = await run_in_threadpool(diet_parser.parse_complex_diet, file.file, None)
        formatted = _convert_to_app_format(raw_data)
        dict_data = formatted.dict()

        db = firebase_admin.firestore.client()
        ref = db.collection('diet_templates').document()
        ref.set({
            'name': name.strip(),
            'description': (description or '').strip(),
            'parsed_data': dict_data,
            'file_name': file.filename,
            'created_by': requester['uid'],
            'created_at': firestore.SERVER_TIMESTAMP,
            'updated_at': firestore.SERVER_TIMESTAMP,
        })

        logger.info("diet_template_created", id=ref.id, by=requester['uid'])
        return {"id": ref.id, "name": name, "message": "Template creato"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("create_diet_template_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore parsing dieta.")
    finally:
        await file.close()


@router.delete("/diet-templates/{template_id}")
@limiter.limit("30/hour")
async def delete_diet_template(
    request: Request,
    template_id: str,
    requester: dict = Depends(verify_professional),
):
    """Elimina un template di dieta."""
    try:
        db = firebase_admin.firestore.client()
        ref = db.collection('diet_templates').document(template_id)
        snap = ref.get()
        if not snap.exists:
            raise HTTPException(status_code=404, detail="Template non trovato.")
        data = snap.to_dict()
        if data.get('created_by') != requester['uid'] and requester['role'] != 'admin':
            raise HTTPException(status_code=403, detail="Non puoi eliminare questo template.")
        ref.delete()
        logger.info("diet_template_deleted", id=template_id, by=requester['uid'])
        return {"message": "Template eliminato"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("delete_diet_template_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore eliminazione template.")


@router.post("/diet-templates/{template_id}/clone-and-assign/{target_uid}")
@limiter.limit("30/hour")
async def clone_and_assign_diet_template(
    request: Request,
    template_id: str,
    target_uid: str,
    requester: dict = Depends(verify_professional),
):
    """Clona un template e crea una dieta corrente per l'utente target.
    Il template originale resta intatto."""
    try:
        db = firebase_admin.firestore.client()

        # Carica template
        ref = db.collection('diet_templates').document(template_id)
        snap = ref.get()
        if not snap.exists:
            raise HTTPException(status_code=404, detail="Template non trovato.")
        data = snap.to_dict()
        if data.get('created_by') != requester['uid'] and requester['role'] != 'admin':
            raise HTTPException(status_code=403, detail="Non puoi usare questo template.")

        # Verifica target gestito dal requester
        target_doc = db.collection('users').document(target_uid).get()
        if not target_doc.exists:
            raise HTTPException(status_code=404, detail="Utente target non trovato.")
        if requester['role'] != 'admin':
            t = target_doc.to_dict()
            if (t.get('parent_id') != requester['uid']
                    and t.get('created_by') != requester['uid']
                    and t.get('nutritionist_id') != requester['uid']):
                raise HTTPException(status_code=403, detail="Non puoi assegnare diete a questo utente.")

        parsed = data.get('parsed_data') or {}
        file_name = data.get('file_name', f"template_{template_id}.pdf")

        # Riutilizza la funzione condivisa per persistere la dieta corrente
        # + history. Stessa funzione di upload-diet, così il template clonato
        # appare come una qualsiasi altra dieta lato client.
        await run_in_threadpool(
            save_diet_to_firestore,
            db, target_uid, requester['uid'], file_name, parsed, True,
        )

        logger.info(
            "diet_template_cloned",
            template=template_id, target=target_uid, by=requester['uid'],
        )
        return {"message": "Template clonato e assegnato"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("clone_diet_template_error", error=sanitize_error_message(e))
        raise HTTPException(status_code=500, detail="Errore clone template.")
