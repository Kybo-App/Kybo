'use client';

import React from 'react';
import Image from 'next/image';
import Link from 'next/link';
import { motion, useReducedMotion } from 'motion/react';
import type { CtaContent, FooterContent } from '@/content/types';
import { SocialIcon } from '@/components/icons/Icons';
import styles from './CTASection.module.css';

interface Props {
  content: CtaContent;
  footer: FooterContent;
}

export default function CTASection({ content, footer }: Props) {
  const reduced = useReducedMotion();

  const reveal = (delay = 0) =>
    reduced
      ? {}
      : {
          initial: { opacity: 0, y: 24 },
          whileInView: { opacity: 1, y: 0 },
          viewport: { once: true, amount: 0.3 },
          transition: { duration: 0.55, delay, ease: [0.16, 1, 0.3, 1] as const },
        };

  return (
    <>
      <section className={styles.section}>
        <div className={styles.content}>
          <motion.h2 className={styles.title} data-reveal {...reveal()}>
            {content.title}
          </motion.h2>
          <motion.p className={styles.subtitle} data-reveal {...reveal(0.1)}>
            {content.subtitle}
          </motion.p>

          {/*
            Gli store non sono ancora attivi. Invece di due link finti che
            sembrano cliccabili, qui ci sono due segnaposto dichiarati come tali:
            <div> e non <a>, con il badge "presto disponibile" accanto.
            Al lancio diventano <a href="…"> con l'URL reale.
          */}
          <motion.div className={styles.buttons} data-reveal {...reveal(0.2)}>
            <div className={styles.storeBadge} aria-label={content.appStore.ariaLabel}>
              <div className={styles.btnText}>
                <span className={styles.btnSub}>{content.appStore.sub}</span>
                <span className={styles.btnMain}>{content.appStore.main}</span>
              </div>
            </div>
            <div className={styles.storeBadge} aria-label={content.googlePlay.ariaLabel}>
              <div className={styles.btnText}>
                <span className={styles.btnSub}>{content.googlePlay.sub}</span>
                <span className={styles.btnMain}>{content.googlePlay.main}</span>
              </div>
            </div>
          </motion.div>

          <motion.p className={styles.note} data-reveal {...reveal(0.3)}>
            <span className={styles.comingSoon}>{content.comingSoonBadge}</span>
            {content.storeNote}
          </motion.p>
        </div>
      </section>

      <footer className={styles.footer}>
        <div className={styles.footerContent}>
          <div className={styles.footerTop}>
            <div className={styles.footerBrand}>
              <div className={styles.footerLogo}>
                <Image
                  src="/logo no bg.png"
                  alt="Kybo"
                  width={32}
                  height={32}
                  className={styles.footerLogoIcon}
                />
                <span className={styles.footerLogoText}>Kybo</span>
              </div>
              <p className={styles.footerTagline}>{footer.tagline}</p>
            </div>

            <div className={styles.footerLinks}>
              {footer.columns.map((column) => (
                <div key={column.heading} className={styles.footerColumn}>
                  <h3>{column.heading}</h3>
                  {column.links.map((link) =>
                    link.href.startsWith('#') ? (
                      <a key={link.label} href={link.href}>
                        {link.label}
                      </a>
                    ) : (
                      <Link key={link.label} href={link.href}>
                        {link.label}
                      </Link>
                    )
                  )}
                </div>
              ))}
            </div>
          </div>

          <div className={styles.footerBottom}>
            <p className={styles.copyright}>{footer.copyright}</p>
            {/*
              Solo i profili che esistono davvero. Prima c'erano anche
              twitter.com e facebook.com, che puntavano alle homepage dei
              social e non a un account Kybo.
            */}
            <div className={styles.socials}>
              {footer.socials.map((social) => (
                <a
                  key={social.key}
                  href={social.href}
                  target="_blank"
                  rel="noopener noreferrer"
                  aria-label={social.label}
                >
                  <SocialIcon name={social.key} />
                </a>
              ))}
            </div>
          </div>
        </div>
      </footer>
    </>
  );
}
