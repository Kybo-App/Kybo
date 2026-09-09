export const REDUCED_MOTION_QUERY = '(prefers-reduced-motion: reduce)';

/**
 * True se l'utente ha chiesto di ridurre le animazioni a livello di sistema.
 * Da chiamare prima di inizializzare GSAP, Lenis o qualsiasi animazione JS.
 *
 * Lo stesso controllo viene fatto in layout.tsx da uno script inline che marca
 * <html data-anim="on"> prima del primo paint: il CSS usa quell'attributo per
 * decidere se partire da uno stato nascosto, questo helper per decidere se
 * animare. Le due cose devono restare allineate.
 */
export function prefersReducedMotion(): boolean {
  if (typeof window === 'undefined' || !window.matchMedia) return false;
  return window.matchMedia(REDUCED_MOTION_QUERY).matches;
}
