'use client';

import React from 'react';
import { motion, useReducedMotion } from 'motion/react';
import type { FeaturesContent } from '@/content/types';
import { FeatureIcon } from '@/components/icons/Icons';
import styles from './FeatureCards.module.css';

export default function FeatureCards({ content }: { content: FeaturesContent }) {
  const reduced = useReducedMotion();

  const reveal = (delay = 0) =>
    reduced
      ? {}
      : {
          initial: { opacity: 0, y: 32 },
          whileInView: { opacity: 1, y: 0 },
          viewport: { once: true, amount: 0.25 },
          transition: { duration: 0.6, delay, ease: [0.16, 1, 0.3, 1] as const },
        };

  return (
    <section id="features" className={styles.section}>
      <div className={styles.container}>
        <motion.h2 className={styles.title} data-reveal {...reveal()}>
          {content.title}
        </motion.h2>
        <motion.p className={styles.subtitle} data-reveal {...reveal(0.1)}>
          {content.subtitle}
        </motion.p>

        <div className={styles.grid}>
          {content.items.map((feature, index) => (
            <motion.article
              key={feature.title}
              className={styles.card}
              data-reveal
              {...reveal(reduced ? 0 : index * 0.08)}
              whileHover={reduced ? undefined : { y: -10, transition: { duration: 0.25 } }}
            >
              <div
                className={styles.iconWrapper}
                style={{
                  background: `linear-gradient(135deg, ${feature.color}22 0%, ${feature.color}44 100%)`,
                  color: feature.color,
                }}
              >
                <FeatureIcon name={feature.icon} />
              </div>
              <h3 className={styles.cardTitle}>{feature.title}</h3>
              <p className={styles.cardDescription}>{feature.description}</p>
              <div className={styles.accent} style={{ background: feature.color }} />
            </motion.article>
          ))}
        </div>
      </div>
    </section>
  );
}
