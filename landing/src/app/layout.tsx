import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import '../styles/globals.css';

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-inter',
});

export const metadata: Metadata = {
  title: 'Kybo - La tua nutrizione semplificata',
  description: 'Gestisci dieta, spesa e dispensa in un\'unica app intelligente',
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="it" className="lenis">
      <body className={inter.className}>
        {children}
      </body>
    </html>
  );
}
