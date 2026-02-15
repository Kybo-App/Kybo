'use client';

import Link from 'next/link';
import styles from './shared.module.css';

export default function NotFound() {
  return (
    <div className={styles.pageWrapper}>
      <div className={styles.notFoundContent}>
        <div className={styles.notFoundCode}>404</div>
        <h1 className={styles.notFoundTitle}>Pagina non trovata</h1>
        <p className={styles.notFoundText}>
          La pagina che stai cercando non esiste o è stata spostata.
        </p>
        <Link href="/" className={styles.homeBtn}>
          Torna alla Home
        </Link>
      </div>
    </div>
  );
}
