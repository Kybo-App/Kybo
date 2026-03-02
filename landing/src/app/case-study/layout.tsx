import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Case Study — Dott.ssa Rossi con Kybo',
  description:
    'Come la Dott.ssa Maria Rossi, biologa nutrizionista a Milano, ha ridotto del 70% il tempo amministrativo e triplicato la soddisfazione dei clienti grazie a Kybo.',
};

export default function CaseStudyLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
