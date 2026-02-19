import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Per Nutrizionisti',
  description:
    'Kybo per professionisti: gestisci i tuoi clienti, carica diete personalizzate e monitora i progressi con il pannello dedicato.',
  openGraph: {
    title: 'Per Nutrizionisti | Kybo',
    description:
      'Gestisci i tuoi clienti, carica diete personalizzate e monitora i progressi con il pannello Kybo.',
    url: 'https://kybo.it/business',
  },
  alternates: { canonical: 'https://kybo.it/business' },
};

export default function BusinessLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
