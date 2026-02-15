'use client';

import dynamic from 'next/dynamic';

const BusinessPageContent = dynamic(() => import('@/components/BusinessPageContent'), { ssr: false });

export default function BusinessPage() {
  return <BusinessPageContent />;
}
