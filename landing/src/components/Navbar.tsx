'use client';

import React, { useEffect, useState } from 'react';
import Image from 'next/image';
import Link from 'next/link';
import { useLenis } from './animations/SmoothScroll';
import type { NavContent } from '@/content/types';
import { UiIcon } from '@/components/icons/UiIcons';
import styles from './Navbar.module.css';

export default function Navbar({ content }: { content: NavContent }) {
  const [isScrolled, setIsScrolled] = useState(false);
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const { lenis } = useLenis();

  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 50);
      if (window.scrollY > 50) setIsMenuOpen(false);
    };
    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const handleAnchorClick = (e: React.MouseEvent<HTMLAnchorElement>, targetId: string) => {
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
    <nav className={`${styles.nav} ${isScrolled ? styles.scrolled : ''}`}>
      <div className={styles.container}>
        <div className={styles.logo}>
          <Image
            src="/logo no bg.png"
            alt="Kybo"
            width={32}
            height={32}
            className={styles.logoIcon}
            priority
          />
          <span className={styles.logoText}>Kybo</span>
        </div>

        <ul className={`${styles.menu} ${isMenuOpen ? styles.menuOpen : ''}`}>
          {content.links.map((link) => (
            <li key={link.label}>
              {link.href.startsWith('#') ? (
                <a href={link.href} onClick={(e) => handleAnchorClick(e, link.href)}>
                  {link.label}
                </a>
              ) : (
                <Link href={link.href} onClick={close}>
                  {link.label}
                </Link>
              )}
            </li>
          ))}
          <li>
            <Link href={content.languageSwitch.href} onClick={close} className={styles.langSwitch}>
              {content.languageSwitch.label}
            </Link>
          </li>
        </ul>

        <div className={styles.ctaGroup}>
          <a
            href={content.loginHref}
            target="_blank"
            rel="noopener noreferrer"
            className={styles.loginBtn}
          >
            {content.loginLabel}
          </a>
          {/* Era un <button> senza handler che prometteva un download inesistente. */}
          <a
            href={content.primaryCta.href}
            className={styles.ctaBtn}
            onClick={(e) => handleAnchorClick(e, content.primaryCta.href)}
          >
            {content.primaryCta.label}
          </a>
        </div>

        <button
          className={styles.hamburger}
          onClick={() => setIsMenuOpen((o) => !o)}
          aria-label={isMenuOpen ? content.closeMenu : content.openMenu}
          aria-expanded={isMenuOpen}
        >
          <UiIcon name={isMenuOpen ? 'cross' : 'menu'} size={22} />
        </button>
      </div>
    </nav>
  );
}
