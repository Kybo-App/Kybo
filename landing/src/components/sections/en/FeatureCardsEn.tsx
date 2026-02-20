'use client';

import React, { useEffect, useRef } from 'react';
import styles from '../FeatureCards.module.css';

const features = [
  {
    icon: '🍎',
    title: 'Diet Tracking',
    description: 'Track your meals effortlessly. Scan barcodes and monitor nutrients in real time.',
    color: '#E53935',
  },
  {
    icon: '🛒',
    title: 'Smart Shopping List',
    description: 'Automatically generate your shopping list based on your diet plan and pantry.',
    color: '#3B82F6',
  },
  {
    icon: '📦',
    title: 'Virtual Pantry',
    description: 'Keep track of all your products and receive notifications before expiry dates.',
    color: '#8B5CF6',
  },
  {
    icon: '📊',
    title: 'Detailed Statistics',
    description: 'Visualise your progress with interactive charts and personalised reports.',
    color: '#FFA726',
  },
  {
    icon: '💬',
    title: 'Nutritionist Chat',
    description: 'Stay in direct contact with your nutritionist. Share attachments and get personalised advice.',
    color: '#66BB6A',
  },
  {
    icon: '🤖',
    title: 'Gemini AI',
    description: 'PDF meal plans are automatically parsed and structured by Google Gemini AI.',
    color: '#EC4899',
  },
];

export default function FeatureCardsEn() {
  const sectionRef = useRef<HTMLElement>(null);
  const titleRef = useRef<HTMLHeadingElement>(null);
  const subtitleRef = useRef<HTMLParagraphElement>(null);
  const cardsRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const initGsap = async () => {
      const { gsap } = await import('gsap');
      const { ScrollTrigger } = await import('gsap/ScrollTrigger');
      gsap.registerPlugin(ScrollTrigger);

      if (titleRef.current) {
        gsap.fromTo(titleRef.current,
          { opacity: 0, y: 40 },
          { opacity: 1, y: 0, duration: 0.8, ease: 'power3.out',
            scrollTrigger: { trigger: titleRef.current, start: 'top 80%', once: true } }
        );
      }
      if (subtitleRef.current) {
        gsap.fromTo(subtitleRef.current,
          { opacity: 0, y: 30 },
          { opacity: 1, y: 0, duration: 0.8, delay: 0.15, ease: 'power3.out',
            scrollTrigger: { trigger: subtitleRef.current, start: 'top 80%', once: true } }
        );
      }
      if (cardsRef.current) {
        const cards = cardsRef.current.querySelectorAll(`.${styles.card}`);
        gsap.fromTo(cards,
          { opacity: 0, y: 50, scale: 0.95 },
          { opacity: 1, y: 0, scale: 1, stagger: 0.15, duration: 0.6, ease: 'power3.out',
            scrollTrigger: { trigger: cardsRef.current, start: 'top 75%', once: true } }
        );
        cards.forEach((card) => {
          const el = card as HTMLElement;
          el.addEventListener('mouseenter', () => gsap.to(el, { y: -8, scale: 1.02, duration: 0.3, ease: 'power2.out' }));
          el.addEventListener('mouseleave', () => gsap.to(el, { y: 0, scale: 1, duration: 0.3, ease: 'power2.out' }));
        });
      }
    };
    initGsap();
  }, []);

  return (
    <section ref={sectionRef} id="features" className={styles.section}>
      <div className={styles.container}>
        <h2 ref={titleRef} className={styles.title}>Everything you need</h2>
        <p ref={subtitleRef} className={styles.subtitle}>
          From meal planning to shopping, all in one app
        </p>

        <div ref={cardsRef} className={styles.grid}>
          {features.map((feature, index) => (
            <div key={index} className={styles.card}>
              <div className={styles.iconWrapper} style={{ background: `${feature.color}22` }}>
                <span className={styles.icon}>{feature.icon}</span>
              </div>
              <h3 className={styles.cardTitle}>{feature.title}</h3>
              <p className={styles.cardDescription}>{feature.description}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
