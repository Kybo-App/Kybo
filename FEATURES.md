# Kybo — Mappa Completa delle Feature

> Generato il 2026-02-28. Aggiornare manualmente a ogni nuova feature implementata.

**Legenda ruoli:**
- 🔴 Admin only
- 🟡 Admin + Nutritionist
- 🟢 Tutti gli utenti autenticati
- 🌐 Pubblico (no auth)

---

## 1. SERVER — API Backend (FastAPI)

### Autenticazione & Sessioni

| Endpoint | Metodo | Ruolo | Descrizione |
|----------|--------|-------|-------------|
| Firebase Auth | — | 🌐 | Login email/password, OAuth, passwordless via Firebase |
| `/admin/session/revoke/{uid}` | POST | 🔴 | Forza logout utente da tutti i dispositivi |
| `/admin/session/revoke-self` | POST | 🟢 | Logout personale da altri dispositivi |

### Gestione Utenti (`/admin`)

| Endpoint | Metodo | Ruolo | Descrizione |
|----------|--------|-------|-------------|
| `/admin/create-user` | POST | 🟡 | Crea nuovo utente (email, password policy 12+ char, ruolo) |
| `/admin/update-user/{uid}` | PUT | 🔴 | Modifica email, nome, bio, specializzazioni, max clienti |
| `/admin/assign-user` | POST | 🔴 | Assegna cliente a nutrizionista (con verifica limite) |
| `/admin/unassign-user` | POST | 🔴 | Rimuove assegnazione, ripristina utente a `independent` |
| `/admin/delete-user/{uid}` | DELETE | 🟡 | Cancellazione GDPR completa (tutti i dati) |
| `/admin/delete-diet/{diet_id}` | DELETE | 🟡 | Elimina dieta dallo storico (audit log tracciato) |
| `/admin/sync-users` | POST | 🔴 | Sincronizza Firebase Auth ↔ Firestore, risolve duplicati email |
| `/admin/users-secure` | GET | 🟡 | Lista utenti con audit log in background (fire-and-forget) |
| `/admin/user-details-secure/{uid}` | GET | 🟡 | Dettagli singolo utente con audit trail |
| `/admin/user-history/{uid}` | GET | 🟡 | Storico diete utente (max 50 documenti) |
| `/admin/log-access` | POST | 🟡 | Registra accesso manuale a dati sensibili (GDPR audit) |

### Gestione Diete (`/diet`)

| Endpoint | Metodo | Ruolo | Descrizione |
|----------|--------|-------|-------------|
| `/upload-diet` | POST | 🟢 | Upload PDF dieta self-service (parsing asincrono RQ queue) |
| `/upload-diet/{uid}` | POST | 🟡 | Upload dieta per altro utente (parser personalizzato del nutrizionista) |
| `/diet/job/{job_id}` | GET | 🟢 | Controlla stato job parsing asincrono (ownership check) |
| `/scan-receipt` | POST | 🟢 | Scansione scontrino: Tesseract OCR + Gemini AI fuzzy matching (10/ora) |
| `/export-diet-pdf` | GET | 🟢 | Esporta dieta corrente in PDF (FPDF, server-side) |
| `/import-diet` | POST | 🟢 | Importa dieta da CSV (MyFitnessPal, Yazio) |
| `/admin/upload-parser/{uid}` | POST | 🔴 | Configura prompt parser personalizzato per nutrizionista (max 50KB) |

### Chat (`/chat`)

| Endpoint | Metodo | Ruolo | Descrizione |
|----------|--------|-------|-------------|
| `/chat/upload-attachment` | POST | 🟡 | Upload allegato chat (jpg/png/pdf) → URL firmato Firebase (1h) |

### Analytics (`/admin/analytics`)

| Endpoint | Metodo | Ruolo | Descrizione |
|----------|--------|-------|-------------|
| `/admin/analytics/overview` | GET | 🟡 | KPI generali: utenti totali/attivi, diete, messaggi (filtrato per nutrizionista) |
| `/admin/analytics/diet-trend` | GET | 🟡 | Trend upload diete (daily/weekly/monthly) |
| `/admin/analytics/nutritionist-activity` | GET | 🟡 | Attività nutrizionisti: clienti, diete, messaggi, tempo risposta |
| `/admin/analytics/inactive-users` | GET | 🟡 | Lista utenti inattivi (filtro giorni configurabile) |
| `/admin/analytics/meal-completion/{uid}` | GET | 🟡 | % aderenza dieta (pasti pianificati vs registrati) |

### Report Mensili (`/admin/reports`)

| Endpoint | Metodo | Ruolo | Descrizione |
|----------|--------|-------|-------------|
| `/admin/reports/monthly` | GET | 🟡 | Recupera report mensile (nutrizionista vede solo il suo) |
| `/admin/reports/generate` | POST | 🟡 | Genera/rigenera report mensile (force_regenerate opzionale) |
| `/admin/reports/list` | GET | 🟡 | Lista report disponibili (max 50, ordinati per data) |
| `/admin/reports/{report_id}` | GET | 🟡 | Recupera report specifico per ID |
| `/admin/reports/{report_id}` | DELETE | 🔴 | Elimina report (operazione irreversibile) |

### GDPR & Privacy (`/gdpr`)

| Endpoint | Metodo | Ruolo | Descrizione |
|----------|--------|-------|-------------|
| `/gdpr/consent` | POST | 🟢 | Registra consenso GDPR (timestamp, versione, IP) |
| `/gdpr/consent` | GET | 🟢 | Legge stato consensi utente corrente |
| `/gdpr/export` | GET | 🟢 | Export dati personali (Art. 20 GDPR) in JSON |
| `/gdpr/export/{uid}` | GET | 🟡 | Export dati per conto di un utente (con audit log) |
| `/gdpr/admin/dashboard` | GET | 🔴 | Dashboard retention: statistiche inattività utenti |
| `/gdpr/admin/retention-config` | GET | 🔴 | Legge configurazione retention policy |
| `/gdpr/admin/retention-config` | POST | 🔴 | Aggiorna retention policy (6–120 mesi, dry-run toggle) |
| `/gdpr/admin/purge-inactive` | POST | 🔴 | Purge Art. 17 GDPR: elimina utenti inattivi (dry-run o reale) |

### Comunicazione (`/admin/communication`)

| Endpoint | Metodo | Ruolo | Descrizione |
|----------|--------|-------|-------------|
| `/admin/communication/email-alert-config` | GET | 🟡 | Legge config alert email messaggi non letti |
| `/admin/communication/email-alert-config` | POST | 🟡 | Salva config alert email (threshold 1–30 giorni) |
| `/admin/communication/broadcast` | POST | 🟡 | Invia broadcast a tutti i propri clienti (batch 400 ops) |
| `/admin/communication/notes/{uid}` | GET | 🟡 | Leggi note interne su un cliente (solo proprietario) |
| `/admin/communication/notes/{uid}` | POST | 🟡 | Crea nota interna (max 10 KB, categorie: general/medical/billing) |
| `/admin/communication/notes/{uid}/{note_id}` | PUT | 🟡 | Aggiorna nota (content, category, pinned) |
| `/admin/communication/notes/{uid}/{note_id}` | DELETE | 🟡 | Elimina nota (solo autore o admin) |

### Suggerimenti Pasti & AI (`/meal-suggestions`)

| Endpoint | Metodo | Ruolo | Descrizione |
|----------|--------|-------|-------------|
| `/meal-suggestions` | GET | 🟢 | Genera suggerimenti AI Gemini 2.5 Flash (cache L1 RAM 30min + Firestore 30gg) |

### Two-Factor Authentication (`/admin/2fa`)

| Endpoint | Metodo | Ruolo | Descrizione |
|----------|--------|-------|-------------|
| `/admin/2fa/setup` | POST | 🟡 | Genera secret TOTP e QR code (non salvato fino a verifica) |
| `/admin/2fa/verify` | POST | 🟡 | Verifica codice TOTP e attiva 2FA (genera backup codes) |
| `/admin/2fa/validate` | POST | 🟢 | Valida codice 2FA per login (TOTP o backup code) |
| `/admin/2fa/disable` | POST | 🟡 | Disabilita 2FA (verifica codice obbligatoria) |
| `/admin/2fa/status` | GET | 🟢 | Controlla se 2FA è abilitato per l'utente corrente |
| `/admin/2fa/backup-codes/regenerate` | POST | 🟡 | Rigenera codici backup (invalida i vecchi) |

### Configurazione App (`/admin/config`)

| Endpoint | Metodo | Ruolo | Descrizione |
|----------|--------|-------|-------------|
| `/admin/config/maintenance` | GET | 🔴 | Legge stato modalità manutenzione |
| `/admin/config/maintenance` | POST | 🔴 | Attiva/disattiva manutenzione manuale |
| `/admin/schedule-maintenance` | POST | 🔴 | Programma manutenzione futura (data + messaggio + broadcast) |
| `/admin/cancel-maintenance` | POST | 🔴 | Annulla manutenzione programmata |
| `/admin/config/app` | GET | 🔴 | Legge configurazione globale app |
| `/admin/config/app` | POST | 🔴 | Aggiorna configurazione (Gemini model, notifiche, limiti upload) |

### Monitoring & Health (`/health`, `/metrics`)

| Endpoint | Metodo | Ruolo | Descrizione |
|----------|--------|-------|-------------|
| `/health` | GET | 🌐 | Health check base (status: ok/degraded) |
| `/health/detailed` | GET | 🌐 | Health check dettagliato (Firestore, Gemini, Tesseract, Redis) |
| `/metrics` | GET | 🌐 | Metriche Prometheus (scraping automatico) |
| `/metrics/api` | GET | 🌐 | Metriche API in JSON (calls, cache hit ratio, errori, OCR stats) |
| `/docs` | GET | 🌐 | Swagger UI (FastAPI auto-generated) |

### Background Workers (RQ / Cron)

| Worker | Frequenza | Descrizione |
|--------|-----------|-------------|
| `unread_notifier` | Configurabile | Monitora messaggi non letti, invia email alert dopo X giorni (limit 500 chat, 2000 config) |
| `monthly_report_mailer` | Mensile | Genera e invia report mensili a tutti i nutrizionisti/admin (limit 5000 utenti) |

---

## 2. ADMIN PANEL — Flutter Web

> Ruoli con accesso: **admin** (accesso completo) · **nutritionist** (accesso limitato al proprio)

### Login & Autenticazione

| Feature | Ruolo | Descrizione |
|---------|-------|-------------|
| Login email/password | 🟡 | Firebase Auth con redirect automatico su 401 |
| 2FA al login | 🟡 | Prompt codice TOTP dopo credenziali se 2FA abilitato |
| Cambio password al primo accesso | 🟡 | Schermata obbligatoria se `requires_password_change = true` |
| Validazione password policy | 🟡 | Min 12 char, maiuscola, minuscola, numero |
| Logout con conferma | 🟡 | Pulisce stato, revoca sessione Firebase |

### Dashboard & Navigazione

| Feature | Ruolo | Descrizione |
|---------|-------|-------------|
| Navigazione pill-based 8 sezioni | 🟡 | Utenti, Analytics, Chat, Config, GDPR, Reports, Calcolo, Metriche |
| Ricerca globale utenti | 🟡 | Ctrl+K — cerca per nome/email in Firestore |
| Scorciatoie tastiera | 🟡 | Ctrl+N nuovo utente, Ctrl+1–8 cambio tab, ? aiuto |
| Multi-lingua IT/EN | 🟡 | Toggle lingua nella top bar |
| Tema adattivo (light/dark) | 🟡 | Rilevamento automatico sistema |

### Gestione Utenti

| Feature | Ruolo | Descrizione |
|---------|-------|-------------|
| Lista utenti con filtro ruolo | 🟡 | Real-time da Firestore, raggruppati per nutrizionista |
| Ricerca real-time nome/email | 🟡 | Filtraggio istantaneo lato client |
| Crea utente | 🟡 | Form con email, nome, ruolo, password temporanea, max clienti |
| Modifica utente | 🟡 | Email, nome, bio, specializzazioni, telefono, max clienti |
| Elimina utente | 🟡 | Cancellazione GDPR completa con conferma doppia |
| Assegna cliente a nutrizionista | 🔴 | Dialog picker con verifica limite max clienti |
| Rimuovi assegnazione | 🔴 | Ripristina utente a `independent` |
| Carica dieta per utente | 🟡 | PDF picker → upload asincrono con polling job status |
| Sincronizza utenti Firebase | 🔴 | Risolve incoerenze Auth ↔ Firestore |
| Indicatore 2FA attivo | 🔴 | Badge nella lista utenti |
| Verifica limite clienti | 🟡 | Blocca assegnazione se nutrizionista ha raggiunto il limite |

### Analytics

| Feature | Ruolo | Descrizione |
|---------|-------|-------------|
| Overview KPI | 🟡 | Utenti totali, attivi 30gg, breakdown per ruolo |
| Trend diete | 🟡 | Grafico lineare (fl_chart), daily/weekly/monthly |
| Attività nutrizionisti | 🔴 | Clienti, diete caricate, messaggi, tempo risposta medio |
| Utenti inattivi | 🟡 | Filtro giorni (7–365), nutrizionista vede solo i suoi |
| Completamento pasti % | 🟡 | Aderenza dieta settimanale per utente selezionato |

### Chat

| Feature | Ruolo | Descrizione |
|---------|-------|-------------|
| Split layout lista/messaggi | 🟡 | Lista sx (350px), chat dx |
| Messaggi real-time | 🟡 | Stream Firestore con timestamp |
| Upload allegati chat | 🟡 | jpg/png/pdf con preview lato mittente |
| Broadcast messaggio | 🟡 | Invia a tutti i propri clienti in una sola azione |
| Config alert email non letti | 🟡 | Toggle + slider giorni (1–30) |
| Badge unread counter | 🟡 | Aggiornato in tempo reale |
| Crea nuova chat | 🔴 | Admin può aprire chat con qualsiasi utente |

### Note Interne (CRM)

| Feature | Ruolo | Descrizione |
|---------|-------|-------------|
| Visualizza note cliente | 🟡 | Lista note visibili solo al professionista |
| Crea nota | 🟡 | Categorie: general, medical, billing. Max 10 KB |
| Modifica nota | 🟡 | Content, category, pin/unpin |
| Elimina nota | 🟡 | Solo autore o admin |

### Configurazione

| Feature | Ruolo | Descrizione |
|---------|-------|-------------|
| Toggle manutenzione manuale | 🔴 | Attiva/disattiva istantaneamente |
| Programma manutenzione | 🔴 | Seleziona data/ora + messaggio personalizzato |
| Broadcast notifica manutenzione | 🔴 | Opzionale al momento della schedulazione |
| Configura Gemini model | 🔴 | Seleziona modello AI per parsing diete |
| Configura notifiche app | 🔴 | Toggle push, email |
| Configura limiti upload | 🔴 | Dimensione massima file PDF |

### GDPR & Privacy

| Feature | Ruolo | Descrizione |
|---------|-------|-------------|
| Dashboard retention | 🔴 | Statistiche utenti inattivi per mese |
| Configura retention policy | 🔴 | Mesi di inattività (6–120), attiva/disattiva, dry-run |
| Simula purge (dry-run) | 🔴 | Mostra preview utenti che verrebbero eliminati |
| Purge batch utenti inattivi | 🔴 | Elimina GDPR-compliant con doppia conferma |
| Purge singolo utente | 🔴 | Elimina dati di un singolo utente specificato |
| Audit log accesso dati | 🟡 | Tabella real-time con export CSV |

### Report Mensili

| Feature | Ruolo | Descrizione |
|---------|-------|-------------|
| Lista report disponibili | 🟡 | Nutrizionista vede solo i suoi, admin vede tutti |
| Filtri report | 🟡 | Per nutrizionista, mese, anno |
| Visualizza dettagli report | 🟡 | KPI: clienti, diete, messaggi, tempo risposta |
| Genera/rigenera report | 🟡 | On-demand, force_regenerate opzionale |
| Download PDF report | 🟡 | Generato lato client da dati JSON |

### Calcolatrice Nutrizionale

| Feature | Ruolo | Descrizione |
|---------|-------|-------------|
| Aggiunta ingredienti | 🟡 | Nome + quantità (g/ml) |
| Calcolo macros real-time | 🟡 | Kcal, proteine, carboidrati, grassi per 100g |
| Totali sommati | 🟡 | Aggregazione automatica di tutti gli ingredienti |

### Metriche Server

| Feature | Ruolo | Descrizione |
|---------|-------|-------------|
| Stato servizi | 🔴 | Gemini, OCR, Redis, Firestore (ok/warning/error) |
| Contatori API | 🔴 | Calls totali, error rate, throughput |
| Cache hit ratio | 🔴 | % di richieste servite da cache |
| Health check infrastruttura | 🔴 | Dettaglio di ogni componente |

### Sicurezza Account

| Feature | Ruolo | Descrizione |
|---------|-------|-------------|
| Setup 2FA (TOTP) | 🟡 | QR code + verifica codice + generazione backup codes |
| Disabilita 2FA | 🟡 | Con verifica codice TOTP obbligatoria |
| Cambio password | 🟡 | Policy: 12+ char, maiuscola, minuscola, numero |

---

## 3. CLIENT APP — Flutter Mobile (iOS/Android)

> Ruoli con accesso: **client** · **independent** (utente senza nutrizionista assegnato)

### Onboarding & Autenticazione

| Feature | Ruolo | Descrizione |
|---------|-------|-------------|
| Schermata onboarding | 🌐 | Scelta tipo utente: con nutrizionista vs indipendente |
| Inserimento codice invito | 🌐 | Dialog per codice nutrizionista (cap 64 char) |
| Login email/password | 🌐 | Firebase Auth |
| Deep link al login | 🌐 | Apertura da link invito con codice pre-compilato |
| Splash screen | 🌐 | Check auth state → redirect automatico |
| Tutorial interattivo | 🟢 | Showcase multi-step al primo accesso (resettabile) |
| Jailbreak/root detection | 🟢 | Avviso su dispositivi compromessi |

### Piano Alimentare

| Feature | Ruolo | Descrizione |
|---------|-------|-------------|
| Visualizzazione piano giornaliero | 🟢 | Pasti del giorno con piatti e quantità |
| Navigazione settimanale | 🟢 | Selezione settimana e giorno con tab |
| Supporto multi-settimana | 🟢 | Piani alimentari con più settimane |
| Checkbox consumo pasto | 🟢 | Traccia pasti completati |
| Selezione porzioni | 🟢 | Moltiplicatore 1×/2×/3× per ogni piatto |
| Swap piatto (sostituzione) | 🟢 | Sostituzioni per codice CAD con drag-drop dialog |
| Diario alimentare | 🟢 | Note giornaliere, umore (emoji), foto opzionale |
| Indicatore "oggi" | 🟢 | Evidenziazione giorno corrente vs passato/futuro |
| Upload dieta PDF (independ.) | 🟢 | Self-service per utenti independent |
| Import dieta CSV | 🟢 | Da MyFitnessPal, Yazio |
| Storico diete cloud | 🟢 | Lista diete precedenti con ripristino/eliminazione |
| Export dieta PDF | 🟢 | Download PDF del piano attuale |
| Banner prossimo pasto | 🟢 | Indica il prossimo pasto della giornata |

### Dispensa

| Feature | Ruolo | Descrizione |
|---------|-------|-------------|
| Lista ingredienti | 🟢 | Con quantità e unità di misura |
| Aggiunta manuale | 🟢 | Nome, quantità, unità |
| Rimozione swipe | 🟢 | Swipe-to-delete con conferma |
| Ricerca/filtro | 🟢 | Filtro real-time per nome |
| Scansione scontrino OCR | 🟢 | FAB → picker immagine → Tesseract + Gemini AI |
| Layout tablet (griglia) | 🟢 | Grid adattiva su schermi larghi |

### Lista della Spesa

| Feature | Ruolo | Descrizione |
|---------|-------|-------------|
| Generazione automatica da dieta | 🟢 | Calcola ingredienti mancanti (dieta − dispensa) |
| Raggruppamento per categoria | 🟢 | Corsia del supermercato (frutta, carne, latticini, ecc.) |
| Stima budget totale | 🟢 | Calcolo costo stimato con prezzi configurati |
| Checkmark items | 🟢 | Marca items come acquistati |
| Sposta a/da dispensa | 🟢 | Trasferimento diretto alla dispensa |
| Condivisione lista | 🟢 | Share via WhatsApp, email, ecc. (Share Plus) |
| Filtro per pasto/giorno | 🟢 | Genera lista solo per selezione specifica |

### Chat con Nutrizionista

| Feature | Ruolo | Descrizione |
|---------|-------|-------------|
| Messaggi real-time | 🟢 | Stream Firestore |
| Invio testo | 🟢 | Messaggi di testo |
| Upload allegati | 🟢 | jpg/png/pdf con picker e preview |
| Auto-scroll a messaggio recente | 🟢 | Scroll automatico all'apertura |
| Mark as read | 🟢 | Segna come letto al focus sulla schermata |
| Indicatore upload | 🟢 | Progress durante upload allegati |

### Statistiche & Tracking

| Feature | Ruolo | Descrizione |
|---------|-------|-------------|
| Aderenza settimanale % | 🟢 | Pasti completati vs pianificati |
| Grafico peso | 🟢 | fl_chart lineare ultimi 30gg con trend line |
| Streak giornaliero | 🟢 | Giorni consecutivi di completamento dieta |
| Input peso manuale | 🟢 | Registrazione con timestamp |
| Obiettivi personalizzati | 🟢 | Peso target, kcal/giorno (CRUD) |
| Statistiche settimanali | 🟢 | Media kcal, bilanciamento macro |

### Suggerimenti AI

| Feature | Ruolo | Descrizione |
|---------|-------|-------------|
| Suggerimenti pasti Gemini | 🟢 | AI contestualizzata su dieta, allergeni, preferenze |
| Filtro per tipo pasto | 🟢 | Colazione/Pranzo/Merenda/Cena |
| Modalità dispensa | 🟢 | Ricette con ingredienti già disponibili |
| Numero suggerimenti custom | 🟢 | Configura quanti risultati ricevere |
| Card dettagliata | 🟢 | Nome, qty, ingredienti, kcal stimata, descrizione |

### Gamification

| Feature | Ruolo | Descrizione |
|---------|-------|-------------|
| Badge sbloccabili | 🟢 | Achievement per azioni specifiche (es. 7 giorni consecutivi) |
| Livelli utente (1–10) | 🟢 | Con emoji e progress bar verso livello successivo |
| Notifiche unlock | 🟢 | Dialog animato al raggiungimento badge/livello |
| Sfide settimanali | 🟢 | Es. "prova 3 nuove ricette questa settimana" |

### Bilancia Smart

| Feature | Ruolo | Descrizione |
|---------|-------|-------------|
| Connessione BLE | 🟢 | Scansione e pairing dispositivi Bluetooth LE |
| Connessione Withings | 🟢 | Integrazione API Withings scale |
| Sync peso automatico | 🟢 | Aggiornamento automatico al peso rilevato |
| Cronologia peso | 🟢 | Storico misurazioni dal dispositivo |

### Impostazioni

| Feature | Ruolo | Descrizione |
|---------|-------|-------------|
| Dark mode toggle | 🟢 | Cambia tema (ThemeProvider) |
| Allarmi pasti | 🟢 | Time picker per ogni tipo pasto (colazione, pranzo, ecc.) |
| Budget spesa | 🟢 | Configura prezzi medi ingredienti |
| Cambio password | 🟢 | Con validazione policy 12+ char |
| Privacy & GDPR | 🟢 | Info consensi e diritti utente |
| Reset tutorial | 🟢 | Riavvia il tutorial interattivo |
| Notifiche | 🟢 | Abilita/disabilita push notifications |
| Logout | 🟢 | Con conferma, pulisce tutti i dati locali |

### Assistenti Vocali & Widget

| Feature | Ruolo | Descrizione |
|---------|-------|-------------|
| Siri / Google Assistant | 🟢 | "Cosa mangio a pranzo?" → risposta con piano |
| Widget home screen | 🟢 | Prossimo pasto e lista spesa (iOS/Android) |
| App Shortcuts | 🟢 | Azioni rapide da icona app |

### Layout Adattivo

| Feature | Ruolo | Descrizione |
|---------|-------|-------------|
| Modalità tablet | 🟢 | Layout sidebar + contenuto ottimizzato per schermi >600dp |
| Modalità telefono | 🟢 | Navbar bottom pill-style |

---

## 4. LANDING PAGE — Next.js (kybo.it)

> Sito pubblico, nessuna autenticazione richiesta. Lingua: IT + EN (`/en`)

### Pagine Principali

| Pagina | URL | Descrizione |
|--------|-----|-------------|
| Home | `/` | Hero + features + stats + mockup + comparison + CTA |
| Business (B2B) | `/business` | Landing per nutrizionisti con pitch, feature pro, ROI calculator |
| Chi Siamo | `/about` | Missione aziendale, storia, team |
| Prezzi | `/pricing` | Piani (free/pro/enterprise) con toggle mensile/annuale |
| FAQ | `/faq` | Domande frequenti con accordion collapsible |
| Contatti | `/contact` | Form contatti (email, oggetto, messaggio) |
| Supporto | `/help` | Centro aiuto e documentazione |
| Privacy Policy | `/privacy` | Informativa GDPR e cookie policy |
| Termini di Servizio | `/terms` | Condizioni d'uso e disclaimer |
| Cookie Policy | `/cookies` | Dettaglio cookie utilizzati e consenso |
| Versione EN | `/en` | Traduzione completa in inglese delle sezioni principali |

### Sezioni Homepage

| Sezione | Descrizione |
|---------|-------------|
| Navbar | Navigazione responsive con mobile menu hamburger |
| Hero | Titolo principale + CTA + GSAP parallax animation |
| Feature Cards | 6 feature card con scroll-triggered animations (GSAP) |
| Stats Section | KPI numerici con counter animato allo scroll |
| App Mockup | Preview smartphone con schermate dell'app |
| Comparison Table | Kybo vs gestione manuale vs altri tool |
| Testimonials | Carousel recensioni utenti |
| Newsletter | Form iscrizione email |
| CTA Section | Call-to-action finale con link App Store / Google Play |
| Footer | Link utili, social, copyright |

### Feature Tecniche Landing

| Feature | Descrizione |
|---------|-------------|
| i18n (IT/EN) | Percorso `/en` con tutti i componenti tradotti |
| Dark mode | Supporto tema scuro via CSS variables |
| Lazy loading | `dynamic()` Next.js per componenti below-the-fold |
| SEO | Metadata OpenGraph, Twitter Card, canonical URL per ogni pagina |
| Schema.org JSON-LD | SoftwareApplication, Organization, WebSite markup |
| Sitemap + robots.txt | Ottimizzati in `/public` |
| Lighthouse ottimizzato | metadataBase, per-page title template |
| Security headers | `_headers` file: CSP, X-Frame-Options, HSTS, nosniff, Referrer-Policy |
| GSAP animations | ScrollTrigger, parallax, counter animations |
| Three.js | Effetti 3D interattivi (background hero) |

---

## Stack Tecnologico Riepilogativo

| Layer | Tecnologia |
|-------|-----------|
| Backend | Python 3.11 · FastAPI · uvicorn |
| Database | Firebase Firestore · Firebase Storage |
| Auth | Firebase Authentication (email/password, OAuth) |
| AI | Google Gemini 2.5 Flash (diet parsing, meal suggestions) |
| OCR | Tesseract 4 + `tesseract-ocr-ita` + pytesseract |
| Cache | L1 RAM (in-memory, 100 entries, 1h) · L2 Redis · L3 Firestore (30gg) |
| Queue | Python RQ (async diet parsing) |
| Monitoring | Prometheus + Sentry |
| Admin | Flutter Web · Provider · fl_chart |
| Client | Flutter Mobile (iOS/Android) · Provider |
| Landing | Next.js 14 (App Router) · GSAP · Three.js · TypeScript |
| Deploy | Render (server Docker) · Render Static (landing) |
| CI/CD | GitHub Actions |
