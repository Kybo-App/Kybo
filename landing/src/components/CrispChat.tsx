/**
 * CrispChat — live support chat widget
 * Carica il widget Crisp (https://crisp.chat) sulla landing page.
 * Per attivare: crea un account su crisp.chat (piano Free), vai su
 * Settings → Website → copia il Website ID e sostituiscilo in CRISP_WEBSITE_ID.
 * Con ID vuoto il widget non viene caricato (nessun errore in console).
 */
'use client';

import { useEffect } from 'react';

const CRISP_WEBSITE_ID = ''; // es. 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'

declare global {
  interface Window {
    $crisp: unknown[];
    CRISP_WEBSITE_ID: string;
  }
}

export default function CrispChat() {
  useEffect(() => {
    if (!CRISP_WEBSITE_ID) return;

    window.$crisp = [];
    window.CRISP_WEBSITE_ID = CRISP_WEBSITE_ID;

    const script = document.createElement('script');
    script.src = 'https://client.crisp.chat/l.js';
    script.async = true;
    document.head.appendChild(script);

    return () => {
      document.head.removeChild(script);
    };
  }, []);

  return null;
}
