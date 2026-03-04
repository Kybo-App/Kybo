import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Lista della Spesa — Kybo',
  description: 'Lista della spesa condivisa tramite Kybo',
  robots: 'noindex',
};

export default function ListLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
