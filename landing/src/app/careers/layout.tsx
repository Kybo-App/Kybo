import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Lavora con Noi',
  description:
    'Unisciti al team Kybo. Scopri le posizioni aperte e contribuisci a rivoluzionare la nutrizione digitale.',
  openGraph: {
    title: 'Lavora con Noi | Kybo',
    description:
      'Unisciti al team Kybo. Scopri le posizioni aperte e contribuisci a rivoluzionare la nutrizione digitale.',
    url: 'https://kybo.it/careers',
  },
  alternates: { canonical: 'https://kybo.it/careers' },
};

export default function CareersLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
