"""
Funzione condivisa per salvare una dieta parsata in Firestore.
Usata da routers/diet.py (sync fallback), tasks/diet_tasks.py (RQ worker) e
routers/diet_templates.py (clone-and-assign).
save_diet_to_firestore: scrive users/{uid}/diets/current (opzionale),
  users/{uid}/diets/{auto}, aggiorna users/{uid}, e aggiunge a diet_history.

[FIX SRV-DIET1] Scrive plan/substitutions/activeSwaps cifrati nello stesso
formato del client (encryption_service.dart), invece che in chiaro: prima
di questa fix, una dieta caricata da un nutrizionista restava in chiaro
finché il client non la toccava (swap/modifica), che la ri-salvava cifrata
e CANCELLAVA il campo `plan` — rompendo export-diet-pdf/suggestions/
analytics che leggevano solo `plan`. Ora entrambi i lati scrivono lo stesso
formato fin dall'inizio; `config` resta in chiaro come già fa il client
(dati non-PII: nomi giorni/pasti).
"""
from firebase_admin import firestore as fs

from app.services.diet_crypto import encrypt_field


def save_diet_to_firestore(
    db,
    target_uid: str,
    requester_id: str,
    file_name: str,
    dict_data: dict,
    set_as_current: bool = True,
) -> None:
    diet_payload = {
        "uploadedAt": fs.SERVER_TIMESTAMP,
        "lastUpdated": fs.SERVER_TIMESTAMP,
        "plan_encrypted": encrypt_field(dict_data.get("plan") or {}, target_uid),
        "substitutions_encrypted": encrypt_field(dict_data.get("substitutions") or {}, target_uid),
        "activeSwaps_encrypted": encrypt_field({}, target_uid),
        "encrypted": True,
        "config": dict_data.get("config"),
        "uploadedBy": requester_id,
        "fileName": file_name,
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
            "userId": target_uid,
            "uploadedAt": fs.SERVER_TIMESTAMP,
            "fileName": file_name,
            "parsedData": dict_data,
            "uploadedBy": requester_id,
        }
    )
