'use client';

import Link from 'next/link';
import styles from '../shared.module.css';
import Navbar from '@/components/Navbar';
import { UiIcon } from '@/components/icons/UiIcons';
import { it } from '@/content/it';

export default function AboutPage() {
  return (
    <div className={styles.pageWrapper}>
      <Navbar content={it.nav} />

      {/* Hero */}
      <div className={styles.heroSmall}>
        <h1 className={styles.pageTitle}>Cos’è Kybo</h1>
        <p className={styles.pageSubtitle}>
          La missione di Kybo è rendere la nutrizione accessibile, semplice e personalizzata per tutti.
        </p>
      </div>

      {/* Mission */}
      <section className={styles.section}>
        <div className={styles.container}>
          <h2 className={styles.sectionTitle}>Perché esiste</h2>
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
              <span className={styles.valueIcon}><UiIcon name="target" size={26} /></span>
              <h3 className={styles.valueTitle}>Semplicità</h3>
              <p className={styles.valueText}>Rendiamo la nutrizione accessibile a tutti, eliminando complessità inutili.</p>
            </div>
            <div className={styles.valueCard}>
              <span className={styles.valueIcon}><UiIcon name="science" size={26} /></span>
              <h3 className={styles.valueTitle}>Innovazione</h3>
              <p className={styles.valueText}>Utilizziamo la tecnologia più avanzata per migliorare l&apos;esperienza utente.</p>
            </div>
            <div className={styles.valueCard}>
              <span className={styles.valueIcon}><UiIcon name="handshake" size={26} /></span>
              <h3 className={styles.valueTitle}>Collaborazione</h3>
              <p className={styles.valueText}>Lavoriamo a stretto contatto con nutrizionisti e utenti per creare il prodotto migliore.</p>
            </div>
            <div className={styles.valueCard}>
              <span className={styles.valueIcon}><UiIcon name="lock" size={26} /></span>
              <h3 className={styles.valueTitle}>Privacy</h3>
              <p className={styles.valueText}>La sicurezza e la privacy dei dati dei nostri utenti è la nostra priorità assoluta.</p>
            </div>
          </div>
        </div>
      </section>

      {/* Chi lo fa */}
      <section className={styles.section}>
        <div className={styles.container}>
          <h2 className={styles.sectionTitle}>Chi lo sviluppa</h2>
          <p className={styles.sectionText}>
            Kybo è sviluppato da una persona sola. Non c&apos;è un team di design né
            un comitato scientifico: c&apos;è un progetto in costruzione, portato
            avanti con l&apos;idea che gestire un piano alimentare non debba essere
            un lavoro d&apos;archivio.
          </p>
          <p className={styles.sectionText} style={{ marginTop: '1.5rem' }}>
            Se sei un nutrizionista e vuoi dire la tua su cosa manca, o hai
            competenze da mettere a disposizione, la pagina{' '}
            <Link href="/careers" className={styles.inlineLink}>collabora</Link>{' '}
            spiega come farsi sentire.
          </p>
        </div>
      </section>

      {/* CTA */}
      <section className={styles.ctaBanner}>
        <h2 className={styles.ctaTitle}>Vuoi saperne di più?</h2>
        <p className={styles.ctaText}>Guarda come funziona, o lascia la mail per sapere quando esce.</p>
        <Link href="/#features" className={styles.ctaBtn}>Scopri Kybo</Link>
      </section>

      {/* Footer */}
      <footer className={styles.footer}>
        <p className={styles.footerText}>© 2025 Kybo. Tutti i diritti riservati.</p>
      </footer>
    </div>
  );
}
