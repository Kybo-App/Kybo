'use client';

import React, { useState } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import styles from '../shared.module.css';
import pStyles from './pricing.module.css';

const plans = [
  {
    name: 'Paziente',
    icon: '🍎',
    monthlyPrice: 0,
    annualPrice: 0,
    description: 'Per chi vuole seguire la propria dieta con facilità.',
    highlight: false,
    features: [
      'Piano alimentare digitale',
      'Lista spesa automatica',
      'Dispensa virtuale',
      'Tracking allergeni',
      'Chat con il nutrizionista',
      'Statistiche personali',
      'Notifiche pasti',
      'Badge & traguardi',
    ],
    cta: 'Scarica Gratis',
    ctaLink: '/',
  },
  {
    name: 'Nutrizionista Pro',
    icon: '👨‍⚕️',
    monthlyPrice: 29,
    annualPrice: 24,
    description: 'Per professionisti che gestiscono i propri pazienti.',
    highlight: true,
    badge: 'Più Popolare',
    features: [
      'Fino a 50 pazienti',
      'Dashboard admin completa',
      'Upload diete PDF con AI',
      'Chat con tutti i pazienti',
      'Analytics avanzate',
      'Report mensili PDF',
      'Notifiche messaggi non letti',
      'Note interne pazienti',
      'Broadcast messaggi',
      'Support prioritario',
    ],
    cta: 'Inizia Gratis 14 giorni',
    ctaLink: '/business',
  },
  {
    name: 'Studio / Clinica',
    icon: '🏥',
    monthlyPrice: 79,
    annualPrice: 65,
    description: 'Per studi con più nutrizionisti e team.',
    highlight: false,
    features: [
      'Pazienti illimitati',
      'Più nutrizionisti (team)',
      'Tutto del piano Pro',
      '2FA per tutti i professionisti',
      'GDPR dashboard avanzata',
      'SLA garantito',
      'Integrazione API Enterprise',
      'Onboarding dedicato',
    ],
    cta: 'Contattaci',
    ctaLink: '/contact',
  },
];

export default function PricingPage() {
  const [isAnnual, setIsAnnual] = useState(false);

  return (
    <div className={styles.pageWrapper}>
      {/* Navbar */}
      <nav className={styles.nav}>
        <div className={styles.navContainer}>
          <Link href="/" className={styles.logo}>
            <Image src="/logo no bg.png" alt="Kybo" width={32} height={32} className={styles.logoIcon} priority />
            <span className={styles.logoText}>Kybo</span>
          </Link>
          <div style={{ display: 'flex', gap: '1rem', alignItems: 'center' }}>
            <a href="https://app.kybo.it" target="_blank" rel="noopener noreferrer" className={styles.backBtn} style={{ border: '1px solid rgba(255,255,255,0.2)', padding: '0.5rem 1rem', borderRadius: '100px' }}>
              Area Riservata
            </a>
            <Link href="/" className={styles.backBtn}>← Torna alla Home</Link>
          </div>
        </div>
      </nav>

      {/* Hero */}
      <div className={styles.heroSmall}>
        <h1 className={styles.pageTitle}>Prezzi Semplici e Trasparenti</h1>
        <p className={styles.pageSubtitle}>
          Gratuito per i pazienti. Professionale per i nutrizionisti.
        </p>

        {/* Billing Toggle */}
        <div className={pStyles.toggleWrapper}>
          <span className={`${pStyles.toggleLabel} ${!isAnnual ? pStyles.activeLabel : ''}`}>Mensile</span>
          <button
            className={pStyles.toggle}
            onClick={() => setIsAnnual(!isAnnual)}
            aria-label="Cambia piano"
          >
            <span className={`${pStyles.toggleThumb} ${isAnnual ? pStyles.toggleThumbOn : ''}`} />
          </button>
          <span className={`${pStyles.toggleLabel} ${isAnnual ? pStyles.activeLabel : ''}`}>
            Annuale <span className={pStyles.saveBadge}>-17%</span>
          </span>
        </div>
      </div>

      {/* Plans Grid */}
      <section className={pStyles.plansSection}>
        <div className={pStyles.plansGrid}>
          {plans.map((plan) => (
            <div
              key={plan.name}
              className={`${pStyles.planCard} ${plan.highlight ? pStyles.planHighlight : ''}`}
            >
              {plan.badge && <div className={pStyles.planBadge}>{plan.badge}</div>}

              <div className={pStyles.planHeader}>
                <span className={pStyles.planIcon}>{plan.icon}</span>
                <h2 className={pStyles.planName}>{plan.name}</h2>
                <p className={pStyles.planDescription}>{plan.description}</p>
              </div>

              <div className={pStyles.priceBlock}>
                {plan.monthlyPrice === 0 ? (
                  <span className={pStyles.priceFree}>Gratis</span>
                ) : (
                  <>
                    <span className={pStyles.priceCurrency}>€</span>
                    <span className={pStyles.priceAmount}>
                      {isAnnual ? plan.annualPrice : plan.monthlyPrice}
                    </span>
                    <span className={pStyles.pricePeriod}>/mese</span>
                  </>
                )}
                {isAnnual && plan.monthlyPrice > 0 && (
                  <p className={pStyles.annualNote}>Fatturato annualmente</p>
                )}
              </div>

              <ul className={pStyles.featureList}>
                {plan.features.map((f, i) => (
                  <li key={i} className={pStyles.featureItem}>
                    <span className={pStyles.checkIcon}>✓</span>
                    {f}
                  </li>
                ))}
              </ul>

              <Link
                href={plan.ctaLink}
                className={`${pStyles.planCta} ${plan.highlight ? pStyles.planCtaHighlight : ''}`}
              >
                {plan.cta}
              </Link>
            </div>
          ))}
        </div>
      </section>

      {/* FAQ teaser */}
      <section className={styles.section}>
        <div className={styles.container} style={{ textAlign: 'center' }}>
          <h2 className={styles.sectionTitle}>Domande Frequenti</h2>
          <p className={styles.sectionText} style={{ maxWidth: '600px', margin: '0 auto 2rem' }}>
            Hai dubbi sul piano giusto per te? Visita la nostra pagina FAQ o contattaci direttamente.
          </p>
          <div style={{ display: 'flex', gap: '1rem', justifyContent: 'center', flexWrap: 'wrap' }}>
            <Link href="/faq" className={styles.backBtn} style={{ border: '1px solid rgba(255,255,255,0.2)', padding: '0.75rem 2rem', borderRadius: '100px' }}>
              Vai alla FAQ
            </Link>
            <Link href="/contact" className={styles.ctaBtn}>
              Contattaci
            </Link>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className={styles.footer}>
        <p className={styles.footerText}>© 2025 Kybo. Tutti i diritti riservati.</p>
      </footer>
    </div>
  );
}
