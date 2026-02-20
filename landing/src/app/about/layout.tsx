import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Chi Siamo',
  description:
    'Scopri la storia di Kybo, la missione e il team dietro la piattaforma di nutrizione intelligente.',
  openGraph: {
    title: 'Chi Siamo | Kybo',
    description:
      'Scopri la storia di Kybo, la missione e il team dietro la piattaforma di nutrizione intelligente.',
    url: 'https://kybo.it/about',
  },
  alternates: { canonical: 'https://kybo.it/about' },
};

export default function AboutLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
