"""
Sync RQ task functions for diet parsing.
These run inside the RQ worker process (separate from the FastAPI server).
All operations must be synchronous — no async/await allowed here.
"""
import io
import os

import firebase_admin
from firebase_admin import firestore as fs


def _ensure_firebase():
    """Initialize Firebase inside the worker process if not already done."""
    if not firebase_admin._apps:
        import json
        creds_json = os.environ.get("FIREBASE_CREDENTIALS", "")
        if creds_json:
            creds_dict = json.loads(creds_json)
            cred = firebase_admin.credentials.Certificate(creds_dict)
        else:
            cred = firebase_admin.credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred)


def process_diet_upload(
    file_bytes: bytes,
    file_name: str,
    target_uid: str,
    requester_id: str,
    requester_role: str,
    custom_prompt: str | None,
    fcm_token: str | None,
    set_as_current: bool = True,
) -> dict:
    """
    RQ job: parses a diet PDF and saves the result to Firestore.

    Returns a dict with the parsed diet data on success.
    Raises on failure so RQ marks the job as failed.
    """
    _ensure_firebase()

    from app.services.diet_service import DietParser
    from app.services.notification_service import NotificationService
    from app.core.logging import logger, sanitize_error_message

    diet_parser = DietParser()
    notification_service = NotificationService()

    file_obj = io.BytesIO(file_bytes)

    try:
        raw_data = diet_parser.parse_complex_diet(file_obj, custom_prompt)
    except Exception as e:
        logger.error("rq_diet_parse_error", uid=target_uid, error=sanitize_error_message(e))
        raise

    # Inline conversion (mirrors _convert_to_app_format in the router)
    from app.routers.diet import _convert_to_app_format
    formatted_data = _convert_to_app_format(raw_data)
    dict_data = formatted_data.dict()

    db = firebase_admin.firestore.client()

    diet_payload = {
        "uploadedAt":  fs.SERVER_TIMESTAMP,
        "lastUpdated": fs.SERVER_TIMESTAMP,
        "plan":          dict_data.get("plan"),
        "substitutions": dict_data.get("substitutions"),
        "config":        dict_data.get("config"),
        "activeSwaps":   {},
        "uploadedBy":    requester_id,
        "fileName":      file_name,
    }

    user_diets_ref = db.collection("users").document(target_uid).collection("diets")

    if set_as_current:
        user_diets_ref.document("current").set(diet_payload)

    user_diets_ref.add(diet_payload)

    db.collection("users").document(target_uid).set(
        {
            "last_diet_update": fs.SERVER_TIMESTAMP,
            "allergies": dict_data.get("allergens", []),
        },
        merge=True,
    )

    db.collection("diet_history").add(
        {
            "userId":     target_uid,
            "uploadedAt": fs.SERVER_TIMESTAMP,
            "fileName":   file_name,
            "parsedData": dict_data,
            "uploadedBy": requester_id,
        }
    )

    if fcm_token:
        try:
            notification_service.send_diet_ready(fcm_token)
        except Exception as notify_err:
            logger.warning("rq_diet_notify_failed uid=%s error=%s", target_uid, notify_err)

    logger.info("rq_diet_job_done", uid=target_uid, uploaded_by=requester_id)
    return dict_data
