'use client';

import React, { useEffect, useRef } from 'react';
import styles from './HeroSection.module.css';

const titleText = 'Kybo';

export default function HeroSection() {
  const heroRef = useRef<HTMLDivElement>(null);
  const titleRef = useRef<HTMLHeadingElement>(null);
  const subtitleRef = useRef<HTMLParagraphElement>(null);
  const ctaRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    let ctx: { revert: () => void } | null = null;

    const initGsap = async () => {
      const { gsap } = await import('gsap');
      const { ScrollTrigger } = await import('gsap/ScrollTrigger');
      gsap.registerPlugin(ScrollTrigger);

      ctx = gsap.context(() => {
        if (titleRef.current) {
          const chars = titleRef.current.querySelectorAll('span');
          gsap.from(chars, {
            y: 100,
            opacity: 0,
            rotationX: -90,
            stagger: 0.03,
            duration: 1,
            ease: 'back.out(1.7)',
            delay: 0.3,
          });
        }

        if (subtitleRef.current) {
          gsap.from(subtitleRef.current, {
            y: 30,
            opacity: 0,
            duration: 1,
            delay: 1,
            ease: 'power2.out',
          });
        }

        if (ctaRef.current) {
          const buttons = ctaRef.current.querySelectorAll('button, a');
          gsap.from(buttons, {
            scale: 0,
            opacity: 0,
            stagger: 0.15,
            duration: 0.6,
            delay: 1.5,
            ease: 'elastic.out(1, 0.5)',
          });
        }
      }, heroRef);
    };

    initGsap();

    return () => {
      ctx?.revert();
    };
  }, []);

  return (
    <section ref={heroRef} className={styles.hero}>
      {/* Content */}
      <div className={styles.content}>
        <h1 ref={titleRef} className={styles.title}>
          {titleText.split('').map((char, i) => (
            <span key={i} style={{ display: 'inline-block' }}>
              {char === ' ' ? '\u00A0' : char}
            </span>
          ))}
        </h1>
        
        <p ref={subtitleRef} className={styles.subtitle}>
          La tua nutrizione, finalmente semplificata
        </p>




        {/* Scroll indicator */}
        <div className={styles.scrollIndicator}>
          <span>Scroll per esplorare</span>
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
            <path d="M12 5v14m0 0l-7-7m7 7l7-7" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
        </div>
      </div>
    </section>
  );
}
