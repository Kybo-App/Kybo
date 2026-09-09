/**
 * Come cambia la gestione di uno studio con Kybo.
 *
 * NOTA — Questa pagina era un case study attribuito a una cliente inesistente
 * ("Dott.ssa Maria Rossi", biologa nutrizionista a Milano), completa di
 * citazioni dirette, badge "Cliente Kybo Pro" e metriche non verificabili
 * (70% di tempo risparmiato, 4.9★ di soddisfazione, clienti triplicati) per un
 * prodotto non ancora pubblicato.
 *
 * È stata riscritta come scenario illustrativo, dichiarato come tale in pagina.
 * Le voci del confronto prima/dopo descrivono funzioni che il prodotto ha
 * davvero. Quando ci sarà un cliente reale disposto a farsi citare, questa
 * pagina può tornare a essere un case study vero — con dati suoi.
 */
import React from 'react';
import Link from 'next/link';
import Navbar from '@/components/Navbar';
import { UiIcon, type UiIconKey } from '@/components/icons/UiIcons';
import { it } from '@/content/it';
import styles from './case-study.module.css';

/** Funzioni del prodotto, non risultati misurati su un cliente. */
const capabilities: Array<{ icon: UiIconKey; value: string; label: string }> = [
  { icon: 'upload', value: 'PDF', label: 'la dieta che carichi viene letta e strutturata dall’AI' },
  { icon: 'chat', value: 'In-app', label: 'la comunicazione col paziente vive in un canale solo' },
  { icon: 'chart', value: 'Live', label: 'l’aderenza al piano è visibile senza chiedere nulla' },
  { icon: 'euro', value: '0 €', label: 'per il paziente, sempre' },
];

const timeline: Array<{ icon: UiIconKey; phase: string; title: string; desc: string }> = [
  {
    phase: 'Primo accesso',
    title: 'Carichi le diete che hai già',
    desc: 'I PDF esistenti vengono letti dal parser AI e trasformati in piani interattivi, senza riscrivere nulla a mano.',
    icon: 'upload',
  },
  {
    phase: 'Attivazione',
    title: 'Inviti i pazienti',
    desc: 'Ogni paziente riceve un link, installa l’app e trova il suo piano già pronto.',
    icon: 'mobile',
  },
  {
    phase: 'Uso quotidiano',
    title: 'Le domande arrivano in un posto solo',
    desc: 'La chat integrata sostituisce WhatsApp ed email. Il paziente segna i pasti consumati direttamente nell’app.',
    icon: 'chat',
  },
  {
    phase: 'Nel tempo',
    title: 'Vedi chi sta faticando',
    desc: 'La dashboard mostra l’aderenza al piano, così puoi intervenire prima della visita successiva invece che dopo.',
    icon: 'chart',
  },
];

const challenges = [
  'Diete gestite su fogli Excel condivisi via email — versioni confuse, file che si perdono',
  'Comunicazione col paziente sparsa tra WhatsApp, email e telefonate',
  'Nessuna visibilità su cosa succede tra una visita e l’altra',
  'Report compilati a mano, ogni volta da capo',
];

const solutions = [
  'Il PDF diventa un piano interattivo senza reinserimento manuale',
  'Chat professionale integrata, separata dai messaggi personali',
  'Aderenza al piano visibile in dashboard',
  'Report generati dai dati già raccolti',
  'Lista della spesa creata in automatico dal piano del paziente',
];

const before = [
  ['Diete', 'Excel e PDF via email'],
  ['Comunicazione', 'WhatsApp ed email mescolate'],
  ['Aderenza', 'Nessuna visibilità'],
  ['Report', 'Compilati a mano'],
];

const after = [
  ['Diete', 'App interattiva'],
  ['Comunicazione', 'Chat dedicata in-app'],
  ['Aderenza', 'Dashboard aggiornata'],
  ['Report', 'Generati dai dati'],
];

export default function CaseStudyPage() {
  return (
    <>
      <Navbar content={it.nav} />
      <main className={styles.main}>

        <section className={styles.hero}>
          <div className={styles.heroContainer}>
            <Link href="/" className={styles.breadcrumb}>
              <UiIcon name="arrowLeft" size={15} /> Torna alla home
            </Link>
            <span className={styles.label}>Scenario</span>
            <h1 className={styles.heroTitle}>
              Come cambia la gestione di uno studio{' '}
              <span className={styles.accent}>con Kybo</span>
            </h1>
            <p className={styles.heroSubtitle}>
              Un percorso illustrativo, costruito sulle funzioni che Kybo offre oggi.
              Non è il racconto di un cliente reale: quando ne avremo uno disposto a
              raccontarsi, questa pagina riporterà i suoi numeri.
            </p>
          </div>
        </section>

        <section className={styles.metricsSection}>
          <div className={styles.container}>
            <div className={styles.metricsGrid}>
              {capabilities.map((m) => (
                <div key={m.label} className={styles.metricCard}>
                  <span className={styles.metricIcon}>
                    <UiIcon name={m.icon} size={26} />
                  </span>
                  <p className={styles.metricValue}>{m.value}</p>
                  <p className={styles.metricLabel}>{m.label}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section className={styles.section}>
          <div className={styles.container}>
            <div className={styles.sectionGrid}>
              <div className={styles.sectionContent}>
                <span className={styles.sectionLabel}>Il problema</span>
                <h2 className={styles.sectionTitle}>Il tempo che se ne va in amministrazione</h2>
                <p className={styles.sectionText}>
                  Gran parte del lavoro di uno studio di nutrizione non è nutrizione:
                  è spostare file, rincorrere messaggi e ricostruire a mano cosa ha
                  fatto il paziente nelle ultime settimane.
                </p>
                <ul className={styles.challengeList}>
                  {challenges.map((c) => (
                    <li key={c} className={styles.challengeItem}>
                      <span className={styles.challengeIcon}>
                        <UiIcon name="cross" size={13} />
                      </span>
                      {c}
                    </li>
                  ))}
                </ul>
              </div>
              <div className={styles.sectionVisual}>
                <div className={styles.beforeCard}>
                  <p className={styles.beforeCardTitle}>
                    <UiIcon name="warning" size={16} /> Senza Kybo
                  </p>
                  {before.map(([k, v]) => (
                    <div key={k} className={styles.beforeRow}>
                      <span>{k}</span>
                      <span className={styles.bad}>{v}</span>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className={`${styles.section} ${styles.sectionAlt}`}>
          <div className={styles.container}>
            <div className={`${styles.sectionGrid} ${styles.sectionGridReverse}`}>
              <div className={styles.sectionContent}>
                <span className={styles.sectionLabel}>La soluzione</span>
                <h2 className={styles.sectionTitle}>Un posto solo per diete, messaggi e progressi</h2>
                <p className={styles.sectionText}>
                  Kybo raccoglie in un&apos;unica piattaforma quello che oggi è sparso tra
                  strumenti diversi. Il parser AI legge i PDF e li rende consultabili
                  dal paziente sul telefono.
                </p>
                <ul className={styles.solutionList}>
                  {solutions.map((s) => (
                    <li key={s}>
                      <span className={styles.solutionIcon}>
                        <UiIcon name="check" size={13} />
                      </span>
                      {s}
                    </li>
                  ))}
                </ul>
              </div>
              <div className={styles.sectionVisual}>
                <div className={styles.afterCard}>
                  <p className={styles.afterCardTitle}>
                    <UiIcon name="check" size={16} /> Con Kybo
                  </p>
                  {after.map(([k, v]) => (
                    <div key={k} className={styles.afterRow}>
                      <span>{k}</span>
                      <span className={styles.good}>{v}</span>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className={styles.section}>
          <div className={styles.container}>
            <div className={styles.timelineHeader}>
              <span className={styles.sectionLabel}>Il percorso</span>
              <h2 className={styles.sectionTitle}>Come si mette in piedi</h2>
            </div>
            <div className={styles.timeline}>
              {timeline.map((step, i) => (
                <div key={step.phase} className={styles.timelineItem}>
                  <div className={styles.timelineLeft}>
                    <div className={styles.timelineDot}>
                      <UiIcon name={step.icon} size={17} />
                    </div>
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

        <section className={styles.ctaSection}>
          <div className={styles.container}>
            <h2 className={styles.ctaTitle}>Vuoi vedere come funziona sul tuo studio?</h2>
            <p className={styles.ctaSubtitle}>
              Ti mostriamo la piattaforma e rispondiamo alle domande.
            </p>
            <div className={styles.ctaButtons}>
              <Link href="/business" className={styles.ctaPrimary}>
                Kybo per i professionisti
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
