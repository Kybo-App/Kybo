/**
 * Modello dei contenuti della landing.
 *
 * Tutti i testi vivono qui, non dentro il JSX: i componenti sono presentazionali
 * e ricevono il contenuto come prop. È quello che permette di avere un solo
 * componente per sezione invece di una copia italiana e una inglese.
 */

export type IconKey = 'plan' | 'cart' | 'pantry' | 'chart' | 'chat' | 'ai';

export type SocialKey = 'instagram' | 'linkedin';

export interface Cta {
  label: string;
  href: string;
  /** true se il link è esterno o va aperto in una nuova scheda */
  external?: boolean;
}

export interface HeroContent {
  /** Il marchio, animato lettera per lettera. È l'h1 della pagina. */
  wordmark: string;
  subtitle: string;
  primaryCta: Cta;
  secondaryCta: Cta;
  scrollHint: string;
}

export interface FeatureItem {
  icon: IconKey;
  title: string;
  description: string;
  color: string;
}

export interface FeaturesContent {
  title: string;
  subtitle: string;
  items: FeatureItem[];
}

export interface ValueItem {
  /** Valore breve mostrato nel cerchio: deve stare in poche lettere. */
  value: string;
  label: string;
  color: string;
}

export interface ValuesContent {
  title: string;
  subtitle: string;
  items: ValueItem[];
}

export type CellValue = boolean | 'partial';

export interface ComparisonRow {
  feature: string;
  kybo: CellValue;
  manual: CellValue;
  others: CellValue;
}

export interface ComparisonContent {
  title: string;
  subtitle: string;
  columns: { feature: string; kybo: string; manual: string; others: string };
  rows: ComparisonRow[];
  legend: { yes: string; partial: string; no: string };
}

export interface NewsletterContent {
  title: string;
  subtitle: string;
  placeholder: string;
  button: string;
  success: string;
  error: string;
}

export interface CtaContent {
  title: string;
  subtitle: string;
  storeNote: string;
  comingSoonBadge: string;
  appStore: { sub: string; main: string; ariaLabel: string };
  googlePlay: { sub: string; main: string; ariaLabel: string };
}

export interface FooterColumn {
  heading: string;
  links: Cta[];
}

export interface FooterContent {
  tagline: string;
  columns: FooterColumn[];
  copyright: string;
  socials: Array<{ key: SocialKey; href: string; label: string }>;
}

export interface NavContent {
  /** Voci che puntano ad ancore nella pagina o ad altre rotte. */
  links: Cta[];
  loginLabel: string;
  loginHref: string;
  /** CTA principale della navbar: porta alla newsletter finché l'app non esce. */
  primaryCta: Cta;
  /** Link alla versione nell'altra lingua. */
  languageSwitch: Cta;
  openMenu: string;
  closeMenu: string;
}

/**
 * Contenuti del mockup dell'app.
 * Rispecchiano le schermate reali in client/lib/screens: diet_view,
 * shopping_list_view, pantry_view e il drawer di home_screen.
 */
export type MockupScreen = 'pantry' | 'diet' | 'shopping';

export interface MockupFood {
  name: string;
  qty: string;
  done?: boolean;
}

export interface MockupMeal {
  name: string;
  kcal: string;
  foods: MockupFood[];
  allConsumed?: boolean;
}

export interface MockupMenuItem {
  icon: string;
  label: string;
  badge?: string;
  tone: 'primary' | 'accent' | 'warning' | 'muted';
}

export interface MockupContent {
  eyebrow: string;
  heading: string;
  headingAccent: string;
  subtext: string;
  bullets: string[];
  hint: string;
  screenLabels: Record<MockupScreen, string>;
  appBar: { title: string; menu: string; swapDays: string; relaxMode: string };
  menu: { title: string; items: MockupMenuItem[]; close: string };
  diet: {
    portionsLabel: string;
    portions: string[];
    days: string[];
    activeDayIndex: number;
    meals: MockupMeal[];
    consumedLabel: string;
  };
  shopping: {
    budgetLabel: string;
    budgetSpent: string;
    budgetTotal: string;
    groupLabel: string;
    items: Array<{ name: string; checked?: boolean }>;
  };
  pantry: {
    title: string;
    aiButton: string;
    addPlaceholder: string;
    qtyPlaceholder: string;
    scanButton: string;
    items: Array<{ name: string; qty: string }>;
  };
}

export interface SiteContent {
  locale: 'it' | 'en';
  nav: NavContent;
  mockup: MockupContent;
  hero: HeroContent;
  features: FeaturesContent;
  values: ValuesContent;
  comparison: ComparisonContent;
  newsletter: NewsletterContent;
  cta: CtaContent;
  footer: FooterContent;
}
