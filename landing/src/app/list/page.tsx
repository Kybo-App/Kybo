'use client';

import React, { useEffect, useState, Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import Link from 'next/link';
import styles from './list.module.css';

interface SharedList {
  items: string[];
  title: string;
}

const CATEGORY_ICONS: Record<string, string> = {
  'Frutta & Verdura': '🥦',
  'Carne & Pesce': '🥩',
  'Latticini & Uova': '🥛',
  'Cereali & Pane': '🍞',
  'Legumi': '🫘',
  'Condimenti & Oli': '🫙',
  'Surgelati': '🧊',
  'Bevande': '🥤',
  'Snack & Dolci': '🍫',
  'Igiene & Casa': '🧹',
  'Altro': '🛒',
};

function groupByCategory(items: string[]): Record<string, string[]> {
  const groups: Record<string, string[]> = {};
  for (const raw of items) {
    const checked = raw.startsWith('OK_');
    const name = checked ? raw.slice(3) : raw;
    // Simple client-side grouping by keyword
    let cat = 'Altro';
    const lower = name.toLowerCase();
    if (/mela|pera|banana|arancia|pomodor|insalata|spinaci|broccol|carota|zucch|melanz|cipolla|aglio|patata|frutta|verdura|peperone/.test(lower)) cat = 'Frutta & Verdura';
    else if (/pollo|manzo|salmone|tonno|pesce|carne|bresaola|prosciutto|salsiccia|gamberi/.test(lower)) cat = 'Carne & Pesce';
    else if (/latte|yogurt|formaggio|mozzarella|ricotta|parmigiano|burro|uovo|uova|panna/.test(lower)) cat = 'Latticini & Uova';
    else if (/pane|pasta|riso|farro|quinoa|avena|farina|crackers|grissini|cereali/.test(lower)) cat = 'Cereali & Pane';
    else if (/fagioli|ceci|lenticchie|piselli|soia|tofu|fave/.test(lower)) cat = 'Legumi';
    else if (/olio|aceto|sale|pepe|salsa|spezie|erbe|origano|basilico/.test(lower)) cat = 'Condimenti & Oli';
    else if (/surgelat|gelato|congelat/.test(lower)) cat = 'Surgelati';
    else if (/acqua|succo|vino|birra|latte|bevanda|tea|caff/.test(lower)) cat = 'Bevande';
    else if (/biscotti|cioccolato|caramelle|snack|patatine|torta/.test(lower)) cat = 'Snack & Dolci';
    else if (/detersivo|sapone|shampoo|carta igienica|spazzolino/.test(lower)) cat = 'Igiene & Casa';

    if (!groups[cat]) groups[cat] = [];
    groups[cat].push(raw);
  }
  return groups;
}

function SharedListContent() {
  const params = useSearchParams();
  const id = params.get('id');
  const isDev = params.get('dev') === '1';
  const apiBase = isDev ? 'https://kybo-test.onrender.com' : 'https://kybo-prod.onrender.com';

  const [data, setData] = useState<SharedList | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [checked, setChecked] = useState<Set<number>>(new Set());

  useEffect(() => {
    if (!id) {
      setError('Link non valido. Manca il parametro ID.');
      setLoading(false);
      return;
    }
    if (!/^[A-Za-z0-9_-]{6,20}$/.test(id)) {
      setError('ID lista non valido.');
      setLoading(false);
      return;
    }

    fetch(`${apiBase}/shopping-list/share/${id}`)
      .then(async (res) => {
        if (res.status === 410) throw new Error('Link scaduto. Chiedi un nuovo link a chi te lo ha inviato.');
        if (!res.ok) throw new Error('Lista non trovata o link scaduto.');
        return res.json();
      })
      .then((json) => {
        setData(json as SharedList);
        setLoading(false);
      })
      .catch((err: Error) => {
        setError(err.message);
        setLoading(false);
      });
  }, [id, apiBase]);

  function toggleItem(idx: number) {
    setChecked((prev) => {
      const next = new Set(prev);
      if (next.has(idx)) next.delete(idx);
      else next.add(idx);
      return next;
    });
  }

  const totalItems = data?.items.length ?? 0;
  const doneItems = checked.size;

  if (loading) {
    return (
      <div className={styles.center}>
        <div className={styles.spinner} />
        <p className={styles.loadingText}>Caricamento lista…</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className={styles.center}>
        <span className={styles.errorIcon}>😕</span>
        <h2 className={styles.errorTitle}>Ops!</h2>
        <p className={styles.errorText}>{error}</p>
        <Link href="/" className={styles.homeBtn}>Vai su Kybo</Link>
      </div>
    );
  }

  const groups = groupByCategory(data!.items);

  return (
    <div className={styles.page}>
      {/* Header */}
      <header className={styles.header}>
        <Link href="/" className={styles.logo}>
          <span className={styles.logoIcon}>🥗</span>
          <span className={styles.logoText}>Kybo</span>
        </Link>
        <div className={styles.progress}>
          <span>{doneItems}/{totalItems}</span>
          <div className={styles.progressBar}>
            <div
              className={styles.progressFill}
              style={{ width: `${totalItems > 0 ? (doneItems / totalItems) * 100 : 0}%` }}
            />
          </div>
        </div>
      </header>

      {/* Title */}
      <div className={styles.titleSection}>
        <h1 className={styles.title}>{data!.title}</h1>
        <p className={styles.subtitle}>{totalItems} articoli · condiviso via Kybo</p>
      </div>

      {/* Items by category */}
      <main className={styles.main}>
        {Object.entries(groups).map(([cat, catItems]) => (
          <div key={cat} className={styles.category}>
            <h2 className={styles.catTitle}>
              <span>{CATEGORY_ICONS[cat] ?? '🛒'}</span>
              {cat}
            </h2>
            <div className={styles.items}>
              {catItems.map((raw, i) => {
                const isOk = raw.startsWith('OK_');
                const name = isOk ? raw.slice(3) : raw;
                const globalIdx = data!.items.indexOf(raw);
                const done = checked.has(globalIdx) || isOk;
                return (
                  <button
                    key={i}
                    className={`${styles.item} ${done ? styles.itemDone : ''}`}
                    onClick={() => toggleItem(globalIdx)}
                    aria-checked={done}
                    role="checkbox"
                  >
                    <span className={styles.check}>{done ? '✓' : ''}</span>
                    <span className={styles.itemName}>{name}</span>
                  </button>
                );
              })}
            </div>
          </div>
        ))}
      </main>

      {/* CTA */}
      <div className={styles.cta}>
        <p className={styles.ctaText}>Vuoi gestire la tua dieta e la lista spesa?</p>
        <Link href="/" className={styles.ctaBtn}>
          Scopri Kybo →
        </Link>
        {/* Deep link: apre Kybo se installato */}
        {id && (
          <a
            href={`kybo://list?id=${id}`}
            className={styles.openAppBtn}
          >
            📱 Apri in Kybo
          </a>
        )}
      </div>
    </div>
  );
}

export default function SharedListPage() {
  return (
    <Suspense fallback={
      <div style={{ minHeight: '100vh', background: '#0f0f0f', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div style={{ color: 'rgba(255,255,255,0.5)', fontSize: '1rem' }}>Caricamento…</div>
      </div>
    }>
      <SharedListContent />
    </Suspense>
  );
}
