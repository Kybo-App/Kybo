# Kybo - Roadmap

---

## SUBITO (completato)

### 1. Backend - Backup Firestore ✅
### 2. Backend - Sentry & Alerting ✅
### 3. Backend - Health Check ✅
- [x] ⚠️ TODO: Fixare Tesseract su Render dev → risolto con nixpacks.toml (commit 350ef4d)
### 4. Backend - CI/CD ✅
### 5. GDPR Base (Obbligo Legale) ✅
### 6. Client - Tracking & Statistiche ✅
### 7. Admin - Calcolatrice Nutrizionale & Alert Diete ✅
### 8. Admin - Gestione Nutrizionisti ✅
### 9. Backend - Riconoscimento Allergeni ✅
### 10. Admin - Allegati Chat ✅
### 11. Admin - Notifiche In-App ✅
### 12. Client - Deep Link & Onboarding ✅
### 13. Client - Badge & Achievement ✅
### 14. Client - Accessibilità ✅
### 15. Admin - Analytics Dashboard ✅
### 16. Client - Chat Media Support ✅

---

## FUTURO (alta priorità)

> Ogni feature è organizzata per implementazione end-to-end:
> backend → admin/client → test. Per le feature admin, il ruolo che
> può accedervi è indicato con 🔴 Admin only, 🟡 Entrambi (admin + nutritionist).

---

### Feature 1: GDPR Avanzato ✅
> Estensione del GDPR base. 🔴 Admin only (compliance di sistema)

**Backend:**
- [x] Servizio retention policy: cloud function o cron che elimina dati dopo X mesi di inattività
- [x] Endpoint `GET /admin/gdpr/dashboard` → stato consensi di tutti gli utenti, date ultimo accesso, dati da eliminare (🔴 verify_admin)
- [x] Endpoint `POST /admin/gdpr/retention-config` → configura periodo retention (🔴 verify_admin)
- [x] Endpoint `POST /admin/gdpr/purge-inactive` → elimina manualmente dati utenti inattivi (🔴 verify_admin)

**Admin:**
- [x] Nuovo sotto-tab o sezione in Settings → "GDPR & Privacy" (admin only)
- [x] Dashboard con tabella consensi (utente, data consenso, ultimo accesso, stato)
- [x] Configurazione retention policy (input mesi + toggle attiva/disattiva)
- [x] Pulsante purge manuale con conferma doppia
- [x] Indicatore visivo utenti prossimi alla scadenza retention

---

### Feature 2: Report Nutrizionisti ✅
> Report mensile automatico. 🟡 Entrambi (admin vede tutti i nutrizionisti, nutritionist vede il proprio)

**Backend:**
- [x] Servizio generazione report: raccoglie dati mese (clienti gestiti, diete caricate, messaggi, tempo risposta medio)
- [x] Endpoint `GET /admin/reports/monthly?nutritionist_id=X&month=YYYY-MM` → genera/scarica report (🟡 verify_professional)
- [x] Endpoint `GET /admin/reports/list` → lista report disponibili
- [x] Opzionale: invio automatico email con PDF allegato a fine mese

**Admin:**
- [x] Sezione "Report" accessibile da entrambi i ruoli (tab o sotto-sezione)
- [x] Selezione mese e nutrizionista (admin) o solo mese (nutritionist)
- [x] Visualizzazione report con metriche chiave
- [x] Pulsante download PDF
- [x] Storico report passati

---

### Feature 3: 2FA (Two-Factor Authentication) ✅
> Sicurezza login admin panel. 🟡 Entrambi (tutti gli utenti admin/nutritionist devono poterlo attivare)

**Backend:**
- [x] Endpoint `POST /admin/2fa/setup` → genera secret TOTP e QR code (🟡 verify_professional)
- [x] Endpoint `POST /admin/2fa/verify` → verifica codice TOTP e attiva 2FA
- [x] Endpoint `POST /admin/2fa/disable` → disattiva 2FA (con verifica password)
- [x] Endpoint `POST /admin/2fa/validate` → valida codice per login
- [x] Campo `two_factor_enabled` e `two_factor_secret` nel documento utente Firestore

**Admin:**
- [x] Schermata setup 2FA (mostra QR code, input codice verifica)
- [x] Step aggiuntivo nel flusso di login: dopo email/password, chiedi codice TOTP
- [x] Sezione in profilo utente per attivare/disattivare 2FA
- [x] Admin può vedere quali utenti hanno 2FA attivo (nella lista utenti)

---

## FUTURO (media priorità)


### Feature 5: Comunicazione Avanzata ✅
> Miglioramenti chat e comunicazione. 🟡 Entrambi (ma usato principalmente dal nutritionist)

**Backend:**
- [x] Endpoint `POST /admin/communication/broadcast` → messaggio a tutti i clienti del nutrizionista (🟡 verify_professional, nutritionist invia solo ai propri)
- [x] Servizio notifica email per messaggi non letti dopo X giorni (worker asincrono + aiosmtplib)
- [x] Endpoint CRUD note interne sul cliente (visibili solo al professionista) → `/admin/communication/notes/{client_uid}`

**Admin:**
- [x] Pulsante "Broadcast" nella chat → invia messaggio a tutti i propri clienti
- [x] Sezione "Note interne" nel profilo cliente (campo note visibile solo a admin/nutritionist)
- [x] Configurazione alert email per messaggi non letti (toggle + slider giorni nell'header Chat)

---

### Feature 6: Admin UX ✅
> Miglioramenti usabilità pannello. 🟡 Entrambi

**Admin:**
- [x] Scorciatoie da tastiera (Ctrl+N nuovo utente, Ctrl+K ricerca, Ctrl+1–8 cambio tab, ? aiuto)
- [x] Ricerca globale (cerca utenti) con dialog Ctrl+K e chip di navigazione rapida
- [x] Multi-lingua admin panel (italiano + inglese) con toggle IT/EN nella top bar

---

### Feature 7: Client - UX & Features ✅
> Miglioramenti app mobile.

- [x] Widget home screen (prossimo pasto, lista spesa)
- [x] Modalità tablet con layout ottimizzato
- [x] Condivisione lista spesa via link/WhatsApp
- [x] Raggruppamento lista spesa per corsia del supermercato
- [x] Prezzi stimati e budget tracking
- [x] Sfide settimanali gamification ("prova 3 nuove ricette questa settimana")

---

### Feature 8: Integrazioni Esterne
> Connessioni con servizi terzi. Client + Backend.

- [x] Sync con Google Fit / Apple Health (passi, peso, calorie bruciate) → health plugin + health_service.dart + UI in statistics_screen
- [x] Export dieta in formato PDF
- [x] Import dieta da altre app (MyFitnessPal, Yazio CSV)
- [x] Integrazione con bilancia smart (peso automatico)

---

### Feature 9: Landing Page
> Rifacimento completo landing.

**Design:**
- [x] Sezione comparison table (Kybo vs gestione manuale vs altri tool)
- [x] Mockup interattivo dell'app (click-through prototype embedded)
- [x] Animazione scroll-triggered per le feature cards
- [x] Dark mode per la landing page
- [x] Pagina pricing dedicata con toggle mensile/annuale

**SEO & Performance:**
- [x] Metadata OpenGraph e Twitter Card per condivisione social
- [x] Schema.org markup (SoftwareApplication, Organization, WebSite) JSON-LD
- [x] Sitemap.xml e robots.txt ottimizzati in /public/
- [x] i18n (versione inglese della landing page `/en`)
- [x] Lazy loading componenti below-the-fold con Suspense + dynamic loading
- [x] Lighthouse score optimization: metadataBase, per-page title template, canonical URLs

**Business Page:**
- [x] Form richiesta demo funzionante con calendar booking (Calendly embed)
- [x] Calcolatrice ROI ("quanto tempo risparmi con Kybo")
- [x] Sezione sicurezza e compliance dettagliata
- [x] Documentazione API pubblica per piano Enterprise

---

### Feature 10: Backend Infrastructure
> Miglioramenti tecnici backend.

**Performance:**
- [x] Redis cache layer (L1.5 distribuito tra RAM e Firestore, graceful fallback)
- [x] Queue system per parsing diete (RQ worker + fallback semaphore — worker.py)

**Monitoring:**
- [x] APM (Application Performance Monitoring) — Prometheus + prometheus-fastapi-instrumentator
- [x] Dashboard metriche API (latenza, error rate, throughput) — /metrics (Prometheus) + /metrics/api (JSON)

**AI / ML:**
- [x] Suggerimenti pasti basati su preferenze storiche dell'utente
- [x] OCR migliorato con pre-processing immagine (contrast, rotation, crop)

**Sicurezza:**
- [x] Session management avanzato (forza logout da altri dispositivi)
- [x] Penetration test report e remediation → server/docs/penetration-test.md + .github/workflows/security.yml (commit 201f5e4)

**DevOps:**
- [x] Database migration strategy → server/docs/migration-strategy.md (commit 201f5e4)
- [x] Load testing (k6/Locust) → server/tests/load/ (auth, diet_upload, chat, smoke) (commit 201f5e4)
- [x] Docker containerization per sviluppo locale

---

## FUTURO (bassa priorità)

### Client - Wearables & Voice
- [x] Siri/Google Assistant integration ("cosa mangio a pranzo?")
- [x] Sync con Google Fit / Apple Health (passi, peso, calorie bruciate) — Flutter plugin `health`

### Client - Shopping List (extra)
- [x] Preferenze supermercato (salva il tuo negozio preferito) → settings_screen.dart
- [x] Lista spesa condivisa via link (kybo.it/list?id=...) → shopping_share.py + landing/list/page.tsx

### Client - Ricette & Meal Prep
- [x] Suggerimenti ricette basate sugli ingredienti in dispensa
- [x] Timer cottura integrato → client/lib/screens/cooking_timer_screen.dart
- [x] Porzioni scalabili (cucino per 2, 4, 6 persone)

### Landing - Contenuti
- [x] Sezione testimonianze / recensioni utenti → landing/src/components/sections/TestimonialsSection.tsx
- [x] Video demo dell'app — VideoSection.tsx rimossa (da reintrodurre quando disponibile video reale)
- [x] Blog / articoli su nutrizione (SEO content marketing) → landing/src/app/blog/page.tsx
- [x] Sezione FAQ espandibile → landing/src/app/faq/page.tsx
- [x] Pagina "Chi Siamo" con storia e mission
- [x] Case study nutrizionisti → /case-study page completa (Dott.ssa Rossi, metriche, timeline)

### Landing - Pagine incomplete
- [ ] `/privacy` — Privacy Policy (testo legale GDPR completo)
- [ ] `/terms` — Termini di Servizio (testo legale completo)
- [ ] `/careers` — Pagina lavora con noi (posizioni aperte o messaggio "non ci sono posizioni aperte")
- [ ] `/help` — Centro assistenza (FAQ tecniche, guide utente, link contatto)

### Landing - Conversione
- [x] Form contatto funzionante → contact/page.tsx + POST /contact/submit (Firestore)
- [x] Newsletter signup con integrazione email marketing → NewsletterSection.tsx + POST /newsletter/subscribe
- [x] Popup/banner "prova gratuita" con timer → TrialPopup.tsx (appare dopo 8 sec)
- [ ] Chat widget supporto live → rimosso per ora, da valutare in futuro
- [ ] Link App Store reale → CTASection.tsx ha placeholder, aggiornare quando l'app iOS è su App Store
- [ ] Link Google Play reale → CTASection.tsx ha placeholder, aggiornare quando l'app è su Play Store
- [x] QR code per download diretto dell'app → CTASection.tsx (SVG inline)

### Client - Tecnico
- [x] `client/nul` → aggiunto al .gitignore
- [x] iOS Universal Links → `apple-app-site-association` creato + `Runner.entitlements` + pbxproj aggiornato
  - ⚠️ TODO: sostituire `XXXXXXXXXX` in `landing/public/.well-known/apple-app-site-association` con il vero Apple Team ID

### Al lancio / quando pronti
- [ ] Aggiornare URL App Store in CTASection.tsx
- [ ] Aggiornare URL Google Play in CTASection.tsx
- [x] VideoSection rimossa dalla landing


New TODOs:

- [x] Aggiungere le schede di allenamento e tutta l'unterfaccia necessaria e la gestione di eessere un personal trainer , sia nutrizionista che personal trainer  , e così ti da le pagine solo necessarie al tuo account 
- [x] preparare un sistema di reward per l'app con reward inseribili dall'admin panel , default vuoto 
- [x] agli utenti indipendenti dare la possibilità di volere un nutrizionista/personal trainer e kybo ti mette in contatto con lui in base a dove vivi e al budget che hai a disposizione e all'obbiettivo che hai 
- [x] i18n admin completo IT/EN — AppLocalizations esteso con ~450 chiavi totali. Tutte le view principali localizzate: MyDayView, workout templates, bulk actions, load-more, export PDF, change_password_screen, diet_templates_view, audit_log_view, matchmaking_board_view, nutritional_calculator_view, gdpr_privacy_view, _UserDetailPane, dashboard nav, rewards_catalog_view, chat_management_view (con email alert config), reports_view (incluso PDF generator), analytics_view, config_view (manutenzione), server_metrics_view (4 sezioni + cache), workout_management_view (+ day presets), two_factor_setup_screen, user_management_view (delete/assign/create/notes/parser/history dialogs + filtri). Resto: edit user dialog completo + workout activity row.
- [x] da admin devo poter modificare il ruolo di un nutri o pt 
- [x] in analytics vedo i dati in chiaro degli utenti , se sono admin non dovrei , come nutri o pt si 
- [x] bisogna lavorare su come un new workout viene aggiunto ad un utente , deve funzionare come le diete secondo me

## Follow-up dal cleanup audit (2026-06-01)

Emersi durante la passata di pulizia: cose che esistono lato backend
ma non sono ancora cablate lato UI / mai usate come dovrebbero.

### 🚨 Compliance — alta priorità
- [ ] **Migrare la lettura dei profili utente da Firestore diretto a `getSecureUserDetails`.** Il server espone `GET /admin/user-details-secure/{uid}` che fa audit log automatico (`READ_USER_PROFILE` su `access_logs/`). Ora `user_management_view._UserDetailPane` legge direttamente da Firestore e non lascia traccia: ogni operatore può leggere PII senza log, in violazione del design GDPR. Endpoint pronto, manca solo la migrazione lato Flutter.

### 🟡 Feature mancanti — media priorità
- [ ] **2FA: recovery dei backup codes persi.** Aggiungere a `two_factor_setup_screen` un pulsante "Rigenera backup codes" che chieda conferma con codice TOTP e chiami `POST /admin/2fa/backup-codes/regenerate`. Senza, chi perde i backup codes resta bloccato fuori senza alternative.
- [ ] **Mood-aware meal suggestions.** Il server in `routers/suggestions.py` aggrega `recent_moods` nel payload utente ma NON li inietta nel prompt Gemini. Decidere se includerli (→ prompt più ricco) o rimuovere il fetch lato server.
- [ ] **Cache management endpoint admin.** `RedisCache` ha `exists/ttl/flush_namespace` ma non c'è nessun endpoint admin che li sfrutti. Aggiungere route tipo `/admin/cache/keys/{key}` (GET stato), `/admin/cache/flush` (POST → flush_namespace), utile per debug e per forzare il refresh dopo una config change.

### 🟢 Polish — bassa priorità
- [ ] **Chat: indicator "ultimo messaggio da te".** Il campo `lastMessageSender` esiste in Firestore e veniva deserializzato in `Chat`. Lo possiamo usare per mostrare un ✓ piccolo sull'ultimo messaggio nell'elenco chat quando l'ho mandato io.
- [ ] **LanguageProvider: load preference da Firestore.** Aggiungere una `setLocale(Locale)` esplicita e chiamarla al login leggendo `users/{uid}.preferred_lang`, così la lingua è persistente cross-device invece di ripartire ogni volta dal default italiano.
- [ ] **Admin design system: usare gli standard invece di inline.** `KyboSpacing` per i padding, `PillSearch` per le barre di ricerca (matchmaking, user filter), `PillDropdown` per i dropdown (role filter, sort menu). Erano widget pronti ma le screen hanno reinventato inline. Da fare quando si tocca l'UI di una di quelle sezioni.

## Follow-up dal security audit (2026-06-11)

Emersi durante l'audit di sicurezza (superficie d'attacco infrastruttura).
I fix immediati sono già stati committati; qui restano i lavori che
richiedono config console o re-architecture e vanno fatti prima/al lancio.

### 🚨 Anti-abuso — alta priorità (fare prima del lancio pubblico)
- [ ] **Firebase App Check.** Le chiavi Firebase nel client sono pubbliche per design: chiunque può scriptare richieste al backend Firebase FUORI dall'app (signup di massa, accesso Firestore entro le rules, generazione costi). Le Security Rules proteggono i *dati* ma non l'*abuso*. App Check (Play Integrity su Android, DeviceCheck/App Attest su iOS, reCAPTCHA su web) garantisce che solo istanze genuine dell'app usino Auth/Firestore/Storage. Steps: aggiungere `firebase_app_check`, registrare i provider in console, configurare debug token per lo sviluppo, attivare l'enforcement in modalità *monitor* prima e poi *enforce* (un enforcement affrettato blocca TUTTI gli utenti — testare bene). Alto valore per controllo costi (rilevante dopo l'incidente billing GCP).
- [ ] **2FA admin: enforcement server-side.** Il 2FA TOTP è oggi SOLO client-side (widget `TwoFactorGuard` nell'app admin). Il server (`verify_admin`) controlla solo il claim `role == 'admin'`: non esiste nessun flag `twofa_verified`. Conseguenza: chi compromette le credenziali Firebase di un admin (phishing, password riusata, leak) ottiene un ID token con `role:admin` e può chiamare TUTTE le API admin direttamente (curl/script), bypassando completamente il 2FA — che protegge solo chi passa dalla UI web. Questo annulla gran parte del valore del 2FA (che serve proprio contro la compromissione password). Fix: dopo `/admin/2fa/validate` settare un claim/sessione `twofa_at` e farlo verificare da `verify_admin` (occhio: i custom claim propagano solo al refresh del token, fino a 1h → forzare un refresh lato client dopo la validazione, o tenere uno store di sessione 2FA-verified su Redis/Firestore controllato in `verify_admin`). Cambio architetturale: testare con cura per non lockare fuori l'admin.

### 🟡 Cifratura dati — media priorità
- [ ] **Cifratura dieta server-side (chiave segreta reale).** L'attuale `encryption_service.dart` deriva la chiave AES solo dall'UID (non segreto, co-locato col ciphertext nel path Firestore) → è *offuscamento*, non cifratura forte (vedi commento esteso nel file). La protezione reale oggi è data dalle Firestore Rules + cifratura at-rest di Google. Per una cifratura davvero robusta contro un dump Firestore serve una chiave/pepper segreta NON co-locata: impossibile lato client (estraibile dall'APK), va spostata server-side (il server cifra/decifra con una master key in env, consegna in chiaro al client solo su TLS autenticato). Richiede schema versionato v3 + migrazione delle diete v2 esistenti. NON cambiare `_generateKeyFromUid` senza migrazione (romperebbe i dati salvati).

### ⚪ Manutenzione — bassa priorità
- [ ] **Aggiornare Next.js (landing).** `npm audit` segnala CVE su Next 14.1 (DoS Image Optimization, SSRF WebSocket, cache poisoning RSC, bypass middleware) + postcss XSS. NON sfruttabili nel deployment attuale: il landing è export statico (`output: 'export'`, `images.unoptimized`) servito da Firebase Hosting → niente runtime Next.js, quindi tutte le CVE server-side non si applicano; la postcss è build-time con CSS nostro. L'upgrade a next@16 è un major breaking change: farlo come manutenzione pianificata (testare il build + tutte le pagine), non urgente.

## Idee UX Client (da valutare)
- [x] Streak counter in home — GIÀ ESISTENTE (streak_badge_widget.dart)
- [x] Skeleton loading (history diete) — implementato con package shimmer
- [x] Haptic feedback su completamento workout + riscatto reward — implementato
- [x] Skeleton loading esteso a chat (bolle), matchmaking e rewards (catalogo + storico)
- [x] Empty state con mini-CTA — implementato in diet_view (Contatta nutrizionista), workout_screen (Contatta PT), chat_screen (3 quick-reply chip che pre-popolano il campo)
- [~] Push reminder programmati — allenamento implementato lato client come notifiche LOCALI ricorrenti (NotificationService.saveWorkoutReminder + WorkoutReminderDialog accessibile da AppBar workout_screen, con toggle/orario/giorni 1-7). Pasti già esistente (scheduleDietNotifications). "Nuova dieta caricata" già esistente (notification_service server). Manca: notifiche chat in background (FCM message handler) + scheduler server-side per push remoti programmati a orari specifici.
- [ ] Widget home iOS/Android: pasto / allenamento di oggi (package home_widget, richiede codice nativo Swift/Kotlin)
- [x] Feedback post-workout rapido (3 emoji 😅/👌/🔥): POST /workouts/feedback, scrive su workout_completions/{date}. Visualizzazione admin: badge "X/7 allenamenti + ultimo feedback" sulla user card
- [x] Ricerca dentro la dieta — GIÀ ESISTENTE (diet_view.dart)
- [x] Onboarding wizard utenti nuovi senza coach — GIÀ ESISTENTE (onboarding_screen.dart)
- [x] Condividi traguardo — GIÀ ESISTENTE (share_plus + achievement_card_generator.dart). Possibile espansione: format dedicato Instagram Stories 9:16 con sfondo brand

## Idee UX Admin (da valutare)
- [x] Saved filter ruolo — GIÀ ESISTENTE (_roleFilter)
- [x] Change log per cliente — GIÀ ESISTENTE (audit_log_view.dart)
- [x] Keyboard shortcut hint visibile — implementato (pill "Cerca... ⌘K")
- [x] Scroll dashboard con mouse wheel + drag — implementato (_AdminScrollBehavior)
- [x] Skeleton loader lista utenti — implementato
- [x] Last activity per user (pallino verde/giallo/rosso + timeago) — implementato
- [x] Bulk actions nella lista utenti (long-press → multi-select → assegna a nutri / export CSV) — implementato (admin user_management_view.dart)
- [x] "La mia giornata" — dashboard operativa con greeting, 3 stat card cliccabili (chat non lette, diete scadute, clienti inattivi >14gg) e lista top-8 clienti da ricontattare ordinati per priorità (admin/lib/screens/my_day_view.dart, prima tab nel dashboard)
- [x] Split view master-detail nella user list — bottone info_outline su ogni card cliente apre _UserDetailPane a destra (responsive: solo viewport >1100px). Pannello mostra avatar grande, nome, email, badge ruolo, info table (UID, creato, ultima attività, ultima dieta) + azioni rapide (Storico / Chiudi). Su viewport più stretti la lista resta full-width e il bottone non fa nulla (opzionale: aprire dialog).
- [x] Templates workout + diete riutilizzabili — workout: toggle "Salva come template" + endpoint clone-and-assign + UI partizionata. Diete: nuovo router server diet_templates.py (CRUD + clone-and-assign su collection diet_templates/{id}, riusa diet_save_service per coerenza con upload diretto) + DietTemplatesView nuovo tab "Templates Diete" (admin/nutritionist) con upload PDF, lista e clone-and-assign con cliente picker.
- [x] Drag & drop PDF dieta su user card (desktop_drop + overlay hover, _uploadDroppedDiet)
- [x] Chat: read receipts (✓ inviato / ✓✓ letto) + typing indicator (3 puntini animati) sia admin che client. Debounce 3s, scrittura su chats/{id}/typing.{role}
- [x] Notification in-app: badge rosso su icona Chat — GIÀ ESISTENTE (AdminNotificationProvider)
- [x] Tabella utenti virtualizzata — implementato cap a 60 elementi per sezione (clienti per nutri, indipendenti, admin) + bottone "Mostra altri 60 (visible/total)". Risolve il bottleneck delle GridView.builder annidate con shrinkWrap+NeverScrollable che costringevano Flutter a costruire tutti i _UserCard eagerly. Il _buildUserGrid top-level (per nutri/PT) è già lazy.
- [x] Export report PDF per cliente — implementato (admin/lib/services/client_report_service.dart). Bottone PDF rosso sulla user card → genera PDF con info base, storico diete, ultimi 30 workout completion + breakdown feedback (facili/ok/duri), note interne. Multi-page con header/footer.
- [x] Dark mode admin — GIÀ ESISTENTE (toggle in user section, KyboThemeProvider)
- [ ] i18n admin: completare traduzioni dei testi ancora hardcoded (solo login + user-edit-dialog tradotti finora)
 