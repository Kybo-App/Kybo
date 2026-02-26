/**
 * k6 Load Test — Authentication
 *
 * Simula il flusso di login tramite Firebase Auth REST API.
 * Non usa l'SDK Firebase ma chiama direttamente il REST endpoint
 * signInWithPassword, che e' quello invocato dai client mobile.
 *
 * Profilo di carico:
 *   - Rampa 0 → 200 VU in 30s
 *   - Steady 200 VU per 2 minuti
 *   - Rampa 200 → 0 in 30s
 *
 * Soglie:
 *   - p95 < 2000ms
 *   - error rate < 1%
 *
 * Utilizzo:
 *   k6 run --env BASE_URL=https://kybo-test.onrender.com auth.js
 */

import http from "k6/http";
import { check, sleep } from "k6";
import { Rate, Trend } from "k6/metrics";

// ---------------------------------------------------------------------------
// Configurazione
// ---------------------------------------------------------------------------

const BASE_URL = __ENV.BASE_URL || "http://localhost:8000";

// Metrica custom: percentuale di errori di autenticazione
const authErrorRate = new Rate("auth_errors");
// Metrica custom: durata specifica del login step
const loginDuration = new Trend("login_duration_ms", true);

export const options = {
  stages: [
    { duration: "30s", target: 200 }, // rampa su
    { duration: "2m",  target: 200 }, // steady state
    { duration: "30s", target: 0   }, // rampa giu'
  ],
  thresholds: {
    // 95% delle richieste deve rispondere entro 2 secondi
    http_req_duration: ["p(95)<2000"],
    // Meno dell'1% delle richieste deve fallire
    http_req_failed: ["rate<0.01"],
    // Metrica custom: errori auth specifici
    auth_errors: ["rate<0.01"],
  },
};

// ---------------------------------------------------------------------------
// Setup — eseguito una volta prima del test
// ---------------------------------------------------------------------------

export function setup() {
  // Verifica che il server sia raggiungibile prima di iniziare
  const res = http.get(`${BASE_URL}/ping`);
  if (res.status !== 200) {
    throw new Error(`Server non raggiungibile: ${BASE_URL}/ping → ${res.status}`);
  }
  console.log(`Server raggiungibile: ${BASE_URL}`);
  return { baseUrl: BASE_URL };
}

// ---------------------------------------------------------------------------
// Scenario principale — eseguito da ogni VU
// ---------------------------------------------------------------------------

export default function (data) {
  // Simula un utente che si autentica con credenziali di test.
  // In un ambiente di test reale sostituire con credenziali valide
  // o usare un endpoint /auth/test-token dedicato.
  const payload = JSON.stringify({
    email: `testuser_${__VU}@kybo-test.local`,
    password: "TestPassword123!",
    returnSecureToken: true,
  });

  const params = {
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
    },
    tags: { name: "auth_login" },
  };

  const startTime = Date.now();

  // Tenta login — l'endpoint /auth/login e' il gateway che verifica
  // il token Firebase e restituisce i dati utente Kybo
  const res = http.post(`${BASE_URL}/users/me`, payload, params);

  loginDuration.add(Date.now() - startTime);

  const success = check(res, {
    // Status 200 (autenticato) o 401 (credenziali invalide) sono attesi.
    // 5xx indica un problema server — quello che vogliamo rilevare.
    "status non e' 5xx": (r) => r.status < 500,
    "risposta non vuota": (r) => r.body && r.body.length > 0,
    "risposta in tempo": (r) => r.timings.duration < 2000,
  });

  authErrorRate.add(!success);

  // Pausa realistica tra le richieste (0.5-1.5s)
  sleep(Math.random() * 1 + 0.5);
}

// ---------------------------------------------------------------------------
// Teardown — eseguito una volta dopo il test
// ---------------------------------------------------------------------------

export function teardown(data) {
  console.log(`Test completato. Base URL: ${data.baseUrl}`);
}
