'use client';

import React from 'react';
import Image from 'next/image';
import Link from 'next/link';
import styles from '../CTASection.module.css';

export default function CTASectionEn() {
  return (
    <>
      <section className={styles.section}>
        <div className={styles.content}>
          <h2 className={styles.title}>Ready to simplify your nutrition?</h2>
          <p className={styles.subtitle}>
            Join thousands of users who have already transformed their approach to food
          </p>

          <div className={styles.buttons}>
            <button className={styles.primaryBtn}>
              <span className={styles.icon}>📱</span>
              <span>Download on App Store</span>
            </button>
            <button className={styles.primaryBtn}>
              <span className={styles.icon}>🤖</span>
              <span>Get it on Google Play</span>
            </button>
          </div>

          <p className={styles.note}>
            Free to download. No credit card required.
          </p>
        </div>
      </section>

      <footer className={styles.footer}>
        <div className={styles.footerContent}>
          <div className={styles.footerTop}>
            <div className={styles.footerBrand}>
              <div className={styles.footerLogo}>
                <Image src="/logo no bg.png" alt="Kybo" width={32} height={32} className={styles.footerLogoIcon} />
                <span className={styles.footerLogoText}>Kybo</span>
              </div>
              <p className={styles.footerTagline}>
                Your nutrition, finally simplified
              </p>
            </div>

            <div className={styles.footerLinks}>
              <div className={styles.footerColumn}>
                <h4>Product</h4>
                <a href="#features">Features</a>
                <a href="#gallery">Gallery</a>
                <a href="#stats">Stats</a>
              </div>

              <div className={styles.footerColumn}>
                <h4>Company</h4>
                <Link href="/about">About Us</Link>
                <Link href="/blog">Blog</Link>
                <Link href="/careers">Careers</Link>
              </div>

              <div className={styles.footerColumn}>
                <h4>Support</h4>
                <Link href="/help">Help Centre</Link>
                <Link href="/contact">Contact</Link>
                <Link href="/faq">FAQ</Link>
              </div>

              <div className={styles.footerColumn}>
                <h4>Legal</h4>
                <Link href="/privacy">Privacy Policy</Link>
                <Link href="/terms">Terms of Service</Link>
                <Link href="/cookies">Cookie Policy</Link>
              </div>
            </div>
          </div>

          <div className={styles.footerBottom}>
            <p className={styles.copyright}>
              © 2025 Kybo. All rights reserved. ·{' '}
              <Link href="/" style={{ color: 'inherit', opacity: 0.6 }}>🇮🇹 Versione Italiana</Link>
            </p>
            <div className={styles.socials}>
              <a href="https://instagram.com" target="_blank" rel="noopener noreferrer" aria-label="Instagram">📷</a>
              <a href="https://twitter.com" target="_blank" rel="noopener noreferrer" aria-label="Twitter">🐦</a>
              <a href="https://facebook.com" target="_blank" rel="noopener noreferrer" aria-label="Facebook">📘</a>
              <a href="https://linkedin.com" target="_blank" rel="noopener noreferrer" aria-label="LinkedIn">💼</a>
            </div>
          </div>
        </div>
      </footer>
    </>
  );
}
