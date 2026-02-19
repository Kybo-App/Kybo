import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Prezzi',
  description: 'Scopri i piani di Kybo. Gratuito per i pazienti, professionale per i nutrizionisti.',
  alternates: { canonical: 'https://kybo.it/pricing' },
  openGraph: {
    title: 'Prezzi | Kybo',
    description: 'Piani flessibili per professionisti della nutrizione.',
    url: 'https://kybo.it/pricing',
  },
};

export default function PricingLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
