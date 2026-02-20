'use client';

import React, { useEffect, useRef, useState } from 'react';
import Image from 'next/image';
import Link from 'next/link';
import { useLenis } from './animations/SmoothScroll';
import styles from './Navbar.module.css';

export default function Navbar() {
  const navRef = useRef<HTMLElement>(null);
  const [isScrolled, setIsScrolled] = useState(false);
  const { lenis } = useLenis();

  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 50);
    };

    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

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
          <li><a href="#features" onClick={(e) => handleNavClick(e, '#features')}>Funzionalità</a></li>
          <li><a href="#stats" onClick={(e) => handleNavClick(e, '#stats')}>Statistiche</a></li>
          <li><a href="#gallery" onClick={(e) => handleNavClick(e, '#gallery')}>Galleria</a></li>
          <li><a href="/business">Per Nutrizionisti</a></li>
          <li><a href="/en" style={{ fontSize: '0.8rem', opacity: 0.6 }}>🇬🇧 EN</a></li>
        </ul>

        <div className={styles.ctaGroup}>
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
