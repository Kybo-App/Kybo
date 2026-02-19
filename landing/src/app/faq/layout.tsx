import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'FAQ',
  description:
    'Domande frequenti su Kybo: come funziona, come iniziare, piani e funzionalità.',
  openGraph: {
    title: 'FAQ | Kybo',
    description: 'Domande frequenti su Kybo: come funziona, come iniziare, piani e funzionalità.',
    url: 'https://kybo.it/faq',
  },
  alternates: { canonical: 'https://kybo.it/faq' },
};

export default function FaqLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
