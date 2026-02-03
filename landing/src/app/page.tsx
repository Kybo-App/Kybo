'use client';

import React from 'react';
import SmoothScroll from '@/components/animations/SmoothScroll';
import Navbar from '@/components/Navbar';
import HeroSection from '@/components/sections/HeroSection';
import FeatureCards from '@/components/sections/FeatureCards';
import StatsSection from '@/components/sections/StatsSection';
import HorizontalGallery from '@/components/sections/HorizontalGallery';
import CTASection from '@/components/sections/CTASection';
import styles from './page.module.css';

export default function HomePage() {
  return (
    <SmoothScroll>
      <Navbar />
      <main className={styles.main}>
        <HeroSection />
        <FeatureCards />
        <StatsSection />
        <HorizontalGallery />
        <CTASection />
      </main>
    </SmoothScroll>
  );
}
