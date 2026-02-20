'use client';

import React, { useEffect, useRef, useState } from 'react';
import Image from 'next/image';
import Link from 'next/link';
import { useLenis } from './animations/SmoothScroll';
import styles from './Navbar.module.css';

export default function NavbarEn() {
  const navRef = useRef<HTMLElement>(null);
  const [isScrolled, setIsScrolled] = useState(false);
  const [isDark, setIsDark] = useState(true);
  const { lenis } = useLenis();

  useEffect(() => {
    const handleScroll = () => setIsScrolled(window.scrollY > 50);
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const toggleTheme = () => {
    const next = !isDark;
    setIsDark(next);
    document.documentElement.setAttribute('data-theme', next ? 'dark' : 'light');
    document.body.style.background = next ? '#1a1a1a' : '#f8fafc';
  };

  const handleNavClick = (e: React.MouseEvent<HTMLAnchorElement>, targetId: string) => {
    e.preventDefault();
    if (lenis) {
      lenis.scrollTo(targetId);
    } else {
      document.querySelector(targetId)?.scrollIntoView({ behavior: 'smooth' });
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
          <li><Link href="/en/business">For Nutritionists</Link></li>
          {/* Language switcher */}
          <li><Link href="/" style={{ fontSize: '0.8rem', opacity: 0.6 }}>🇮🇹 IT</Link></li>
        </ul>

        <div className={styles.ctaGroup}>
          <button
            className={styles.themeToggle}
            onClick={toggleTheme}
            aria-label={isDark ? 'Switch to light mode' : 'Switch to dark mode'}
            title={isDark ? 'Light Mode' : 'Dark Mode'}
          >
            {isDark ? '☀️' : '🌙'}
          </button>
          <a href="https://app.kybo.it" target="_blank" rel="noopener noreferrer" className={styles.loginBtn}>
            Sign In
          </a>
          <button className={styles.ctaBtn}>
            Download App
          </button>
        </div>
      </div>
    </nav>
  );
}
