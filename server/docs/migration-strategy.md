# Kybo — Firestore Migration Strategy

**Versione documento:** 1.0
**Data:** 2026-02-25
**Autore:** Team Kybo

---

## 1. Filosofia

Firestore e' un database NoSQL schema-less: non esistono colonne obbligatorie,
ALTER TABLE o versioni di schema a livello di database. Questo comporta che le
"migrazioni" in Kybo non siano eseguite a livello di storage, ma a livello di
**logica applicativa**.

Principi guida:

- **Backward compatible first**: ogni modifica deve poter essere letta sia dal
  codice vecchio che da quello nuovo per un periodo di transizione.
- **Additive by default**: aggiungere campi e' sempre sicuro; rimuoverli
  richiede un periodo di deprecazione.
- **Explicit versioning**: i documenti critici portano un campo `_schema_version`
  che permette al codice di applicare la lettura corretta in base alla versione.
- **No downtime**: le migrazioni non richiedono fermi del server se seguono
  questo pattern.

---

## 2. Tipi di migrazione

### 2.1 Additive (aggiunta campi nuovi)

Il tipo piu' sicuro. Si aggiunge un campo nuovo; i documenti vecchi non ce
l'avranno, ma il codice legge con fallback.

**Esempio**: aggiungere `custom_parser_prompt` a `users/{uid}`.

```python
# Lettura con fallback sicuro
user_data = doc.to_dict()
custom_prompt = user_data.get("custom_parser_prompt", None)
```

**Rischio**: basso. Nessuna migrazione batch necessaria se il fallback e'
implementato correttamente.

### 2.2 Breaking (campo rinominato o rimosso)

Il tipo piu' pericoloso. Richiede una migrazione batch prima di rimuovere il
vecchio campo.

**Pattern consigliato (three-phase rename):**

- **Fase 1** — Deploy codice che scrive sia il vecchio che il nuovo campo;
  legge il nuovo con fallback sul vecchio.
- **Fase 2** — Eseguire lo script di migrazione batch (tutti i doc aggiornati).
- **Fase 3** — Deploy codice che legge solo il nuovo campo; rimuove la scrittura
  del vecchio. Dopo stabilizzazione, rimuovere il vecchio campo con cleanup
  script.

### 2.3 Data transform (trasformazione valori)

Campo che esiste ma deve cambiare formato (es. timestamp stringa → Firestore
Timestamp, array → mappa, ecc.).

Richiedono sempre uno script batch e una fase di compatibilita' doppia.

---

## 3. Pattern consigliato: schema versioning

I documenti nelle collezioni critiche (`users`, `diets`) includono un campo
`_schema_version` (intero). Il codice legge questo campo e applica il parsing
appropriato.

```python
# In app/services/user_service.py (esempio)
def parse_user_doc(doc_data: dict) -> dict:
    version = doc_data.get("_schema_version", 1)

    if version == 1:
        # Schema originale: nessun campo custom_prompt
        return {
            "uid":           doc_data.get("uid"),
            "email":         doc_data.get("email"),
            "role":          doc_data.get("role", "client"),
            "parent_id":     doc_data.get("parent_id"),
            "custom_prompt": None,  # fallback per schema v1
        }

    if version >= 2:
        # Schema v2: aggiunto custom_parser_prompt
        return {
            "uid":           doc_data.get("uid"),
            "email":         doc_data.get("email"),
            "role":          doc_data.get("role", "client"),
            "parent_id":     doc_data.get("parent_id"),
            "custom_prompt": doc_data.get("custom_parser_prompt"),
        }

    raise ValueError(f"Schema version {version} non supportata")
```

**Aggiornamento versione durante write:**

```python
# Quando si scrive/aggiorna un documento, portarlo alla versione corrente
CURRENT_SCHEMA_VERSION = 2

db.collection("users").document(uid).set({
    ...dati,
    "_schema_version": CURRENT_SCHEMA_VERSION,
}, merge=True)
```

---

## 4. Script di migrazione (esempio)

Script Python per batch update di tutti i documenti `users` alla versione 2
dello schema (aggiunta campo `custom_parser_prompt` con valore default `None`).

```python
#!/usr/bin/env python3
"""
Migration: users schema v1 → v2
Aggiunge campo custom_parser_prompt (default None) e imposta _schema_version=2.

Utilizzo:
    python server/migrations/migrate_users_v1_to_v2.py --dry-run
    python server/migrations/migrate_users_v1_to_v2.py --execute

Prerequisiti:
    export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccountKey.json
    pip install firebase-admin
"""

import argparse
import time
import firebase_admin
from firebase_admin import credentials, firestore

BATCH_SIZE    = 500   # Firestore max 500 write per batch
TARGET_VERSION = 2
DRY_RUN       = True  # default sicuro: dry run


def migrate(dry_run: bool):
    if not firebase_admin._apps:
        cred = credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred)

    db = firestore.client()

    users_ref  = db.collection("users")
    total      = 0
    migrated   = 0
    skipped    = 0
    errors     = 0
    batch      = db.batch()
    batch_count = 0

    print(f"Avvio migrazione users v1 → v{TARGET_VERSION} (dry_run={dry_run})")
    print("-" * 60)

    for doc in users_ref.stream():
        total += 1
        data    = doc.to_dict()
        version = data.get("_schema_version", 1)

        if version >= TARGET_VERSION:
            skipped += 1
            continue

        try:
            update_payload = {
                "_schema_version":     TARGET_VERSION,
                "custom_parser_prompt": data.get("custom_parser_prompt", None),
            }

            if dry_run:
                print(f"[DRY RUN] Migrerei {doc.id}: {update_payload}")
                migrated += 1
            else:
                batch.update(doc.reference, update_payload)
                batch_count += 1
                migrated    += 1

                # Commit ogni BATCH_SIZE documenti
                if batch_count >= BATCH_SIZE:
                    batch.commit()
                    print(f"  Batch committato ({batch_count} documenti)...")
                    batch       = db.batch()
                    batch_count = 0
                    time.sleep(0.5)  # throttle per non stressare Firestore

        except Exception as e:
            errors += 1
            print(f"[ERRORE] Documento {doc.id}: {e}")

    # Commit eventuale batch finale
    if not dry_run and batch_count > 0:
        batch.commit()
        print(f"  Batch finale committato ({batch_count} documenti).")

    print("-" * 60)
    print(f"Risultato: totale={total}, migrati={migrated}, saltati={skipped}, errori={errors}")

    if errors > 0:
        print(f"ATTENZIONE: {errors} errori. Controllare i log e ripetere.")
        exit(1)
    else:
        print("Migrazione completata con successo.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true", default=True)
    parser.add_argument("--execute", action="store_true", default=False)
    args = parser.parse_args()

    dry_run = not args.execute
    migrate(dry_run=dry_run)
```

**Note sullo script:**

- Lanciare sempre con `--dry-run` prima di `--execute`.
- Il batch da 500 e' il massimo supportato da Firestore in un singolo commit.
- Il `time.sleep(0.5)` tra batch evita di saturare le quote Firestore.
- Aggiungere lo script in `server/migrations/` con naming
  `migrate_{collection}_{from}_{to}.py`.

---

## 5. Rollback

### 5.1 Rollback codice

Se la nuova versione del backend ha un bug critico:

1. Fare rollback del deploy su Render (Previous Deploy → Redeploy).
2. Il codice vecchio legge il campo `_schema_version` e usa il path corretto.
3. Se la migrazione batch e' gia' avvenuta ma il codice vecchio non capisce
   la v2, serve uno script di rollback dati (inverso della migrazione).

### 5.2 Backup pre-migrazione con Firestore Export

Eseguire sempre un export prima di lanciare script di migrazione batch:

```bash
# Richiede gcloud CLI autenticato con il service account Kybo
gcloud firestore export gs://<BACKUP_BUCKET>/migrations/pre-v2-$(date +%Y%m%d)

# Restore in caso di emergenza (crea un nuovo progetto Firebase o sovrascrive)
gcloud firestore import gs://<BACKUP_BUCKET>/migrations/pre-v2-20260225
```

**Costo**: Firestore Export usa Cloud Storage. Stimare ~0.02$/GB per i backup.

### 5.3 Script di rollback dati

Ogni migration script deve avere il suo inverse. Convenzione:

```
server/migrations/migrate_users_v1_to_v2.py   → migrazione
server/migrations/rollback_users_v2_to_v1.py  → rollback
```

---

## 6. Checklist migrazione

### Prima della migrazione

- [ ] Documento di migrazione scritto (cosa cambia, perche', impatto)
- [ ] Script di migrazione testato su database di sviluppo
- [ ] Script di rollback scritto e testato
- [ ] Backup Firestore Export eseguito e verificato
- [ ] Codice applicativo aggiornato con fallback per il periodo di transizione
- [ ] Deploy del nuovo codice in staging e smoke test passati
- [ ] Finestra di manutenzione concordata con il team (se breaking)

### Durante la migrazione

- [ ] Monitorare Sentry per nuovi errori durante lo script
- [ ] Controllare le quote Firestore (Firebase Console > Usage)
- [ ] Tenere aperto un canale di comunicazione con il team
- [ ] Non interrompere lo script a meta' — completare o rollback

### Dopo la migrazione

- [ ] Verificare che i dati migrati siano corretti (campione manuale)
- [ ] Smoke test del backend
- [ ] Smoke test del client mobile (app critica: diete utenti)
- [ ] Aggiornare la tabella "Migrazioni effettuate" in questo documento
- [ ] Eliminare script di migrazione temporanei dopo periodo di stabilizzazione

---

## 7. Migrazioni effettuate

Questa tabella va aggiornata dopo ogni migrazione in produzione.

| Versione | Data       | Collezione     | Descrizione                            | Script                              |
|----------|------------|----------------|----------------------------------------|-------------------------------------|
| —        | —          | —              | *Nessuna migrazione effettuata ancora* | —                                   |

---

## 8. Riferimenti

- [Firestore Data Export](https://firebase.google.com/docs/firestore/manage-data/export-import)
- [Firestore Batch Writes](https://firebase.google.com/docs/firestore/manage-data/transactions#batched-writes)
- [firebase-admin Python SDK](https://firebase.google.com/docs/reference/admin/python)
- Schema attuale collezioni: vedere `CLAUDE.md` sezione "Firestore Collections"
