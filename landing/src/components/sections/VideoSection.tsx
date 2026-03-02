/**
 * VideoSection — "Guarda Kybo in azione"
 * Embed YouTube/Vimeo. Imposta VIDEO_ID (YouTube) o VIMEO_ID per attivare il player;
 * lascia entrambi vuoti per mostrare il placeholder "Demo in arrivo".
 */
'use client';

import React, { useState } from 'react';
import styles from './VideoSection.module.css';

const VIDEO_ID = ''; // YouTube video ID — es. 'dQw4w9WgXcQ'
const VIMEO_ID = ''; // Vimeo video ID (alternativa a YouTube)

export default function VideoSection() {
  const [playing, setPlaying] = useState(false);

  const hasVideo = VIDEO_ID || VIMEO_ID;

  const embedUrl = VIDEO_ID
    ? `https://www.youtube-nocookie.com/embed/${VIDEO_ID}?autoplay=1&rel=0&modestbranding=1`
    : VIMEO_ID
    ? `https://player.vimeo.com/video/${VIMEO_ID}?autoplay=1`
    : '';

  return (
    <section className={styles.section} id="demo">
      <div className={styles.container}>
        <div className={styles.header}>
          <span className={styles.label}>Demo</span>
          <h2 className={styles.title}>
            Guarda <span className={styles.titleAccent}>Kybo</span> in azione
          </h2>
          <p className={styles.subtitle}>
            Scopri come nutrizionisti e clienti usano Kybo ogni giorno per semplificare la nutrizione.
          </p>
        </div>

        <div className={styles.playerWrapper}>
          {hasVideo && playing ? (
            <iframe
              className={styles.iframe}
              src={embedUrl}
              title="Kybo demo video"
              allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
              allowFullScreen
            />
          ) : (
            <div
              className={`${styles.poster} ${hasVideo ? styles.posterClickable : ''}`}
              onClick={() => hasVideo && setPlaying(true)}
              role={hasVideo ? 'button' : undefined}
              aria-label={hasVideo ? 'Avvia video demo' : undefined}
              tabIndex={hasVideo ? 0 : undefined}
              onKeyDown={(e) => hasVideo && e.key === 'Enter' && setPlaying(true)}
            >
              <div className={styles.posterInner}>
                <div className={styles.appIcons}>
                  <span className={styles.icon}>🥗</span>
                  <span className={styles.icon}>🛒</span>
                  <span className={styles.icon}>💬</span>
                  <span className={styles.icon}>📊</span>
                </div>
                {hasVideo ? (
                  <>
                    <div className={styles.playBtn} aria-hidden="true">
                      <svg viewBox="0 0 24 24" fill="currentColor" className={styles.playIcon}>
                        <path d="M8 5v14l11-7z" />
                      </svg>
                    </div>
                    <p className={styles.posterLabel}>Guarda la demo</p>
                  </>
                ) : (
                  <>
                    <div className={styles.comingSoon}>
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" className={styles.clockIcon}>
                        <circle cx="12" cy="12" r="10" />
                        <polyline points="12 6 12 12 16 14" />
                      </svg>
                    </div>
                    <p className={styles.posterLabel}>Video demo in arrivo</p>
                    <p className={styles.posterSub}>Presto disponibile su questo sito</p>
                  </>
                )}
              </div>
              <div className={styles.posterGlow} aria-hidden="true" />
            </div>
          )}
        </div>

        <div className={styles.pills}>
          <span className={styles.pill}>✅ Nessuna carta di credito richiesta</span>
          <span className={styles.pill}>✅ Setup in meno di 5 minuti</span>
          <span className={styles.pill}>✅ Supporto incluso</span>
        </div>
      </div>
    </section>
  );
}
