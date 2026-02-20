'use client';

import React from 'react';
import Image from 'next/image';
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
                <a href="/about">About Us</a>
                <a href="/blog">Blog</a>
                <a href="/careers">Careers</a>
              </div>

              <div className={styles.footerColumn}>
                <h4>Support</h4>
                <a href="/help">Help Centre</a>
                <a href="/contact">Contact</a>
                <a href="/faq">FAQ</a>
              </div>

              <div className={styles.footerColumn}>
                <h4>Legal</h4>
                <a href="/privacy">Privacy Policy</a>
                <a href="/terms">Terms of Service</a>
                <a href="/cookies">Cookie Policy</a>
              </div>
            </div>
          </div>

          <div className={styles.footerBottom}>
            <p className={styles.copyright}>
              © 2025 Kybo. All rights reserved. ·{' '}
              <a href="/" style={{ color: 'inherit', opacity: 0.6 }}>🇮🇹 Versione Italiana</a>
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
