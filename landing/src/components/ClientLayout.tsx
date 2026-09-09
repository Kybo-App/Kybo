'use client';

import SmoothScroll from './animations/SmoothScroll';

// Import statico: SmoothScroll renderizza solo {children} e tocca Lenis dentro
// useEffect, quindi è già client-only. Caricarlo con ssr:false faceva collassare
// il prerender di ogni pagina del sito (body vuoto nell'HTML statico).
export default function ClientLayout({ children }: { children: React.ReactNode }) {
  return <SmoothScroll>{children}</SmoothScroll>;
}
