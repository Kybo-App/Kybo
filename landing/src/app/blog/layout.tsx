import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Blog',
  description:
    'Articoli, consigli e aggiornamenti su nutrizione, dieta e benessere dal team Kybo.',
  openGraph: {
    title: 'Blog | Kybo',
    description:
      'Articoli, consigli e aggiornamenti su nutrizione, dieta e benessere dal team Kybo.',
    url: 'https://kybo.it/blog',
  },
  alternates: { canonical: 'https://kybo.it/blog' },
};

export default function BlogLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
