'use client';

import React, { useState } from 'react';
import styles from './NewsletterSection.module.css';

export default function NewsletterSection() {
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
      const res = await fetch('https://kybo-prod.onrender.com/newsletter/subscribe', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email }),
      });

      if (!res.ok) {
        const data = await res.json().catch(() => null);
        throw new Error(data?.detail ?? 'Si è verificato un errore. Riprova più tardi.');
      }

      setSuccess(true);
      setEmail('');
    } catch (err: unknown) {
      if (err instanceof Error) {
        setError(err.message);
      } else {
        setError('Si è verificato un errore. Riprova più tardi.');
      }
    } finally {
      setLoading(false);
    }
  }

  return (
    <section className={styles.section}>
      <div className={styles.container}>
        <h2 className={styles.title}>
          Resta aggiornato su{' '}
          <span className={styles.titleAccent}>Kybo</span>
        </h2>
        <p className={styles.subtitle}>
          Notizie, aggiornamenti e consigli nutrizionali. Nessuno spam.
        </p>

        {!success ? (
          <form className={styles.form} onSubmit={handleSubmit} noValidate>
            <input
              className={styles.input}
              type="email"
              placeholder="La tua email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              disabled={loading}
              aria-label="Indirizzo email"
            />
            <button className={styles.button} type="submit" disabled={loading}>
              {loading ? 'Iscrizione...' : 'Iscriviti'}
            </button>
          </form>
        ) : null}

        {success && (
          <p className={styles.messageSuccess}>
            Grazie! Sei iscritto alla newsletter di Kybo.
          </p>
        )}
        {error && (
          <p className={styles.messageError}>{error}</p>
        )}
      </div>
    </section>
  );
}
