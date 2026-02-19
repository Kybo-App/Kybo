'use client';

import React, { useEffect, useRef } from 'react';
import { useLenis } from '../animations/SmoothScroll';
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
  const outerRef = useRef<HTMLDivElement>(null);
  const scrollerRef = useRef<HTMLDivElement>(null);
  const { lenis } = useLenis();

  useEffect(() => {
    const outer = outerRef.current;
    const scroller = scrollerRef.current;
    if (!outer || !scroller) return;

    // Compute and set the outer container's height so that the sticky section
    // has enough vertical scroll space to show all cards horizontally.
    const setHeight = () => {
      const scrollWidth = scroller.scrollWidth - window.innerWidth;
      outer.style.height = `${window.innerHeight + Math.max(0, scrollWidth)}px`;
    };

    setHeight();
    window.addEventListener('resize', setHeight);

    // Core update: map vertical scroll progress → horizontal translateX
    const update = (scrollY: number) => {
      const rect = outer.getBoundingClientRect();
      const scrollWidth = scroller.scrollWidth - window.innerWidth;
      if (scrollWidth <= 0) return;

      // rect.top is relative to viewport; when section is pinned, rect.top = 0
      // and -rect.top grows as user scrolls into the section
      const rawProgress = -rect.top / scrollWidth;
      const progress = Math.min(1, Math.max(0, rawProgress));
      scroller.style.transform = `translateX(${-progress * scrollWidth}px)`;
    };

    // Listen via Lenis (smooth scroll events) AND native scroll (fallback)
    let lenisUnsub: (() => void) | null = null;

    if (lenis) {
      const handler = ({ scroll }: { scroll: number }) => update(scroll);
      lenis.on('scroll', handler);
      lenisUnsub = () => lenis.off('scroll', handler);
    } else {
      const handler = () => update(window.scrollY);
      window.addEventListener('scroll', handler, { passive: true });
      lenisUnsub = () => window.removeEventListener('scroll', handler);
    }

    return () => {
      window.removeEventListener('resize', setHeight);
      lenisUnsub?.();
    };
  }, [lenis]);

  return (
    <div ref={outerRef} id="gallery" className={styles.outer}>
      <div className={styles.sticky}>
        <div className={styles.header}>
          <h2 className={styles.title}>Esplora l'app</h2>
          <p className={styles.subtitle}>Scorri per vedere tutte le funzionalità</p>
        </div>

        <div ref={scrollerRef} className={styles.scroller}>
          {screenshots.map((screenshot) => (
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
      </div>
    </div>
  );
}
