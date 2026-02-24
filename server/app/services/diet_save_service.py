"""
Funzione condivisa per salvare una dieta parsata in Firestore.
Usata da routers/diet.py (sync fallback) e tasks/diet_tasks.py (RQ worker).
save_diet_to_firestore: scrive users/{uid}/diets/current (opzionale),
  users/{uid}/diets/{auto}, aggiorna users/{uid}, e aggiunge a diet_history.
"""
import firebase_admin
from firebase_admin import firestore as fs


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
        "plan": dict_data.get("plan"),
        "substitutions": dict_data.get("substitutions"),
        "config": dict_data.get("config"),
        "activeSwaps": {},
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
