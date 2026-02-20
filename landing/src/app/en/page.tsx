'use client';

import React, { Suspense } from 'react';
import dynamic from 'next/dynamic';
import styles from '../page.module.css';

const SmoothScroll = dynamic(() => import('@/components/animations/SmoothScroll'), { ssr: false });
const NavbarEn = dynamic(() => import('@/components/NavbarEn'), { ssr: false });
const HeroSectionEn = dynamic(() => import('@/components/sections/en/HeroSectionEn'), { ssr: false });

const FeatureCardsEn = dynamic(
  () => import('@/components/sections/en/FeatureCardsEn'),
  { ssr: false, loading: () => <div style={{ minHeight: '400px' }} /> }
);
const StatsSectionEn = dynamic(
  () => import('@/components/sections/en/StatsSectionEn'),
  { ssr: false, loading: () => <div style={{ minHeight: '200px' }} /> }
);
const ComparisonTableEn = dynamic(
  () => import('@/components/sections/en/ComparisonTableEn'),
  { ssr: false, loading: () => <div style={{ minHeight: '400px' }} /> }
);
const CTASectionEn = dynamic(
  () => import('@/components/sections/en/CTASectionEn'),
  { ssr: false, loading: () => <div style={{ minHeight: '200px' }} /> }
);

export default function EnPage() {
  return (
    <SmoothScroll>
      <NavbarEn />
      <main className={styles.main}>
        <HeroSectionEn />
        <Suspense fallback={<div style={{ minHeight: '400px' }} />}>
          <FeatureCardsEn />
        </Suspense>
        <Suspense fallback={<div style={{ minHeight: '200px' }} />}>
          <StatsSectionEn />
        </Suspense>
        <Suspense fallback={<div style={{ minHeight: '400px' }} />}>
          <ComparisonTableEn />
        </Suspense>
        <Suspense fallback={<div style={{ minHeight: '200px' }} />}>
          <CTASectionEn />
        </Suspense>
      </main>
    </SmoothScroll>
  );
}
