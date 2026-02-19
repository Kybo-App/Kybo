import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Prezzi | Kybo',
  robots: { index: false }, // redirect verso /business#prezzi
  alternates: { canonical: 'https://kybo.it/business' },
};

export default function PricingLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
