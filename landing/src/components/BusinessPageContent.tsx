'use client';

import React, { useState } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import styles from '../app/business/page.module.css';
import pStyles from '../app/pricing/pricing.module.css';

// ===== ROI CALCULATOR =====
function RoiCalculator() {
  const [clients, setClients] = useState(30);
  const [hoursPerClient, setHoursPerClient] = useState(2);
  const [hourlyRate, setHourlyRate] = useState(60);

  const hoursSaved = Math.round(clients * hoursPerClient * 0.6);
  const moneySaved = hoursSaved * hourlyRate;
  const extraClients = Math.floor(hoursSaved / hoursPerClient);
  const extraRevenue = extraClients * hourlyRate * 4;

  return (
    <section className={styles.roiSection}>
      <div className={styles.container}>
        <h2 className={styles.sectionTitle}>Calcolatrice ROI</h2>
        <p className={styles.sectionSubtitle}>
          Scopri quanto tempo e denaro puoi risparmiare ogni mese con Kybo
        </p>

        <div className={styles.roiGrid}>
          <div className={styles.roiInputs}>
            <div className={styles.roiSliderWrapper}>
              <label className={styles.roiLabel}>Numero di clienti attivi</label>
              <input
                type="range" min={5} max={200} value={clients}
                onChange={(e) => setClients(Number(e.target.value))}
                className={styles.roiSlider}
              />
              <span className={styles.roiSliderValue}>{clients} clienti</span>
            </div>

            <div className={styles.roiSliderWrapper}>
              <label className={styles.roiLabel}>Ore spese per cliente / mese (admin)</label>
              <input
                type="range" min={0.5} max={8} step={0.5} value={hoursPerClient}
                onChange={(e) => setHoursPerClient(Number(e.target.value))}
                className={styles.roiSlider}
              />
              <span className={styles.roiSliderValue}>{hoursPerClient} ore/cliente</span>
            </div>

            <div className={styles.roiSliderWrapper}>
              <label className={styles.roiLabel}>Tariffa oraria (€)</label>
              <input
                type="range" min={20} max={200} step={5} value={hourlyRate}
                onChange={(e) => setHourlyRate(Number(e.target.value))}
                className={styles.roiSlider}
              />
              <span className={styles.roiSliderValue}>€{hourlyRate}/ora</span>
            </div>
          </div>

          <div className={styles.roiResults}>
            <div className={styles.roiResultItem}>
              <span className={styles.roiResultLabel}>⏱ Ore risparmiate / mese</span>
              <span className={styles.roiResultValue}>{hoursSaved}h</span>
            </div>
            <div className={styles.roiResultItem}>
              <span className={styles.roiResultLabel}>💰 Risparmio admin (€/mese)</span>
              <span className={styles.roiResultValue}>€{moneySaved.toLocaleString('it-IT')}</span>
            </div>
            <div className={styles.roiResultItem}>
              <span className={styles.roiResultLabel}>👥 Clienti extra gestibili</span>
              <span className={styles.roiResultValue}>+{extraClients}</span>
            </div>
            <div className={styles.roiResultItem}>
              <span className={styles.roiResultLabel}>📈 Fatturato extra potenziale</span>
              <span className={styles.roiResultValueBig}>€{extraRevenue.toLocaleString('it-IT')}</span>
            </div>
            <p className={styles.roiDisclaimer}>
              * Stime basate sull&apos;uso medio di Kybo da parte di nutrizionisti professionisti.
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}

// ===== DEMO FORM =====
function DemoForm() {
  const [submitted, setSubmitted] = useState(false);
  const [form, setForm] = useState({
    nome: '', cognome: '', email: '', telefono: '', studio: '', clienti: '10-30',
  });

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    setForm((prev) => ({ ...prev, [e.target.name]: e.target.value }));
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    // In production: POST to /api/demo-request or a Zapier/n8n webhook
    setSubmitted(true);
  };

  return (
    <section className={styles.demoSection} id="demo">
      <div className={styles.container}>
        <div className={styles.demoGrid}>
          <div className={styles.demoInfo}>
            <h2 className={styles.demoInfoTitle}>
              Prenota una Demo Gratuita
            </h2>
            <p className={styles.demoInfoText}>
              Ti mostriamo in 30 minuti come Kybo può trasformare il tuo studio nutrizionistico.
              Nessun impegno, nessuna carta di credito richiesta.
            </p>
            <div className={styles.demoPerks}>
              {[
                'Demo personalizzata sul tuo flusso di lavoro',
                'Setup assistito gratuito per i primi 30 giorni',
                'Migrazione dati da altri software inclusa',
                'Supporto dedicato via chat e telefono',
                'Prova gratuita 14 giorni senza limiti',
              ].map((p) => (
                <div key={p} className={styles.demoPerk}>
                  <span className={styles.demoPerkIcon}>✓</span>
                  <span>{p}</span>
                </div>
              ))}
            </div>
          </div>

          <div className={styles.demoFormCard}>
            {submitted ? (
              <div className={styles.formSuccess}>
                <span className={styles.formSuccessIcon}>🎉</span>
                <p className={styles.formSuccessTitle}>Richiesta inviata!</p>
                <p className={styles.formSuccessText}>
                  Ti contatteremo entro 24 ore per fissare la tua demo personalizzata.
                  Controlla anche la cartella spam.
                </p>
              </div>
            ) : (
              <form onSubmit={handleSubmit}>
                <div className={styles.formRow}>
                  <div className={styles.formGroup}>
                    <label className={styles.formLabel}>Nome *</label>
                    <input
                      name="nome" required value={form.nome} onChange={handleChange}
                      placeholder="Marco" className={styles.formInput}
                    />
                  </div>
                  <div className={styles.formGroup}>
                    <label className={styles.formLabel}>Cognome *</label>
                    <input
                      name="cognome" required value={form.cognome} onChange={handleChange}
                      placeholder="Rossi" className={styles.formInput}
                    />
                  </div>
                </div>

                <div className={styles.formGroup}>
                  <label className={styles.formLabel}>Email professionale *</label>
                  <input
                    name="email" type="email" required value={form.email} onChange={handleChange}
                    placeholder="marco.rossi@studio.it" className={styles.formInput}
                  />
                </div>

                <div className={styles.formRow}>
                  <div className={styles.formGroup}>
                    <label className={styles.formLabel}>Telefono</label>
                    <input
                      name="telefono" value={form.telefono} onChange={handleChange}
                      placeholder="+39 333 1234567" className={styles.formInput}
                    />
                  </div>
                  <div className={styles.formGroup}>
                    <label className={styles.formLabel}>Clienti attivi</label>
                    <select name="clienti" value={form.clienti} onChange={handleChange} className={styles.formSelect}>
                      <option value="<10">Meno di 10</option>
                      <option value="10-30">10 – 30</option>
                      <option value="30-80">30 – 80</option>
                      <option value="80+">Più di 80</option>
                    </select>
                  </div>
                </div>

                <div className={styles.formGroup}>
                  <label className={styles.formLabel}>Nome studio / clinica</label>
                  <input
                    name="studio" value={form.studio} onChange={handleChange}
                    placeholder="Studio Nutrizionale Rossi" className={styles.formInput}
                  />
                </div>

                <button type="submit" className={styles.formSubmit}>
                  Prenota Demo Gratuita →
                </button>

                <p className={styles.formPrivacy}>
                  Inviando il modulo accetti la nostra{' '}
                  <Link href="/privacy" style={{ color: '#66BB6A' }}>Privacy Policy</Link>.
                  I tuoi dati non saranno mai condivisi con terze parti.
                </p>
              </form>
            )}
          </div>
        </div>
      </div>
    </section>
  );
}

// ===== SECURITY SECTION =====
function SecuritySection() {
  const items = [
    {
      icon: '🔐',
      title: 'Cifratura AES-256',
      desc: 'I dati alimentari dei pazienti sono cifrati at-rest con AES-256. Le chiavi di cifratura sono gestite da Firebase KMS e mai accessibili in chiaro.',
    },
    {
      icon: '🛡️',
      title: 'GDPR Compliant',
      desc: "Retention policy configurabile, dashboard consensi, purge automatico e manuale. Audit log completo per ogni accesso a dati sensibili.",
    },
    {
      icon: '🔒',
      title: 'Autenticazione 2FA',
      desc: 'Supporto TOTP (Google Authenticator, Authy) per tutti i professionisti. Session management con revoca forzata da remoto.',
    },
    {
      icon: '☁️',
      title: 'Infrastruttura Cloud',
      desc: 'Hosted su Google Cloud (Firebase) con SLA 99.9%. Backup automatici giornalieri su Firestore. Zero downtime deployment.',
    },
    {
      icon: '🔍',
      title: 'Audit Log',
      desc: 'Ogni accesso a dati sensibili è tracciato con timestamp, IP e ruolo. Log accessibili dall\'admin per compliance e audit di sicurezza.',
    },
    {
      icon: '🚦',
      title: 'Rate Limiting',
      desc: 'Protezione DoS con rate limiting per IP e utente. Rilevamento anomalie e blocco automatico di pattern sospetti.',
    },
  ];

  const badges = [
    { icon: '✅', text: 'GDPR Art. 25 (Privacy by Design)' },
    { icon: '🔒', text: 'TLS 1.3 in Transit' },
    { icon: '☁️', text: 'ISO 27001 (Google Cloud)' },
    { icon: '🇪🇺', text: 'Dati in UE (europa-west)' },
    { icon: '🛡️', text: 'Firebase Security Rules' },
  ];

  return (
    <section className={styles.securitySection}>
      <div className={styles.container}>
        <h2 className={styles.sectionTitle}>Sicurezza & Compliance</h2>
        <p className={styles.sectionSubtitle}>
          I dati dei tuoi pazienti sono protetti con gli stessi standard delle aziende Fortune 500
        </p>

        <div className={styles.securityGrid}>
          {items.map((item) => (
            <div key={item.title} className={styles.securityCard}>
              <span className={styles.securityIcon}>{item.icon}</span>
              <h3>{item.title}</h3>
              <p>{item.desc}</p>
            </div>
          ))}
        </div>

        <div className={styles.securityBadges}>
          {badges.map((b) => (
            <div key={b.text} className={styles.securityBadge}>
              <span>{b.icon}</span>
              <span>{b.text}</span>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

// ===== API DOCS SECTION =====
function ApiSection() {
  const endpoints = [
    { method: 'GET', path: '/api/users', desc: 'Lista pazienti', cls: 'get' },
    { method: 'POST', path: '/api/diet/upload', desc: 'Carica dieta PDF', cls: 'post' },
    { method: 'GET', path: '/api/diet/export-pdf', desc: 'Esporta dieta PDF', cls: 'get' },
    { method: 'POST', path: '/api/diet/import', desc: 'Import CSV/JSON', cls: 'post' },
    { method: 'GET', path: '/api/reports/monthly', desc: 'Report mensile', cls: 'get' },
    { method: 'POST', path: '/api/communication/broadcast', desc: 'Broadcast messaggi', cls: 'post' },
    { method: 'DELETE', path: '/api/gdpr/purge-inactive', desc: 'Purge utenti GDPR', cls: 'delete' },
  ];

  const codeExample = `// Esempio: carica una dieta per un paziente
const response = await fetch(
  'https://kybo.onrender.com/diet/upload',
  {
    method: 'POST',
    headers: {
      'Authorization': 'Bearer YOUR_API_KEY',
      'Content-Type': 'multipart/form-data',
    },
    body: formData, // FormData con il PDF
  }
);

const result = await response.json();
// result.plan → piano alimentare strutturato
// result.days → giorni della settimana
// result.cached → true se risposta da cache`;

  return (
    <section className={styles.apiSection}>
      <div className={styles.container}>
        <h2 className={styles.sectionTitle}>API Enterprise</h2>
        <p className={styles.sectionSubtitle}>
          Integra Kybo nel tuo software gestionale esistente con la nostra REST API
        </p>

        <div className={styles.apiGrid}>
          <div className={styles.apiInfo}>
            <p className={styles.apiInfoText}>
              Il piano Enterprise include accesso completo alla REST API di Kybo.
              Autenticazione via Bearer token, rate limit configurabile, webhook
              per eventi real-time e documentazione OpenAPI 3.0 completa.
            </p>

            <div className={styles.apiEndpoints}>
              {endpoints.map((ep) => (
                <div key={ep.path} className={styles.apiEndpoint}>
                  <span className={`${styles.apiMethod} ${styles[ep.cls as 'get' | 'post' | 'delete']}`}>
                    {ep.method}
                  </span>
                  <span className={styles.apiPath}>{ep.path}</span>
                  <span className={styles.apiPathDesc}>{ep.desc}</span>
                </div>
              ))}
            </div>

            <div className={styles.apiCtaRow}>
              <a
                href="mailto:enterprise@kybo.it"
                className={`${styles.apiCtaBtn} ${styles.apiCtaPrimary}`}
              >
                📩 Contatta Sales
              </a>
              <a
                href="https://kybo.onrender.com/docs"
                target="_blank"
                rel="noopener noreferrer"
                className={`${styles.apiCtaBtn} ${styles.apiCtaSecondary}`}
              >
                📖 Swagger Docs
              </a>
            </div>
          </div>

          <div className={styles.apiCode}>
            <div className={styles.apiCodeHeader}>
              <div className={styles.apiCodeDots}>
                <div className={styles.apiCodeDot} />
                <div className={styles.apiCodeDot} />
                <div className={styles.apiCodeDot} />
              </div>
              <span className={styles.apiCodeLang}>JavaScript / TypeScript</span>
            </div>
            <div className={styles.apiCodeBody}>
              <pre>{codeExample}</pre>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

// ===== PRICING SECTION =====
const professionalPlans = [
  {
    name: 'Nutrizionista Pro',
    icon: '👨‍⚕️',
    monthlyPrice: 29,
    annualPrice: 24,
    description: 'Per professionisti che gestiscono i propri pazienti.',
    highlight: true,
    badge: 'Più Popolare',
    features: [
      'Fino a 50 pazienti',
      'Dashboard admin completa',
      'Upload diete PDF con AI',
      'Chat con tutti i pazienti',
      'Analytics avanzate',
      'Report mensili PDF',
      'Notifiche messaggi non letti',
      'Note interne pazienti',
      'Broadcast messaggi ai clienti',
      'Supporto prioritario',
    ],
    cta: 'Inizia Gratis 14 giorni',
  },
  {
    name: 'Studio / Clinica',
    icon: '🏥',
    monthlyPrice: 79,
    annualPrice: 65,
    description: 'Per studi con più nutrizionisti e team.',
    highlight: false,
    features: [
      'Pazienti illimitati',
      'Più nutrizionisti (team)',
      'Tutto del piano Pro',
      '2FA per tutti i professionisti',
      'GDPR dashboard avanzata',
      'SLA garantito 99.9%',
      'Integrazione API Enterprise',
      'Account manager dedicato',
      'Onboarding e migrazione dati',
    ],
    cta: 'Contattaci',
  },
];

function PricingSection() {
  const [isAnnual, setIsAnnual] = useState(false);

  return (
    <section className={styles.pricingFull} id="prezzi">
      <div className={styles.container}>
        <h2 className={styles.sectionTitle}>Piani Tariffari</h2>
        <p className={styles.sectionSubtitle}>
          Scegli il piano giusto per la tua attività. Prova gratuita di 14 giorni, nessuna carta richiesta.
        </p>

        {/* Toggle mensile / annuale */}
        <div className={pStyles.toggleWrapper}>
          <span className={`${pStyles.toggleLabel} ${!isAnnual ? pStyles.activeLabel : ''}`}>Mensile</span>
          <button
            className={pStyles.toggle}
            onClick={() => setIsAnnual(!isAnnual)}
            aria-label="Cambia piano"
          >
            <span className={`${pStyles.toggleThumb} ${isAnnual ? pStyles.toggleThumbOn : ''}`} />
          </button>
          <span className={`${pStyles.toggleLabel} ${isAnnual ? pStyles.activeLabel : ''}`}>
            Annuale <span className={pStyles.saveBadge}>-17%</span>
          </span>
        </div>

        <div className={styles.pricingFullGrid}>
          {professionalPlans.map((plan) => (
            <div
              key={plan.name}
              className={`${pStyles.planCard} ${plan.highlight ? pStyles.planHighlight : ''}`}
            >
              {plan.badge && <div className={pStyles.planBadge}>{plan.badge}</div>}
              <div className={pStyles.planHeader}>
                <span className={pStyles.planIcon}>{plan.icon}</span>
                <h2 className={pStyles.planName}>{plan.name}</h2>
                <p className={pStyles.planDescription}>{plan.description}</p>
              </div>
              <div className={pStyles.priceBlock}>
                <>
                  <span className={pStyles.priceCurrency}>€</span>
                  <span className={pStyles.priceAmount}>
                    {isAnnual ? plan.annualPrice : plan.monthlyPrice}
                  </span>
                  <span className={pStyles.pricePeriod}>/mese</span>
                </>
                {isAnnual && (
                  <p className={pStyles.annualNote}>Fatturato annualmente</p>
                )}
              </div>
              <ul className={pStyles.featureList}>
                {plan.features.map((f, i) => (
                  <li key={i} className={pStyles.featureItem}>
                    <span className={pStyles.checkIcon}>✓</span>
                    {f}
                  </li>
                ))}
              </ul>
              <button
                className={`${pStyles.planCta} ${plan.highlight ? pStyles.planCtaHighlight : ''}`}
                onClick={() => document.getElementById('demo')?.scrollIntoView({ behavior: 'smooth' })}
              >
                {plan.cta}
              </button>
            </div>
          ))}
        </div>

        <p className={styles.pricingNote}>
          💚 I <strong>pazienti</strong> usano Kybo gratuitamente — il costo è solo per il professionista.
        </p>
      </div>
    </section>
  );
}

// ===== MAIN COMPONENT =====
export default function BusinessPageContent() {
  return (
    <>
      {/* Navbar */}
      <nav className={styles.nav}>
        <div className={styles.navContainer}>
          <Link href="/" className={styles.logo}>
            <Image src="/logo no bg.png" alt="Kybo" width={32} height={32} className={styles.logoIcon} priority />
            <span className={styles.logoText}>Kybo</span>
          </Link>
          <div className={styles.navActions}>
            <a href="https://app.kybo.it" target="_blank" rel="noopener noreferrer" className={styles.loginBtn}>
              Accedi alla Dashboard
            </a>
            <Link href="/" className={styles.backBtn}>
              ← Torna alla Home
            </Link>
          </div>
        </div>
      </nav>

      {/* Hero Section */}
      <section className={styles.hero}>
        <div className={styles.heroContent}>
          <h1 className={styles.title}>
            Kybo per Nutrizionisti
          </h1>
          <p className={styles.subtitle}>
            Potenzia la tua pratica professionale con strumenti avanzati per la gestione dei pazienti
          </p>
          <button
            className={styles.ctaBtn}
            onClick={() => document.getElementById('demo')?.scrollIntoView({ behavior: 'smooth' })}
          >
            Richiedi una Demo
          </button>
        </div>
      </section>

      {/* Features Section */}
      <section className={styles.features}>
        <div className={styles.container}>
          <h2 className={styles.sectionTitle}>Strumenti Professionali</h2>
          <p className={styles.sectionSubtitle}>
            Dashboard completa per gestire i tuoi pazienti con efficienza
          </p>

          <div className={styles.grid}>
            <div className={styles.featureCard}>
              <div className={styles.iconWrapper} style={{ background: 'linear-gradient(135deg, #66BB6A22 0%, #66BB6A44 100%)' }}>
                <span className={styles.icon}>👥</span>
              </div>
              <h3>Gestione Pazienti Completa</h3>
              <p>Crea, modifica ed elimina account pazienti direttamente dalla dashboard. Visualizza tutti i tuoi pazienti in un&apos;unica schermata con ricerca rapida per nome o email. Assegna pazienti a te stesso o trasferiscili ad altri nutrizionisti del team.</p>
              <div className={styles.featureHighlight}>
                <span>✓ Creazione account pazienti</span>
                <span>✓ Ricerca e filtri avanzati</span>
                <span>✓ Assegnazione nutrizionisti</span>
              </div>
            </div>

            <div className={styles.featureCard}>
              <div className={styles.iconWrapper} style={{ background: 'linear-gradient(135deg, #3B82F622 0%, #3B82F644 100%)' }}>
                <span className={styles.icon}>📋</span>
              </div>
              <h3>Upload Diete PDF</h3>
              <p>Carica piani alimentari in formato PDF direttamente per i tuoi pazienti. I file vengono salvati in modo sicuro e sono immediatamente accessibili dall&apos;app mobile del paziente. Supporto per configurazioni parser personalizzate.</p>
              <div className={styles.featureHighlight}>
                <span>✓ Upload PDF sicuro</span>
                <span>✓ Accesso immediato paziente</span>
                <span>✓ Parser configurabile</span>
              </div>
            </div>

            <div className={styles.featureCard}>
              <div className={styles.iconWrapper} style={{ background: 'linear-gradient(135deg, #8B5CF622 0%, #8B5CF644 100%)' }}>
                <span className={styles.icon}>📊</span>
              </div>
              <h3>Storico & Analytics</h3>
              <p>Visualizza lo storico completo di ogni paziente: diete caricate, progressi, aderenza al piano. Dashboard analytics con metriche chiave per monitorare l&apos;evoluzione dell&apos;intero portfolio clienti.</p>
              <div className={styles.featureHighlight}>
                <span>✓ Timeline completa paziente</span>
                <span>✓ Aderenza al piano</span>
                <span>✓ Report mensili automatici</span>
              </div>
            </div>

            <div className={styles.featureCard}>
              <div className={styles.iconWrapper} style={{ background: 'linear-gradient(135deg, #FFA72622 0%, #FFA72644 100%)' }}>
                <span className={styles.icon}>💬</span>
              </div>
              <h3>Chat & Comunicazione</h3>
              <p>Messaggistica diretta con i pazienti, supporto allegati foto e documenti. Broadcast a tutti i clienti, note interne riservate e alert automatici per messaggi non letti.</p>
              <div className={styles.featureHighlight}>
                <span>✓ Chat diretta</span>
                <span>✓ Broadcast messaggi</span>
                <span>✓ Note interne riservate</span>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ROI Calculator */}
      <RoiCalculator />

      {/* Demo Form */}
      <DemoForm />

      {/* Security */}
      <SecuritySection />

      {/* API Enterprise */}
      <ApiSection />

      {/* Pricing Section */}
      <PricingSection />

      {/* CTA Section */}
      <section className={styles.cta}>
        <div className={styles.ctaContent}>
          <h2>Pronto a trasformare la tua pratica?</h2>
          <p>Unisciti a centinaia di nutrizionisti che già usano Kybo</p>
          <div className={styles.ctaButtons}>
            <button className={styles.ctaBtn}
              onClick={() => document.getElementById('demo')?.scrollIntoView({ behavior: 'smooth' })}>
              Richiedi una Demo Gratuita
            </button>
            <a href="https://app.kybo.it" target="_blank" rel="noopener noreferrer" className={styles.ctaLoginBtn}>
              Accedi alla Dashboard →
            </a>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className={styles.footer}>
        <div className={styles.footerContent}>
          <p>© 2025 Kybo. Tutti i diritti riservati. · <Link href="/privacy" style={{ color: 'rgba(255,255,255,0.5)' }}>Privacy</Link> · <Link href="/terms" style={{ color: 'rgba(255,255,255,0.5)' }}>Termini</Link></p>
        </div>
      </footer>
    </>
  );
}
