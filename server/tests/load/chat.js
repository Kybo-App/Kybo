/**
 * k6 Load Test — Chat
 *
 * Testa gli endpoint di messaggistica: GET /chat/messages e POST /chat/send.
 * Il chat e' l'endpoint con il maggiore throughput in produzione (molti
 * utenti leggono/scrivono in tempo reale).
 *
 * Profilo di carico:
 *   - Steady 200 VU per 3 minuti
 *
 * Soglie (stringenti, il chat deve essere veloce):
 *   - p95 < 500ms
 *   - error rate < 1%
 *
 * Utilizzo:
 *   k6 run \
 *     --env BASE_URL=https://kybo-test.onrender.com \
 *     --env TEST_TOKEN=<firebase_id_token> \
 *     chat.js
 */

import http from "k6/http";
import { check, sleep, group } from "k6";
import { Rate, Trend } from "k6/metrics";

// ---------------------------------------------------------------------------
// Configurazione
// ---------------------------------------------------------------------------

const BASE_URL   = __ENV.BASE_URL   || "http://localhost:8000";
const TEST_TOKEN = __ENV.TEST_TOKEN || "";

const chatReadErrors  = new Rate("chat_read_errors");
const chatWriteErrors = new Rate("chat_write_errors");
const readDuration    = new Trend("chat_read_duration_ms",  true);
const writeDuration   = new Trend("chat_write_duration_ms", true);

export const options = {
  stages: [
    { duration: "3m", target: 200 }, // steady 200 VU per 3 minuti
  ],
  thresholds: {
    // Chat deve rispondere velocemente
    http_req_duration: ["p(95)<500"],
    http_req_failed:   ["rate<0.01"],
    chat_read_errors:  ["rate<0.01"],
    chat_write_errors: ["rate<0.01"],
  },
};

// ---------------------------------------------------------------------------
// Setup
// ---------------------------------------------------------------------------

export function setup() {
  const res = http.get(`${BASE_URL}/ping`);
  if (res.status !== 200) {
    throw new Error(`Server non raggiungibile: ${BASE_URL}/ping → ${res.status}`);
  }
  if (!TEST_TOKEN) {
    console.warn("ATTENZIONE: TEST_TOKEN non impostato. Le richieste autenticate riceveranno 401.");
  }
  return { baseUrl: BASE_URL };
}

// ---------------------------------------------------------------------------
// Scenario principale
// Ogni VU simula un utente che alterna lettura e scrittura messaggi
// ---------------------------------------------------------------------------

export default function (data) {
  const authHeader = TEST_TOKEN
    ? { "Authorization": `Bearer ${TEST_TOKEN}` }
    : {};

  const commonHeaders = {
    "Content-Type": "application/json",
    "Accept":       "application/json",
    ...authHeader,
  };

  // Simula un ID chat realistico (in test usare un chatId esistente)
  const chatId = `test_chat_${(__VU % 10) + 1}`; // 10 chat di test in round-robin

  // --- GET messaggi ---
  group("chat_read", function () {
    const startTime = Date.now();

    const res = http.get(
      `${BASE_URL}/chat/${chatId}/messages?limit=20`,
      { headers: commonHeaders, tags: { name: "chat_get_messages" } }
    );

    readDuration.add(Date.now() - startTime);

    const ok = check(res, {
      "GET messages: status non 5xx": (r) => r.status < 500,
      "GET messages: risposta rapida": (r) => r.timings.duration < 500,
    });

    chatReadErrors.add(!ok);
  });

  sleep(0.2); // breve pausa tra read e write (comportamento realistico)

  // --- POST messaggio (70% letture, 30% scritture — simula pattern reale) ---
  if (Math.random() < 0.3) {
    group("chat_write", function () {
      const payload = JSON.stringify({
        chat_id: chatId,
        message: `Messaggio di test da VU ${__VU} — ${new Date().toISOString()}`,
        sender_id: `test_user_${__VU}`,
      });

      const startTime = Date.now();

      const res = http.post(
        `${BASE_URL}/chat/send`,
        payload,
        { headers: commonHeaders, tags: { name: "chat_send_message" } }
      );

      writeDuration.add(Date.now() - startTime);

      const ok = check(res, {
        "POST send: status non 5xx":  (r) => r.status < 500,
        "POST send: risposta rapida":  (r) => r.timings.duration < 500,
      });

      chatWriteErrors.add(!ok);
    });
  }

  // Pausa realistica: gli utenti chat leggono ogni ~1-2 secondi
  sleep(Math.random() * 1 + 0.5);
}

export function teardown(data) {
  console.log("Test chat completato.");
}
