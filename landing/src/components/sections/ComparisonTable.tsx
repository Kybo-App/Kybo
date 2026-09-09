'use client';

import React from 'react';
import { motion, useReducedMotion } from 'motion/react';
import type { CellValue, ComparisonContent } from '@/content/types';
import { UiIcon } from '@/components/icons/UiIcons';
import styles from './ComparisonTable.module.css';

function Cell({ value, legend }: { value: CellValue; legend: ComparisonContent['legend'] }) {
  // Il simbolo è decorativo: il significato viene dal testo per screen reader,
  // altrimenti una tabella di spunte è illeggibile senza vederla.
  if (value === true) {
    return (
      <span className={styles.yes}>
        <UiIcon name="check" size={16} />
        <span className={styles.srOnly}>{legend.yes}</span>
      </span>
    );
  }
  if (value === 'partial') {
    return (
      <span className={styles.partial}>
        <span aria-hidden="true">~</span>
        <span className={styles.srOnly}>{legend.partial}</span>
      </span>
    );
  }
  return (
    <span className={styles.no}>
      <UiIcon name="cross" size={16} />
      <span className={styles.srOnly}>{legend.no}</span>
    </span>
  );
}

export default function ComparisonTable({ content }: { content: ComparisonContent }) {
  const reduced = useReducedMotion();

  const reveal = (delay = 0) =>
    reduced
      ? {}
      : {
          initial: { opacity: 0, y: 26 },
          whileInView: { opacity: 1, y: 0 },
          viewport: { once: true, amount: 0.2 },
          transition: { duration: 0.55, delay, ease: [0.16, 1, 0.3, 1] as const },
        };

  return (
    <section id="comparison" className={styles.section}>
      <div className={styles.container}>
        <motion.h2 className={styles.title} data-reveal {...reveal()}>
          {content.title}
        </motion.h2>
        <motion.p className={styles.subtitle} data-reveal {...reveal(0.1)}>
          {content.subtitle}
        </motion.p>

        <motion.div className={styles.tableWrapper} data-reveal {...reveal(0.18)}>
          <table className={styles.table}>
            <thead>
              <tr>
                <th className={styles.featureCol}>{content.columns.feature}</th>
                <th className={`${styles.colHeader} ${styles.kyboCol}`}>
                  <span className={styles.kyboBadge}>{content.columns.kybo}</span>
                </th>
                <th className={styles.colHeader}>{content.columns.manual}</th>
                <th className={styles.colHeader}>{content.columns.others}</th>
              </tr>
            </thead>
            <tbody>
              {content.rows.map((row) => (
                <tr key={row.feature} className={styles.row}>
                  <td className={styles.featureLabel}>{row.feature}</td>
                  <td className={`${styles.cell} ${styles.kyboCell}`}>
                    <Cell value={row.kybo} legend={content.legend} />
                  </td>
                  <td className={styles.cell}>
                    <Cell value={row.manual} legend={content.legend} />
                  </td>
                  <td className={styles.cell}>
                    <Cell value={row.others} legend={content.legend} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </motion.div>

        <p className={styles.legend}>
          <span className={styles.yes}><UiIcon name="check" size={14} /></span> {content.legend.yes} &nbsp;
          <span className={styles.partial} aria-hidden="true">~</span> {content.legend.partial} &nbsp;
          <span className={styles.no}><UiIcon name="cross" size={14} /></span> {content.legend.no}
        </p>
      </div>
    </section>
  );
}
