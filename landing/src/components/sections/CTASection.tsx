'use client';

import React, { useEffect, useRef } from 'react';
import Image from 'next/image';
import Link from 'next/link';
import styles from './CTASection.module.css';

export default function CTASection() {
  const sectionRef = useRef<HTMLElement>(null);
  const contentRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    // No animations - content is immediately visible
  }, []);

  return (
    <>
      <section ref={sectionRef} className={styles.section}>
        <div ref={contentRef} className={styles.content}>
          <h2 className={styles.title}>Pronto a semplificare la tua nutrizione?</h2>
          <p className={styles.subtitle}>
            Unisciti a migliaia di utenti che hanno già trasformato il loro approccio al cibo
          </p>

          <div className={styles.buttons}>
            <button className={styles.primaryBtn}>
              <span className={styles.icon}>📱</span>
              <span>Scarica su App Store</span>
            </button>
            <button className={styles.primaryBtn}>
              <span className={styles.icon}>🤖</span>
              <span>Scarica su Google Play</span>
            </button>
          </div>

          <p className={styles.note}>
            Disponibile gratuitamente. Nessuna carta di credito richiesta.
          </p>
        </div>
      </section>

      {/* Enhanced Footer */}
      <footer className={styles.footer}>
        <div className={styles.footerContent}>
          <div className={styles.footerTop}>
            <div className={styles.footerBrand}>
              <div className={styles.footerLogo}>
                <Image src="/logo no bg.png" alt="Kybo" width={32} height={32} className={styles.footerLogoIcon} />
                <span className={styles.footerLogoText}>Kybo</span>
              </div>
              <p className={styles.footerTagline}>
                La tua nutrizione, finalmente semplificata
              </p>
            </div>

            <div className={styles.footerLinks}>
              <div className={styles.footerColumn}>
                <h4>Prodotto</h4>
                <a href="#features">Features</a>
                <a href="#gallery">Gallery</a>
                <a href="#stats">Statistiche</a>
              </div>

              <div className={styles.footerColumn}>
                <h4>Azienda</h4>
                <Link href="/about">Chi Siamo</Link>
                <Link href="/blog">Blog</Link>
                <Link href="/careers">Lavora con noi</Link>
              </div>

              <div className={styles.footerColumn}>
                <h4>Supporto</h4>
                <Link href="/help">Centro Assistenza</Link>
                <Link href="/contact">Contatti</Link>
                <Link href="/faq">FAQ</Link>
              </div>

              <div className={styles.footerColumn}>
                <h4>Legale</h4>
                <Link href="/privacy">Privacy Policy</Link>
                <Link href="/terms">Termini di Servizio</Link>
                <Link href="/cookies">Cookie Policy</Link>
              </div>
            </div>
          </div>

          <div className={styles.footerBottom}>
            <p className={styles.copyright}>© 2025 Kybo. Tutti i diritti riservati.</p>
            <div className={styles.socials}>
              <a href="https://instagram.com" target="_blank" rel="noopener noreferrer" aria-label="Instagram">
                📷
              </a>
              <a href="https://twitter.com" target="_blank" rel="noopener noreferrer" aria-label="Twitter">
                🐦
              </a>
              <a href="https://facebook.com" target="_blank" rel="noopener noreferrer" aria-label="Facebook">
                📘
              </a>
              <a href="https://linkedin.com" target="_blank" rel="noopener noreferrer" aria-label="LinkedIn">
                💼
              </a>
            </div>
          </div>
        </div>
      </footer>
    </>
  );
}
