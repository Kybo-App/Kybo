'use client';

import React from 'react';
import styles from './PillButton.module.css';

interface PillButtonProps {
  children: React.ReactNode;
  variant?: 'primary' | 'accent' | 'outline';
  href?: string;
  onClick?: () => void;
  className?: string;
  size?: 'small' | 'medium' | 'large';
}

export default function PillButton({
  children,
  variant = 'primary',
  href,
  onClick,
  className = '',
  size = 'medium',
}: PillButtonProps) {
  const classes = `${styles.pillButton} ${styles[variant]} ${styles[size]} ${className}`;

  if (href) {
    return (
      <a href={href} className={classes} target={href.startsWith('http') ? '_blank' : undefined} rel={href.startsWith('http') ? 'noopener noreferrer' : undefined}>
        {children}
      </a>
    );
  }

  return (
    <button onClick={onClick} className={classes}>
      {children}
    </button>
  );
}
