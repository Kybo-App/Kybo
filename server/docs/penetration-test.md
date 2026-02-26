# Kybo — Penetration Test Report (OWASP Top 10 2021)

**Versione documento:** 1.0
**Data:** 2026-02-25
**Metodologia:** OWASP Top 10 2021 — analisi statica + revisione architetturale
**Scope:** Backend FastAPI (`server/`) + Firestore rules + client Flutter

> Questo documento e' una valutazione di sicurezza interna basata su revisione
> del codice sorgente (SAST informale) e analisi dell'architettura. Non
> sostituisce un penetration test black-box condotto da un team esterno.

---

## Riepilogo esecutivo

| ID   | Voce OWASP                              | Status          |
|------|-----------------------------------------|-----------------|
| A01  | Broken Access Control                   | Mitigato        |
| A02  | Cryptographic Failures                  | Mitigato        |
| A03  | Injection                               | Mitigato        |
| A04  | Insecure Design                         | Mitigato        |
| A05  | Security Misconfiguration               | Mitigato        |
| A06  | Vulnerable and Outdated Components      | Parzialmente    |
| A07  | Identification & Authentication Failures| Mitigato        |
| A08  | Software & Data Integrity Failures      | Parzialmente    |
| A09  | Security Logging & Monitoring Failures  | Mitigato        |
| A10  | Server-Side Request Forgery (SSRF)      | Mitigato        |

**Findings aperti:** 3 azioni richieste (vedere sezione finale).

---

## A01 — Broken Access Control

**Descrizione del rischio**
Gli utenti accedono a risorse o eseguono operazioni al di fuori dei propri
permessi (es. un client che legge dati di altri utenti, o un utente non-admin
che chiama endpoint admin).

**Come Kybo lo mitiga**

Ogni endpoint e' protetto da dependency injection in
`server/app/core/dependencies.py`:

- `verify_token` — qualsiasi utente autenticato (verifica JWT Firebase)
- `verify_admin` — solo ruolo `admin`
- `verify_professional` — ruoli `admin` o `nutritionist`
- `get_current_uid` — ritorna l'UID dell'utente corrente per scope-check

Esempio pratico nel router `diet.py`:
```python
@router.post("/diet/upload")
async def upload_diet(decoded: dict = Depends(verify_professional)):
    ...
```

Le Firestore Security Rules (`firestore.rules`) applicano i controlli anche
lato database, garantendo che un utente non possa leggere direttamente i
documenti di altri utenti anche bypassando il backend.

L'audit trail e' registrato nella collezione `access_logs/{id}` per ogni
accesso a dati PII.

**Status: Mitigato**

---

## A02 — Cryptographic Failures

**Descrizione del rischio**
Dati sensibili esposti in chiaro: in transito (HTTP), a riposo (DB non
cifrato), o attraverso algoritmi crittografici deboli.

**Come Kybo lo mitiga**

- **In transito**: tutto il traffico avviene via HTTPS. Il backend e' deployato
  su Render con TLS automatico (Let's Encrypt). Il client Flutter usa
  `https://` per tutte le chiamate API.

- **A riposo**: i dati dietetici dei client sono cifrati con AES-256 prima
  di essere salvati in Firestore (`diets/current`, `diets/{id}`). La chiave
  di cifratura non e' hardcoded nel repo.

- **Autenticazione**: Firebase Auth usa internamente bcrypt per le password e
  JWTs firmati con RS256 (chiave privata Google). Il backend non gestisce
  mai password in chiaro.

- **Comunicazioni email**: le credenziali SMTP sono in variabili d'ambiente
  (mai nel repo).

**Status: Mitigato**

---

## A03 — Injection

**Descrizione del rischio**
Input dell'utente interpretato come codice o comandi: SQL Injection, NoSQL
Injection, Command Injection, XSS stored.

**Come Kybo lo mitiga**

- **SQL Injection**: non applicabile — Kybo non usa SQL. Il database e' Firestore
  (NoSQL), che non ha un linguaggio di query injectable.

- **NoSQL Injection**: le query Firestore usano l'SDK ufficiale `firebase-admin`
  con parametri tipizzati (mai concatenazione di stringhe nelle query).

- **Input validation**: tutti i body delle richieste sono validati tramite
  modelli Pydantic (`pydantic==2.6.0`), che applica type checking, regex e
  vincoli di lunghezza. Input invalidi vengono rifiutati con 422 prima di
  raggiungere la logica di business.
  ```python
  class NewsletterSubscribeRequest(BaseModel):
      email: EmailStr  # validazione email automatica
  ```

- **Sanitizzazione dieta**: i PDF in input passano per una pipeline di
  sanitizzazione GDPR in `diet_service.py` prima di essere inviati a Gemini AI.
  La pipeline rimuove pattern che corrispondono a PII (CF, email, telefono).

- **Command Injection**: Tesseract OCR viene chiamato via `subprocess` con
  argomenti come lista (mai come stringa), il che previene shell injection.

- **Logging**: `core/logging.py` include `sanitize_error_message()` che
  maschera token Bearer e altri dati sensibili nei log.

**Status: Mitigato**

---

## A04 — Insecure Design

**Descrizione del rischio**
Architettura che per design non puo' resistere ad attacchi: assenza di threat
modeling, nessun controllo del business logic, nessuna difesa in profondita'.

**Come Kybo lo mitiga**

- **Rate limiting**: implementato via `slowapi` in `core/limiter.py` con chiave
  composita `IP:UID`. Quando l'utente e' autenticato, il rate limit e' per
  utente (non solo IP), prevenendo abusi da utenti dietro NAT condiviso.

- **GDPR compliance**: il backend include un router dedicato `routers/gdpr.py`
  per diritto all'oblio e export dati, in linea con GDPR Art. 17 e Art. 20.

- **Audit logging**: ogni accesso a dati PII scrive in `access_logs/{id}` su
  Firestore, fornendo un trail verificabile per audit di conformita'.

- **Semaforo per task pesanti**: `heavy_tasks_semaphore` in `dependencies.py`
  limita le chiamate AI Gemini concorrenti, prevenendo OOM e degradazione del
  servizio.

- **Separazione dei ruoli**: il sistema a 4 ruoli (`client`, `nutritionist`,
  `admin`, `independent`) implementa il principio del minimo privilegio.

**Status: Mitigato**

---

## A05 — Security Misconfiguration

**Descrizione del rischio**
Configurazioni errate o insicure: credenziali di default, stack trace esposti,
porte non necessarie aperte, CORS troppo permissivo, Firebase rules permissive.

**Come Kybo lo mitiga**

- **Firestore Security Rules**: il file `firestore.rules` (nella root del
  progetto) definisce regole granulari per ogni collezione. I client non
  possono accedere direttamente ai dati di altri utenti.

- **Variabili d'ambiente**: nessuna credenziale nel repository. Le secrets
  (`FIREBASE_CREDENTIALS`, `SENTRY_DSN`, `GOOGLE_API_KEY`) sono configurate
  come env vars su Render. Il file `.env` e' in `.gitignore`.

- **CORS**: la lista `ALLOWED_ORIGINS` in `core/config.py` include solo i
  domini Kybo. Non e' configurato `allow_origins=["*"]`.

- **Stack trace**: Sentry cattura le eccezioni in produzione senza esporle
  all'utente. Le risposte di errore non includono stack trace.

- **Swagger UI**: il backend espone `/docs` (Swagger) solo in ambiente `dev`.
  In produzione e' disabilitato tramite `include_in_schema=False` sugli
  endpoint interni.

- **Sentry alerting**: configurato con `send_default_pii=False` per non
  inviare dati personali ai server Sentry.

**Status: Mitigato**

---

## A06 — Vulnerable and Outdated Components

**Descrizione del rischio**
Dipendenze con vulnerabilita' note (CVE), versioni EOL, o non aggiornate
periodicamente.

**Come Kybo lo mitiga (parzialmente)**

Il file `server/requirements.txt` mostra attenzione alla sicurezza delle
dipendenze — alcune sono pinate a versioni sicure con commenti espliciti:

```
# [SECURITY] Patched Versions
fastapi>=0.109.1

# [SECURITY] Patched Buffer Overflow Vulnerability
Pillow>=10.3.0

# [SECURITY] Pinned version to prevent supply chain attacks
google-genai==1.0.0
```

**Gap identificati:**

1. Non esiste uno strumento automatico di vulnerability scanning nel CI/CD.
   Dipendenze come `firebase-admin==6.4.0` o `pdfplumber==0.10.3` potrebbero
   ricevere CVE senza che il team venga notificato automaticamente.

2. Alcune versioni sono pinate esattamente (es. `uvicorn==0.27.0`) il che
   blocca le patch di sicurezza automatiche; altre usano `>=` il che potrebbe
   portare a versioni non testate.

**Azioni richieste (vedere sezione Findings aperti)**

**Status: Parzialmente mitigato**

---

## A07 — Identification & Authentication Failures

**Descrizione del rischio**
Autenticazione debole: password senza policy, sessioni non invalidate,
brute force senza rate limit, nessuna MFA.

**Come Kybo lo mitiga**

- **Firebase Auth**: gestisce internamente policy password, protezione brute
  force, e token rotation. Il backend non implementa un proprio sistema di
  autenticazione.

- **JWT verification**: `verify_token` in `dependencies.py` chiama
  `firebase_admin.auth.verify_id_token()` che verifica firma, scadenza e
  revoca del token. Token revocati (es. dopo logout) vengono rifiutati.

- **Token cache**: la cache in-memory dei token ha TTL di 25 minuti (i token
  Firebase scadono dopo 60 min). Questo e' un trade-off conscio tra performance
  e sicurezza — un token revocato continua a funzionare per max 25 minuti.

- **2FA TOTP**: il router `routers/twofa.py` implementa autenticazione a due
  fattori con codici TOTP (Time-based One-Time Password), usato per gli account
  admin e nutritionist.

- **Rate limiting su login**: il rate limiter slowapi si applica anche agli
  endpoint di autenticazione, prevenendo brute force.

**Status: Mitigato**

---

## A08 — Software & Data Integrity Failures

**Descrizione del rischio**
Pipeline CI/CD non sicura, dipendenze da fonti non verificate, aggiornamenti
automatici senza verifica dell'integrita', deserializzazione insicura.

**Come Kybo lo mitiga (parzialmente)**

- **GitHub Actions**: il deploy usa CI/CD su GitHub Actions con branch
  protection su `main`. I deploy su Render avvengono da `main` verificato.

- **Pinning dipendenze**: le dipendenze critiche sono pinate a versioni
  specifiche in `requirements.txt` (es. `google-genai==1.0.0`) per prevenire
  supply chain attacks tramite dependency confusion.

- **Deserializzazione**: i payload JSON sono deserializzati tramite Pydantic
  (non `pickle` o `marshal`), che non esegue codice arbitrario.

**Gap identificati:**

1. Non esiste verifica degli hash (`sha256`) delle dipendenze (pip hash
   checking). Un attaccante con accesso a PyPI potrebbe in teoria sostituire
   un pacchetto.

2. Il CI/CD non include uno step di SAST (Static Application Security Testing)
   automatico.

**Azioni richieste (vedere sezione Findings aperti)**

**Status: Parzialmente mitigato**

---

## A09 — Security Logging & Monitoring Failures

**Descrizione del rischio**
Nessun log degli eventi di sicurezza, assenza di alerting su anomalie, logs
che non permettono il forensic dopo un incidente.

**Come Kybo lo mitiga**

- **Sentry**: integrato con `sentry-sdk[fastapi]`. Cattura automaticamente tutte
  le eccezioni non gestite con stack trace, request context e environment.
  Configurato con `traces_sample_rate=0.1` per performance tracing.

- **Prometheus + APM**: `prometheus-fastapi-instrumentator` espone metriche
  HTTP (latenza, throughput, error rate) sull'endpoint `/metrics`. L'endpoint
  `/metrics/api` espone metriche custom Kybo (cache hit/miss, Gemini calls).

- **Structured logging**: `core/logging.py` usa `structlog` per log JSON
  strutturati con campi consistenti (`event`, `uid`, `endpoint`, ecc.),
  facilitando il parsing e la ricerca in Cloudwatch/Datadog.

- **Audit log Firestore**: ogni accesso a PII scrive in `access_logs/{id}` con
  timestamp, UID, tipo di accesso. Questo trail e' immutabile (regole Firestore
  impediscono la modifica dei log da parte dei client).

- **Sanitizzazione log**: `sanitize_error_message()` maschera token Bearer,
  credenziali e dati sensibili prima della scrittura nei log.

**Status: Mitigato**

---

## A10 — Server-Side Request Forgery (SSRF)

**Descrizione del rischio**
Il server effettua richieste HTTP verso URL controllati dall'attaccante,
potenzialmente raggiungendo servizi interni (metadata cloud, database, ecc.).

**Come Kybo lo mitiga**

- **Nessun fetch di URL utente**: il backend non accetta URL forniti dall'utente
  per effettuare fetch HTTP arbitrari. Le uniche chiamate HTTP esterne sono
  verso endpoint fissi e noti (Firebase, Google Gemini AI, SMTP).

- **PDF processing**: il parsing PDF avviene su file caricati dall'utente, non
  su URL. pdfplumber non effettua richieste di rete.

- **Gemini API**: le chiamate a Gemini AI usano l'SDK ufficiale
  (`google-genai`) con API key, non URL costruiti dinamicamente.

- **Webhook assenti**: il backend non implementa webhook verso URL esterni
  configurabili dall'utente.

**Note**: se in futuro vengono aggiunte funzionalita' che accettano URL utente
(es. importazione dieta da URL), implementare una whitelist di domini ammessi
e bloccare gli IP range privati (10.x.x.x, 172.16.x.x, 192.168.x.x, 169.254.x.x).

**Status: Mitigato**

---

## Findings aperti

Le seguenti azioni sono richieste per portare A06 e A08 a stato "Mitigato".

### Finding 1 — Dependency vulnerability scanning automatico (A06)

**Priorita'**: Alta
**Azione**: Aggiungere uno step nel CI/CD GitHub Actions che esegue
`pip-audit` (o `safety`) su ogni push su `main` e `dev`:

```yaml
# .github/workflows/security.yml
- name: Audit Python dependencies
  run: |
    pip install pip-audit
    pip-audit -r server/requirements.txt --strict
```

Configurare alert su GitHub Security Advisories per notifiche automatiche di
nuove CVE nelle dipendenze del progetto.

### Finding 2 — Pinning versioni con hash in requirements.txt (A06, A08)

**Priorita'**: Media
**Azione**: Generare `requirements.txt` con hash SHA256 per ogni dipendenza,
impedendo la sostituzione silente di pacchetti:

```bash
# Genera requirements con hash
pip-compile --generate-hashes requirements.in -o requirements.txt

# Installa verificando gli hash
pip install --require-hashes -r requirements.txt
```

Questo previene supply chain attacks anche se un attaccante compromette un
mirror PyPI.

### Finding 3 — SAST tool nel CI/CD (A08)

**Priorita'**: Media
**Azione**: Integrare Bandit (SAST per Python) nel pipeline CI/CD:

```yaml
# .github/workflows/security.yml
- name: SAST — Bandit
  run: |
    pip install bandit
    bandit -r server/app/ -ll --format json -o bandit-report.json
    bandit -r server/app/ -ll  # output leggibile
```

Bandit rileva automaticamente pattern di sicurezza problematici: uso di
`subprocess` senza shell=False, pickle insicuro, hardcoded passwords, ecc.

---

## Note metodologiche

Questo report e' basato su:

1. **Revisione codice sorgente** (`server/app/`) — tutti i file principali
   (routers, core, services) sono stati analizzati.
2. **Analisi `requirements.txt`** — versioni dipendenze verificate contro
   known vulnerabilities alla data del report.
3. **Architettura Kybo** come documentata in `CLAUDE.md`.

**Non incluso in questo report** (richiede test dinamico):

- Test di penetrazione black-box (richiede ambiente di staging dedicato)
- Fuzzing degli endpoint API
- Test di escalation privilege con token reali
- Analisi del traffico di rete (MITM test)

Si raccomanda un penetration test esterno prima del lancio in produzione.
