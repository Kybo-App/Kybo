import { redirect } from 'next/navigation';

/**
 * I prezzi sono stati unificati nella pagina /business.
 * I pazienti usano Kybo gratuitamente — i piani riguardano solo i professionisti.
 */
export default function PricingPage() {
  redirect('/business#prezzi');
}
