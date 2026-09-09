'use client';

import React from 'react';
import Link from 'next/link';
import { motion, useReducedMotion } from 'motion/react';
import type { HeroContent } from '@/content/types';
import styles from './HeroSection.module.css';

export default function HeroSection({ content }: { content: HeroContent }) {
  const reduced = useReducedMotion();

  // Con reduced motion niente stato iniziale: Motion renderizza direttamente
  // la posizione finale, sia lato server che lato client.
  const reveal = (delay: number) =>
    reduced
      ? {}
      : {
          initial: { opacity: 0, y: 24 },
          animate: { opacity: 1, y: 0 },
          transition: { duration: 0.7, delay, ease: [0.16, 1, 0.3, 1] as const },
        };

  const letters = content.wordmark.split('');

  return (
    <section className={styles.hero}>
      <div className={styles.content}>
        {/* Il marchio è l'h1: la descrizione del prodotto sta nel sottotitolo
            subito sotto, che è testo reale e indicizzabile. */}
        <h1 className={styles.wordmark}>
          {letters.map((char, i) => (
            <motion.span
              key={i}
              data-reveal
              {...(reduced
                ? {}
                : {
                    initial: { opacity: 0, y: 60, rotateX: -70 },
                    animate: { opacity: 1, y: 0, rotateX: 0 },
                    transition: {
                      duration: 0.9,
                      delay: 0.2 + i * 0.07,
                      ease: [0.16, 1, 0.3, 1] as const,
                    },
                  })}
            >
              {char}
            </motion.span>
          ))}
        </h1>

        <motion.p className={styles.subtitle} data-reveal {...reveal(0.75)}>
          {content.subtitle}
        </motion.p>

        <motion.div className={styles.cta} data-reveal {...reveal(0.95)}>
          <a href={content.primaryCta.href} className={styles.primaryBtn}>
            {content.primaryCta.label}
          </a>
          <Link href={content.secondaryCta.href} className={styles.secondaryBtn}>
            {content.secondaryCta.label}
          </Link>
        </motion.div>

        <motion.div className={styles.scrollIndicator} data-reveal {...reveal(1.15)}>
          <span>{content.scrollHint}</span>
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" aria-hidden="true">
            <path
              d="M12 5v14m0 0l-7-7m7 7l7-7"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </motion.div>
      </div>
    </section>
  );
}
