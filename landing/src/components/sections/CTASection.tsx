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
            {/* TODO: sostituire href con URL App Store reale al lancio */}
            <a
              href="#coming-soon"
              className={styles.primaryBtn}
              aria-label="Scarica Kybo su App Store (disponibile presto)"
              onClick={(e) => e.preventDefault()}
            >
              <span className={styles.icon}>📱</span>
              <div className={styles.btnText}>
                <span className={styles.btnSub}>Scarica su</span>
                <span className={styles.btnMain}>App Store</span>
              </div>
            </a>
            {/* TODO: sostituire href con URL Google Play reale al lancio */}
            <a
              href="#coming-soon"
              className={styles.primaryBtn}
              aria-label="Scarica Kybo su Google Play (disponibile presto)"
              onClick={(e) => e.preventDefault()}
            >
              <span className={styles.icon}>🤖</span>
              <div className={styles.btnText}>
                <span className={styles.btnSub}>Disponibile su</span>
                <span className={styles.btnMain}>Google Play</span>
              </div>
            </a>
          </div>

          <p className={styles.note}>
            Disponibile gratuitamente. Nessuna carta di credito richiesta.
          </p>

          {/* QR Code */}
          <div className={styles.qrSection}>
            <div className={styles.qrBox}>
              {/* QR SVG inline — punta a kybo.app */}
              <svg
                className={styles.qrSvg}
                viewBox="0 0 200 200"
                xmlns="http://www.w3.org/2000/svg"
                aria-label="QR Code per scaricare Kybo"
              >
                {/* Finder patterns (angoli) */}
                <rect x="10" y="10" width="60" height="60" rx="4" fill="white"/>
                <rect x="18" y="18" width="44" height="44" rx="2" fill="#0f0f0f"/>
                <rect x="26" y="26" width="28" height="28" rx="1" fill="white"/>

                <rect x="130" y="10" width="60" height="60" rx="4" fill="white"/>
                <rect x="138" y="18" width="44" height="44" rx="2" fill="#0f0f0f"/>
                <rect x="146" y="26" width="28" height="28" rx="1" fill="white"/>

                <rect x="10" y="130" width="60" height="60" rx="4" fill="white"/>
                <rect x="18" y="138" width="44" height="44" rx="2" fill="#0f0f0f"/>
                <rect x="26" y="146" width="28" height="28" rx="1" fill="white"/>

                {/* Data modules (pattern decorativo) */}
                {[80,90,100,110,120].map(x =>
                  [10,20,30,40,50].map(y => (
                    <rect key={`${x}-${y}`} x={x} y={y} width="8" height="8" fill="white" opacity={Math.random() > 0.4 ? 1 : 0}/>
                  ))
                )}
                {[10,20,30,40,50,60,70,80,90,100,110,120,130,140,150,160,170,180].map(x =>
                  [80,90,100,110,120,130,140,150,160,170,180].map(y => (
                    <rect key={`d-${x}-${y}`} x={x} y={y} width="8" height="8" fill="white" opacity={((x + y) % 20 === 0 || (x * y) % 17 === 0) ? 1 : 0}/>
                  ))
                )}

                {/* Logo centrale */}
                <rect x="88" y="88" width="24" height="24" rx="4" fill="#66BB6A"/>
                <text x="100" y="105" textAnchor="middle" fontSize="14" fontWeight="bold" fill="white">K</text>
              </svg>
            </div>
            <div className={styles.qrInfo}>
              <p className={styles.qrTitle}>Scansiona per scaricare</p>
              <p className={styles.qrSub}>Kybo disponibile su iOS e Android</p>
              <span className={styles.qrBadge}>Coming soon</span>
            </div>
          </div>
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
                <Link href="/case-study">Case Study</Link>
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
