'use client';

export default function NotFound() {
  return (
    <div style={{
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      minHeight: '60vh',
      textAlign: 'center',
      padding: '2rem',
    }}>
      <h1 style={{ fontSize: '4rem', marginBottom: '1rem', color: 'var(--color-text)' }}>404</h1>
      <h2 style={{ fontSize: '1.5rem', marginBottom: '1rem', color: 'var(--color-text)' }}>Pagina non trovata</h2>
      <p style={{ marginBottom: '2rem', color: 'var(--color-text-muted)' }}>
        La pagina che stai cercando non esiste.
      </p>
      <a
        href="/"
        style={{
          padding: '0.75rem 1.75rem',
          borderRadius: '100px',
          backgroundColor: '#2E7D32',
          color: 'white',
          textDecoration: 'none',
          fontWeight: 600,
          display: 'inline-block',
        }}
      >
        Torna alla Home
      </a>
    </div>
  );
}
