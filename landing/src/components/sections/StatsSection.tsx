'use client';

import React, { useEffect, useRef } from 'react';
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

  useEffect(() => {
    if (!statsRef.current) return;

    const statElements = statsRef.current.querySelectorAll(`.${styles.stat}`);

    statElements.forEach((stat, index) => {
      const valueElement = stat.querySelector(`.${styles.value}`) as HTMLElement;
      const targetValue = stats[index].value;
      const suffix = stats[index].suffix;

      // Set initial value immediately
      if (valueElement) {
        valueElement.textContent = targetValue + suffix;
      }
    });

  }, []);

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
                  <span className={styles.value}>0{stat.suffix}</span>
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
