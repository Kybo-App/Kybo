'use client';

import React from 'react';
import styles from './StatCard.module.css';

interface StatCardProps {
  value: string;
  label: string;
  icon?: string;
  color?: 'primary' | 'accent' | 'admin';
}

export default function StatCard({
  value,
  label,
  icon,
  color = 'primary',
}: StatCardProps) {
  return (
    <div className={`${styles.statCard} ${styles[color]}`}>
      {icon && <div className={styles.icon}>{icon}</div>}
      <div className={styles.value}>{value}</div>
      <div className={styles.label}>{label}</div>
    </div>
  );
}
