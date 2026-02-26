'use client';

import React from 'react';
import styles from './TestimonialsSection.module.css';

interface Testimonial {
  name: string;
  role: string;
  location: string;
  rating: number;
  quote: string;
  avatarColor: string;
}

const testimonials: Testimonial[] = [
  {
    name: 'Maria R.',
    role: 'Nutrizionista',
    location: 'Milano',
    rating: 5,
    quote:
      'Ho ridotto il tempo di gestione delle diete del 70%. I miei clienti sono più coinvolti grazie alla chat integrata.',
    avatarColor: 'linear-gradient(135deg, #66BB6A 0%, #2E7D32 100%)',
  },
  {
    name: 'Luca T.',
    role: 'Cliente',
    location: 'Roma',
    rating: 5,
    quote:
      'Finalmente capisco cosa mangio. La lista spesa generata automaticamente mi ha cambiato la vita.',
    avatarColor: 'linear-gradient(135deg, #42A5F5 0%, #1565C0 100%)',
  },
  {
    name: 'Dr.ssa Anna M.',
    role: 'Biologa Nutrizionista',
    location: 'Torino',
    rating: 5,
    quote:
      'Il parsing AI dei PDF è preciso al 95%. Ho smesso di dover inserire dati manualmente.',
    avatarColor: 'linear-gradient(135deg, #AB47BC 0%, #6A1B9A 100%)',
  },
  {
    name: 'Marco B.',
    role: 'Cliente',
    location: 'Napoli',
    rating: 4,
    quote:
      'Pratico e intuitivo. La modalità relax che nasconde le calorie è un dettaglio che apprezzo molto.',
    avatarColor: 'linear-gradient(135deg, #FF7043 0%, #BF360C 100%)',
  },
  {
    name: 'Federica L.',
    role: 'Nutrizionista',
    location: 'Firenze',
    rating: 5,
    quote:
      'I report mensili sono diventati il mio strumento principale per mostrare i progressi ai clienti.',
    avatarColor: 'linear-gradient(135deg, #26C6DA 0%, #00838F 100%)',
  },
  {
    name: 'Simone G.',
    role: 'Cliente',
    location: 'Bologna',
    rating: 5,
    quote:
      'La dispensa con OCR scontrino è geniale. Aggiorno la dispensa in 10 secondi.',
    avatarColor: 'linear-gradient(135deg, #FFCA28 0%, #F57F17 100%)',
  },
];

function initials(name: string): string {
  return name
    .split(' ')
    .map((part) => part[0])
    .join('')
    .toUpperCase()
    .slice(0, 2);
}

function StarRow({ rating }: { rating: number }) {
  return (
    <div className={styles.stars}>
      {Array.from({ length: 5 }, (_, i) => (
        <span key={i} className={`${styles.star} ${i >= rating ? styles.starEmpty : ''}`}>
          ★
        </span>
      ))}
    </div>
  );
}

export default function TestimonialsSection() {
  return (
    <section className={styles.section}>
      <div className={styles.container}>
        <div className={styles.header}>
          <span className={styles.label}>Testimonianze</span>
          <h2 className={styles.title}>
            Cosa dicono di{' '}
            <span className={styles.titleAccent}>Kybo</span>
          </h2>
          <p className={styles.subtitle}>
            Professionisti e clienti reali che hanno trasformato il loro approccio alla nutrizione.
          </p>
        </div>

        <div className={styles.grid}>
          {testimonials.map((t) => (
            <div key={t.name} className={styles.card}>
              <StarRow rating={t.rating} />
              <p className={styles.quote}>&ldquo;{t.quote}&rdquo;</p>
              <div className={styles.authorRow}>
                <div
                  className={styles.avatar}
                  style={{ background: t.avatarColor }}
                >
                  {initials(t.name)}
                </div>
                <div className={styles.authorInfo}>
                  <p className={styles.authorName}>{t.name}</p>
                  <p className={styles.authorRole}>
                    {t.role} &middot; {t.location}
                  </p>
                </div>
                <div className={styles.verified}>
                  <span className={styles.verifiedDot} />
                  Verificata
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
