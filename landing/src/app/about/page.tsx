'use client';

import Link from 'next/link';
import Image from 'next/image';
import styles from '../shared.module.css';

export default function AboutPage() {
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
        <h1 className={styles.pageTitle}>Chi Siamo</h1>
        <p className={styles.pageSubtitle}>
          La missione di Kybo è rendere la nutrizione accessibile, semplice e personalizzata per tutti.
        </p>
      </div>

      {/* Mission */}
      <section className={styles.section}>
        <div className={styles.container}>
          <h2 className={styles.sectionTitle}>La Nostra Missione</h2>
          <p className={styles.sectionText}>
            Kybo nasce dalla convinzione che una corretta alimentazione non debba essere complicata. Il nostro obiettivo è creare strumenti innovativi che aiutino le persone a gestire la propria nutrizione in modo semplice ed efficace, e che supportino i professionisti della nutrizione nel loro lavoro quotidiano.
          </p>
          <p className={styles.sectionText} style={{ marginTop: '1.5rem' }}>
            Crediamo che la tecnologia possa essere un ponte tra la scienza della nutrizione e la vita quotidiana. Per questo abbiamo sviluppato un ecosistema completo: un&apos;app per i clienti che rende il tracciamento alimentare intuitivo, e una dashboard professionale per i nutrizionisti che semplifica la gestione dei pazienti.
          </p>
        </div>
      </section>

      {/* Values */}
      <section className={styles.sectionAlt}>
        <div className={styles.container}>
          <h2 className={styles.sectionTitle}>I Nostri Valori</h2>
          <div className={styles.valuesGrid}>
            <div className={styles.valueCard}>
              <span className={styles.valueIcon}>🎯</span>
              <h3 className={styles.valueTitle}>Semplicità</h3>
              <p className={styles.valueText}>Rendiamo la nutrizione accessibile a tutti, eliminando complessità inutili.</p>
            </div>
            <div className={styles.valueCard}>
              <span className={styles.valueIcon}>🔬</span>
              <h3 className={styles.valueTitle}>Innovazione</h3>
              <p className={styles.valueText}>Utilizziamo la tecnologia più avanzata per migliorare l&apos;esperienza utente.</p>
            </div>
            <div className={styles.valueCard}>
              <span className={styles.valueIcon}>🤝</span>
              <h3 className={styles.valueTitle}>Collaborazione</h3>
              <p className={styles.valueText}>Lavoriamo a stretto contatto con nutrizionisti e utenti per creare il prodotto migliore.</p>
            </div>
            <div className={styles.valueCard}>
              <span className={styles.valueIcon}>🔒</span>
              <h3 className={styles.valueTitle}>Privacy</h3>
              <p className={styles.valueText}>La sicurezza e la privacy dei dati dei nostri utenti è la nostra priorità assoluta.</p>
            </div>
          </div>
        </div>
      </section>

      {/* Team */}
      <section className={styles.section}>
        <div className={styles.container}>
          <h2 className={styles.sectionTitle}>Il Team</h2>
          <p className={styles.sectionText}>
            Un team appassionato di tecnologia e nutrizione, unito dalla volontà di fare la differenza.
          </p>
          <div className={styles.teamGrid}>
            <div className={styles.teamCard}>
              <div className={styles.avatar}>👨‍💻</div>
              <h3 className={styles.teamName}>Leonardo</h3>
              <p className={styles.teamRole}>Founder & Developer</p>
            </div>
            <div className={styles.teamCard}>
              <div className={styles.avatar}>🎨</div>
              <h3 className={styles.teamName}>Design Team</h3>
              <p className={styles.teamRole}>UX/UI Design</p>
            </div>
            <div className={styles.teamCard}>
              <div className={styles.avatar}>🔬</div>
              <h3 className={styles.teamName}>Nutrition Team</h3>
              <p className={styles.teamRole}>Consulenza Nutrizionale</p>
            </div>
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className={styles.ctaBanner}>
        <h2 className={styles.ctaTitle}>Vuoi saperne di più?</h2>
        <p className={styles.ctaText}>Scarica Kybo e scopri come possiamo aiutarti nel tuo percorso nutrizionale.</p>
        <Link href="/" className={styles.ctaBtn}>Scopri Kybo</Link>
      </section>

      {/* Footer */}
      <footer className={styles.footer}>
        <p className={styles.footerText}>© 2025 Kybo. Tutti i diritti riservati.</p>
      </footer>
    </div>
  );
}
