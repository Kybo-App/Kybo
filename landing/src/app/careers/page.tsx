'use client';

import Link from 'next/link';
import Image from 'next/image';
import styles from '../shared.module.css';

const openPositions = [
  {
    id: 1,
    title: 'Flutter Developer',
    location: 'Remoto',
    type: 'Full-time',
    description: 'Cerchiamo uno sviluppatore Flutter esperto per contribuire allo sviluppo dell\'app mobile Kybo. Esperienza con state management e integrazione API richiesta.',
  },
  {
    id: 2,
    title: 'Backend Developer (Python/FastAPI)',
    location: 'Remoto',
    type: 'Full-time',
    description: 'Unisciti al team backend per sviluppare e mantenere le API che alimentano l\'ecosistema Kybo. Esperienza con Firebase e cloud services è un plus.',
  },
  {
    id: 3,
    title: 'UX/UI Designer',
    location: 'Remoto',
    type: 'Part-time',
    description: 'Cerchiamo un designer creativo per migliorare continuamente l\'esperienza utente su tutte le piattaforme Kybo. Portfolio richiesto.',
  },
  {
    id: 4,
    title: 'Nutrizionista Consulente',
    location: 'Remoto',
    type: 'Freelance',
    description: 'Collabora con noi per validare funzionalità nutrizionali, creare contenuti educativi e fornire consulenza scientifica al team di sviluppo.',
  },
];

const perks = [
  { icon: '🏠', title: 'Lavoro 100% Remoto', text: 'Lavora da dove vuoi, quando vuoi. Flessibilità totale.' },
  { icon: '📚', title: 'Formazione Continua', text: 'Budget annuale per corsi, conferenze e crescita professionale.' },
  { icon: '🚀', title: 'Impatto Reale', text: 'Il tuo lavoro aiuterà migliaia di persone a vivere meglio.' },
  { icon: '🤝', title: 'Team Appassionato', text: 'Un ambiente collaborativo dove le idee di tutti contano.' },
  { icon: '⚡', title: 'Strumenti Moderni', text: 'Stack tecnologico all\'avanguardia e processi agili.' },
  { icon: '🌱', title: 'Crescita Rapida', text: 'Startup in crescita con opportunità di carriera concrete.' },
];

export default function CareersPage() {
  return (
    <div className={styles.pageWrapper}>
      {/* Navbar */}
      <nav className={styles.nav}>
        <div className={styles.navContainer}>
          <Link href="/" className={styles.logo}>
            <Image src="/logo no bg.png" alt="Kybo" width={32} height={32} className={styles.logoIcon} priority />
            <span className={styles.logoText}>Kybo</span>
          </Link>
          <Link href="/" className={styles.backBtn}>
            ← Torna alla Home
          </Link>
        </div>
      </nav>

      {/* Hero */}
      <div className={styles.heroSmall}>
        <h1 className={styles.pageTitle}>Lavora con Noi</h1>
        <p className={styles.pageSubtitle}>
          Unisciti al team Kybo e aiutaci a rivoluzionare il mondo della nutrizione digitale.
        </p>
      </div>

      {/* Perks */}
      <section className={styles.sectionAlt}>
        <div className={styles.container}>
          <h2 className={styles.sectionTitle}>Perché Kybo?</h2>
          <div className={styles.valuesGrid}>
            {perks.map((perk, i) => (
              <div key={i} className={styles.valueCard}>
                <span className={styles.valueIcon}>{perk.icon}</span>
                <h3 className={styles.valueTitle}>{perk.title}</h3>
                <p className={styles.valueText}>{perk.text}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Open Positions */}
      <section className={styles.section}>
        <div className={styles.container}>
          <h2 className={styles.sectionTitle}>Posizioni Aperte</h2>
          <p className={styles.sectionText}>
            Stiamo cercando persone talentuose e appassionate da aggiungere al nostro team.
          </p>
          <div className={styles.jobsList}>
            {openPositions.map((job) => (
              <div key={job.id} className={styles.jobCard}>
                <div className={styles.jobInfo}>
                  <h3 className={styles.jobTitle}>{job.title}</h3>
                  <div className={styles.jobMeta}>
                    <span className={styles.jobMetaItem}>📍 {job.location}</span>
                    <span className={styles.jobMetaItem}>⏰ {job.type}</span>
                  </div>
                  <p className={styles.jobDescription}>{job.description}</p>
                </div>
                <button className={styles.applyBtn}>Candidati</button>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className={styles.ctaBanner}>
        <h2 className={styles.ctaTitle}>Non trovi la posizione giusta?</h2>
        <p className={styles.ctaText}>Inviaci la tua candidatura spontanea a careers@kybo.app</p>
        <a href="mailto:careers@kybo.app" className={styles.ctaBtn}>Invia Candidatura</a>
      </section>

      {/* Footer */}
      <footer className={styles.footer}>
        <p className={styles.footerText}>© 2025 Kybo. Tutti i diritti riservati.</p>
      </footer>
    </div>
  );
}
