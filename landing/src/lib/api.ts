// Base URL del backend Kybo. Default su prod per build production su kybo.it.
// In dev locale: impostare NEXT_PUBLIC_API_URL=https://kybo-test.onrender.com in .env.local
export const API_BASE =
  process.env.NEXT_PUBLIC_API_URL ?? 'https://kybo-prod.onrender.com';
