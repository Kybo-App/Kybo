'use client';

import React from 'react';
import styles from './PillCard.module.css';

interface PillCardProps {
  children: React.ReactNode;
  className?: string;
  elevated?: boolean;
  onClick?: () => void;
}

export default function PillCard({
  children,
  className = '',
  elevated = false,
  onClick,
}: PillCardProps) {
  const classes = `${styles.pillCard} ${elevated ? styles.elevated : ''} ${className}`;

  return (
    <div className={classes} onClick={onClick}>
      {children}
    </div>
  );
}
