import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Come cambia la gestione con Kybo',
  description:
    'Uno scenario illustrativo: come Kybo cambia la gestione quotidiana di uno studio di nutrizione, dal caricamento delle diete al monitoraggio dell’aderenza.',
};

export default function CaseStudyLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
