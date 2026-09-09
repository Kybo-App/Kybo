'use client';

import React, { useState } from 'react';
import { API_BASE } from '@/lib/api';
import type { NewsletterContent } from '@/content/types';
import styles from './NewsletterSection.module.css';

export default function NewsletterSection({ content }: { content: NewsletterContent }) {
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState('');

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!email.trim()) return;

    setLoading(true);
    setError('');
    setSuccess(false);

    try {
      const res = await fetch(`${API_BASE}/newsletter/subscribe`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email }),
      });

      if (!res.ok) {
        const data = await res.json().catch(() => null);
        throw new Error(data?.detail ?? content.error);
      }

      setSuccess(true);
      setEmail('');
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : content.error);
    } finally {
      setLoading(false);
    }
  }

  return (
    <section id="newsletter" className={styles.section}>
      <div className={styles.container}>
        <h2 className={styles.title}>{content.title}</h2>
        <p className={styles.subtitle}>{content.subtitle}</p>

        {!success ? (
          <form className={styles.form} onSubmit={handleSubmit} noValidate>
            <input
              className={styles.input}
              type="email"
              placeholder={content.placeholder}
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              disabled={loading}
              aria-label={content.placeholder}
            />
            <button className={styles.button} type="submit" disabled={loading}>
              {loading ? '…' : content.button}
            </button>
          </form>
        ) : null}

        {/* aria-live: l'esito arriva dopo una chiamata di rete, va annunciato */}
        <div aria-live="polite">
          {success && <p className={styles.messageSuccess}>{content.success}</p>}
          {error && <p className={styles.messageError}>{error}</p>}
        </div>
      </div>
    </section>
  );
}
