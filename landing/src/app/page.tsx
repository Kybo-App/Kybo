'use client';

import React from 'react';
import dynamic from 'next/dynamic';
import styles from './page.module.css';

const SmoothScroll = dynamic(() => import('@/components/animations/SmoothScroll'), { ssr: false });
const Navbar = dynamic(() => import('@/components/Navbar'), { ssr: false });
const HeroSection = dynamic(() => import('@/components/sections/HeroSection'), { ssr: false });
const FeatureCards = dynamic(() => import('@/components/sections/FeatureCards'), { ssr: false });
const StatsSection = dynamic(() => import('@/components/sections/StatsSection'), { ssr: false });
const HorizontalGallery = dynamic(() => import('@/components/sections/HorizontalGallery'), { ssr: false });
const CTASection = dynamic(() => import('@/components/sections/CTASection'), { ssr: false });

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
