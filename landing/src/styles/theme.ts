// Design System Theme for Kybo Landing Pages
// Pill-shaped UI with strict design guidelines

export const theme = {
  // Border Radius
  borderRadius: {
    pill: '100px',      // For buttons, inputs, badges
    large: '24px',      // For cards
    medium: '16px',     // For smaller elements
  },

  // Color Palette
  colors: {
    // Primary Brand (Kybo Green)
    primary: '#2E7D32',
    primaryLight: '#60AD5E',
    primaryDark: '#005005',

    // Accent (Blue for Nutritionist section)
    accent: '#3B82F6',
    accentLight: '#60A5FA',
    accentDark: '#2563EB',

    // Admin/Parser (Purple)
    admin: '#8B5CF6',
    adminLight: '#A78BFA',
    adminDark: '#7C3AED',

    // Light Mode
    light: {
      background: '#F8FAFC',
      surface: '#FFFFFF',
      surfaceElevated: '#FFFFFF',
      text: '#0F172A',
      textMuted: '#475569',
      border: '#E2E8F0',
    },

    // Dark Mode
    dark: {
      background: '#0F172A',
      surface: '#1E293B',
      surfaceElevated: '#334155',
      text: '#F8FAFC',
      textMuted: '#94A3B8',
      border: '#334155',
    },
  },

  // Shadows
  shadows: {
    small: '0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px -1px rgba(0, 0, 0, 0.1)',
    medium: '0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -2px rgba(0, 0, 0, 0.1)',
    large: '0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -4px rgba(0, 0, 0, 0.1)',
    xl: '0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 8px 10px -6px rgba(0, 0, 0, 0.1)',
  },

  // Transitions
  transitions: {
    fast: '150ms cubic-bezier(0.4, 0, 0.2, 1)',
    normal: '200ms cubic-bezier(0.4, 0, 0.2, 1)',
    slow: '300ms cubic-bezier(0.4, 0, 0.2, 1)',
  },

  // Typography
  fonts: {
    body: "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
    heading: "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
  },

  fontSizes: {
    xs: '0.75rem',    // 12px
    sm: '0.875rem',   // 14px
    base: '1rem',     // 16px
    lg: '1.125rem',   // 18px
    xl: '1.25rem',    // 20px
    '2xl': '1.5rem',  // 24px
    '3xl': '1.875rem',// 30px
    '4xl': '2.25rem', // 36px
    '5xl': '3rem',    // 48px
  },

  // Spacing
  spacing: {
    xs: '0.5rem',   // 8px
    sm: '0.75rem',  // 12px
    md: '1rem',     // 16px
    lg: '1.5rem',   // 24px
    xl: '2rem',     // 32px
    '2xl': '3rem',  // 48px
    '3xl': '4rem',  // 64px
  },
} as const;

export type Theme = typeof theme;
