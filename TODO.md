# Kybo - Roadmap
 
---
 
## SUBITO

### 1. Backend - Backup Firestore ✅
- [x] Backup automatico Firestore giornaliero (export verso Cloud Storage)

### 2. Backend - Sentry & Alerting ✅
- [x] Error tracking (Sentry integration)
- [x] Alerting automatico (Slack/email su errori critici) - gratis con Sentry

### 3. Backend - Health Check ✅
- [x] Health check avanzato (controlla Firebase, Gemini, Tesseract)
- [ ] ⚠️ TODO: Fixare Tesseract su Render dev (cambiare a Docker o configurare build script)

### 4. Backend - CI/CD ✅
- [x] CI/CD pipeline (GitHub Actions per test + lint server)

### 5. GDPR Base (Obbligo Legale) ✅
- [x] Consenso privacy tracciato con timestamp
- [x] Export dati cliente completo (GDPR data portability)

### 6. Client - Tracking & Statistiche ✅
- [x] Dashboard progressi settimanale (pasti consumati, aderenza alla dieta)
- [x] Grafici trend calorie/peso
- [x] Tracking peso con grafico storico
- [x] Obiettivi personalizzati con progress bar (es. "bevi 2L acqua al giorno")
- [x] Diario alimentare (note libere per ogni pasto)

### 7. Admin - Calcolatrice Nutrizionale & Alert Diete ✅
- [x] Calcolatrice nutrizionale integrata (macro/micro nutrienti per pasto)
- [x] Alert automatico quando una dieta scade (es. dopo 30 giorni)

### 8. Admin - Gestione Nutrizionisti ✅
- [x] Profilo nutrizionista con bio, specializzazioni
- [x] Limite massimo clienti per nutrizionista (configurabile)
- [x] Controllo limite durante assegnazione

### 9. Backend - Riconoscimento Allergeni ✅
- [x] Riconoscimento allergeni automatico dal PDF durante parsing Gemini

### 10. Admin - Allegati Chat ✅
- [x] Allegati nella chat (immagini, PDF)

### 11. Admin - Notifiche In-App
- [ ] Badge su icone nav (non solo chat)
- [ ] Sistema notifiche unificato

### 12. Client - Deep Link & Onboarding
- [ ] Onboarding personalizzato per tipo utente (indipendente vs cliente)
- [ ] Deep link per aprire direttamente una sezione dell'app

### 13. Client - Badge & Achievement
> ⚠️ Dipende dal completamento di "Tracking & Statistiche"
- [ ] Badge e achievement (7 giorni consecutivi, primo receipt scan, etc.)
- [ ] Streak di aderenza alla dieta

### 14. Client - Accessibilità
- [ ] Accessibilita screen reader (VoiceOver/TalkBack) completa

---
 
## FUTURO (alta priorita)

### GDPR Avanzato
- [ ] Retention policy automatica (elimina dati dopo X mesi di inattivita)
- [ ] Dashboard GDPR con stato consensi di tutti gli utenti

### Backend - 2FA
- [ ] 2FA (Two-Factor Authentication) per admin e nutrizionisti

### Admin - Report Nutrizionisti
- [ ] Report mensile automatico per ogni nutrizionista (PDF/email)

### Admin - Analytics Dashboard
- [ ] Dashboard home con grafici riassuntivi (utenti attivi, diete caricate, messaggi)
- [ ] Grafico trend upload diete nel tempo (giornaliero/settimanale/mensile)
- [ ] Mappa attivita per nutrizionista (quanti clienti, quante diete, tempo risposta chat)
- [ ] Widget "utenti inattivi" (non aprono l'app da X giorni)
- [ ] Tasso di completamento pasti per cliente (quanti pasti consumati vs pianificati)

---
 
## FUTURO

### Admin - Gestione Diete Avanzata
- [ ] Editor dieta visuale drag-and-drop (creare diete direttamente nel webapp senza PDF)
- [ ] Template diete riutilizzabili (il nutrizionista salva modelli base)
- [ ] Duplica dieta da un cliente all'altro con modifiche
- [ ] Confronto side-by-side tra due versioni di dieta

### Admin - Comunicazione
- [ ] Messaggi broadcast del nutrizionista a tutti i suoi clienti
- [ ] Notifica email quando il cliente non legge i messaggi da X giorni
- [ ] Note interne sul cliente (visibili solo al nutrizionista, non al cliente)

### Admin - UX
- [ ] Scorciatoie da tastiera (Ctrl+N nuovo utente, Ctrl+K ricerca, etc.)
- [ ] Ricerca globale (cerca in utenti, diete, chat, log)
- [ ] Multi-lingua (attualmente solo italiano)

### Client - UX Avanzata
- [ ] Widget home screen (prossimo pasto, lista spesa)
- [ ] Modalita tablet con layout ottimizzato

### Client - Shopping List
- [ ] Condivisione lista spesa via link/WhatsApp
- [ ] Raggruppamento per corsia del supermercato (frutta, latticini, carne...)
- [ ] Prezzi stimati e budget tracking (forse)

### Client - Gamification
- [ ] Sfide settimanali ("prova 3 nuove ricette questa settimana")

### Client - Integrazioni
- [ ] Sync con Google Fit / Apple Health (passi, peso, calorie bruciate)
- [ ] Export dieta in formato PDF/calendario
- [ ] Import dieta da altre app (MyFitnessPal, Yazio)
- [ ] Integrazione con bilancia smart (peso automatico)

### Landing - Design
- [ ] Sezione comparison table (Kybo vs gestione manuale vs altri tool)
- [ ] Mockup interattivo dell'app (click-through prototype embedded)
- [ ] Animazione scroll-triggered per le feature cards
- [ ] Dark mode per la landing page
- [ ] Pagina pricing dedicata con toggle mensile/annuale e feature comparison

### Landing - SEO & Performance
- [ ] Metadata OpenGraph e Twitter Card per condivisione social
- [ ] Schema.org markup (SoftwareApplication, Organization)
- [ ] Sitemap.xml e robots.txt ottimizzati
- [ ] i18n (versione inglese della landing page)
- [ ] Lazy loading immagini e componenti below-the-fold
- [ ] Lighthouse score optimization (target 95+ su tutte le categorie)

### Backend - Performance
- [ ] Redis cache layer (sostituire o affiancare L1 in-memory)
- [ ] Queue system per parsing diete (Celery/RQ invece di semaphore)

### Backend - Monitoring
- [ ] APM (Application Performance Monitoring)
- [ ] Dashboard metriche API (latenza, error rate, throughput)

### Backend - AI / ML
- [ ] Suggerimenti pasti basati su preferenze storiche dell'utente
- [ ] OCR migliorato con pre-processing immagine (contrast, rotation, crop)

### Backend - Sicurezza
- [ ] Session management avanzato (forza logout da altri dispositivi)
- [ ] Penetration test report e remediation

### Backend - DevOps
- [ ] Database migration strategy
- [ ] Load testing (k6/Locust)
- [ ] Docker containerization per sviluppo locale

---
 
## FUTURO (bassa priorita)

### Client - Wearables & Voice (Progetti Separati)
- [ ] Apple Watch / Wear OS companion (prossimo pasto, reminder)
- [ ] Siri/Google Assistant integration ("cosa mangio a pranzo?")

### Landing - Pagina Business (Nutrizionisti)
- [ ] Form richiesta demo funzionante con calendar booking (Calendly embed)
- [ ] Calcolatrice ROI ("quanto tempo risparmi con Kybo")
- [ ] Sezione sicurezza e compliance dettagliata (GDPR, encryption, audit)
- [ ] Documentazione API pubblica per piano Enterprise

### Landing - Contenuti
- [ ] Sezione testimonianze / recensioni utenti
- [ ] Video demo dell'app (embedded YouTube/Vimeo)
- [ ] Blog / articoli su nutrizione (SEO content marketing)
- [ ] Sezione FAQ espandibile
- [ ] Pagina "Chi Siamo" con storia e mission
- [ ] Case study nutrizionisti (come Kybo ha migliorato il loro workflow)

### Landing - Conversione
- [ ] Form contatto funzionante (con backend per ricevere richieste demo)
- [ ] Newsletter signup con integrazione email marketing (Mailchimp/Resend)
- [ ] Popup/banner "prova gratuita" con timer
- [ ] Chat widget per supporto live (Crisp/Intercom/custom)
- [ ] Link diretto a App Store e Google Play quando l'app sara pubblicata
- [ ] QR code per download diretto dell'app

### Client - Shopping List (bassa)
- [ ] Preferenze supermercato (salva il tuo negozio preferito)
- [ ] Lista spesa collaborativa (famiglia/coinquilini)

### Client - Ricette & Meal Prep
- [ ] Suggerimenti ricette basate sugli ingredienti in dispensa
- [ ] Timer cottura integrato
- [ ] Porzioni scalabili (cucino per 2, 4, 6 persone)
- [ ] Meal prep planner (prepara domenica per tutta la settimana)
- [ ] Salva piatti preferiti per richiederli al nutrizionista
