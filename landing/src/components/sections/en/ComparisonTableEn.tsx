'use client';

import React, { useEffect, useRef } from 'react';
import styles from '../ComparisonTable.module.css';

type CellValue = boolean | 'partial';
interface Row { feature: string; kybo: CellValue; manual: CellValue; others: CellValue; }

const rows: Row[] = [
  { feature: 'Automatic shopping list', kybo: true, manual: false, others: 'partial' },
  { feature: 'AI diet parsing (PDF)', kybo: true, manual: false, others: false },
  { feature: 'Nutritionist chat', kybo: true, manual: 'partial', others: false },
  { feature: 'Gamification & badges', kybo: true, manual: false, others: false },
  { feature: 'Virtual pantry', kybo: true, manual: false, others: 'partial' },
  { feature: 'Progress statistics', kybo: true, manual: false, others: 'partial' },
  { feature: 'Receipt OCR scan', kybo: true, manual: false, others: false },
  { feature: 'Dark mode', kybo: true, manual: false, others: 'partial' },
  { feature: 'Export / Import diet', kybo: true, manual: false, others: 'partial' },
  { feature: '100% free for patients', kybo: true, manual: true, others: false },
];

function Cell({ value }: { value: CellValue }) {
  if (value === true) return <span className={styles.yes}>✓</span>;
  if (value === 'partial') return <span className={styles.partial}>~</span>;
  return <span className={styles.no}>✗</span>;
}

export default function ComparisonTableEn() {
  const sectionRef = useRef<HTMLElement>(null);
  const headingRef = useRef<HTMLHeadingElement>(null);
  const tableRef = useRef<HTMLTableElement>(null);

  useEffect(() => {
    const initGsap = async () => {
      const { gsap } = await import('gsap');
      const { ScrollTrigger } = await import('gsap/ScrollTrigger');
      gsap.registerPlugin(ScrollTrigger);

      if (headingRef.current) {
        gsap.fromTo(headingRef.current,
          { opacity: 0, y: 40 },
          { opacity: 1, y: 0, duration: 0.8, ease: 'power3.out',
            scrollTrigger: { trigger: headingRef.current, start: 'top 80%', once: true } }
        );
      }
      if (tableRef.current) {
        const rows = tableRef.current.querySelectorAll('tbody tr');
        gsap.fromTo(rows,
          { opacity: 0, x: -20 },
          { opacity: 1, x: 0, stagger: 0.05, duration: 0.4, ease: 'power2.out',
            scrollTrigger: { trigger: tableRef.current, start: 'top 75%', once: true } }
        );
      }
    };
    initGsap();
  }, []);

  return (
    <section ref={sectionRef} className={styles.section}>
      <div className={styles.container}>
        <h2 ref={headingRef} className={styles.heading}>Kybo vs the alternatives</h2>
        <p className={styles.subheading}>See why Kybo is the smartest choice for patient nutrition management</p>

        <div className={styles.tableWrapper}>
          <table ref={tableRef} className={styles.table}>
            <thead>
              <tr>
                <th className={styles.featureCol}>Feature</th>
                <th className={`${styles.col} ${styles.kyboCol}`}>
                  <span className={styles.kyboLabel}>Kybo</span>
                </th>
                <th className={styles.col}>Manual</th>
                <th className={styles.col}>Others</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row) => (
                <tr key={row.feature} className={styles.row}>
                  <td className={styles.featureName}>{row.feature}</td>
                  <td className={`${styles.cell} ${styles.kyboCell}`}><Cell value={row.kybo} /></td>
                  <td className={styles.cell}><Cell value={row.manual} /></td>
                  <td className={styles.cell}><Cell value={row.others} /></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p className={styles.note}>~ = partially available or requires extra tools</p>
      </div>
    </section>
  );
}
