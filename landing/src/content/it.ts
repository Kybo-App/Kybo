import type { SiteContent } from './types';

export const it: SiteContent = {
  locale: 'it',

  nav: {
    links: [
      { label: 'Funzionalità', href: '#features' },
      { label: 'Come funziona', href: '#stats' },
      { label: 'Galleria', href: '#gallery' },
      { label: 'Per nutrizionisti', href: '/business' },
    ],
    loginLabel: 'Area riservata',
    loginHref: 'https://app.kybo.it',
    // Finché l'app non è pubblicata la CTA porta alla newsletter, non a un
    // download che non esiste.
    primaryCta: { label: 'Avvisami al lancio', href: '#newsletter' },
    languageSwitch: { label: 'EN', href: '/en' },
    openMenu: 'Apri menu',
    closeMenu: 'Chiudi menu',
  },

  mockup: {
    eyebrow: 'App mobile',
    heading: 'Tutto quello che ti serve,',
    headingAccent: 'sempre con te',
    subtext:
      'Le schermate qui accanto sono quelle vere dell’app: piano alimentare, lista della spesa e dispensa. Tocca la barra in basso per passare da una all’altra.',
    bullets: [
      'Piano alimentare giorno per giorno',
      'Lista della spesa con budget',
      'Dispensa con scanner dello scontrino',
      'Chat diretta con il nutrizionista',
      'Ricette AI da ciò che hai in casa',
    ],
    hint: 'Interattivo — tocca per esplorare',
    screenLabels: { pantry: 'Dispensa', diet: 'Piano', shopping: 'Lista' },
    appBar: {
      title: 'Kybo',
      menu: 'Apri il menu',
      swapDays: 'Scambia giorni',
      relaxMode: 'Modalità relax',
    },
    menu: {
      title: 'Menu',
      close: 'Chiudi il menu',
      items: [
        { icon: 'chat', label: 'Dr.ssa Rossi', badge: '2', tone: 'primary' },
        { icon: 'history', label: 'Cronologia', tone: 'accent' },
        { icon: 'trophy', label: 'Traguardi', tone: 'warning' },
        { icon: 'pdf', label: 'Esporta PDF', tone: 'primary' },
        { icon: 'chart', label: 'Statistiche', tone: 'accent' },
        { icon: 'sparkle', label: 'Suggerimenti AI', tone: 'primary' },
        { icon: 'gift', label: 'Shop Premi', tone: 'warning' },
        { icon: 'settings', label: 'Impostazioni', tone: 'muted' },
      ],
    },
    diet: {
      portionsLabel: 'Porzioni:',
      portions: ['×1', '×2', '×4', '×6'],
      days: ['LUN', 'MAR', 'MER', 'GIO', 'VEN', 'SAB', 'DOM'],
      activeDayIndex: 2,
      consumedLabel: 'Consumato',
      meals: [
        {
          name: 'Colazione',
          kcal: '350 kcal',
          allConsumed: true,
          foods: [
            { name: 'Yogurt greco', qty: '150 g', done: true },
            { name: 'Mela', qty: '1 pz', done: true },
            { name: 'Caffè', qty: 'A piacere', done: true },
          ],
        },
        {
          name: 'Pranzo',
          kcal: '580 kcal',
          foods: [
            { name: 'Petto di pollo', qty: '150 g', done: true },
            { name: 'Riso integrale', qty: '80 g', done: true },
            { name: 'Zucchine', qty: '200 g' },
          ],
        },
        {
          name: 'Cena',
          kcal: '510 kcal',
          foods: [
            { name: 'Salmone', qty: '180 g' },
            { name: 'Patate al forno', qty: '200 g' },
            { name: 'Insalata', qty: 'A piacere' },
          ],
        },
      ],
    },
    shopping: {
      budgetLabel: 'Budget: €60',
      budgetSpent: '€41,30',
      budgetTotal: 'stimati su €60',
      groupLabel: 'Raggruppa per categoria',
      items: [
        { name: 'Petto di pollo — 600 g', checked: true },
        { name: 'Salmone fresco — 720 g' },
        { name: 'Riso integrale — 500 g', checked: true },
        { name: 'Zucchine — 800 g' },
        { name: 'Yogurt greco — 6 vasetti' },
        { name: 'Mele — 1 kg' },
        { name: 'Patate — 1,5 kg' },
      ],
    },
    pantry: {
      title: 'La tua Dispensa',
      aiButton: 'Ricette AI',
      addPlaceholder: 'Aggiungi cibo...',
      qtyPlaceholder: 'Qtà',
      scanButton: 'Scansiona Scontrino',
      items: [
        { name: 'Riso integrale', qty: '500 g' },
        { name: 'Yogurt greco', qty: '4 vasetti' },
        { name: 'Zucchine', qty: '600 g' },
        { name: 'Olio EVO', qty: '750 ml' },
        { name: 'Mele', qty: '1 kg' },
      ],
    },
  },

  hero: {
    wordmark: 'Kybo',
    subtitle:
      'Kybo trasforma il piano alimentare in PDF in un’app da consultare: i pasti di oggi, la lista della spesa che si compila da sola e la chat diretta con il tuo professionista.',
    primaryCta: { label: 'Scopri come funziona', href: '#features' },
    secondaryCta: { label: 'Sei un nutrizionista?', href: '/business' },
    scrollHint: 'Scorri per esplorare',
  },

  features: {
    title: 'Tutto ciò di cui hai bisogno',
    subtitle: 'Un ecosistema completo per gestire la tua nutrizione',
    items: [
      {
        icon: 'plan',
        title: 'Piano alimentare',
        description:
          'I pasti di ogni giorno, con porzioni e alternative. Segna cosa hai consumato con un tocco.',
        color: '#66BB6A',
      },
      {
        icon: 'cart',
        title: 'Lista della spesa',
        description:
          'Si genera dal tuo piano e da quello che hai già in dispensa. Organizzata per reparto.',
        color: '#3B82F6',
      },
      {
        icon: 'pantry',
        title: 'Dispensa',
        description:
          'Tieni traccia dei prodotti e ricevi un avviso prima che scadano. Aggiorni tutto scansionando lo scontrino.',
        color: '#8B5CF6',
      },
      {
        icon: 'chart',
        title: 'Progressi',
        description:
          'Grafici e report sull’aderenza al piano, da condividere con il tuo nutrizionista.',
        color: '#FFA726',
      },
      {
        icon: 'chat',
        title: 'Chat col nutrizionista',
        description:
          'Domande, dubbi e allegati in un canale diretto, senza rincorrersi via WhatsApp.',
        color: '#26C6DA',
      },
      {
        icon: 'ai',
        title: 'Lettura automatica del PDF',
        description:
          'Il piano che ti manda il professionista viene letto e strutturato dall’AI di Google Gemini.',
        color: '#EC4899',
      },
    ],
  },

  // NOTA: questi sono fatti sul prodotto, non metriche di adozione.
  // Prima di aggiungerne altri, assicurarsi che siano verificabili.
  values: {
    title: 'Come funziona, in concreto',
    subtitle: 'Quattro cose che Kybo garantisce dal primo giorno',
    items: [
      { value: 'PDF', label: 'Il piano del tuo nutrizionista, letto dall’AI', color: '#66BB6A' },
      { value: 'AES-256', label: 'I tuoi dati alimentari cifrati a riposo', color: '#3B82F6' },
      { value: '0 €', label: 'Sempre gratuito per il paziente', color: '#FFA726' },
      { value: 'Offline', label: 'Il piano resta consultabile senza rete', color: '#8B5CF6' },
    ],
  },

  comparison: {
    title: 'Perché scegliere Kybo?',
    subtitle: 'Confronta Kybo con le alternative più comuni',
    columns: {
      feature: 'Funzionalità',
      kybo: 'Kybo',
      manual: 'Gestione manuale',
      others: 'Altri tool',
    },
    rows: [
      { feature: 'Piano alimentare digitale', kybo: true, manual: false, others: 'partial' },
      { feature: 'Lista spesa automatica', kybo: true, manual: false, others: false },
      { feature: 'Chat con nutrizionista', kybo: true, manual: false, others: false },
      { feature: 'Tracking dispensa', kybo: true, manual: false, others: false },
      { feature: 'Statistiche & progressi', kybo: true, manual: false, others: 'partial' },
      { feature: 'Allergeni evidenziati', kybo: true, manual: false, others: false },
      { feature: 'Modalità offline', kybo: true, manual: true, others: 'partial' },
      { feature: 'Notifiche pasti', kybo: true, manual: false, others: 'partial' },
      { feature: 'Upload PDF nutrizionista', kybo: true, manual: false, others: false },
      { feature: 'Gratuito per il paziente', kybo: true, manual: true, others: false },
    ],
    legend: { yes: 'Disponibile', partial: 'Parzialmente', no: 'Non disponibile' },
  },

  newsletter: {
    title: 'Ti avvisiamo quando Kybo esce',
    subtitle:
      'Una email quando l’app è disponibile, più gli aggiornamenti importanti. Nient’altro.',
    placeholder: 'La tua email',
    button: 'Avvisami',
    success: 'Fatto. Ti scriviamo appena Kybo è disponibile.',
    error: 'Si è verificato un errore. Riprova più tardi.',
  },

  cta: {
    title: 'Kybo sta arrivando',
    subtitle:
      'L’app è in fase finale di sviluppo. Lascia la tua email qui sopra e sarai tra i primi a provarla.',
    storeNote: 'Sarà gratuita per chi segue un piano alimentare. Nessuna carta di credito.',
    comingSoonBadge: 'Presto disponibile',
    appStore: { sub: 'Presto su', main: 'App Store', ariaLabel: 'Kybo sarà presto disponibile su App Store' },
    googlePlay: { sub: 'Presto su', main: 'Google Play', ariaLabel: 'Kybo sarà presto disponibile su Google Play' },
  },

  footer: {
    tagline: 'La dieta del tuo nutrizionista, chiara ogni giorno',
    columns: [
      {
        heading: 'Prodotto',
        links: [
          { label: 'Funzionalità', href: '#features' },
          { label: 'Galleria', href: '#gallery' },
          { label: 'Per nutrizionisti', href: '/business' },
        ],
      },
      {
        heading: 'Azienda',
        links: [
          { label: 'Chi siamo', href: '/about' },
          { label: 'Blog', href: '/blog' },
          { label: 'Lavora con noi', href: '/careers' },
        ],
      },
      {
        heading: 'Supporto',
        links: [
          { label: 'Centro assistenza', href: '/help' },
          { label: 'Contatti', href: '/contact' },
          { label: 'FAQ', href: '/faq' },
          { label: 'Prezzi', href: '/business#prezzi' },
        ],
      },
      {
        heading: 'Legale',
        links: [
          { label: 'Privacy policy', href: '/privacy' },
          { label: 'Termini di servizio', href: '/terms' },
          { label: 'Cookie policy', href: '/cookies' },
        ],
      },
    ],
    copyright: '© 2025 Kybo. Tutti i diritti riservati.',
    socials: [
      { key: 'instagram', href: 'https://www.instagram.com/kybo.nutrition/', label: 'Instagram' },
      { key: 'linkedin', href: 'https://www.linkedin.com/company/kybonutrition', label: 'LinkedIn' },
    ],
  },
};
