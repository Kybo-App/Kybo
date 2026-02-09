'use client';

import Link from 'next/link';
import Image from 'next/image';
import styles from '@/app/shared.module.css';

interface PlaceholderPageProps {
  title: string;
  icon: string;
  description: string;
}

export default function PlaceholderPage({ title, icon, description }: PlaceholderPageProps) {
  return (
    <div className={styles.pageWrapper}>
      <nav className={styles.nav}>
        <div className={styles.navContainer}>
          <Link href="/" className={styles.logo}>
            <Image src="/logo no bg.png" alt="Kybo" width={32} height={32} className={styles.logoIcon} priority />
            <span className={styles.logoText}>Kybo</span>
          </Link>
          <Link href="/" className={styles.backBtn}>
            ← Torna alla Home
          </Link>
        </div>
      </nav>

      <div className={styles.placeholderContent}>
        <span className={styles.placeholderIcon}>{icon}</span>
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
