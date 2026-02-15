'use client';

import React, { useEffect, useRef } from 'react';
import styles from './FeatureCards.module.css';

const features = [
  {
    icon: '🍎',
    title: 'Tracking Dieta',
    description: 'Monitora i tuoi pasti con facilità. Scansiona barcode e traccia i nutrienti in tempo reale.',
    color: '#E53935',
  },
  {
    icon: '🛒',
    title: 'Lista Spesa Smart',
    description: 'Genera automaticamente la lista della spesa in base alla tua dieta e dispensa.',
    color: '#3B82F6',
  },
  {
    icon: '📦',
    title: 'Dispensa Virtuale',
    description: 'Tieni traccia di tutti i prodotti e ricevi notifiche prima della scadenza.',
    color: '#8B5CF6',
  },
  {
    icon: '📊',
    title: 'Statistiche Dettagliate',
    description: 'Visualizza i tuoi progressi con grafici interattivi e report personalizzati.',
    color: '#FFA726',
  },
];

export default function FeatureCards() {
  const sectionRef = useRef<HTMLElement>(null);
  const cardsRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!cardsRef.current) return;

    const cards = cardsRef.current.querySelectorAll(`.${styles.card}`);

    // Simple hover animations only
    const hoverListeners: Array<{ element: Element; enter: () => void; leave: () => void }> = [];

    cards.forEach((card) => {
      const cardElement = card as HTMLElement;
      
      const handleMouseEnter = () => {
        cardElement.style.transform = 'translateY(-10px) scale(1.05)';
      };

      const handleMouseLeave = () => {
        cardElement.style.transform = 'translateY(0) scale(1)';
      };

      cardElement.addEventListener('mouseenter', handleMouseEnter);
      cardElement.addEventListener('mouseleave', handleMouseLeave);

      hoverListeners.push({
        element: cardElement,
        enter: handleMouseEnter,
        leave: handleMouseLeave,
      });
    });

    // Cleanup
    return () => {
      hoverListeners.forEach(({ element, enter, leave }) => {
        element.removeEventListener('mouseenter', enter);
        element.removeEventListener('mouseleave', leave);
      });
    };
  }, []);

  return (
    <section ref={sectionRef} id="features" className={styles.section}>
      <div className={styles.container}>
        <h2 className={styles.title}>Tutto ciò di cui hai bisogno</h2>
        <p className={styles.subtitle}>
          Un ecosistema completo per gestire la tua nutrizione
        </p>

        <div ref={cardsRef} className={styles.grid}>
          {features.map((feature, index) => (
            <div key={index} className={styles.card}>
              <div 
                className={styles.iconWrapper}
                style={{ background: `linear-gradient(135deg, ${feature.color}22 0%, ${feature.color}44 100%)` }}
              >
                <span className={styles.icon}>{feature.icon}</span>
              </div>
              <h3 className={styles.cardTitle}>{feature.title}</h3>
              <p className={styles.cardDescription}>{feature.description}</p>
              <div 
                className={styles.accent}
                style={{ background: feature.color }}
              />
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
