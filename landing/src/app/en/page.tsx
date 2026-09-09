import React from 'react';
import Navbar from '@/components/Navbar';
import HeroSection from '@/components/sections/HeroSection';
import FeatureCards from '@/components/sections/FeatureCards';
import ValuesSection from '@/components/sections/ValuesSection';
import ComparisonTable from '@/components/sections/ComparisonTable';
import AppMockup from '@/components/sections/AppMockup';
import NewsletterSection from '@/components/sections/NewsletterSection';
import CTASection from '@/components/sections/CTASection';
import { en } from '@/content/en';
import styles from '../page.module.css';

/*
  Stessi componenti della home italiana, contenuto diverso.
  Prima esistevano cinque copie dei componenti in components/sections/en/,
  già divergenti dalle italiane: ora ce n'è una sola per sezione.
*/

export default function EnPage() {
  return (
    <>
      <Navbar content={en.nav} />
      <main className={styles.main}>
        <HeroSection content={en.hero} />
        <FeatureCards content={en.features} />
        <ValuesSection content={en.values} />
        <AppMockup content={en.mockup} />
        <ComparisonTable content={en.comparison} />
        <NewsletterSection content={en.newsletter} />
        <CTASection content={en.cta} footer={en.footer} />
      </main>
    </>
  );
}
