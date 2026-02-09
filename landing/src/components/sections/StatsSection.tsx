'use client';

import React, { useRef } from 'react';
import styles from './StatsSection.module.css';

const stats = [
  { value: 10000, suffix: '+', label: 'Utenti Attivi', color: '#66BB6A' },
  { value: 95, suffix: '%', label: 'Soddisfazione', color: '#3B82F6' },
  { value: 50, suffix: '%', label: 'Tempo Risparmiato', color: '#FFA726' },
  { value: 30, suffix: '%', label: 'Spreco Ridotto', color: '#8B5CF6' },
];

export default function StatsSection() {
  const sectionRef = useRef<HTMLElement>(null);
  const statsRef = useRef<HTMLDivElement>(null);

  return (
    <section ref={sectionRef} id="stats" className={styles.section}>
      <div className={styles.container}>
        <h2 className={styles.title}>I numeri parlano chiaro</h2>
        <p className={styles.subtitle}>
          Migliaia di persone hanno già semplificato la loro nutrizione
        </p>

        <div ref={statsRef} className={styles.grid}>
          {stats.map((stat, index) => (
            <div key={index} className={styles.stat}>
              <div 
                className={styles.circle}
                style={{ 
                  background: `conic-gradient(${stat.color} 0deg, ${stat.color}44 360deg)`,
                  boxShadow: `0 0 40px ${stat.color}44`,
                }}
              >
                <div className={styles.innerCircle}>
                  <span className={styles.value}>{stat.value}{stat.suffix}</span>
                </div>
              </div>
              <p className={styles.label}>{stat.label}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
