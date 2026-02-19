'use client';

import React, { useEffect, useRef } from 'react';
import styles from './HorizontalGallery.module.css';

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

  useEffect(() => {
    if (!sectionRef.current || !scrollerRef.current) return;

    let ctx: { revert: () => void } | null = null;

    const initGsap = async () => {
      const { gsap } = await import('gsap');
      const { ScrollTrigger } = await import('gsap/ScrollTrigger');
      gsap.registerPlugin(ScrollTrigger);

      const section = sectionRef.current!;
      const scroller = scrollerRef.current!;

      // Aspetta il prossimo frame di layout per misurare le dimensioni reali
      await new Promise<void>((resolve) => requestAnimationFrame(() => requestAnimationFrame(() => resolve())));

      if (!sectionRef.current || !scrollerRef.current) return;

      ctx = gsap.context(() => {
        const getScrollWidth = () => scroller.scrollWidth - window.innerWidth;

        gsap.to(scroller, {
          x: () => -getScrollWidth(),
          ease: 'none',
          scrollTrigger: {
            trigger: section,
            start: 'top top',        // inizia quando la section tocca il top — nessun salto
            end: () => `+=${getScrollWidth()}`,
            scrub: 0.6,              // più reattivo, meno lag
            pin: true,
            pinSpacing: true,        // riserva spazio corretto evitando il salto di layout
            anticipatePin: 0,        // disabilitato: causava il pre-scroll jerky
            invalidateOnRefresh: true,
            fastScrollEnd: true,
          },
        });
      }, sectionRef);

      ScrollTrigger.refresh();
    };

    initGsap();

    return () => { ctx?.revert(); };
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
