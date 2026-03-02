'use client';

import React, { useEffect, useState } from 'react';
import Link from 'next/link';
import styles from './TrialPopup.module.css';

const POPUP_DELAY_MS = 8000;       // appare dopo 8 secondi
const SESSION_KEY   = 'kybo_trial_popup_seen';

export default function TrialPopup() {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    if (typeof window === 'undefined') return;
    if (sessionStorage.getItem(SESSION_KEY)) return;

    const timer = setTimeout(() => {
      setVisible(true);
    }, POPUP_DELAY_MS);

    return () => clearTimeout(timer);
  }, []);

  function dismiss() {
    setVisible(false);
    sessionStorage.setItem(SESSION_KEY, '1');
  }

  if (!visible) return null;

  return (
    <div className={styles.overlay} onClick={(e) => { if (e.target === e.currentTarget) dismiss(); }}>
      <div className={styles.popup} role="dialog" aria-modal="true" aria-label="Prova Kybo gratis">
        <button className={styles.closeBtn} onClick={dismiss} aria-label="Chiudi">✕</button>

        <div className={styles.badge}>🎁 Offerta di lancio</div>

        <h2 className={styles.title}>
          Prova Kybo<br />
          <span className={styles.accent}>14 giorni gratis</span>
        </h2>

        <p className={styles.text}>
          Nessuna carta di credito richiesta.<br />
          Cancella quando vuoi.
        </p>

        <ul className={styles.features}>
          <li>✅ App paziente nativa iOS &amp; Android</li>
          <li>✅ Parsing automatico PDF dieta con AI</li>
          <li>✅ Chat integrata nutrizionista ↔ paziente</li>
          <li>✅ Analytics &amp; report mensili</li>
        </ul>

        <Link href="/contact" className={styles.ctaBtn} onClick={dismiss}>
          Inizia la prova gratuita →
        </Link>

        <button className={styles.skipBtn} onClick={dismiss}>
          No grazie, per ora non mi interessa
        </button>
      </div>
    </div>
  );
}
