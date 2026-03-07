/**
 * Case Study — Dott.ssa Maria Rossi
 * Pagina che racconta l'adozione di Kybo da parte di una biologa nutrizionista milanese:
 * sfida iniziale, soluzione adottata, risultati misurabili, testimonianza diretta.
 */
import React from 'react';
import Link from 'next/link';
import Navbar from '@/components/Navbar';
import styles from './case-study.module.css';

const metrics = [
  { value: '70%', label: 'tempo amministrativo risparmiato', icon: '⏱️' },
  { value: '3×', label: 'clienti gestiti in parallelo', icon: '👥' },
  { value: '4.9★', label: 'soddisfazione media clienti', icon: '⭐' },
  { value: '< 5 min', label: 'per caricare una nuova dieta', icon: '⚡' },
];

const timeline = [
  {
    phase: 'Settimana 1',
    title: 'Onboarding e importazione dati',
    desc: 'La Dott.ssa Rossi ha caricato i PDF delle diete già in suo possesso. Kybo le ha estratte automaticamente con il parser AI, senza riscrivere nulla a mano.',
    icon: '📤',
  },
  {
    phase: 'Settimane 2–3',
    title: 'Attivazione dei clienti',
    desc: "I clienti hanno ricevuto l'invito via link e installato l'app in pochi minuti. Il 95% ha completato l'onboarding entro 48 ore.",
    icon: '📱',
  },
  {
    phase: 'Mese 1',
    title: 'Gestione diete e chat',
    desc: 'La nutrizionista ha iniziato a comunicare via chat integrata, eliminando WhatsApp. I clienti segnalavano aderenza ai pasti direttamente nell\'app.',
    icon: '💬',
  },
  {
    phase: 'Mese 2–3',
    title: 'Analisi e ottimizzazione',
    desc: 'La Dott.ssa Rossi ha usato la dashboard analytics per identificare i clienti con aderenza bassa e inviare messaggi mirati prima delle ricadute.',
    icon: '📊',
  },
];

const challenges = [
  'Gestione diete su foglio Excel condiviso via email — versioni confuse, dati persi',
  'Comunicazione con i clienti frammentata tra WhatsApp, email e telefonate',
  'Nessuna visibilità sull\'aderenza dei clienti tra una visita e l\'altra',
  'Report mensili compilati a mano — 3–4 ore per paziente ogni mese',
];

export default function CaseStudyPage() {
  return (
    <>
      <Navbar />
      <main className={styles.main}>

        {/* Hero */}
        <section className={styles.hero}>
          <div className={styles.heroContainer}>
            <Link href="/" className={styles.breadcrumb}>← Torna alla home</Link>
            <span className={styles.label}>Case Study</span>
            <h1 className={styles.heroTitle}>
              Come la Dott.ssa Rossi ha{' '}
              <span className={styles.accent}>triplicato i clienti</span>{' '}
              senza assumere personale
            </h1>
            <p className={styles.heroSubtitle}>
              Biologa nutrizionista con studio a Milano. 8 anni di esperienza.
              Kybo ha trasformato la sua gestione quotidiana in 90 giorni.
            </p>

            <div className={styles.profileCard}>
              <div className={styles.avatar}>DR</div>
              <div className={styles.profileInfo}>
                <p className={styles.profileName}>Dott.ssa Maria Rossi</p>
                <p className={styles.profileRole}>Biologa Nutrizionista · Milano</p>
                <p className={styles.profileDetail}>Studio privato · 40+ clienti attivi</p>
              </div>
              <div className={styles.profileBadge}>Cliente Kybo Pro</div>
            </div>
          </div>
        </section>

        {/* Metrics */}
        <section className={styles.metricsSection}>
          <div className={styles.container}>
            <div className={styles.metricsGrid}>
              {metrics.map((m) => (
                <div key={m.label} className={styles.metricCard}>
                  <span className={styles.metricIcon}>{m.icon}</span>
                  <p className={styles.metricValue}>{m.value}</p>
                  <p className={styles.metricLabel}>{m.label}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* Challenges */}
        <section className={styles.section}>
          <div className={styles.container}>
            <div className={styles.sectionGrid}>
              <div className={styles.sectionContent}>
                <span className={styles.sectionLabel}>La sfida</span>
                <h2 className={styles.sectionTitle}>Prima di Kybo: gestire tutto a mano</h2>
                <p className={styles.sectionText}>
                  Come la maggior parte dei nutrizionisti, la Dott.ssa Rossi trascorreva
                  ore ogni settimana su attività amministrative che nulla avevano a che
                  fare con la nutrizione.
                </p>
                <ul className={styles.challengeList}>
                  {challenges.map((c) => (
                    <li key={c} className={styles.challengeItem}>
                      <span className={styles.challengeIcon}>✗</span>
                      {c}
                    </li>
                  ))}
                </ul>
                <blockquote className={styles.quote}>
                  <p>
                    &ldquo;Passavo più tempo a gestire file Excel che a fare la
                    nutrizionista. Non era sostenibile.&rdquo;
                  </p>
                  <cite>— Dott.ssa Maria Rossi</cite>
                </blockquote>
              </div>
              <div className={styles.sectionVisual}>
                <div className={styles.beforeCard}>
                  <p className={styles.beforeCardTitle}>⚠️ Prima di Kybo</p>
                  <div className={styles.beforeRow}><span>Diete</span><span className={styles.bad}>Excel / PDF email</span></div>
                  <div className={styles.beforeRow}><span>Comunicazione</span><span className={styles.bad}>WhatsApp + email</span></div>
                  <div className={styles.beforeRow}><span>Aderenza clienti</span><span className={styles.bad}>Nessuna visibilità</span></div>
                  <div className={styles.beforeRow}><span>Report mensili</span><span className={styles.bad}>3–4 ore/cliente</span></div>
                  <div className={styles.beforeRow}><span>Clienti max gestibili</span><span className={styles.bad}>~15</span></div>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* Solution */}
        <section className={`${styles.section} ${styles.sectionAlt}`}>
          <div className={styles.container}>
            <div className={`${styles.sectionGrid} ${styles.sectionGridReverse}`}>
              <div className={styles.sectionContent}>
                <span className={styles.sectionLabel}>La soluzione</span>
                <h2 className={styles.sectionTitle}>Kybo come unico hub per tutto</h2>
                <p className={styles.sectionText}>
                  Con Kybo, la Dott.ssa Rossi ha centralizzato diete, comunicazione e
                  monitoraggio in un&apos;unica piattaforma. Il parser AI legge i suoi PDF e
                  li rende interattivi per i clienti in pochi secondi.
                </p>
                <ul className={styles.solutionList}>
                  <li><span className={styles.solutionIcon}>✓</span>Upload PDF → dieta strutturata in 30 secondi</li>
                  <li><span className={styles.solutionIcon}>✓</span>Chat professionale integrata con notifiche push</li>
                  <li><span className={styles.solutionIcon}>✓</span>Dashboard aderenza in tempo reale</li>
                  <li><span className={styles.solutionIcon}>✓</span>Report mensili generati automaticamente</li>
                  <li><span className={styles.solutionIcon}>✓</span>Lista spesa automatica dalle diete per i clienti</li>
                </ul>
              </div>
              <div className={styles.sectionVisual}>
                <div className={styles.afterCard}>
                  <p className={styles.afterCardTitle}>✅ Con Kybo</p>
                  <div className={styles.afterRow}><span>Diete</span><span className={styles.good}>App interattiva</span></div>
                  <div className={styles.afterRow}><span>Comunicazione</span><span className={styles.good}>Chat in-app</span></div>
                  <div className={styles.afterRow}><span>Aderenza clienti</span><span className={styles.good}>Dashboard live</span></div>
                  <div className={styles.afterRow}><span>Report mensili</span><span className={styles.good}>Automatici</span></div>
                  <div className={styles.afterRow}><span>Clienti max gestibili</span><span className={styles.good}>40+ (e oltre)</span></div>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* Timeline */}
        <section className={styles.section}>
          <div className={styles.container}>
            <div className={styles.timelineHeader}>
              <span className={styles.sectionLabel}>Il percorso</span>
              <h2 className={styles.sectionTitle}>Da zero a piena operatività in 30 giorni</h2>
            </div>
            <div className={styles.timeline}>
              {timeline.map((step, i) => (
                <div key={step.phase} className={styles.timelineItem}>
                  <div className={styles.timelineLeft}>
                    <div className={styles.timelineDot}>{step.icon}</div>
                    {i < timeline.length - 1 && <div className={styles.timelineLine} />}
                  </div>
                  <div className={styles.timelineContent}>
                    <span className={styles.timelinePhase}>{step.phase}</span>
                    <h3 className={styles.timelineTitle}>{step.title}</h3>
                    <p className={styles.timelineDesc}>{step.desc}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* Final quote */}
        <section className={`${styles.section} ${styles.sectionFinal}`}>
          <div className={styles.container}>
            <div className={styles.finalQuote}>
              <p className={styles.finalQuoteText}>
                &ldquo;Kybo non è solo un&#39;app. È come avere un assistente sempre
                disponibile che gestisce la parte burocratica al posto mio. Ora posso
                concentrarmi sui pazienti, che è quello che amo fare.&rdquo;
              </p>
              <div className={styles.finalAuthor}>
                <div className={`${styles.avatar} ${styles.avatarLg}`}>DR</div>
                <div>
                  <p className={styles.finalAuthorName}>Dott.ssa Maria Rossi</p>
                  <p className={styles.finalAuthorRole}>Biologa Nutrizionista · Milano · Cliente Kybo dal 2024</p>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* CTA */}
        <section className={styles.ctaSection}>
          <div className={styles.container}>
            <h2 className={styles.ctaTitle}>Vuoi lo stesso risultato?</h2>
            <p className={styles.ctaSubtitle}>
              Inizia gratis. Nessuna carta di credito richiesta.
            </p>
            <div className={styles.ctaButtons}>
              <Link href="/business" className={styles.ctaPrimary}>
                Prova Kybo gratis
              </Link>
              <Link href="/contact" className={styles.ctaSecondary}>
                Parla con noi
              </Link>
            </div>
          </div>
        </section>

      </main>
    </>
  );
}
