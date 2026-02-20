import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Privacy Policy',
  description: 'Informativa sulla privacy di Kybo: come raccogliamo e utilizziamo i tuoi dati.',
  robots: { index: false },
  alternates: { canonical: 'https://kybo.it/privacy' },
};

export default function PrivacyLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
