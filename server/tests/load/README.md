# Kybo Load Tests — k6

Questa cartella contiene i test di carico scritti con [k6](https://k6.io/) per
il backend Kybo. I test coprono autenticazione, upload dieta, messaggi chat e
uno smoke test post-deploy.

---

## Installazione k6

**macOS (Homebrew)**
```bash
brew install k6
```

**Windows (winget)**
```bash
winget install k6
```

**Linux (Debian/Ubuntu)**
```bash
sudo gpg -k
sudo gpg --no-default-keyring \
  --keyring /usr/share/keyrings/k6-archive-keyring.gpg \
  --keyserver hkp://keyserver.ubuntu.com:80 \
  --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" \
  | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update && sudo apt-get install k6
```

**Docker**
```bash
docker run --rm -i grafana/k6 run - <script.js
```

---

## Come lanciare i test

Variabili d'ambiente accettate da tutti gli script:

| Variabile    | Default                       | Descrizione                        |
|--------------|-------------------------------|------------------------------------|
| `BASE_URL`   | `http://localhost:8000`       | URL base del server                |
| `TEST_TOKEN` | *(stringa vuota)*             | Firebase ID token per route protette |

### Smoke test (dopo ogni deploy)
```bash
k6 run --env BASE_URL=https://kybo-test.onrender.com server/tests/load/smoke.js
```

### Test autenticazione
```bash
k6 run --env BASE_URL=https://kybo-test.onrender.com server/tests/load/auth.js
```

### Test upload dieta
```bash
k6 run \
  --env BASE_URL=https://kybo-test.onrender.com \
  --env TEST_TOKEN=<firebase_id_token> \
  server/tests/load/diet_upload.js
```

### Test chat
```bash
k6 run \
  --env BASE_URL=https://kybo-test.onrender.com \
  --env TEST_TOKEN=<firebase_id_token> \
  server/tests/load/chat.js
```

---

## Output e metriche

k6 stampa un riepilogo al termine. Le metriche principali sono:

| Metrica               | Significato                                                   |
|-----------------------|---------------------------------------------------------------|
| `http_req_duration`   | Durata totale richiesta (dal client al server e ritorno)      |
| `p(95)`               | Il 95° percentile: il 95% delle richieste ha risposto entro X |
| `p(99)`               | Il 99° percentile: solo 1% delle richieste supera questo tempo|
| `http_req_failed`     | Percentuale di richieste con status >= 400 o errore di rete  |
| `vus`                 | Virtual Users attivi in quel momento                          |
| `vus_max`             | Picco di VU raggiunto durante il test                         |
| `iterations`          | Numero totale di cicli completati                             |
| `rps` (reqs/s)        | Throughput: richieste al secondo (visibile in tempo reale)    |

Esempio output atteso per smoke test:
```
checks.........................: 100.00% 30 out of 30
http_req_duration.............: avg=120ms  p(95)=310ms  p(99)=480ms
http_req_failed...............: 0.00%   0 out of 30
```

---

## Note importanti

- **Ambiente di test**: usare sempre `kybo-test.onrender.com` per i test di
  carico. Non eseguire load test su `kybo-prod.onrender.com` (produzione) senza
  coordinamento con il team — il traffico artificiale impatta gli utenti reali
  e puo' attivare i rate limiter.

- **Token di test**: ottenere un `TEST_TOKEN` valido da Firebase Console
  (Authentication > Users > "Copia ID token") o tramite la Firebase REST API.
  Il token scade dopo 1 ora; rigenerarlo prima di test lunghi.

- **Rate limiting**: il backend ha rate limit via slowapi. Per test con molti
  VU usare IP dedicati o disabilitare il rate limit nell'ambiente di test.

- **Cold start Render**: il free tier di Render spegne il server dopo
  inattivita'. Il primo request puo' durare 20-30 secondi. Lo smoke test
  include un `sleep(1)` iniziale per questo motivo — in produzione usare
  UptimeRobot per il keep-alive.
