'use client';

import React, { useRef } from 'react';
import styles from '../StatsSection.module.css';

const stats = [
  { value: 10000, suffix: '+', label: 'Active Users', color: '#66BB6A' },
  { value: 95, suffix: '%', label: 'Satisfaction', color: '#3B82F6' },
  { value: 50, suffix: '%', label: 'Time Saved', color: '#FFA726' },
  { value: 30, suffix: '%', label: 'Waste Reduced', color: '#8B5CF6' },
];

export default function StatsSectionEn() {
  const sectionRef = useRef<HTMLElement>(null);
  const statsRef = useRef<HTMLDivElement>(null);

  return (
    <section ref={sectionRef} id="stats" className={styles.section}>
      <div className={styles.container}>
        <h2 className={styles.title}>Numbers speak for themselves</h2>
        <p className={styles.subtitle}>
          Thousands of people have already simplified their nutrition
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
