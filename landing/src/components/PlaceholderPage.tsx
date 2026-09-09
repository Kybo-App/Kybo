'use client';

import Link from 'next/link';
import styles from '@/app/shared.module.css';
import Navbar from '@/components/Navbar';
import { UiIcon, type UiIconKey } from '@/components/icons/UiIcons';
import { it } from '@/content/it';

interface PlaceholderPageProps {
  title: string;
  icon: UiIconKey;
  description: string;
}

export default function PlaceholderPage({ title, icon, description }: PlaceholderPageProps) {
  return (
    <div className={styles.pageWrapper}>
      <Navbar content={it.nav} />

      <div className={styles.placeholderContent}>
        <span className={styles.placeholderIcon}>
          <UiIcon name={icon} size={44} />
        </span>
        <h1 className={styles.placeholderTitle}>{title}</h1>
        <p className={styles.placeholderText}>{description}</p>
        <Link href="/" className={styles.homeBtn}>
          Torna alla Home
        </Link>
      </div>

      <footer className={styles.footer}>
        <p className={styles.footerText}>© 2025 Kybo. Tutti i diritti riservati.</p>
      </footer>
    </div>
  );
}
