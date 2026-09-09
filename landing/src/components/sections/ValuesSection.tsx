'use client';

import React from 'react';
import { motion, useReducedMotion } from 'motion/react';
import type { ValuesContent } from '@/content/types';
import styles from './StatsSection.module.css';

/**
 * Sostituisce la vecchia StatsSection.
 *
 * Prima mostrava "10000+ utenti attivi" e "95% soddisfazione" per un'app non
 * ancora pubblicata. Qui i quattro cerchi riportano fatti sul prodotto, non
 * metriche di adozione: restano veri anche prima del lancio.
 */
export default function ValuesSection({ content }: { content: ValuesContent }) {
  const reduced = useReducedMotion();

  const reveal = (delay = 0) =>
    reduced
      ? {}
      : {
          initial: { opacity: 0, y: 28 },
          whileInView: { opacity: 1, y: 0 },
          viewport: { once: true, amount: 0.3 },
          transition: { duration: 0.55, delay, ease: [0.16, 1, 0.3, 1] as const },
        };

  return (
    <section id="stats" className={styles.section}>
      <div className={styles.container}>
        <motion.h2 className={styles.title} data-reveal {...reveal()}>
          {content.title}
        </motion.h2>
        <motion.p className={styles.subtitle} data-reveal {...reveal(0.1)}>
          {content.subtitle}
        </motion.p>

        <div className={styles.grid}>
          {content.items.map((item, index) => (
            <motion.div
              key={item.label}
              className={styles.stat}
              data-reveal
              {...reveal(reduced ? 0 : 0.15 + index * 0.08)}
            >
              <div
                className={styles.circle}
                style={{
                  background: `conic-gradient(${item.color} 0deg, ${item.color}44 360deg)`,
                  boxShadow: `0 0 40px ${item.color}44`,
                }}
              >
                <div className={styles.innerCircle}>
                  <span className={styles.value} style={{ color: item.color }}>
                    {item.value}
                  </span>
                </div>
              </div>
              <p className={styles.label}>{item.label}</p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
