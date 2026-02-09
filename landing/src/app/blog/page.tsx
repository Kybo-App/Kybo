'use client';

import Link from 'next/link';
import Image from 'next/image';
import styles from '../shared.module.css';

const blogPosts = [
  {
    id: 1,
    tag: 'Nutrizione',
    title: 'Come iniziare un percorso di alimentazione consapevole',
    excerpt: 'Scopri i primi passi per migliorare la tua alimentazione quotidiana con consigli pratici e strategie efficaci per un cambiamento duraturo.',
    date: '15 Gen 2025',
    color: '#66BB6A',
  },
  {
    id: 2,
    tag: 'Tecnologia',
    title: 'Il futuro del food tracking: AI e nutrizione personalizzata',
    excerpt: 'Come l\'intelligenza artificiale sta rivoluzionando il modo in cui monitoriamo e ottimizziamo la nostra alimentazione.',
    date: '8 Gen 2025',
    color: '#3B82F6',
  },
  {
    id: 3,
    tag: 'Aggiornamenti',
    title: 'Kybo 2.0: nuove funzionalità e interfaccia rinnovata',
    excerpt: 'Scopri tutte le novità dell\'ultimo aggiornamento: dashboard migliorata, nuovi report e molto altro.',
    date: '2 Gen 2025',
    color: '#8B5CF6',
  },
  {
    id: 4,
    tag: 'Salute',
    title: 'L\'importanza dei macronutrienti nel piano alimentare',
    excerpt: 'Proteine, carboidrati e grassi: come bilanciare correttamente i macronutrienti per raggiungere i tuoi obiettivi.',
    date: '28 Dic 2024',
    color: '#FFA726',
  },
  {
    id: 5,
    tag: 'Per Professionisti',
    title: 'Gestire i pazienti in modo efficiente con Kybo Business',
    excerpt: 'Una guida completa per nutrizionisti su come sfruttare al meglio la dashboard professionale di Kybo.',
    date: '20 Dic 2024',
    color: '#E53935',
  },
  {
    id: 6,
    tag: 'Ricette',
    title: '5 ricette sane e veloci per la settimana lavorativa',
    excerpt: 'Meal prep fatto bene: ricette bilanciate che puoi preparare in anticipo per tutta la settimana.',
    date: '15 Dic 2024',
    color: '#66BB6A',
  },
];

export default function BlogPage() {
  return (
    <div className={styles.pageWrapper}>
      {/* Navbar */}
      <nav className={styles.nav}>
        <div className={styles.navContainer}>
          <Link href="/" className={styles.logo}>
            <Image src="/logo no bg.png" alt="Kybo" width={32} height={32} className={styles.logoIcon} priority />
            <span className={styles.logoText}>Kybo</span>
          </Link>
          <Link href="/" className={styles.backBtn}>
            ← Torna alla Home
          </Link>
        </div>
      </nav>

      {/* Hero */}
      <div className={styles.heroSmall}>
        <h1 className={styles.pageTitle}>Blog</h1>
        <p className={styles.pageSubtitle}>
          Articoli, consigli e novità dal mondo della nutrizione e della tecnologia.
        </p>
      </div>

      {/* Blog Posts */}
      <section className={styles.section}>
        <div className={styles.container}>
          <div className={styles.blogGrid}>
            {blogPosts.map((post) => (
              <article key={post.id} className={styles.blogCard}>
                <div style={{
                  width: '100%',
                  height: '200px',
                  background: `linear-gradient(135deg, ${post.color}22 0%, ${post.color}44 100%)`,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}>
                  <span style={{ fontSize: '3rem', opacity: 0.5 }}>📝</span>
                </div>
                <div className={styles.blogContent}>
                  <span className={styles.blogTag}>{post.tag}</span>
                  <h3 className={styles.blogTitle}>{post.title}</h3>
                  <p className={styles.blogExcerpt}>{post.excerpt}</p>
                  <span className={styles.blogDate}>{post.date}</span>
                </div>
              </article>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className={styles.ctaBanner}>
        <h2 className={styles.ctaTitle}>Resta aggiornato</h2>
        <p className={styles.ctaText}>Segui il nostro blog per le ultime novità su nutrizione e Kybo.</p>
        <Link href="/" className={styles.ctaBtn}>Scopri Kybo</Link>
      </section>

      {/* Footer */}
      <footer className={styles.footer}>
        <p className={styles.footerText}>© 2025 Kybo. Tutti i diritti riservati.</p>
      </footer>
    </div>
  );
}
