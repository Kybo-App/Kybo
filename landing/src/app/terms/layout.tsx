import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Termini di Servizio',
  description: 'Termini e condizioni di utilizzo della piattaforma Kybo.',
  robots: { index: false },
  alternates: { canonical: 'https://kybo.it/terms' },
};

export default function TermsLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
