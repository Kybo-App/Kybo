import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import '../styles/globals.css';
import ClientLayout from '@/components/ClientLayout';

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-inter',
});

const SITE_URL = 'https://kybo.it';
const OG_IMAGE = `${SITE_URL}/og-image.png`;

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: 'Kybo — La tua nutrizione semplificata',
    template: '%s | Kybo',
  },
  description:
    "Kybo è la piattaforma intelligente per nutrizionisti e clienti: gestisci diete, lista della spesa e dispensa in un'unica app.",
  applicationName: 'Kybo',
  keywords: [
    'nutrizione', 'dieta', 'nutrizionista', 'app dieta', 'gestione dieta',
    'lista spesa', 'dispensa', 'piano alimentare', 'Kybo',
  ],
  authors: [{ name: 'Kybo', url: SITE_URL }],
  creator: 'Kybo',
  publisher: 'Kybo',
  robots: {
    index: true,
    follow: true,
    googleBot: { index: true, follow: true },
  },
  icons: {
    icon: '/icon.ico',
    apple: '/icon.ico',
  },
  openGraph: {
    type: 'website',
    locale: 'it_IT',
    url: SITE_URL,
    siteName: 'Kybo',
    title: 'Kybo — La tua nutrizione semplificata',
    description:
      "Piattaforma intelligente per nutrizionisti e clienti. Diete, lista spesa e dispensa in un'unica app.",
    images: [
      {
        url: OG_IMAGE,
        width: 1200,
        height: 630,
        alt: 'Kybo — La tua nutrizione semplificata',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Kybo — La tua nutrizione semplificata',
    description:
      "Piattaforma intelligente per nutrizionisti e clienti. Diete, lista spesa e dispensa in un'unica app.",
    images: [OG_IMAGE],
    site: '@kyboapp',
    creator: '@kyboapp',
  },
  alternates: {
    canonical: SITE_URL,
  },
};

const jsonLd = {
  '@context': 'https://schema.org',
  '@graph': [
    {
      '@type': 'Organization',
      '@id': `${SITE_URL}/#organization`,
      name: 'Kybo',
      url: SITE_URL,
      logo: {
        '@type': 'ImageObject',
        url: `${SITE_URL}/logo.png`,
      },
      sameAs: [],
    },
    {
      '@type': 'WebSite',
      '@id': `${SITE_URL}/#website`,
      url: SITE_URL,
      name: 'Kybo',
      publisher: { '@id': `${SITE_URL}/#organization` },
      inLanguage: 'it-IT',
    },
    {
      '@type': 'SoftwareApplication',
      '@id': `${SITE_URL}/#app`,
      name: 'Kybo',
      applicationCategory: 'HealthApplication',
      operatingSystem: 'iOS, Android',
      description:
        "App per la gestione di diete, lista della spesa e dispensa. Ideale per nutrizionisti e i loro clienti.",
      offers: {
        '@type': 'Offer',
        price: '0',
        priceCurrency: 'EUR',
      },
      publisher: { '@id': `${SITE_URL}/#organization` },
    },
  ],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="it" className="lenis" data-theme="dark" suppressHydrationWarning>
      <head>
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
      </head>
      <body className={inter.className} suppressHydrationWarning>
        <ClientLayout>{children}</ClientLayout>
      </body>
    </html>
  );
}
