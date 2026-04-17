'use client';

import React, { useState } from 'react';
import Navbar from '@/components/Navbar';
import styles from './contact.module.css';

export default function ContactPage() {
  const [form, setForm] = useState({ name: '', email: '', message: '' });
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState('');

  function handleChange(e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) {
    setForm((prev) => ({ ...prev, [e.target.name]: e.target.value }));
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!form.name.trim() || !form.email.trim() || !form.message.trim()) return;

    setLoading(true);
    setError('');

    try {
      const res = await fetch('https://kybo-prod.onrender.com/contact/submit', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form),
      });

      if (!res.ok) {
        const data = await res.json().catch(() => null);
        throw new Error(data?.detail ?? 'Si è verificato un errore. Riprova più tardi.');
      }

      setSuccess(true);
      setForm({ name: '', email: '', message: '' });
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Errore inaspettato. Riprova più tardi.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <>
      <Navbar />
      <main className={styles.main}>
        <div className={styles.container}>
          <div className={styles.header}>
            <h1 className={styles.title}>Contattaci</h1>
            <p className={styles.subtitle}>
              Hai domande su Kybo o vuoi richiedere una demo?<br />
              Risponderemo entro 24 ore.
            </p>
          </div>

          <div className={styles.grid}>
            {/* Info box */}
            <div className={styles.info}>
              <div className={styles.infoCard}>
                <span className={styles.infoIcon}>📧</span>
                <div>
                  <h3 className={styles.infoTitle}>Email</h3>
                  <a href="mailto:info@kybo.app" className={styles.infoLink}>info@kybo.app</a>
                </div>
              </div>
              <div className={styles.infoCard}>
                <span className={styles.infoIcon}>⏱️</span>
                <div>
                  <h3 className={styles.infoTitle}>Tempo di risposta</h3>
                  <p className={styles.infoText}>Entro 24 ore lavorative</p>
                </div>
              </div>
              <div className={styles.infoCard}>
                <span className={styles.infoIcon}>🇮🇹</span>
                <div>
                  <h3 className={styles.infoTitle}>Supporto</h3>
                  <p className={styles.infoText}>In italiano e inglese</p>
                </div>
              </div>
            </div>

            {/* Form */}
            <div className={styles.formWrap}>
              {success ? (
                <div className={styles.successBox}>
                  <span className={styles.successIcon}>✅</span>
                  <h2 className={styles.successTitle}>Messaggio inviato!</h2>
                  <p className={styles.successText}>
                    Grazie per averci contattato. Ti risponderemo entro 24 ore lavorative.
                  </p>
                  <button
                    className={styles.resetBtn}
                    onClick={() => setSuccess(false)}
                  >
                    Invia un altro messaggio
                  </button>
                </div>
              ) : (
                <form className={styles.form} onSubmit={handleSubmit} noValidate>
                  <div className={styles.field}>
                    <label className={styles.label} htmlFor="name">Nome completo</label>
                    <input
                      className={styles.input}
                      id="name"
                      name="name"
                      type="text"
                      placeholder="Mario Rossi"
                      value={form.name}
                      onChange={handleChange}
                      required
                      disabled={loading}
                      maxLength={100}
                    />
                  </div>

                  <div className={styles.field}>
                    <label className={styles.label} htmlFor="email">Email</label>
                    <input
                      className={styles.input}
                      id="email"
                      name="email"
                      type="email"
                      placeholder="mario@esempio.it"
                      value={form.email}
                      onChange={handleChange}
                      required
                      disabled={loading}
                    />
                  </div>

                  <div className={styles.field}>
                    <label className={styles.label} htmlFor="message">Messaggio</label>
                    <textarea
                      className={styles.textarea}
                      id="message"
                      name="message"
                      placeholder="Descrivi la tua richiesta..."
                      value={form.message}
                      onChange={handleChange}
                      required
                      disabled={loading}
                      rows={5}
                      maxLength={2000}
                    />
                    <span className={styles.charCount}>{form.message.length}/2000</span>
                  </div>

                  {error && <p className={styles.errorMsg}>{error}</p>}

                  <button className={styles.submit} type="submit" disabled={loading}>
                    {loading ? 'Invio in corso...' : 'Invia messaggio'}
                  </button>
                </form>
              )}
            </div>
          </div>
        </div>
      </main>
    </>
  );
}
