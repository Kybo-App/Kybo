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
  const titleRef = useRef<HTMLHeadingElement>(null);
  const subtitleRef = useRef<HTMLParagraphElement>(null);

  useEffect(() => {
    if (typeof window === 'undefined') return;

    const initGsap = async () => {
      const { gsap } = await import('gsap');
      const { ScrollTrigger } = await import('gsap/ScrollTrigger');
      gsap.registerPlugin(ScrollTrigger);

      if (!cardsRef.current || !sectionRef.current) return;
      const cards = cardsRef.current.querySelectorAll(`.${styles.card}`);

      // Title & subtitle scroll-triggered fade in
      if (titleRef.current && subtitleRef.current) {
        gsap.fromTo(
          [titleRef.current, subtitleRef.current],
          { opacity: 0, y: 40 },
          {
            opacity: 1,
            y: 0,
            duration: 0.8,
            stagger: 0.15,
            ease: 'power3.out',
            scrollTrigger: {
              trigger: sectionRef.current,
              start: 'top 80%',
              once: true,
            },
          }
        );
      }

      // Cards staggered scroll-triggered animation
      gsap.fromTo(
        cards,
        { opacity: 0, y: 60, scale: 0.95 },
        {
          opacity: 1,
          y: 0,
          scale: 1,
          duration: 0.7,
          stagger: 0.15,
          ease: 'power3.out',
          scrollTrigger: {
            trigger: cardsRef.current,
            start: 'top 75%',
            once: true,
          },
        }
      );

      // GSAP hover animations
      cards.forEach((card) => {
        const el = card as HTMLElement;
        el.addEventListener('mouseenter', () =>
          gsap.to(el, { y: -12, scale: 1.03, duration: 0.3, ease: 'power2.out' })
        );
        el.addEventListener('mouseleave', () =>
          gsap.to(el, { y: 0, scale: 1, duration: 0.4, ease: 'power2.inOut' })
        );
      });
    };

    initGsap();
  }, []);

  return (
    <section ref={sectionRef} id="features" className={styles.section}>
      <div className={styles.container}>
        <h2 ref={titleRef} className={styles.title}>Tutto ciò di cui hai bisogno</h2>
        <p ref={subtitleRef} className={styles.subtitle}>
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
