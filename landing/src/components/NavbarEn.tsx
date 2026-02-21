'use client';

import React, { useEffect, useRef, useState } from 'react';
import Image from 'next/image';
import { useLenis } from './animations/SmoothScroll';
import styles from './Navbar.module.css';

export default function NavbarEn() {
  const navRef = useRef<HTMLElement>(null);
  const [isScrolled,  setIsScrolled]  = useState(false);
  const [isMenuOpen,  setIsMenuOpen]  = useState(false);
  const { lenis } = useLenis();

  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 50);
      if (window.scrollY > 50) setIsMenuOpen(false);
    };
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const handleNavClick = (e: React.MouseEvent<HTMLAnchorElement>, targetId: string) => {
    e.preventDefault();
    setIsMenuOpen(false);
    if (lenis) {
      lenis.scrollTo(targetId);
    } else {
      document.querySelector(targetId)?.scrollIntoView({ behavior: 'smooth' });
    }
  };

  const close = () => setIsMenuOpen(false);

  return (
    <nav ref={navRef} className={`${styles.nav} ${isScrolled ? styles.scrolled : ''}`}>
      <div className={styles.container}>
        <div className={styles.logo}>
          <Image src="/logo no bg.png" alt="Kybo" width={32} height={32} className={styles.logoIcon} priority />
          <span className={styles.logoText}>Kybo</span>
        </div>

        <ul className={`${styles.menu} ${isMenuOpen ? styles.menuOpen : ''}`}>
          <li><a href="#features" onClick={(e) => handleNavClick(e, '#features')}>Features</a></li>
          <li><a href="#stats"    onClick={(e) => handleNavClick(e, '#stats')}>Stats</a></li>
          <li><a href="#gallery"  onClick={(e) => handleNavClick(e, '#gallery')}>Gallery</a></li>
          <li><a href="/en/business" onClick={close}>For Nutritionists</a></li>
          <li><a href="/" onClick={close} style={{ fontSize: '0.8rem', opacity: 0.6 }}>🇮🇹 IT</a></li>
        </ul>

        <div className={styles.ctaGroup}>
          <a href="https://app.kybo.it" target="_blank" rel="noopener noreferrer" className={styles.loginBtn}>
            Sign In
          </a>
          <button className={styles.ctaBtn}>Download App</button>
        </div>

        <button
          className={styles.hamburger}
          onClick={() => setIsMenuOpen(o => !o)}
          aria-label={isMenuOpen ? 'Close menu' : 'Open menu'}
          aria-expanded={isMenuOpen}
        >
          {isMenuOpen ? '✕' : '☰'}
        </button>
      </div>
    </nav>
  );
}
