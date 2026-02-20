# Kybo — Task Manuali & Guide Operative

Questo file raccoglie tutto ciò che richiede un'azione manuale da parte del team
(configurazioni esterne, setup servizi, deploy, ecc.) e i tutorial per usare
le funzionalità di infrastruttura implementate.

---

## 1. Redis Cache Layer (L1.5)

### Cosa fa
Redis si posiziona tra la cache RAM locale (L1) e Firestore (L2) come cache
distribuita condivisa tra tutte le istanze del server. Se non è configurato,
il sistema funziona normalmente usando solo RAM + Firestore (graceful fallback).

### Setup su Render (produzione)

1. **Crea un Redis su Render**
   - Vai su [render.com](https://render.com) → **New** → **Redis**
   - Nome: `kybo-redis`
   - Piano: **Free** (25 MB) per iniziare; **Starter** ($10/mese) per produzione
   - Copia l'**Internal Redis URL** (formato: `redis://red-xxx:6379`)

2. **Aggiungi la variabile d'ambiente al servizio backend**
   - Vai sul tuo servizio Render (`kybo` o `kybo-test`)
   - **Environment** → **Add Environment Variable**
   - Key: `REDIS_URL`
   - Value: l'URL copiato sopra (es. `redis://red-xxx:6379`)
   - Salva e rideploya

3. **Verifica che funzioni**
   ```bash
   curl https://kybo.onrender.com/health/detailed
   # Dovresti vedere: "redis": {"status": "ok", "message": "Connected"}
   ```

### Alternativa gratuita: Upstash Redis

1. Vai su [upstash.com](https://upstash.com) → crea un database Redis (piano free)
2. Copia la **Redis URL** (formato: `redis://default:xxx@xxx.upstash.io:6379`)
3. Aggiungila come `REDIS_URL` su Render

### TTL configurabili (variabili d'ambiente opzionali)

| Variabile               | Default | Descrizione                        |
|-------------------------|---------|------------------------------------|
| `REDIS_DIET_TTL`        | `3600`  | Secondi cache parsing diete (1h)   |
| `REDIS_SUGGESTIONS_TTL` | `1800`  | Secondi cache suggerimenti (30min) |
| `REDIS_TOKEN_TTL`       | `1500`  | Secondi cache token JWT (25min)    |

### Sviluppo locale con Docker

```bash
# Avvia Redis in locale
docker run -d -p 6379:6379 --name kybo-redis redis:7-alpine

# Aggiungi a server/.env
REDIS_URL=redis://localhost:6379/0

# Verifica
docker exec kybo-redis redis-cli ping
# → PONG
```

### Come leggere i log del server (flusso cache)

```
Richiesta parsing dieta
  → L1 RAM check       (hit → risposta in ~µs)
  → L1.5 Redis check   (hit → risposta in ~1-5ms)
  → L2 Firestore check (hit → risposta in ~20-50ms)
  → Gemini API call    (miss totale → ~20-90 secondi)
  → salva in L1 + L1.5 + L2
```

I log del server mostrano il layer colpito:
```
✅ Cache L1 (RAM) HIT per hash abc12345...
✅ Cache L1.5 (Redis) HIT per hash abc12345...
✅ Cache L2 (Firestore) HIT per hash abc12345...
🔑 Cache MISS per hash abc12345... (chiamata API)
```

---

## 2. APM — Prometheus + Dashboard Metriche API

### Cosa fa
Il backend espone due endpoint di monitoring:
- **`GET /metrics`** — formato Prometheus (text/plain), per scraping da Grafana
- **`GET /metrics/api`** — formato JSON leggibile direttamente o dall'admin panel

### Endpoint `/metrics/api` — esempio risposta

```json
{
  "timestamp": "2026-02-20T15:30:00+00:00",
  "environment": "PROD",
  "diet_parser": {
    "gemini_calls": 142,
    "gemini_errors": 3,
    "avg_parse_duration_s": 28.4,
    "cache": {
      "ram_entries": 87,
      "ram_max": 100,
      "L1_ram":       {"hits": 1204, "misses": 142, "ratio": "89.4%"},
      "L1_5_redis":   {"hits": 98,   "misses": 44,  "ratio": "69.0%"},
      "L2_firestore": {"hits": 39,   "misses": 5,   "ratio": "88.6%"}
    }
  },
  "meal_suggestions": {
    "gemini_calls": 67,
    "gemini_errors": 1,
    "avg_generation_duration_s": 6.2,
    "cache": {
      "ram_entries": 23,
      "L1_ram":     {"hits": 312, "misses": 67, "ratio": "82.3%"},
      "L1_5_redis": {"hits": 41,  "misses": 26, "ratio": "61.2%"}
    }
  },
  "redis": {
    "available": true,
    "url_configured": true
  },
  "prometheus_endpoint": "/metrics"
}
```

### Setup Grafana Cloud (opzione consigliata — gratuita)

1. Crea un account su [grafana.com](https://grafana.com) → **Start for free**
2. Vai su **Connections** → **Add new connection** → **Prometheus**
3. Aggiungi il datasource puntando al backend Render:
   ```
   URL: https://kybo.onrender.com
   Path: /metrics
   Scrape interval: 30s
   ```
4. Importa una dashboard FastAPI predefinita (Grafana Dashboard ID: **14837**)
   oppure crea le tue usando le metriche `kybo_*`

### Setup locale con Docker Compose

```bash
# Crea prometheus.yml nella root del progetto
cat > prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: kybo-api
    static_configs:
      - targets: ['host.docker.internal:8000']
    metrics_path: /metrics
EOF

# Avvia Prometheus + Grafana
docker run -d -p 9090:9090 \
  -v $(pwd)/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus:latest

docker run -d -p 3001:3000 \
  -e GF_SECURITY_ADMIN_PASSWORD=kybo123 \
  grafana/grafana:latest

# Apri Grafana: http://localhost:3001 (admin / kybo123)
# Apri Prometheus: http://localhost:9090
```

### Metriche Prometheus disponibili

#### HTTP (automatiche)

| Metrica | Tipo | Descrizione |
|---------|------|-------------|
| `http_requests_total` | Counter | Richieste per route, method, status code |
| `http_request_duration_seconds` | Histogram | Latenza per route |
| `kybo_http_requests_inprogress` | Gauge | Richieste HTTP in corso |

#### Diet Parser

| Metrica | Tipo | Descrizione |
|---------|------|-------------|
| `kybo_diet_gemini_calls_total` | Counter | Chiamate Gemini AI totali |
| `kybo_diet_gemini_errors_total` | Counter | Errori Gemini AI |
| `kybo_diet_cache_hits_total{layer}` | Counter | Cache hit per layer |
| `kybo_diet_cache_misses_total{layer}` | Counter | Cache miss per layer |
| `kybo_diet_parse_duration_seconds` | Histogram | Durata parsing Gemini |
| `kybo_diet_memory_cache_size` | Gauge | Entry correnti in cache RAM |

#### Meal Suggestions

| Metrica | Tipo | Descrizione |
|---------|------|-------------|
| `kybo_suggestions_gemini_calls_total` | Counter | Chiamate Gemini totali |
| `kybo_suggestions_gemini_errors_total` | Counter | Errori Gemini |
| `kybo_suggestions_cache_hits_total{layer}` | Counter | Cache hit per layer |
| `kybo_suggestions_cache_misses_total{layer}` | Counter | Cache miss per layer |
| `kybo_suggestions_duration_seconds` | Histogram | Durata generazione suggerimenti |

#### Auth & Infra

| Metrica | Tipo | Descrizione |
|---------|------|-------------|
| `kybo_auth_token_cache_hits_total` | Counter | Token JWT trovati in cache RAM |
| `kybo_auth_token_cache_misses_total` | Counter | Token non in cache (verifica Firebase) |
| `kybo_auth_errors_total{reason}` | Counter | Errori autenticazione per tipo |
| `kybo_ocr_scans_total` | Counter | Scansioni scontrino OCR totali |
| `kybo_ocr_duration_seconds` | Histogram | Durata OCR |

### Query PromQL utili (da incollare in Grafana)

```promql
# Latenza media per route (ultimi 5 minuti)
rate(http_request_duration_seconds_sum[5m])
  / rate(http_request_duration_seconds_count[5m])

# Error rate (% risposte 5xx)
sum(rate(http_requests_total{status="5xx"}[5m]))
  / sum(rate(http_requests_total[5m])) * 100

# Cache hit ratio diet — L1 RAM
rate(kybo_diet_cache_hits_total{layer="L1_ram"}[10m])
  / (  rate(kybo_diet_cache_hits_total{layer="L1_ram"}[10m])
     + rate(kybo_diet_cache_misses_total{layer="L1_ram"}[10m]))

# Durata media parsing diete (ultimi 30 minuti)
rate(kybo_diet_parse_duration_seconds_sum[30m])
  / rate(kybo_diet_parse_duration_seconds_count[30m])

# Chiamate Gemini al minuto
rate(kybo_diet_gemini_calls_total[1m]) * 60

# Suggerimenti generati al minuto
rate(kybo_suggestions_gemini_calls_total[1m]) * 60
```

### ⚠️ Sicurezza endpoint `/metrics`

L'endpoint `/metrics` è attualmente **pubblico**. Se il backend è esposto su
internet, considera di proteggerlo. Opzioni:

**Opzione A — Render Private Service**
Imposta il backend come servizio privato su Render: sarà accessibile solo dalla
rete interna di Render (altri servizi Render, non dall'esterno).

**Opzione B — Token di autenticazione**
Aggiungi in `server/.env`:
```bash
METRICS_TOKEN=un-token-segreto-lungo
```
E chiama così:
```bash
curl -H "X-Metrics-Token: un-token-segreto-lungo" \
  https://kybo.onrender.com/metrics/api
```

---

## 3. Health Check Endpoints — Riferimento

| Endpoint | Auth | Descrizione |
|----------|------|-------------|
| `GET /health` | No | Check base per load balancer (risposta veloce) |
| `GET /health/detailed` | No | Check tutti i servizi: Firebase, Gemini, Redis, Tesseract, Sentry |
| `GET /ping` | No | Ultra-leggero keep-alive (usato da UptimeRobot, supporta HEAD) |
| `GET /metrics` | No* | Metriche Prometheus (text/plain) |
| `GET /metrics/api` | No* | Metriche JSON human-friendly |

---

## 4. Variabili d'Ambiente — Riferimento Completo

### Backend (`server/.env` o Render → Environment)

```bash
# ── OBBLIGATORIE ──────────────────────────────────────────────────────────────
GOOGLE_API_KEY=AIza...                  # Gemini AI API key (Google AI Studio)
FIREBASE_CREDENTIALS={"type":...}       # JSON service account Firebase (escaped)
STORAGE_BUCKET=kybo-xxx.appspot.com     # Firebase Storage bucket

# ── CONSIGLIATE ───────────────────────────────────────────────────────────────
SENTRY_DSN=https://xxx@sentry.io/xxx    # Error tracking (Sentry)
REDIS_URL=redis://red-xxx:6379           # Cache distribuita (Render Redis / Upstash)

# ── SMTP EMAIL ────────────────────────────────────────────────────────────────
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=noreply@kybo.it
SMTP_PASSWORD=xxx
SMTP_FROM_EMAIL=noreply@kybo.it
SMTP_FROM_NAME=Kybo

# ── AMBIENTE ──────────────────────────────────────────────────────────────────
ENV=PROD                                # DEV | STAGING | PROD
GEMINI_MODEL=gemini-2.5-flash           # Modello Gemini da usare

# ── CACHE TTL (opzionali, hanno default) ──────────────────────────────────────
REDIS_DIET_TTL=3600                     # 1h
REDIS_SUGGESTIONS_TTL=1800              # 30min
REDIS_TOKEN_TTL=1500                    # 25min
```

### Flutter Client / Admin (`.env` nella root di `client/` o `admin/`)

```bash
API_URL=https://kybo.onrender.com       # produzione
# oppure
API_URL=https://kybo-test.onrender.com  # test/dev
```

---

## 5. Deploy Checklist

### Nuovo deploy backend (Render)

- [ ] Variabile `ENV=PROD` impostata
- [ ] `GOOGLE_API_KEY` valida e con quota sufficiente
- [ ] `FIREBASE_CREDENTIALS` JSON correttamente escaped (tutto su una riga)
- [ ] `STORAGE_BUCKET` corretto
- [ ] `SENTRY_DSN` impostato (per error tracking)
- [ ] `REDIS_URL` impostato (per cache distribuita)
- [ ] SMTP configurato (per email notifiche e report mensili)
- [ ] Verifica `GET /health/detailed` → tutti i check `"ok"`
- [ ] Verifica `GET /metrics/api` → risponde correttamente

### Nuovo deploy client Flutter

- [ ] `.env` punta all'URL corretto (`prod` vs `test`)
- [ ] Flavor corretto: `flutter build apk --flavor prod --release`
- [ ] Firebase `google-services.json` aggiornato (se cambiato progetto)

### Nuovo deploy landing (Firebase Hosting)

```bash
cd landing
npm run build          # genera /out
firebase deploy        # deploya su Firebase Hosting
```
- [ ] Verifica tutte le route: `/`, `/business`, `/pricing`, `/en`, ecc.
- [ ] Verifica OpenGraph tags con [opengraph.xyz](https://opengraph.xyz)
