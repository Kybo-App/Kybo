'use client';

import React, { Suspense } from 'react';
import dynamic from 'next/dynamic';
import styles from './page.module.css';

// Above the fold — caricato subito
const SmoothScroll = dynamic(() => import('@/components/animations/SmoothScroll'), { ssr: false });
const Navbar = dynamic(() => import('@/components/Navbar'), { ssr: false });
const HeroSection = dynamic(() => import('@/components/sections/HeroSection'), { ssr: false });

// Below the fold — lazy loaded
const FeatureCards = dynamic(
  () => import('@/components/sections/FeatureCards'),
  { ssr: false, loading: () => <div style={{ minHeight: '400px' }} /> }
);
const StatsSection = dynamic(
  () => import('@/components/sections/StatsSection'),
  { ssr: false, loading: () => <div style={{ minHeight: '200px' }} /> }
);
const HorizontalGallery = dynamic(
  () => import('@/components/sections/HorizontalGallery'),
  { ssr: false, loading: () => <div style={{ minHeight: '400px' }} /> }
);
const ComparisonTable = dynamic(
  () => import('@/components/sections/ComparisonTable'),
  { ssr: false, loading: () => <div style={{ minHeight: '400px' }} /> }
);
const AppMockup = dynamic(
  () => import('@/components/sections/AppMockup'),
  { ssr: false, loading: () => <div style={{ minHeight: '500px' }} /> }
);
const CTASection = dynamic(
  () => import('@/components/sections/CTASection'),
  { ssr: false, loading: () => <div style={{ minHeight: '200px' }} /> }
);

export default function HomePage() {
  return (
    <SmoothScroll>
      <Navbar />
      <main className={styles.main}>
        <HeroSection />
        <Suspense fallback={<div style={{ minHeight: '400px' }} />}>
          <FeatureCards />
        </Suspense>
        <Suspense fallback={<div style={{ minHeight: '200px' }} />}>
          <StatsSection />
        </Suspense>
        <Suspense fallback={<div style={{ minHeight: '400px' }} />}>
          <HorizontalGallery />
        </Suspense>
        <Suspense fallback={<div style={{ minHeight: '500px' }} />}>
          <AppMockup />
        </Suspense>
        <Suspense fallback={<div style={{ minHeight: '400px' }} />}>
          <ComparisonTable />
        </Suspense>
        <Suspense fallback={<div style={{ minHeight: '200px' }} />}>
          <CTASection />
        </Suspense>
      </main>
    </SmoothScroll>
  );
}
