import type { SiteContent } from './types';

export const en: SiteContent = {
  locale: 'en',

  nav: {
    links: [
      { label: 'Features', href: '#features' },
      { label: 'How it works', href: '#stats' },
      { label: 'Gallery', href: '#gallery' },
      { label: 'For nutritionists', href: '/business' },
    ],
    loginLabel: 'Sign in',
    loginHref: 'https://app.kybo.it',
    primaryCta: { label: 'Notify me at launch', href: '#newsletter' },
    languageSwitch: { label: 'IT', href: '/' },
    openMenu: 'Open menu',
    closeMenu: 'Close menu',
  },

  mockup: {
    eyebrow: 'Mobile app',
    heading: 'Everything you need,',
    headingAccent: 'always with you',
    subtext:
      'These are the app’s real screens: meal plan, shopping list and pantry. Tap the bar at the bottom to move between them.',
    bullets: [
      'Day-by-day meal plan',
      'Shopping list with a budget',
      'Pantry with receipt scanning',
      'Direct chat with your nutritionist',
      'AI recipes from what you already have',
    ],
    hint: 'Interactive — tap to explore',
    screenLabels: { pantry: 'Pantry', diet: 'Plan', shopping: 'List' },
    appBar: {
      title: 'Kybo',
      menu: 'Open menu',
      swapDays: 'Swap days',
      relaxMode: 'Relax mode',
    },
    menu: {
      title: 'Menu',
      close: 'Close menu',
      items: [
        { icon: 'chat', label: 'Dr. Rossi', badge: '2', tone: 'primary' },
        { icon: 'history', label: 'History', tone: 'accent' },
        { icon: 'trophy', label: 'Achievements', tone: 'warning' },
        { icon: 'pdf', label: 'Export PDF', tone: 'primary' },
        { icon: 'chart', label: 'Statistics', tone: 'accent' },
        { icon: 'sparkle', label: 'AI suggestions', tone: 'primary' },
        { icon: 'gift', label: 'Rewards shop', tone: 'warning' },
        { icon: 'settings', label: 'Settings', tone: 'muted' },
      ],
    },
    diet: {
      portionsLabel: 'Portions:',
      portions: ['×1', '×2', '×4', '×6'],
      days: ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'],
      activeDayIndex: 2,
      consumedLabel: 'Eaten',
      meals: [
        {
          name: 'Breakfast',
          kcal: '350 kcal',
          allConsumed: true,
          foods: [
            { name: 'Greek yoghurt', qty: '150 g', done: true },
            { name: 'Apple', qty: '1 pc', done: true },
            { name: 'Coffee', qty: 'As you like', done: true },
          ],
        },
        {
          name: 'Lunch',
          kcal: '580 kcal',
          foods: [
            { name: 'Chicken breast', qty: '150 g', done: true },
            { name: 'Brown rice', qty: '80 g', done: true },
            { name: 'Courgettes', qty: '200 g' },
          ],
        },
        {
          name: 'Dinner',
          kcal: '510 kcal',
          foods: [
            { name: 'Salmon', qty: '180 g' },
            { name: 'Roast potatoes', qty: '200 g' },
            { name: 'Salad', qty: 'As you like' },
          ],
        },
      ],
    },
    shopping: {
      budgetLabel: 'Budget: €60',
      budgetSpent: '€41.30',
      budgetTotal: 'estimated of €60',
      groupLabel: 'Group by category',
      items: [
        { name: 'Chicken breast — 600 g', checked: true },
        { name: 'Fresh salmon — 720 g' },
        { name: 'Brown rice — 500 g', checked: true },
        { name: 'Courgettes — 800 g' },
        { name: 'Greek yoghurt — 6 pots' },
        { name: 'Apples — 1 kg' },
        { name: 'Potatoes — 1.5 kg' },
      ],
    },
    pantry: {
      title: 'Your Pantry',
      aiButton: 'AI recipes',
      addPlaceholder: 'Add food...',
      qtyPlaceholder: 'Qty',
      scanButton: 'Scan receipt',
      items: [
        { name: 'Brown rice', qty: '500 g' },
        { name: 'Greek yoghurt', qty: '4 pots' },
        { name: 'Courgettes', qty: '600 g' },
        { name: 'Olive oil', qty: '750 ml' },
        { name: 'Apples', qty: '1 kg' },
      ],
    },
  },

  hero: {
    wordmark: 'Kybo',
    subtitle:
      'Kybo turns the PDF meal plan into an app you can actually use: today’s meals, a shopping list that fills itself, and a direct line to your professional.',
    primaryCta: { label: 'See how it works', href: '#features' },
    secondaryCta: { label: 'Are you a nutritionist?', href: '/business' },
    scrollHint: 'Scroll to explore',
  },

  features: {
    title: 'Everything you need',
    subtitle: 'One place to follow your plan, from the shop to the plate',
    items: [
      {
        icon: 'plan',
        title: 'Meal plan',
        description:
          'Every day’s meals, with portions and alternatives. Tick off what you ate with one tap.',
        color: '#66BB6A',
      },
      {
        icon: 'cart',
        title: 'Shopping list',
        description:
          'Built from your plan and what’s already in your pantry. Sorted by aisle.',
        color: '#3B82F6',
      },
      {
        icon: 'pantry',
        title: 'Pantry',
        description:
          'Track what you have and get a warning before it expires. Scan the receipt to update it.',
        color: '#8B5CF6',
      },
      {
        icon: 'chart',
        title: 'Progress',
        description:
          'Charts and reports on how closely you follow the plan, ready to share with your nutritionist.',
        color: '#FFA726',
      },
      {
        icon: 'chat',
        title: 'Chat with your nutritionist',
        description:
          'Questions, doubts and attachments in one channel, instead of chasing each other on WhatsApp.',
        color: '#26C6DA',
      },
      {
        icon: 'ai',
        title: 'Automatic PDF reading',
        description:
          'The plan your professional sends is read and structured by Google Gemini AI.',
        color: '#EC4899',
      },
    ],
  },

  values: {
    title: 'What Kybo actually gives you',
    subtitle: 'Four things guaranteed from day one',
    items: [
      { value: 'PDF', label: 'Your nutritionist’s plan, read by AI', color: '#66BB6A' },
      { value: 'AES-256', label: 'Your diet data encrypted at rest', color: '#3B82F6' },
      { value: '€0', label: 'Always free for the patient', color: '#FFA726' },
      { value: 'Offline', label: 'Your plan stays readable without a connection', color: '#8B5CF6' },
    ],
  },

  comparison: {
    title: 'Why choose Kybo?',
    subtitle: 'How Kybo compares with the usual alternatives',
    columns: {
      feature: 'Feature',
      kybo: 'Kybo',
      manual: 'Manual tracking',
      others: 'Other tools',
    },
    rows: [
      { feature: 'Digital meal plan', kybo: true, manual: false, others: 'partial' },
      { feature: 'Automatic shopping list', kybo: true, manual: false, others: false },
      { feature: 'Nutritionist chat', kybo: true, manual: false, others: false },
      { feature: 'Pantry tracking', kybo: true, manual: false, others: false },
      { feature: 'Statistics & progress', kybo: true, manual: false, others: 'partial' },
      { feature: 'Allergen highlights', kybo: true, manual: false, others: false },
      { feature: 'Offline mode', kybo: true, manual: true, others: 'partial' },
      { feature: 'Meal notifications', kybo: true, manual: false, others: 'partial' },
      { feature: 'Nutritionist PDF upload', kybo: true, manual: false, others: false },
      { feature: 'Free for patients', kybo: true, manual: true, others: false },
    ],
    legend: { yes: 'Available', partial: 'Partially', no: 'Not available' },
  },

  newsletter: {
    title: 'We’ll tell you when Kybo launches',
    subtitle: 'One email when the app is out, plus the updates that matter. Nothing else.',
    placeholder: 'Your email',
    button: 'Notify me',
    success: 'Done. We’ll write as soon as Kybo is available.',
    error: 'Something went wrong. Please try again later.',
  },

  cta: {
    title: 'Kybo is on its way',
    subtitle:
      'The app is in the final stage of development. Leave your email above to be among the first to try it.',
    storeNote: 'Free for anyone following a meal plan. No credit card.',
    comingSoonBadge: 'Coming soon',
    appStore: { sub: 'Soon on', main: 'App Store', ariaLabel: 'Kybo will soon be available on the App Store' },
    googlePlay: { sub: 'Soon on', main: 'Google Play', ariaLabel: 'Kybo will soon be available on Google Play' },
  },

  footer: {
    tagline: 'Your nutritionist’s plan, clear every day',
    columns: [
      {
        heading: 'Product',
        links: [
          { label: 'Features', href: '#features' },
          { label: 'Gallery', href: '#gallery' },
          { label: 'For nutritionists', href: '/business' },
        ],
      },
      {
        heading: 'Company',
        links: [
          { label: 'About', href: '/about' },
          { label: 'Blog', href: '/blog' },
          { label: 'Careers', href: '/careers' },
        ],
      },
      {
        heading: 'Support',
        links: [
          { label: 'Help centre', href: '/help' },
          { label: 'Contact', href: '/contact' },
          { label: 'FAQ', href: '/faq' },
          { label: 'Pricing', href: '/business#prezzi' },
        ],
      },
      {
        heading: 'Legal',
        links: [
          { label: 'Privacy policy', href: '/privacy' },
          { label: 'Terms of service', href: '/terms' },
          { label: 'Cookie policy', href: '/cookies' },
        ],
      },
    ],
    copyright: '© 2025 Kybo. All rights reserved.',
    socials: [
      { key: 'instagram', href: 'https://www.instagram.com/kybo.nutrition/', label: 'Instagram' },
      { key: 'linkedin', href: 'https://www.linkedin.com/company/kybonutrition', label: 'LinkedIn' },
    ],
  },
};
