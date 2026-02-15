'use client';

import React from 'react';
import Link from 'next/link';
import Image from 'next/image';
import styles from '../app/business/page.module.css';

export default function BusinessPageContent() {
  return (
    <>
      {/* Navbar */}
      <nav className={styles.nav}>
        <div className={styles.navContainer}>
          <Link href="/" className={styles.logo}>
            <Image src="/logo no bg.png" alt="Kybo" width={32} height={32} className={styles.logoIcon} priority />
            <span className={styles.logoText}>Kybo</span>
          </Link>
          <div className={styles.navActions}>
            <a href="https://app.kybo.it" target="_blank" rel="noopener noreferrer" className={styles.loginBtn}>
              Accedi alla Dashboard
            </a>
            <Link href="/" className={styles.backBtn}>
              ← Torna alla Home
            </Link>
          </div>
        </div>
      </nav>

      {/* Hero Section */}
      <section className={styles.hero}>
        <div className={styles.heroContent}>
          <h1 className={styles.title}>
            Kybo per Nutrizionisti
          </h1>
          <p className={styles.subtitle}>
            Potenzia la tua pratica professionale con strumenti avanzati per la gestione dei pazienti
          </p>
          <button className={styles.ctaBtn}>
            Richiedi una Demo
          </button>
        </div>
      </section>

      {/* Features Section */}
      <section className={styles.features}>
        <div className={styles.container}>
          <h2 className={styles.sectionTitle}>Strumenti Professionali</h2>
          <p className={styles.sectionSubtitle}>
            Dashboard completa per gestire i tuoi pazienti con efficienza
          </p>
          
          <div className={styles.grid}>
            <div className={styles.featureCard}>
              <div className={styles.iconWrapper} style={{ background: 'linear-gradient(135deg, #66BB6A22 0%, #66BB6A44 100%)' }}>
                <span className={styles.icon}>👥</span>
              </div>
              <h3>Gestione Pazienti Completa</h3>
              <p>Crea, modifica ed elimina account pazienti direttamente dalla dashboard. Visualizza tutti i tuoi pazienti in un&apos;unica schermata con ricerca rapida per nome o email. Assegna pazienti a te stesso o trasferiscili ad altri nutrizionisti del team.</p>
              <div className={styles.featureHighlight}>
                <span>✓ Creazione account pazienti</span>
                <span>✓ Ricerca e filtri avanzati</span>
                <span>✓ Assegnazione nutrizionisti</span>
              </div>
            </div>

            <div className={styles.featureCard}>
              <div className={styles.iconWrapper} style={{ background: 'linear-gradient(135deg, #3B82F622 0%, #3B82F644 100%)' }}>
                <span className={styles.icon}>📋</span>
              </div>
              <h3>Upload Diete PDF</h3>
              <p>Carica piani alimentari in formato PDF direttamente per i tuoi pazienti. I file vengono salvati in modo sicuro e sono immediatamente accessibili dall&apos;app mobile del paziente. Supporto per configurazioni parser personalizzate.</p>
              <div className={styles.featureHighlight}>
                <span>✓ Upload PDF sicuro</span>
                <span>✓ Accesso immediato paziente</span>
                <span>✓ Parser configurabile</span>
              </div>
            </div>

            <div className={styles.featureCard}>
              <div className={styles.iconWrapper} style={{ background: 'linear-gradient(135deg, #8B5CF622 0%, #8B5CF644 100%)' }}>
                <span className={styles.icon}>📊</span>
              </div>
              <h3>Storico Pazienti</h3>
              <p>Visualizza lo storico completo di ogni paziente: diete caricate, modifiche account, e tutte le azioni effettuate. Tracciamento completo per monitorare l&apos;evoluzione del percorso nutrizionale di ogni cliente.</p>
              <div className={styles.featureHighlight}>
                <span>✓ Timeline completa</span>
                <span>✓ Storico diete</span>
                <span>✓ Log modifiche</span>
              </div>
            </div>

            <div className={styles.featureCard}>
              <div className={styles.iconWrapper} style={{ background: 'linear-gradient(135deg, #FFA72622 0%, #FFA72644 100%)' }}>
                <span className={styles.icon}>🔒</span>
              </div>
              <h3>Sicurezza e Controllo</h3>
              <p>Sistema di autenticazione sicuro con ruoli differenziati (Admin, Nutrizionista). Audit log completo di tutte le azioni sensibili. Protezione dati pazienti conforme alle normative privacy.</p>
              <div className={styles.featureHighlight}>
                <span>✓ Autenticazione sicura</span>
                <span>✓ Gestione ruoli</span>
                <span>✓ Audit log completo</span>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Pricing Section */}
      <section className={styles.pricing}>
        <div className={styles.container}>
          <h2 className={styles.sectionTitle}>Piani Tariffari</h2>
          
          <div className={styles.pricingGrid}>
            <div className={styles.pricingCard}>
              <h3>Starter</h3>
              <div className={styles.price}>
                <span className={styles.amount}>€49</span>
                <span className={styles.period}>/mese</span>
              </div>
              <ul className={styles.featuresList}>
                <li>✓ Fino a 20 pazienti</li>
                <li>✓ Piani alimentari base</li>
                <li>✓ Report mensili</li>
                <li>✓ Supporto email</li>
              </ul>
              <button className={styles.pricingBtn}>Inizia Ora</button>
            </div>

            <div className={`${styles.pricingCard} ${styles.featured}`}>
              <div className={styles.badge}>Più Popolare</div>
              <h3>Professional</h3>
              <div className={styles.price}>
                <span className={styles.amount}>€99</span>
                <span className={styles.period}>/mese</span>
              </div>
              <ul className={styles.featuresList}>
                <li>✓ Pazienti illimitati</li>
                <li>✓ Piani alimentari avanzati</li>
                <li>✓ Report settimanali</li>
                <li>✓ Chat integrata</li>
                <li>✓ Supporto prioritario</li>
              </ul>
              <button className={`${styles.pricingBtn} ${styles.featuredBtn}`}>Inizia Ora</button>
            </div>

            <div className={styles.pricingCard}>
              <h3>Enterprise</h3>
              <div className={styles.price}>
                <span className={styles.amount}>Custom</span>
              </div>
              <ul className={styles.featuresList}>
                <li>✓ Tutto in Professional</li>
                <li>✓ API personalizzate</li>
                <li>✓ White label</li>
                <li>✓ Account manager dedicato</li>
              </ul>
              <button className={styles.pricingBtn}>Contattaci</button>
            </div>
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className={styles.cta}>
        <div className={styles.ctaContent}>
          <h2>Pronto a trasformare la tua pratica?</h2>
          <p>Unisciti a centinaia di nutrizionisti che già usano Kybo</p>
          <div className={styles.ctaButtons}>
            <button className={styles.ctaBtn}>Richiedi una Demo Gratuita</button>
            <a href="https://app.kybo.it" target="_blank" rel="noopener noreferrer" className={styles.ctaLoginBtn}>
              Accedi alla Dashboard →
            </a>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className={styles.footer}>
        <div className={styles.footerContent}>
          <p>© 2025 Kybo. Tutti i diritti riservati.</p>
        </div>
      </footer>
    </>
  );
}
