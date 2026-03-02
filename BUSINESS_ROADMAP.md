# Kybo — Road Map verso il mercato
> Documento strategico per la trasformazione di Kybo in una società commerciale.
> Ultimo aggiornamento: marzo 2026

---

## Indice

1. [Il prodotto e il posizionamento](#1-il-prodotto-e-il-posizionamento)
2. [Analisi competitor](#2-analisi-competitor)
3. [Nodo legale critico: dispositivo medico?](#3-nodo-legale-critico-dispositivo-medico)
4. [Forma giuridica consigliata](#4-forma-giuridica-consigliata)
5. [Business model e pricing](#5-business-model-e-pricing)
6. [Passi concreti in ordine](#6-passi-concreti-in-ordine)
7. [Da chi andare e cosa chiedere](#7-da-chi-andare-e-cosa-chiedere)
8. [Riferimenti e fonti](#8-riferimenti-e-fonti)

---

## 1. Il prodotto e il posizionamento

### Cosa è Kybo

Kybo è una piattaforma **B2B SaaS verticale** per la gestione dello studio nutrizionale.
Comprende quattro componenti:

| Componente | Utente | Funzione principale |
|---|---|---|
| App mobile (Flutter iOS/Android) | Cliente/paziente | Visualizza dieta, traccia pasti, chat con nutrizionista |
| Admin panel (Flutter Web) | Nutrizionista / Admin | Gestisce clienti, carica diete, visualizza analytics |
| Backend (FastAPI + Firebase) | Sistema | API, AI parsing PDF, OCR, autenticazione |
| Landing page (Next.js) | Prospect | Marketing, richiesta demo, SEO |

### Perché il modello B2B è il più solido

- Il nutrizionista è il cliente pagante → biglietto alto, basso churn
- Il paziente usa l'app come "valore incluso" nel servizio del professionista
- Non sei in competizione con app consumer (MyFitnessPal, Yazio, ecc.)
- Il professionista vuole uno strumento affidabile, non il più economico

### Vantaggio competitivo principale

Nessun competitor italiano offre **app mobile nativa per il paziente integrata nella subscription del nutrizionista**. I competitor hanno portali web o app di terze parti separate.

Features differenzianti di Kybo rispetto ai competitor:
- App mobile nativa (iOS + Android) per il cliente inclusa nel piano
- AI parsing automatico dei PDF di dieta (Gemini)
- OCR ricevute per tracking spesa alimentare
- Chat in-app nutrizionista ↔ paziente con allegati
- Crittografia AES-256 dei dati dieta at-rest

---

## 2. Analisi competitor

| Software | Tipo | Prezzo | Punti deboli |
|---|---|---|---|
| Metadieta | Desktop + cloud, certificato CE | ~€50/mese | Interfaccia datata, no app mobile nativa paziente |
| Nutriverso | Cloud SaaS italiano | €40–80/mese | No app paziente integrata |
| Nutribook | SaaS moderno italiano | €30–60/mese | No AI, no OCR |
| Nutrium | SaaS internazionale (120k utenti) | €79–149/mese | Costoso, no Italia-first, no app paziente inclusa |

### Posizionamento di prezzo suggerito

Kybo si può posizionare **tra Nutribook e Nutrium**: moderno come Nutribook,
feature-rich come Nutrium, con l'app paziente che nessuno degli altri ha.

---

## 3. Nodo legale critico: dispositivo medico?

### Il problema

Il **Regolamento EU 2017/745 (MDR — Medical Device Regulation)** stabilisce che
un software è un dispositivo medico se è destinato a diagnosi, prevenzione,
monitoraggio o trattamento di malattie. Se Kybo ricadesse in questa categoria,
servirebbe la marcatura CE tramite organismo notificato: iter da **€5.000 a €50.000+**
e diversi mesi di burocrazia.

### La buona notizia: Kybo può evitarlo

Il modello di Kybo è:
1. Il nutrizionista (professionista abilitato) **crea** il piano alimentare
2. L'AI **parsifica** il PDF caricato dal professionista (non genera raccomandazioni cliniche)
3. L'app **visualizza** la dieta al paziente

Questo schema è classificabile come **software di gestione dello studio professionale**,
non come dispositivo medico. Lo stesso posizionamento è usato da Nutribook.

### Regola d'oro per il marketing

| ❌ NON scrivere (rischio MDR) | ✅ Scrivi così |
|---|---|
| "Kybo aiuta a trattare l'obesità" | "Kybo è uno strumento di gestione studio per nutrizionisti" |
| "Consiglia la dieta corretta per la tua patologia" | "Il nutrizionista carica e gestisce i piani alimentari" |
| "Monitora parametri clinici" | "Traccia i progressi definiti dal professionista" |
| "Diagnosi nutrizionale basata su AI" | "Parsing automatico dei PDF di dieta caricati dal professionista" |

### Azione concreta

Fai fare una **valutazione MDR scritta** da un avvocato specializzato (1–2 ore di
consulenza, ~€200–400). Il documento scritto è importante: protegge in caso di
contestazione futura.

---

## 4. Forma giuridica consigliata

### Struttura: S.r.l. + iscrizione come Startup Innovativa

#### Perché S.r.l. e non ditta individuale o S.a.s.

- Separa il patrimonio personale dal rischio d'impresa
- È l'unica forma ammessa per ottenere lo status di Startup Innovativa
- Permette di assegnare equity a co-fondatori e investitori
- Capitale minimo: **€1** (non è più necessario il minimo di €10.000)

#### Startup Innovativa — Vantaggi (L. 221/2012 e novità L. 193/2024)

| Vantaggio | Dettaglio |
|---|---|
| Detrazione IRPEF per chi investe | 40% (65% in regime de minimis) → facilita raccolta da angel investor |
| Esonero parziale contributi | Agevolazioni previdenziali per i fondatori |
| Niente bolli e diritti camerali | Risparmio ~€500/anno |
| Stock option semplificate | Possibilità di assegnare quote a developer e team |
| Norme fallimento semplificate | Protezione maggiore in caso di chiusura |
| Regime durata | Massimo 7 anni (3+2+2 con crescita fatturato +20%/anno) |

#### Requisito più facile per Kybo: software registrato

Per qualificarsi come Startup Innovativa basta soddisfare **uno** di questi tre criteri:
1. Spese R&S ≥ 15% dei costi totali
2. Almeno 1/3 del team con dottorato o 2/3 con laurea magistrale
3. **Titolare di software registrato** ← il più accessibile per Kybo

**Azione**: registra il codice sorgente di Kybo alla **SIAE** (Registro Pubblico Speciale
per i Programmi per Elaboratore). Costo: ~€70. Ti qualifica immediatamente.

#### Costi di costituzione

| Voce | Costo stimato |
|---|---|
| Notaio (atto costitutivo S.r.l.) | €1.000–2.000 |
| Camera di Commercio (iscrizione + bolli) | €300–500 |
| Commercialista (pratiche iniziali) | €500–1.000 |
| Registrazione software SIAE | ~€70 |
| **Totale** | **~€2.000–3.500** |

---

## 5. Business model e pricing

### Piano subscription B2B (consigliato al lancio)

| Piano | Prezzo | Target | Incluso |
|---|---|---|---|
| **Solo** | €39/mese | Nutrizionista libero professionista | 1 nutrizionista, fino a 30 clienti attivi, app paziente inclusa |
| **Studio** | €79/mese | Libero professionista affermato | 1 nutrizionista, clienti illimitati, analytics avanzate, export PDF |
| **Team** | €149/mese | Studio / piccola clinica | Fino a 5 nutrizionisti, branding white-label, priorità supporto |
| **Enterprise** | Su misura | Centri medici, catene | Multi-sede, SSO, API access, SLA garantito |

### Cosa NON fare al lancio

- **No freemium**: i professionisti cercano strumenti seri, non toy gratuiti.
  Il freemium attira utenti non paganti e aumenta i costi di infrastruttura.
- **No prezzo troppo basso**: €29/mese non è percepito come "professionale".
  Il competitor Nutrium a €149/mese ha 120.000 utenti. Il prezzo segnala qualità.

### Trial

Offri **14 giorni di trial gratuito** senza carta di credito richiesta.
Poi paywall duro. Questo è il modello di tutti i SaaS B2B di successo.

### Revenue aggiuntiva (fase successiva)

- Marketplace di template dieta tra nutrizionisti (% sulla vendita)
- Modulo per centri fitness / palestre (nutrizionista + trainer insieme)
- Export dati aggregati anonimizzati per ricerca (con consenso esplicito, GDPR-compliant)
- Certificazione Kybo per professionisti (badge di qualità nel profilo)

---

## 6. Passi concreti in ordine

### Fase 0 — Validazione (gratis, prima settimana)

- [ ] Parla con **10 nutrizionisti reali**: mostra Kybo, chiedi €39/mese
- [ ] Obiettivo: **3 su 10 dicono "sì, lo pago"** → hai validazione sufficiente per procedere
- [ ] Registra il software alla **SIAE** (~€70) → qualifica Startup Innovativa
- [ ] Registra il dominio **kybo.app** se non già fatto

### Fase 1 — Struttura legale (settimane 2–4, €2.000–4.000)

- [ ] Scegli il commercialista (specializzato startup/tech, non generico)
- [ ] Apri la **S.r.l.** dal notaio (capitale minimo €1)
- [ ] Iscrivi alla **sezione speciale Startup Innovativa** alla Camera di Commercio
- [ ] Apri conto bancario aziendale (Qonto o N26 Business sono comodi per startup)
- [ ] 1h di consulenza MDR con avvocato digital health → ottieni parere scritto

### Fase 2 — Lancio (mesi 1–3)

- [ ] Integra **Stripe** per i pagamenti subscription nella landing
- [ ] Crea pricing page pubblica sulla landing
- [ ] Scrivi **contratto di servizio** (termini B2B, DPA GDPR, SLA)
- [ ] Onboarda i **primi 10 clienti paganti**
- [ ] Registra il **marchio "Kybo"** all'UAMI europeo (~€850, protegge in tutta l'UE)

### Fase 3 — Scala (mesi 3–12)

- [ ] Se arrivi a **€3.000–5.000 MRR** → considera un angel round o incubatore
- [ ] Presentati a convegni/eventi di **ANDID, SINU, Ordini dei Biologi**
- [ ] Attiva il **programma referral** per nutrizionisti (porta un collega = 1 mese gratis)
- [ ] Inizia a costruire **social proof** (case study, testimonianze con nome e foto)

---

## 7. Da chi andare e cosa chiedere

### 1. Commercialista specializzato startup tech

**Quando andare**: prima di costituire la società.

**Cosa chiedergli**:
- Forma giuridica ottimale per la tua situazione (S.r.l. vs S.r.l.s.)
- Regime fiscale (forfettario se sei solo vs tassazione ordinaria S.r.l.)
- Gestione pratica Startup Innovativa (autocertificazione requisiti)
- Stock option / gestione equity per eventuali co-fondatori o dipendenti
- Previdenza: come gestire i contributi da fondatore

**Dove trovarlo**: chiedi referral a startup del tuo settore, oppure cerca su
piattaforme come Feeda o StartupItalia. Evita commercialisti generalisti.

---

### 2. Avvocato — diritto digitale / healthtech

**Quando andare**: prima del lancio pubblico.

**Cosa chiedergli**:
- **(a) Valutazione MDR** per iscritto: "Kybo rientra nella definizione di dispositivo medico?"
- **(b) Termini e Condizioni** B2B (contratto nutrizionista ↔ Kybo)
- **(c) Data Processing Agreement (DPA)** GDPR conforme
- **(d) Privacy Policy** per utenti finali (pazienti)
- **(e) Disclaimer medico** nella landing e nell'app

**Studi di riferimento**:
- [Stefanelli & Stefanelli Studio Legale](https://www.studiolegalestefanelli.it) — specializzati MDR/dispositivi medici in Italia
- Qualsiasi studio con practice "digital health" o "diritto delle tecnologie"

---

### 3. Camera di Commercio (sportello gratuito)

**Quando andare**: al momento della costituzione della S.r.l.

**Cosa fare**: iscrizione alla sezione speciale Startup Innovativa tramite
Comunicazione Unica. Il commercialista lo gestisce per te, ma puoi anche
informarti gratuitamente allo sportello della Camera di Commercio della tua provincia.

**Link utile**: [MIMIT — Startup Innovative](https://www.mimit.gov.it/it/startup-innovative)

---

### 4. Incubatori / acceleratori (se vuoi funding)

**Quando andare**: dopo aver raggiunto i primi 5–10 clienti paganti. Prima non ha senso.

| Incubatore | Sede | Specializzazione | Note |
|---|---|---|---|
| [Polihub](https://polihub.it/) | Milano (Politecnico) | Tech, deep tech | Ottimo network accademico e industriale |
| [Bio4Dreams](https://bio4dreams.com/en/) | Milano / Verona | Life sciences, digital health | Specifico healthtech, certificato MISE |
| [LVenture Group](https://www.lventure.com/) | Roma | Generalista tech | Track record solido, connesso a grandi corporate |
| [Impact Hub Milano](https://milan.impacthub.net/) | Milano | Social impact, health | Ottimo per primi pitch e networking a basso costo |
| [PoliTo Incubatore](https://www.i3p.it/) | Torino | Tech | Se sei in area Nord-Ovest |

**Come prepararsi per un incubatore**:
- Deck di 10 slide (problema, soluzione, mercato, traction, team, ask)
- MRR attuale e tasso di crescita mensile
- Churn mensile (quanti nutrizionisti smettono di pagare)
- CAC (costo acquisizione cliente) e LTV (lifetime value stimato)

---

### 5. Associazioni di categoria nutrizionisti

**Quando andare**: subito, anche prima del lancio. Sono i tuoi canali di distribuzione.

| Associazione | Chi rappresenta | Come sfruttarla |
|---|---|---|
| [ANDID](https://www.andid.it/) | Dietisti italiani | Newsletter, eventi, partnership |
| [SINU](https://www.sinu.it/) | Scienziati della nutrizione | Convegni scientifici, credibilità |
| [Ordine Nazionale Biologi](https://www.onb.it/) | Biologi nutrizionisti | Evento annuale, newsletter agli iscritti |
| [Federazione ANSES](https://www.anses.it/) | Specialisti in nutrizione | Community attiva |

**Azione concreta**: contatta l'ufficio comunicazione di ANDID o ONB e proponi
una partnership: demo gratuita di 3 mesi per i loro iscritti in cambio di
visibilità nella loro newsletter. È il canale più diretto per raggiungere
centinaia di potenziali clienti paganti a costo quasi zero.

---

## 8. Riferimenti e fonti

### Legali e normativi

- [Regolamento EU 2017/745 (MDR) — testo ufficiale](https://eur-lex.europa.eu/legal-content/IT/TXT/?uri=CELEX%3A32017R0745)
- [MIMIT — Startup Innovative](https://www.mimit.gov.it/it/startup-innovative)
- [Incentivi de minimis per Startup Innovative](https://www.mimit.gov.it/it/impresa/competitivita-e-nuove-imprese/start-up-innovative/incentivi-de-minimis)
- [Novità L. 193/2024 e L. 162/2024 — Startup Innovative](https://tutelafiscale.it/startup-e-pmi-innovative-dal-2025-cambiano-le-regole-e-gli-incentivi-fiscali/)
- [Classificazione software come dispositivo medico](https://www.studiolegalestefanelli.it/it/dispositivi-medici-normativa-regolatorio)
- [App nutrizionali e GDPR — ESG360](https://www.esg360.it/risk-management/app-nutrizionali-come-si-applica-il-gdpr/)
- [Quando un'app sanitaria è un dispositivo medico](https://www.tendenzenuove.it/2021/12/14/quando-un-app-e-un-dispositivo-medico-inquadramento-normativo/)

### Competitor e mercato

- [Metadieta — analisi software nutrizionisti](https://www.metadieta.it/blog/software-per-nutrizionisti-aspetti-professionali-tecnici-legali-quali-scegliere-pro-e-contro/)
- [Nutribook — prezzi](https://nutribook.app/prezzi/)
- [Nutrium — piani professionisti](https://nutrium.com/en/professionals)
- [Nutriverso — prezzi](https://nutriverso.cloud/en/prezzi)

### Incubatori e funding

- [Polihub — incubatore Politecnico Milano](https://polihub.it/)
- [Bio4Dreams — healthtech incubator](https://bio4dreams.com/en/)
- [LVenture Group](https://www.lventure.com/)
- [Impact Hub Milano](https://milan.impacthub.net/)
- [Top 20 VC italiani per startup 2025](https://www.pitchdrive.com/academy/top-20-venture-capital-firms-in-italy-for-startups-in-2025)

### Associazioni di categoria

- [ANDID — Associazione Nazionale Dietisti](https://www.andid.it/)
- [SINU — Società Italiana di Nutrizione Umana](https://www.sinu.it/)
- [Ordine Nazionale Biologi](https://www.onb.it/)

---

*Documento creato a marzo 2026 — da aggiornare dopo ogni interazione significativa
con avvocati, commercialisti o potenziali clienti.*
