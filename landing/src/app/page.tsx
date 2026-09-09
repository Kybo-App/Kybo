import React from 'react';
import Navbar from '@/components/Navbar';
import HeroSection from '@/components/sections/HeroSection';
import FeatureCards from '@/components/sections/FeatureCards';
import ValuesSection from '@/components/sections/ValuesSection';
import ComparisonTable from '@/components/sections/ComparisonTable';
import AppMockup from '@/components/sections/AppMockup';
import NewsletterSection from '@/components/sections/NewsletterSection';
import CTASection from '@/components/sections/CTASection';
// [DISABILITATO 2026-09] import TrialPopup from '@/components/TrialPopup';
import { it } from '@/content/it';
import styles from './page.module.css';

/*
  Qui c'era una sezione testimonianze, poi eliminata insieme al suo componente.

  Conteneva sei recensioni firmate con nome, città e badge "Verificata",
  introdotte come "professionisti e clienti reali", per un'app che nella stessa
  pagina si dichiara non ancora pubblicata. Va ricostruita da zero quando ci
  saranno persone vere che hanno dato il consenso a essere citate.
*/

export default function HomePage() {
  return (
    <>
      <Navbar content={it.nav} />
      <main className={styles.main}>
        <HeroSection content={it.hero} />
        <FeatureCards content={it.features} />
        <ValuesSection content={it.values} />
        <AppMockup content={it.mockup} />
        <ComparisonTable content={it.comparison} />
        <NewsletterSection content={it.newsletter} />
        <CTASection content={it.cta} footer={it.footer} />
      </main>
      {/*
        [DISABILITATO 2026-09] Popup "Sei un nutrizionista?" (compariva dopo 8s).
        Messo in pausa in attesa di decidere se tenerlo: un audit UX lo ha
        indicato come concorrente dei CTA dell'header/hero sopra la piega.
        Il componente resta intatto in components/TrialPopup.tsx — per
        riattivarlo bastano questa riga e l'import sopra.
        <TrialPopup />
      */}
    </>
  );
}
