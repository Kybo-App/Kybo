'use client';

import React, { useState } from 'react';
import styles from './PillExpansionTile.module.css';

interface PillExpansionTileProps {
  title: string;
  children: React.ReactNode;
  defaultExpanded?: boolean;
}

export default function PillExpansionTile({
  title,
  children,
  defaultExpanded = false,
}: PillExpansionTileProps) {
  const [isExpanded, setIsExpanded] = useState(defaultExpanded);

  return (
    <div className={styles.expansionTile}>
      <button
        className={styles.header}
        onClick={() => setIsExpanded(!isExpanded)}
        aria-expanded={isExpanded}
      >
        <span className={styles.title}>{title}</span>
        <span className={`${styles.icon} ${isExpanded ? styles.expanded : ''}`}>
          ▼
        </span>
      </button>
      <div className={`${styles.content} ${isExpanded ? styles.show : ''}`}>
        <div className={styles.contentInner}>{children}</div>
      </div>
    </div>
  );
}
