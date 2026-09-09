import React from 'react';
import type { IconKey, SocialKey } from '@/content/types';

/**
 * Set di icone di linea, disegnate sulla stessa griglia 24×24 con lo stesso
 * spessore di tratto, così da leggersi come una famiglia unica.
 *
 * Sostituiscono le emoji usate in precedenza: le emoji cambiano forma su ogni
 * sistema operativo, non si possono colorare col brand e su un prodotto che
 * tratta piani alimentari abbassano la percezione di serietà.
 *
 * Ereditano il colore dal contenitore via `currentColor`.
 */

const base = {
  width: 24,
  height: 24,
  viewBox: '0 0 24 24',
  fill: 'none',
  stroke: 'currentColor',
  strokeWidth: 1.75,
  strokeLinecap: 'round' as const,
  strokeLinejoin: 'round' as const,
  'aria-hidden': true,
  focusable: false,
};

const paths: Record<IconKey, React.ReactNode> = {
  // Calendario con spunta: il piano dei pasti giorno per giorno
  plan: (
    <>
      <rect x="3" y="5" width="18" height="16" rx="2.5" />
      <path d="M3 10h18M8 3v4M16 3v4" />
      <path d="M9 15.5l2 2 4-4" />
    </>
  ),
  // Carrello della spesa
  cart: (
    <>
      <path d="M2.5 3h2l2.2 11.2a1.8 1.8 0 0 0 1.8 1.4h8.4a1.8 1.8 0 0 0 1.8-1.4L20.5 7H6" />
      <circle cx="9.5" cy="20" r="1.4" />
      <circle cx="17.5" cy="20" r="1.4" />
    </>
  ),
  // Barattolo con coperchio: la dispensa
  pantry: (
    <>
      <path d="M7 3h10M8 6h8" />
      <path d="M6.5 6h11l-.7 13a2 2 0 0 1-2 1.9h-5.6a2 2 0 0 1-2-1.9z" />
      <path d="M7 12h10" />
    </>
  ),
  // Grafico a barre: i progressi
  chart: (
    <>
      <path d="M3 21h18" />
      <path d="M6.5 21v-6M12 21V7M17.5 21v-9" />
    </>
  ),
  // Fumetto: la chat col nutrizionista
  chat: (
    <>
      <path d="M21 11.5a7.5 7.5 0 0 1-10.9 6.7L4 20l1.8-5.1A7.5 7.5 0 1 1 21 11.5z" />
      <path d="M9 11h.01M12.5 11h.01M16 11h.01" />
    </>
  ),
  // Scintilla: la lettura automatica del PDF
  ai: (
    <>
      <path d="M12 3l1.9 5.1L19 10l-5.1 1.9L12 17l-1.9-5.1L5 10l5.1-1.9z" />
      <path d="M18.5 16.5l.7 1.8 1.8.7-1.8.7-.7 1.8-.7-1.8-1.8-.7 1.8-.7z" />
    </>
  ),
};

export function FeatureIcon({ name, className }: { name: IconKey; className?: string }) {
  return (
    <svg {...base} className={className}>
      {paths[name]}
    </svg>
  );
}

const socialPaths: Record<SocialKey, React.ReactNode> = {
  instagram: (
    <>
      <rect x="3" y="3" width="18" height="18" rx="5" />
      <circle cx="12" cy="12" r="4" />
      <path d="M17.5 6.5h.01" />
    </>
  ),
  linkedin: (
    <>
      <path d="M4.5 9.5v11M4.5 5.2v.01" />
      <path d="M10 20.5v-6a3 3 0 0 1 6 0v6" />
      <path d="M10 9.5v11" />
    </>
  ),
};

export function SocialIcon({ name, className }: { name: SocialKey; className?: string }) {
  return (
    <svg {...base} className={className}>
      {socialPaths[name]}
    </svg>
  );
}
