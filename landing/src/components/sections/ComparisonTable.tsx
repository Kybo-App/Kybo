'use client';

import React, { useEffect, useRef } from 'react';
import styles from './ComparisonTable.module.css';

type CellValue = boolean | 'partial';

interface Row {
  feature: string;
  kybo: CellValue;
  manual: CellValue;
  others: CellValue;
}

const rows: Row[] = [
  {
    feature: 'Piano alimentare digitale',
    kybo: true,
    manual: false,
    others: 'partial',
  },
  {
    feature: 'Lista spesa automatica',
    kybo: true,
    manual: false,
    others: false,
  },
  {
    feature: 'Chat con nutrizionista',
    kybo: true,
    manual: false,
    others: false,
  },
  {
    feature: 'Tracking dispensa',
    kybo: true,
    manual: false,
    others: false,
  },
  {
    feature: 'Statistiche & progressi',
    kybo: true,
    manual: false,
    others: 'partial',
  },
  {
    feature: 'Allergeni evidenziati',
    kybo: true,
    manual: false,
    others: false,
  },
  {
    feature: 'Modalità offline',
    kybo: true,
    manual: true,
    others: 'partial',
  },
  {
    feature: 'Notifiche pasti',
    kybo: true,
    manual: false,
    others: 'partial',
  },
  {
    feature: 'Upload PDF nutrizionista',
    kybo: true,
    manual: false,
    others: false,
  },
  {
    feature: 'Gratuito per il paziente',
    kybo: true,
    manual: true,
    others: false,
  },
];

function Cell({ value }: { value: CellValue }) {
  if (value === true) return <span className={styles.yes}>✓</span>;
  if (value === 'partial') return <span className={styles.partial}>~</span>;
  return <span className={styles.no}>✗</span>;
}

export default function ComparisonTable() {
  const sectionRef = useRef<HTMLElement>(null);
  const tableRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (typeof window === 'undefined') return;

    const init = async () => {
      const { gsap } = await import('gsap');
      const { ScrollTrigger } = await import('gsap/ScrollTrigger');
      gsap.registerPlugin(ScrollTrigger);

      if (!sectionRef.current || !tableRef.current) return;

      // Fade in heading
      const heading = sectionRef.current.querySelector('h2');
      const subtitle = sectionRef.current.querySelector('p');
      if (heading && subtitle) {
        gsap.fromTo(
          [heading, subtitle],
          { opacity: 0, y: 30 },
          {
            opacity: 1,
            y: 0,
            duration: 0.7,
            stagger: 0.12,
            ease: 'power3.out',
            scrollTrigger: { trigger: sectionRef.current, start: 'top 80%', once: true },
          }
        );
      }

      // Rows stagger in
      const tableRows = tableRef.current.querySelectorAll('tr');
      gsap.fromTo(
        tableRows,
        { opacity: 0, x: -20 },
        {
          opacity: 1,
          x: 0,
          duration: 0.5,
          stagger: 0.06,
          ease: 'power2.out',
          scrollTrigger: { trigger: tableRef.current, start: 'top 80%', once: true },
        }
      );
    };

    init();
  }, []);

  return (
    <section ref={sectionRef} id="comparison" className={styles.section}>
      <div className={styles.container}>
        <h2 className={styles.title}>Perché scegliere Kybo?</h2>
        <p className={styles.subtitle}>
          Confronta Kybo con le alternative più comuni
        </p>

        <div ref={tableRef} className={styles.tableWrapper}>
          <table className={styles.table}>
            <thead>
              <tr>
                <th className={styles.featureCol}>Funzionalità</th>
                <th className={`${styles.colHeader} ${styles.kyboCol}`}>
                  <span className={styles.kyboBadge}>Kybo</span>
                </th>
                <th className={styles.colHeader}>Gestione Manuale</th>
                <th className={styles.colHeader}>Altri Tool</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row, i) => (
                <tr key={i} className={styles.row}>
                  <td className={styles.featureLabel}>{row.feature}</td>
                  <td className={`${styles.cell} ${styles.kyboCell}`}>
                    <Cell value={row.kybo} />
                  </td>
                  <td className={styles.cell}>
                    <Cell value={row.manual} />
                  </td>
                  <td className={styles.cell}>
                    <Cell value={row.others} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <p className={styles.legend}>
          <span className={styles.yes}>✓</span> Disponibile &nbsp;
          <span className={styles.partial}>~</span> Parzialmente &nbsp;
          <span className={styles.no}>✗</span> Non disponibile
        </p>
      </div>
    </section>
  );
}
