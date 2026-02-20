import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Kybo – AI-powered Diet Management for Nutritionists',
  description:
    'Kybo helps nutritionists manage clients, upload personalised meal plans, track progress, and communicate via built-in chat. Start your free trial today.',
  openGraph: {
    title: 'Kybo – AI-powered Diet Management for Nutritionists',
    description:
      'Manage your nutrition clients effortlessly. Upload PDF meal plans, track compliance, and chat directly with patients.',
    url: 'https://kybo.it/en',
    images: [{ url: 'https://kybo.it/og-image.png', width: 1200, height: 630, alt: 'Kybo App' }],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Kybo – AI-powered Diet Management',
    description: 'The all-in-one platform for nutritionists and their clients.',
  },
  alternates: {
    canonical: 'https://kybo.it/en',
    languages: { 'it': 'https://kybo.it', 'en': 'https://kybo.it/en' },
  },
};

export default function EnLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
