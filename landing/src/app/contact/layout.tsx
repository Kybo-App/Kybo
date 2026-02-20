import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Contatti',
  description: 'Contatta il team Kybo per supporto, partnership o informazioni.',
  openGraph: {
    title: 'Contatti | Kybo',
    description: 'Contatta il team Kybo per supporto, partnership o informazioni.',
    url: 'https://kybo.it/contact',
  },
  alternates: { canonical: 'https://kybo.it/contact' },
};

export default function ContactLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
