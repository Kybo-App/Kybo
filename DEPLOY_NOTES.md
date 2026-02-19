# Deploy Notes — Azioni manuali richieste

Questo file raccoglie tutte le configurazioni e azioni che richiedono intervento manuale
(variabili d'ambiente, account esterni, configurazioni infrastruttura).

---

## 🔴 SMTP — Notifiche email messaggi non letti

**Quando**: Appena vuoi attivare gli alert email per i nutrizionisti (Feature 5)

**Dove**: Render → kybo-test / kybo-prod → Environment → Environment Variables

Aggiungere le seguenti variabili:

| Variabile | Valore | Note |
|---|---|---|
| `SMTP_HOST` | es. `smtp.gmail.com` | Host del tuo provider email |
| `SMTP_PORT` | `587` | Porta TLS standard |
| `SMTP_USERNAME` | es. `noreply@kybo.it` | Account mittente |
| `SMTP_PASSWORD` | (password o app password) | Per Gmail: usa "App Password" |
| `SMTP_FROM_EMAIL` | `noreply@kybo.it` | Indirizzo visibile al destinatario |
| `SMTP_FROM_NAME` | `Kybo` | Nome visibile al destinatario |

**Come testare**: Dopo il deploy, un nutrizionista può attivare gli alert dal pannello Chat → icona campanella 🔔. Le email vengono inviate automaticamente quando un messaggio non letto supera la soglia impostata.

**Se SMTP non è configurato**: il sistema si avvia comunque senza errori, le email sono semplicemente skippate.

---

---

## 🔴 OG Image — Landing Page social sharing

**Quando**: Prima di andare live con la landing / quando vuoi condivisioni social ottimizzate

**Cosa fare**: Creare e caricare il file `landing/public/og-image.png`

**Specifiche**:
- Dimensione: **1200 × 630 px**
- Formato: PNG
- Contenuto consigliato: logo Kybo + tagline "La tua nutrizione semplificata" su sfondo verde (#2E7D32) o dark
- Il file è già referenziato nei metadata OpenGraph e Twitter Card

**Dove**: salvare come `landing/public/og-image.png` e fare push su dev → il CI/CD lo include nel build.

---

## 🟡 Twitter/X Handle

**Quando**: quando Kybo ha un account Twitter/X ufficiale

**Cosa fare**: aggiornare `@kyboapp` nel file `landing/src/app/layout.tsx` (righe `site` e `creator` nei metadata Twitter) con l'handle reale.

---

## 🟡 Schema.org `sameAs` — Social Links

**Quando**: quando Kybo ha profili social ufficiali (Instagram, LinkedIn, ecc.)

**Cosa fare**: aggiungere gli URL nel campo `sameAs` dell'Organization in `landing/src/app/layout.tsx`:
```ts
sameAs: [
  'https://www.instagram.com/kyboapp',
  'https://www.linkedin.com/company/kyboapp',
  // ...
],
```

---

---

## 🟡 Redis — Cache Layer (Feature 10, opzionale)

**Quando**: se vuoi sostituire/affiancare la cache in-memory con Redis per persistenza tra restart

**Dove**: Render → crea un Redis database → copia la connection string

**Cosa fare**:
1. Aggiungere su Render una istanza Redis
2. Aggiungere variabile `REDIS_URL=redis://...` nel backend
3. Installare `redis` nel `requirements.txt`
4. Aggiornare `diet_service.py` per usare Redis come L2 cache invece di Firestore

---

## 🟡 APM — Application Performance Monitoring (Feature 10, opzionale)

**Quando**: quando vuoi monitorare latenza, error rate e throughput delle API

**Opzioni**:
- **Sentry Performance**: aggiungere `traces_sample_rate=1.0` al sentry_sdk.init già configurato
- **Datadog**: aggiungere `ddtrace` in requirements.txt e configurare DD_API_KEY su Render
- **Render Metrics**: disponibile nativamente nel dashboard Render (CPU, memoria, richieste)

---

## 🟡 Session Management — Revoca Sessioni (Feature 10)

**Implementato**: `POST /admin/session/revoke/{uid}` (admin) e `POST /admin/session/revoke-self` (self)

**Come funziona**: Firebase `auth.revoke_refresh_tokens(uid)` invalida tutti i refresh token.
Il JWT corrente rimane valido max 1 ora, poi l'utente è forzato al login.

**Nota**: per ridurre questa finestra a 0, configura il `verify_token` per controllare `valid_since`
tramite `auth.get_user(uid).tokens_valid_after_time`. Aggiunta alla roadmap come miglioramento futuro.

---

*Ultimo aggiornamento: 2026-02-19*
