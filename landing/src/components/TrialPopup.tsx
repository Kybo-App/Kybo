'use client';

import React, { useEffect, useState } from 'react';
import Link from 'next/link';
import styles from './TrialPopup.module.css';
import { UiIcon } from '@/components/icons/UiIcons';

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
      <div className={styles.popup} role="dialog" aria-modal="true" aria-label="Kybo per i nutrizionisti">
        <button className={styles.closeBtn} onClick={dismiss} aria-label="Chiudi"><UiIcon name="cross" size={18} /></button>

        {/*
          Prima diceva "Offerta di lancio — 14 giorni gratis, cancella quando
          vuoi": una promessa commerciale su un listino che non esiste ancora.
        */}
        <div className={styles.badge}><UiIcon name="clock" size={15} /> In sviluppo</div>

        <h2 className={styles.title}>
          Sei un<br />
          <span className={styles.accent}>nutrizionista?</span>
        </h2>

        <p className={styles.text}>
          Kybo non è ancora pubblico. Se gestisci pazienti e vuoi<br />
          provarlo per primo, scrivimi.
        </p>

        {/*
          L'app paziente non è ancora pubblicata: elencarla come inclusa
          contraddiceva il resto della pagina, che la dà in arrivo.
          Le altre tre voci riguardano il pannello per professionisti, che esiste.
        */}
        <ul className={styles.features}>
          <li><UiIcon name="check" size={15} /> Parsing automatico PDF dieta con AI</li>
          <li><UiIcon name="check" size={15} /> Chat integrata nutrizionista ↔ paziente</li>
          <li><UiIcon name="check" size={15} /> Analytics &amp; report mensili</li>
          <li><UiIcon name="clock" size={15} /> App paziente iOS &amp; Android, in arrivo</li>
        </ul>

        <Link href="/contact" className={styles.ctaBtn} onClick={dismiss}>
          Mettiti in contatto
        </Link>

        <button className={styles.skipBtn} onClick={dismiss}>
          Non ora
        </button>
      </div>
    </div>
  );
}
