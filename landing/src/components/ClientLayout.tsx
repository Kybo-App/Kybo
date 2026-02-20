'use client';

import dynamic from 'next/dynamic';

const SmoothScroll = dynamic(() => import('./animations/SmoothScroll'), { ssr: false });

export default function ClientLayout({ children }: { children: React.ReactNode }) {
  return <SmoothScroll>{children}</SmoothScroll>;
}
