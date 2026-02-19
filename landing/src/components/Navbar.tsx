'use client';

import React, { useEffect, useRef, useState } from 'react';
import Image from 'next/image';
import { useLenis } from './animations/SmoothScroll';
import styles from './Navbar.module.css';

export default function Navbar() {
  const navRef = useRef<HTMLElement>(null);
  const [isScrolled, setIsScrolled] = useState(false);
  const [isDark, setIsDark] = useState(true);
  const { lenis } = useLenis();

  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 50);
    };

    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const toggleTheme = () => {
    const next = !isDark;
    setIsDark(next);
    document.documentElement.setAttribute('data-theme', next ? 'dark' : 'light');
    // Also update body background so dark-mode sections look right
    document.body.style.background = next ? '#1a1a1a' : '#f8fafc';
  };

  const handleNavClick = (e: React.MouseEvent<HTMLAnchorElement>, targetId: string) => {
    e.preventDefault();
    if (lenis) {
      lenis.scrollTo(targetId);
    } else {
      const element = document.querySelector(targetId);
      element?.scrollIntoView({ behavior: 'smooth' });
    }
  };

  return (
    <nav ref={navRef} className={`${styles.nav} ${isScrolled ? styles.scrolled : ''}`}>
      <div className={styles.container}>
        <div className={styles.logo}>
          <Image src="/logo no bg.png" alt="Kybo" width={32} height={32} className={styles.logoIcon} priority />
          <span className={styles.logoText}>Kybo</span>
        </div>

        <ul className={styles.menu}>
          <li><a href="#features" onClick={(e) => handleNavClick(e, '#features')}>Features</a></li>
          <li><a href="#stats" onClick={(e) => handleNavClick(e, '#stats')}>Stats</a></li>
          <li><a href="#gallery" onClick={(e) => handleNavClick(e, '#gallery')}>Gallery</a></li>
          <li><a href="/business">Per Nutrizionisti</a></li>
          <li><a href="/business#prezzi">Prezzi</a></li>
          <li><a href="/en" style={{ fontSize: '0.8rem', opacity: 0.6 }}>🇬🇧 EN</a></li>
        </ul>

        <div className={styles.ctaGroup}>
          <button
            className={styles.themeToggle}
            onClick={toggleTheme}
            aria-label={isDark ? 'Passa alla modalità chiara' : 'Passa alla modalità scura'}
            title={isDark ? 'Modalità Chiara' : 'Modalità Scura'}
          >
            {isDark ? '☀️' : '🌙'}
          </button>
          <a href="https://app.kybo.it" target="_blank" rel="noopener noreferrer" className={styles.loginBtn}>
            Area Riservata
          </a>
          <button className={styles.ctaBtn}>
            Scarica App
          </button>
        </div>
      </div>
    </nav>
  );
}
