/**
 * k6 Smoke Test — Kybo API
 *
 * Test leggero da lanciare dopo ogni deploy per verificare che il server
 * sia operativo e gli endpoint principali rispondano correttamente.
 *
 * Profilo: 5 VU per 1 minuto — nessun carico reale, solo sanity check.
 *
 * Soglie (stringenti, il server deve essere gia' caldo):
 *   - p95 < 1000ms
 *   - error rate 0% (nessun errore tollerato in smoke test)
 *
 * Utilizzo:
 *   k6 run --env BASE_URL=https://kybo-test.onrender.com smoke.js
 *
 * Integrazione CI/CD:
 *   Aggiungere come step post-deploy in GitHub Actions:
 *     - name: Smoke test
 *       run: k6 run --env BASE_URL=${{ env.API_URL }} server/tests/load/smoke.js
 */

import http from "k6/http";
import { check, sleep } from "k6";
import { Rate } from "k6/metrics";

// ---------------------------------------------------------------------------
// Configurazione
// ---------------------------------------------------------------------------

const BASE_URL = __ENV.BASE_URL || "http://localhost:8000";

const smokeErrors = new Rate("smoke_errors");

export const options = {
  vus:      5,
  duration: "1m",
  thresholds: {
    http_req_duration: ["p(95)<1000"],
    http_req_failed:   ["rate<0.001"], // quasi zero: smoke deve essere verde
    smoke_errors:      ["rate<0.001"],
  },
};

// ---------------------------------------------------------------------------
// Setup — attende che il server sia pronto (gestisce cold start Render)
// ---------------------------------------------------------------------------

export function setup() {
  // Attendi fino a 60s per il cold start del server (free tier Render)
  let attempts = 0;
  const maxAttempts = 12; // 12 * 5s = 60s

  while (attempts < maxAttempts) {
    const res = http.get(`${BASE_URL}/ping`, { timeout: "10s" });
    if (res.status === 200) {
      console.log(`Server pronto dopo ${attempts * 5}s`);
      return { baseUrl: BASE_URL, ready: true };
    }
    console.log(`Tentativo ${attempts + 1}/${maxAttempts}: server non pronto (${res.status}), riprovo in 5s...`);
    sleep(5);
    attempts++;
  }

  throw new Error(`Server non raggiungibile dopo ${maxAttempts * 5}s: ${BASE_URL}`);
}

// ---------------------------------------------------------------------------
// Scenario principale
// ---------------------------------------------------------------------------

export default function (data) {
  const params = {
    tags:    { test_type: "smoke" },
    timeout: "15s",
  };

  // --- /ping — ultra-leggero, nessuna dipendenza ---
  const pingRes = http.get(`${BASE_URL}/ping`, { ...params, tags: { name: "smoke_ping" } });
  const pingOk  = check(pingRes, {
    "ping: status 200":         (r) => r.status === 200,
    "ping: risposta rapida":    (r) => r.timings.duration < 500,
    "ping: body corretto":      (r) => {
      try {
        return JSON.parse(r.body).ok === true;
      } catch {
        return false;
      }
    },
  });
  smokeErrors.add(!pingOk);

  sleep(0.5);

  // --- /health — verifica stato generale ---
  const healthRes = http.get(`${BASE_URL}/health`, { ...params, tags: { name: "smoke_health" } });
  const healthOk  = check(healthRes, {
    "health: status 200":      (r) => r.status === 200,
    "health: risposta rapida": (r) => r.timings.duration < 1000,
    "health: status healthy":  (r) => {
      try {
        return JSON.parse(r.body).status === "healthy";
      } catch {
        return false;
      }
    },
  });
  smokeErrors.add(!healthOk);

  sleep(0.5);

  // --- /health/detailed — verifica dipendenze (Firebase, Gemini, Redis) ---
  // Nota: questo endpoint chiama Firebase, quindi piu' lento
  const detailedRes = http.get(`${BASE_URL}/health/detailed`, { ...params, tags: { name: "smoke_health_detailed" } });
  const detailedOk  = check(detailedRes, {
    "health/detailed: status 200":     (r) => r.status === 200,
    "health/detailed: firebase ok":    (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.checks && body.checks.firebase && body.checks.firebase.status === "ok";
      } catch {
        return false;
      }
    },
  });
  smokeErrors.add(!detailedOk);

  // Pausa tra iterazioni (smoke e' leggero, non stressare il server)
  sleep(2);
}

export function teardown(data) {
  if (data.ready) {
    console.log("Smoke test completato. Se tutti i check sono verdi il deploy e' OK.");
  }
}
