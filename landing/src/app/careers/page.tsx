'use client';

/*
  Qui c'erano quattro posizioni aperte (Flutter Developer, Backend Developer,
  UX/UI Designer, Nutrizionista Consulente) con tanto di bottone "Candidati",
  e un elenco di benefit aziendali — budget formazione, team, percorsi di
  carriera. Kybo è un progetto portato avanti da una persona sola: quelle
  posizioni non esistono e chi si candidava non riceveva risposta da nessuno.

  La pagina è diventata un invito onesto a collaborare, che è la cosa vera.
*/

import styles from '../shared.module.css';
import Navbar from '@/components/Navbar';
import { UiIcon, type UiIconKey } from '@/components/icons/UiIcons';
import { it } from '@/content/it';

const profili: Array<{ icon: UiIconKey; title: string; text: string }> = [
  {
    icon: 'stethoscope',
    title: 'Nutrizionisti e biologi',
    text: 'Per validare come Kybo struttura i piani alimentari e capire cosa serve davvero in uno studio.',
  },
  {
    icon: 'code',
    title: 'Sviluppatori',
    text: 'Lo stack è Flutter per le app, FastAPI e Firebase sul backend, Next.js per questo sito.',
  },
  {
    icon: 'palette',
    title: 'Designer',
    text: 'C’è molto da sistemare su interfaccia e accessibilità, sia nell’app che qui.',
  },
];

export default function CareersPage() {
  return (
    <div className={styles.pageWrapper}>
      <Navbar content={it.nav} />

      <div className={styles.heroSmall}>
        <h1 className={styles.pageTitle}>Collabora con Kybo</h1>
        <p className={styles.pageSubtitle}>
          Kybo oggi è il progetto di una persona sola. Non ci sono posizioni aperte
          né stipendi da offrire — c’è un prodotto in costruzione e spazio per chi
          ha voglia di contribuire.
        </p>
      </div>

      <section className={styles.sectionAlt}>
        <div className={styles.container}>
          <h2 className={styles.sectionTitle}>Chi può dare una mano</h2>
          <div className={styles.valuesGrid}>
            {profili.map((p) => (
              <div key={p.title} className={styles.valueCard}>
                <span className={styles.valueIcon}>
                  <UiIcon name={p.icon} size={24} />
                </span>
                <h3 className={styles.valueTitle}>{p.title}</h3>
                <p className={styles.valueText}>{p.text}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className={styles.ctaBanner}>
        <h2 className={styles.ctaTitle}>Ti interessa?</h2>
        <p className={styles.ctaText}>
          Scrivimi a info@kybo.it: raccontami cosa sai fare e cosa ti incuriosisce
          del progetto. Rispondo io.
        </p>
        <a href="mailto:info@kybo.it" className={styles.ctaBtn}>
          Scrivi una mail
        </a>
      </section>

      <footer className={styles.footer}>
        <p className={styles.footerText}>© 2025 Kybo. Tutti i diritti riservati.</p>
      </footer>
    </div>
  );
}
