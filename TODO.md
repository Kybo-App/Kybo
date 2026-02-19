# Kybo - Roadmap

---

## SUBITO (completato)

### 1. Backend - Backup Firestore ✅
### 2. Backend - Sentry & Alerting ✅
### 3. Backend - Health Check ✅
- [ ] ⚠️ TODO: Fixare Tesseract su Render dev (cambiare a Docker o configurare build script)
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

### Feature 7: Client - UX & Features
> Miglioramenti app mobile.

- [x] Widget home screen (prossimo pasto, lista spesa)
- [ ] Modalità tablet con layout ottimizzato
- [x] Condivisione lista spesa via link/WhatsApp
- [x] Raggruppamento lista spesa per corsia del supermercato
- [ ] Prezzi stimati e budget tracking (forse)
- [x] Sfide settimanali gamification ("prova 3 nuove ricette questa settimana")

---

### Feature 8: Integrazioni Esterne
> Connessioni con servizi terzi. Client + Backend.

- [ ] Sync con Google Fit / Apple Health (passi, peso, calorie bruciate)
- [ ] Export dieta in formato PDF/calendario
- [ ] Import dieta da altre app (MyFitnessPal, Yazio)
- [ ] Integrazione con bilancia smart (peso automatico)

---

### Feature 9: Landing Page
> Rifacimento completo landing.

**Design:**
- [x] Sezione comparison table (Kybo vs gestione manuale vs altri tool)
- [ ] Mockup interattivo dell'app (click-through prototype embedded)
- [x] Animazione scroll-triggered per le feature cards
- [x] Dark mode per la landing page
- [x] Pagina pricing dedicata con toggle mensile/annuale

**SEO & Performance:**
- [x] Metadata OpenGraph e Twitter Card per condivisione social
- [x] Schema.org markup (SoftwareApplication, Organization, WebSite) JSON-LD
- [x] Sitemap.xml e robots.txt ottimizzati in /public/
- [ ] i18n (versione inglese della landing page)
- [x] Lazy loading componenti below-the-fold con Suspense + dynamic loading
- [x] Lighthouse score optimization: metadataBase, per-page title template, canonical URLs

**Business Page:**
- [ ] Form richiesta demo funzionante con calendar booking (Calendly embed)
- [ ] Calcolatrice ROI ("quanto tempo risparmi con Kybo")
- [ ] Sezione sicurezza e compliance dettagliata
- [ ] Documentazione API pubblica per piano Enterprise

---

### Feature 10: Backend Infrastructure
> Miglioramenti tecnici backend.

**Performance:**
- [ ] Redis cache layer (sostituire o affiancare L1 in-memory)
- [ ] Queue system per parsing diete (Celery/RQ invece di semaphore)

**Monitoring:**
- [ ] APM (Application Performance Monitoring)
- [ ] Dashboard metriche API (latenza, error rate, throughput)

**AI / ML:**
- [ ] Suggerimenti pasti basati su preferenze storiche dell'utente
- [x] OCR migliorato con pre-processing immagine (contrast, rotation, crop)

**Sicurezza:**
- [x] Session management avanzato (forza logout da altri dispositivi)
- [ ] Penetration test report e remediation

**DevOps:**
- [ ] Database migration strategy
- [ ] Load testing (k6/Locust)
- [x] Docker containerization per sviluppo locale

---

## FUTURO (bassa priorità)

### Client - Wearables & Voice
- [ ] Apple Watch / Wear OS companion (prossimo pasto, reminder)
- [ ] Siri/Google Assistant integration ("cosa mangio a pranzo?")

### Client - Shopping List (extra)
- [ ] Preferenze supermercato (salva il tuo negozio preferito)
- [ ] Lista spesa collaborativa (famiglia/coinquilini)

### Client - Ricette & Meal Prep
- [ ] Suggerimenti ricette basate sugli ingredienti in dispensa
- [ ] Timer cottura integrato
- [ ] Porzioni scalabili (cucino per 2, 4, 6 persone)
- [ ] Meal prep planner (prepara domenica per tutta la settimana)
- [ ] Salva piatti preferiti per richiederli al nutrizionista

### Landing - Contenuti
- [ ] Sezione testimonianze / recensioni utenti
- [ ] Video demo dell'app (embedded YouTube/Vimeo)
- [ ] Blog / articoli su nutrizione (SEO content marketing)
- [ ] Sezione FAQ espandibile
- [ ] Pagina "Chi Siamo" con storia e mission
- [ ] Case study nutrizionisti

### Landing - Conversione
- [ ] Form contatto funzionante (backend per ricevere richieste demo)
- [ ] Newsletter signup con integrazione email marketing
- [ ] Popup/banner "prova gratuita" con timer
- [ ] Chat widget per supporto live
- [ ] Link diretto a App Store e Google Play
- [ ] QR code per download diretto dell'app
