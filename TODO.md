# Kybo - Feature Ideas & Roadmap

---

## Admin Webapp

### Analytics Dashboard
- [ ] Dashboard home con grafici riassuntivi (utenti attivi, diete caricate, messaggi)
- [ ] Grafico trend upload diete nel tempo (giornaliero/settimanale/mensile)
- [ ] Mappa attivita per nutrizionista (quanti clienti, quante diete, tempo risposta chat)
- [ ] Widget "utenti inattivi" (non aprono l'app da X giorni)
- [ ] Tasso di completamento pasti per cliente (quanti pasti consumati vs pianificati)

### Gestione Nutrizionisti
- [ ] Profilo nutrizionista con bio, specializzazioni, orari di disponibilita
- [ ] Limite massimo clienti per nutrizionista (configurabile)
- [ ] Notifica automatica quando un nutrizionista raggiunge il limite
- [ ] Report mensile automatico per ogni nutrizionista (PDF/email)

### Gestione Diete Avanzata
- [ ] Editor dieta visuale drag-and-drop (creare diete direttamente nel webapp senza PDF)
- [ ] Template diete riutilizzabili (il nutrizionista salva modelli base)
- [ ] Duplica dieta da un cliente all'altro con modifiche
- [ ] Confronto side-by-side tra due versioni di dieta
- [ ] Calcolatrice nutrizionale integrata (macro/micro nutrienti per pasto)
- [ ] Alert automatico quando una dieta scade (es. dopo 30 giorni)

### Comunicazione
- [ ] Messaggi broadcast del nutrizionista a tutti i suoi clienti
- [ ] Messaggi predefiniti / risposte rapide (template salvabili)
- [ ] Allegati nella chat (immagini, PDF)
- [ ] Notifica email quando il cliente non legge i messaggi da X giorni
- [ ] Note interne sul cliente (visibili solo al nutrizionista, non al cliente)

### Compliance & Reporting
- [ ] Export dati cliente completo (GDPR data portability)
- [ ] Consenso privacy tracciato con timestamp
- [ ] Retention policy automatica (elimina dati dopo X mesi di inattivita)
- [ ] Dashboard GDPR con stato consensi di tutti gli utenti

### UX
- [ ] Ricerca globale (cerca in utenti, diete, chat, log)
- [ ] Scorciatoie da tastiera (Ctrl+N nuovo utente, Ctrl+K ricerca, etc.)
- [ ] Notifiche in-app (badge su icone nav, non solo chat)
- [ ] Tema personalizzabile per brand del nutrizionista (colori, logo)
- [ ] Multi-lingua (attualmente solo italiano)

---

## Landing Page

### Contenuti
- [ ] Sezione testimonianze / recensioni utenti
- [ ] Video demo dell'app (embedded YouTube/Vimeo)
- [ ] Blog / articoli su nutrizione (SEO content marketing)
- [ ] Sezione FAQ espandibile
- [ ] Pagina "Chi Siamo" con storia e mission
- [ ] Case study nutrizionisti (come Kybo ha migliorato il loro workflow)

### Conversione
- [ ] Form contatto funzionante (con backend per ricevere richieste demo)
- [ ] Newsletter signup con integrazione email marketing (Mailchimp/Resend)
- [ ] Popup/banner "prova gratuita" con timer
- [ ] Chat widget per supporto live (Crisp/Intercom/custom)
- [ ] Link diretto a App Store e Google Play quando l'app sara pubblicata
- [ ] QR code per download diretto dell'app

### SEO & Performance
- [ ] Metadata OpenGraph e Twitter Card per condivisione social
- [ ] Schema.org markup (SoftwareApplication, Organization)
- [ ] Sitemap.xml e robots.txt ottimizzati
- [ ] i18n (versione inglese della landing page)
- [ ] Lazy loading immagini e componenti below-the-fold
- [ ] Lighthouse score optimization (target 95+ su tutte le categorie)

### Design
- [ ] Sezione comparison table (Kybo vs gestione manuale vs altri tool)
- [ ] Mockup interattivo dell'app (click-through prototype embedded)
- [ ] Animazione scroll-triggered per le feature cards
- [ ] Dark mode per la landing page
- [ ] Pagina pricing dedicata con toggle mensile/annuale e feature comparison

### Pagina Business (Nutrizionisti)
- [ ] Form richiesta demo funzionante con calendar booking (Calendly embed)
- [ ] Calcolatrice ROI ("quanto tempo risparmi con Kybo")
- [ ] Sezione sicurezza e compliance dettagliata (GDPR, encryption, audit)
- [ ] Documentazione API pubblica per piano Enterprise

---

## Client App

### Tracking & Statistiche
- [ ] Dashboard progressi settimanale (pasti consumati, aderenza alla dieta)
- [ ] Grafici trend (calorie, macro, peso nel tempo)
- [ ] Obiettivi personalizzati con progress bar (es. "bevi 2L acqua al giorno")
- [ ] Diario alimentare (note libere per ogni pasto)
- [ ] Tracking peso con grafico storico

### Pantry Avanzata
- [ ] Scadenze prodotti con notifica prima della scadenza
- [ ] Categorie pantry (frigo, freezer, dispensa)
- [ ] Barcode scanner per aggiungere prodotti (oltre al receipt scanning)
- [ ] Suggerimenti "sta per scadere, usalo in questo pasto"
- [ ] Storico acquisti (cosa compri piu spesso)

### Shopping List Avanzata
- [ ] Condivisione lista spesa via link/WhatsApp
- [ ] Raggruppamento per corsia del supermercato (frutta, latticini, carne...)
- [ ] Prezzi stimati e budget tracking
- [ ] Preferenze supermercato (salva il tuo negozio preferito)
- [ ] Lista spesa collaborativa (famiglia/coinquilini)

### Social & Gamification
- [ ] Badge e achievement (7 giorni consecutivi, primo receipt scan, etc.)
- [ ] Streak di aderenza alla dieta
- [ ] Condivisione pasti su social (foto + info nutrizionali)
- [ ] Sfide settimanali ("prova 3 nuove ricette questa settimana")

### Ricette & Meal Prep
- [ ] Suggerimenti ricette basate sugli ingredienti in dispensa
- [ ] Timer cottura integrato
- [ ] Porzioni scalabili (cucino per 2, 4, 6 persone)
- [ ] Meal prep planner (prepara domenica per tutta la settimana)
- [ ] Salva piatti preferiti per richiederli al nutrizionista

### UX & Accessibility
- [ ] Widget home screen (prossimo pasto, lista spesa)
- [ ] Apple Watch / Wear OS companion (prossimo pasto, reminder)
- [ ] Siri/Google Assistant integration ("cosa mangio a pranzo?")
- [ ] Modalita tablet con layout ottimizzato
- [ ] Accessibilita screen reader (VoiceOver/TalkBack) completa
- [ ] Onboarding personalizzato per tipo utente (indipendente vs cliente)
- [ ] Deep link per aprire direttamente una sezione dell'app

### Integrazioni
- [ ] Sync con Google Fit / Apple Health (passi, peso, calorie bruciate)
- [ ] Export dieta in formato PDF/calendario
- [ ] Import dieta da altre app (MyFitnessPal, Yazio)
- [ ] Integrazione con bilancia smart (peso automatico)
- [ ] Google Calendar sync per i pasti

---

## Backend / Infrastruttura

### Performance
- [ ] Redis cache layer (sostituire o affiancare L1 in-memory)
- [ ] Queue system per parsing diete (Celery/RQ invece di semaphore)
- [ ] WebSocket per chat real-time (ridurre polling Firestore dal server)
- [ ] CDN per assets statici

### Monitoring
- [ ] Error tracking (Sentry integration)
- [ ] APM (Application Performance Monitoring)
- [ ] Dashboard metriche API (latenza, error rate, throughput)
- [ ] Alerting automatico (Slack/email su errori critici)
- [ ] Health check avanzato (controlla Firebase, Gemini, Tesseract)

### AI / ML
- [ ] Suggerimenti pasti basati su preferenze storiche dell'utente
- [ ] Riconoscimento allergeni automatico dal PDF
- [ ] Analisi sentiment messaggi chat (alertare nutrizionista se cliente in difficolta)
- [ ] OCR migliorato con pre-processing immagine (contrast, rotation, crop)
- [ ] Fine-tuning prompt Gemini per tipologie specifiche di PDF diete

### Sicurezza
- [ ] 2FA (Two-Factor Authentication) per admin e nutrizionisti
- [ ] Session management avanzato (forza logout da altri dispositivi)
- [ ] IP whitelist per accesso admin
- [ ] Penetration test report e remediation
- [ ] Backup automatico Firestore giornaliero

### DevOps
- [ ] CI/CD pipeline (GitHub Actions per test + deploy automatico)
- [ ] Staging environment separato
- [ ] Database migration strategy
- [ ] Load testing (k6/Locust)
- [ ] Docker containerization per sviluppo locale
- [ ] Terraform/Pulumi per infrastruttura as code
