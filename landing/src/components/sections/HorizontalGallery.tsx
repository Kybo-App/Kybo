'use client';

import React, { useEffect, useRef } from 'react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import styles from './HorizontalGallery.module.css';

if (typeof window !== 'undefined') {
  gsap.registerPlugin(ScrollTrigger);
}

const screenshots = [
  { id: 1, title: 'Dashboard', color: '#66BB6A' },
  { id: 2, title: 'Tracking Pasti', color: '#E53935' },
  { id: 3, title: 'Lista Spesa', color: '#3B82F6' },
  { id: 4, title: 'Dispensa', color: '#8B5CF6' },
  { id: 5, title: 'Statistiche', color: '#FFA726' },
  { id: 6, title: 'Profilo', color: '#66BB6A' },
];

export default function HorizontalGallery() {
  const sectionRef = useRef<HTMLElement>(null);
  const scrollerRef = useRef<HTMLDivElement>(null);

  // Use useLayoutEffect for GSAP to prevent FOUC and handle strict mode better
  const useIsomorphicLayoutEffect = typeof window !== 'undefined' ? React.useLayoutEffect : React.useEffect;

  useIsomorphicLayoutEffect(() => {
    if (!sectionRef.current || !scrollerRef.current) return;

    const ctx = gsap.context(() => {
      const section = sectionRef.current!;
      const scroller = scrollerRef.current!;
      
      // Calculate scroll width
      const scrollWidth = scroller.scrollWidth - window.innerWidth;

      // Create horizontal scroll animation
      gsap.to(scroller, {
        x: -scrollWidth,
        ease: 'none',
        scrollTrigger: {
          trigger: section,
          start: 'top top',
          end: () => `+=${scrollWidth}`,
          scrub: 1,
          // pin: true,
          // anticipatePin: 1,
          invalidateOnRefresh: true,
        },
      });
    }, sectionRef); // Scope to section

    // Cleanup
    return () => ctx.revert();
  }, []);

  return (
    <section ref={sectionRef} id="gallery" className={styles.section}>
      <div className={styles.header}>
        <h2 className={styles.title}>Esplora l'app</h2>
        <p className={styles.subtitle}>Scorri orizzontalmente per vedere tutte le funzionalità</p>
      </div>

      <div ref={scrollerRef} className={styles.scroller}>
        {screenshots.map((screenshot, index) => (
          <div key={screenshot.id} className={styles.card}>
            <div 
              className={styles.mockup}
              style={{ background: `linear-gradient(135deg, ${screenshot.color}22 0%, ${screenshot.color}44 100%)` }}
            >
              <div className={styles.phone}>
                <div className={styles.notch} />
                <div 
                  className={styles.screen}
                  style={{ background: screenshot.color }}
                >
                  <span className={styles.screenTitle}>{screenshot.title}</span>
                </div>
              </div>
            </div>
            <p className={styles.cardTitle}>{screenshot.title}</p>
          </div>
        ))}
      </div>

      <div className={styles.scrollHint}>
        <span>← Scroll →</span>
      </div>
    </section>
  );
}
