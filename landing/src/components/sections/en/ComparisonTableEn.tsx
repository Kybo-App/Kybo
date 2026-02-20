'use client';

import React, { useEffect, useRef } from 'react';
import styles from '../ComparisonTable.module.css';

type CellValue = boolean | 'partial';
interface Row { feature: string; kybo: CellValue; manual: CellValue; others: CellValue; }

const rows: Row[] = [
  { feature: 'Digital meal plan', kybo: true, manual: false, others: 'partial' },
  { feature: 'Automatic shopping list', kybo: true, manual: false, others: false },
  { feature: 'Nutritionist chat', kybo: true, manual: false, others: false },
  { feature: 'Pantry tracking', kybo: true, manual: false, others: false },
  { feature: 'Statistics & progress', kybo: true, manual: false, others: 'partial' },
  { feature: 'Allergen highlights', kybo: true, manual: false, others: false },
  { feature: 'Offline mode', kybo: true, manual: true, others: 'partial' },
  { feature: 'Meal notifications', kybo: true, manual: false, others: 'partial' },
  { feature: 'Nutritionist PDF upload', kybo: true, manual: false, others: false },
  { feature: 'Free for patients', kybo: true, manual: true, others: false },
];

function Cell({ value }: { value: CellValue }) {
  if (value === true) return <span className={styles.yes}>✓</span>;
  if (value === 'partial') return <span className={styles.partial}>~</span>;
  return <span className={styles.no}>✗</span>;
}

export default function ComparisonTableEn() {
  const sectionRef = useRef<HTMLElement>(null);
  const tableRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (typeof window === 'undefined') return;

    const init = async () => {
      const { gsap } = await import('gsap');
      const { ScrollTrigger } = await import('gsap/ScrollTrigger');
      gsap.registerPlugin(ScrollTrigger);

      if (!sectionRef.current || !tableRef.current) return;

      const heading = sectionRef.current.querySelector('h2');
      const subtitle = sectionRef.current.querySelector('p');
      if (heading && subtitle) {
        gsap.fromTo(
          [heading, subtitle],
          { opacity: 0, y: 30 },
          {
            opacity: 1, y: 0, duration: 0.7, stagger: 0.12, ease: 'power3.out',
            scrollTrigger: { trigger: sectionRef.current, start: 'top 80%', once: true },
          }
        );
      }

      const tableRows = tableRef.current.querySelectorAll('tr');
      gsap.fromTo(
        tableRows,
        { opacity: 0, x: -20 },
        {
          opacity: 1, x: 0, duration: 0.5, stagger: 0.06, ease: 'power2.out',
          scrollTrigger: { trigger: tableRef.current, start: 'top 80%', once: true },
        }
      );
    };

    init();
  }, []);

  return (
    <section ref={sectionRef} id="comparison" className={styles.section}>
      <div className={styles.container}>
        <h2 className={styles.title}>Why choose Kybo?</h2>
        <p className={styles.subtitle}>
          Compare Kybo with the most common alternatives
        </p>

        <div ref={tableRef} className={styles.tableWrapper}>
          <table className={styles.table}>
            <thead>
              <tr>
                <th className={styles.featureCol}>Feature</th>
                <th className={`${styles.colHeader} ${styles.kyboCol}`}>
                  <span className={styles.kyboBadge}>Kybo</span>
                </th>
                <th className={styles.colHeader}>Manual</th>
                <th className={styles.colHeader}>Others</th>
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
          <span className={styles.yes}>✓</span> Available &nbsp;
          <span className={styles.partial}>~</span> Partially &nbsp;
          <span className={styles.no}>✗</span> Not available
        </p>
      </div>
    </section>
  );
}
