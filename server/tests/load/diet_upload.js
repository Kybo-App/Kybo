/**
 * k6 Load Test — Diet Upload
 *
 * Testa l'endpoint piu' pesante del backend: POST /diet/upload.
 * L'upload scatena: PDF parsing (pdfplumber) → Gemini AI → Firestore write.
 * E' normale che i tempi siano nell'ordine dei secondi.
 *
 * Profilo di carico (spike test progressivo):
 *   Fase 1 — Rampa 0 → 50 VU    in 30s   (warm-up)
 *   Fase 2 — Steady 50 VU       per 1min  (baseline)
 *   Fase 3 — Rampa 50 → 200 VU  in 30s   (carico normale)
 *   Fase 4 — Steady 200 VU      per 2min  (test sostenuto)
 *   Fase 5 — Rampa 200 → 500 VU in 30s   (spike)
 *   Fase 6 — Steady 500 VU      per 30s   (picco spike)
 *   Fase 7 — Rampa 500 → 0      in 30s   (cooldown)
 *
 * Soglie (permissive per AI):
 *   - p95 < 10000ms (10 secondi)
 *   - error rate < 5%
 *
 * Utilizzo:
 *   k6 run \
 *     --env BASE_URL=https://kybo-test.onrender.com \
 *     --env TEST_TOKEN=<firebase_id_token> \
 *     diet_upload.js
 */

import http from "k6/http";
import { check, sleep } from "k6";
import { Rate, Trend, Counter } from "k6/metrics";
import encoding from "k6/encoding";

// ---------------------------------------------------------------------------
// Configurazione
// ---------------------------------------------------------------------------

const BASE_URL   = __ENV.BASE_URL   || "http://localhost:8000";
const TEST_TOKEN = __ENV.TEST_TOKEN || "";

const uploadErrors   = new Rate("upload_errors");
const uploadDuration = new Trend("upload_duration_ms", true);
const aiTimeouts     = new Counter("ai_timeouts");

export const options = {
  stages: [
    { duration: "30s", target: 50  }, // fase 1: warm-up
    { duration: "1m",  target: 50  }, // fase 2: baseline
    { duration: "30s", target: 200 }, // fase 3: rampa carico normale
    { duration: "2m",  target: 200 }, // fase 4: carico sostenuto
    { duration: "30s", target: 500 }, // fase 5: rampa spike
    { duration: "30s", target: 500 }, // fase 6: spike plateau
    { duration: "30s", target: 0   }, // fase 7: cooldown
  ],
  thresholds: {
    // Upload + AI: soglia permissiva di 10 secondi al p95
    http_req_duration: ["p(95)<10000"],
    // Max 5% errori (AI puo' avere timeout occasionali)
    http_req_failed: ["rate<0.05"],
    upload_errors:   ["rate<0.05"],
  },
};

// ---------------------------------------------------------------------------
// PDF fake minimo (alcuni byte validi per testare parsing base)
// Un PDF reale verrebbe passato come multipart/form-data
// ---------------------------------------------------------------------------

// Header PDF minimo — pdfplumber lo riconosce come PDF valido vuoto
const FAKE_PDF_BYTES = "%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\nxref\n0 1\n0000000000 65535 f\ntrailer\n<< /Size 1 /Root 1 0 R >>\nstartxref\n9\n%%EOF";
const FAKE_PDF_B64   = encoding.b64encode(FAKE_PDF_BYTES);

// ---------------------------------------------------------------------------
// Setup
// ---------------------------------------------------------------------------

export function setup() {
  if (!TEST_TOKEN) {
    console.warn("ATTENZIONE: TEST_TOKEN non impostato. Le richieste riceveranno 401.");
  }

  const res = http.get(`${BASE_URL}/ping`);
  if (res.status !== 200) {
    throw new Error(`Server non raggiungibile: ${BASE_URL}/ping → ${res.status}`);
  }
  return { baseUrl: BASE_URL };
}

// ---------------------------------------------------------------------------
// Scenario principale
// ---------------------------------------------------------------------------

export default function (data) {
  if (!TEST_TOKEN) {
    // Senza token testa solo il layer di autenticazione (aspettiamo 401)
    const res = http.post(
      `${BASE_URL}/diet/upload`,
      JSON.stringify({ pdf_base64: FAKE_PDF_B64 }),
      { headers: { "Content-Type": "application/json" }, tags: { name: "diet_upload_noauth" } }
    );
    check(res, { "401 senza token": (r) => r.status === 401 });
    sleep(1);
    return;
  }

  const payload = JSON.stringify({
    pdf_base64: FAKE_PDF_B64,
    client_id: `test_client_${__VU}`,
  });

  const params = {
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${TEST_TOKEN}`,
    },
    tags:    { name: "diet_upload" },
    timeout: "30s", // upload AI puo' richiedere fino a 30s
  };

  const startTime = Date.now();
  const res       = http.post(`${BASE_URL}/diet/upload`, payload, params);
  const elapsed   = Date.now() - startTime;

  uploadDuration.add(elapsed);

  if (res.status === 408 || res.status === 504) {
    aiTimeouts.add(1);
  }

  const success = check(res, {
    "status non e' 5xx":      (r) => r.status < 500,
    "non e' timeout gateway": (r) => r.status !== 504,
    "risposta in tempo":      (r) => r.timings.duration < 10000,
  });

  uploadErrors.add(!success);

  // Pausa piu' lunga: upload e' operazione pesante, simuliamo utenti reali
  sleep(Math.random() * 3 + 2);
}

export function teardown(data) {
  console.log(`Test upload completato. AI timeouts registrati: vedere metrica ai_timeouts.`);
}
