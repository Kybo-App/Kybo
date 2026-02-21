'use client';

import React, { useState, useEffect, useRef } from 'react';
import styles from './AppMockup.module.css';

type NavTab  = 'diet' | 'pantry' | 'shopping';
type Screen  = NavTab | 'chat' | 'ai';

/* ─── PIANO ALIMENTARE ─────────────────────────────────────────────────────── */
const ScreenDiet = ({ s }: { s: typeof styles }) => (
  <div className={s.screenDiet}>
    {/* Day tabs */}
    <div className={s.dayTabs}>
      {['LUN','MAR','MER','GIO','VEN'].map((d, i) => (
        <div key={d} className={`${s.dayTab} ${i === 2 ? s.dayActive : ''}`}>{d}</div>
      ))}
    </div>

    {/* Next meal banner */}
    <div className={s.nextMealBanner}>
      <span className={s.nextMealIcon}>🍽️</span>
      <div>
        <p className={s.nextMealLabel}>Prossimo pasto: Cena</p>
        <p className={s.nextMealItems}>Salmone · Patate · Insalata</p>
      </div>
    </div>

    {/* Meal cards */}
    {[
      { icon: '☀️', name: 'Colazione', kcal: 350, done: true,
        ingredients: [['Yogurt greco','150 g'],['Mela','1 pz'],['Caffè','—']] },
      { icon: '🌞', name: 'Pranzo', kcal: 580, done: true,
        ingredients: [['Petto di pollo','150 g'],['Riso integrale','80 g'],['Zucchine','200 g']] },
      { icon: '🌙', name: 'Cena', kcal: 510, done: false,
        ingredients: [['Salmone','180 g'],['Patate al forno','200 g'],['Insalata','q.b.']] },
    ].map((m) => (
      <div key={m.name} className={`${s.mealCard} ${m.done ? s.mealCardDone : ''}`}>
        <div className={s.mealCardHeader}>
          <span className={s.mealIcon}>{m.icon}</span>
          <span className={s.mealName}>{m.name}</span>
          <span className={s.mealKcal}>{m.kcal} kcal</span>
        </div>
        <div className={s.mealIngredients}>
          {m.ingredients.map(([name, qty]) => (
            <div key={name} className={s.mealIngRow}>
              <span className={s.mealIngName}>{name}</span>
              <span className={s.mealIngQty}>{qty}</span>
            </div>
          ))}
        </div>
        <div className={m.done ? s.mealConsumedDone : s.mealConsumedPending}>
          {m.done ? '✓ Consumato' : '○ Segna come consumato'}
        </div>
      </div>
    ))}
  </div>
);

/* ─── DISPENSA ─────────────────────────────────────────────────────────────── */
const ScreenPantry = ({ s }: { s: typeof styles }) => (
  <div className={s.screenPantry}>
    <div className={s.pantryAddRow}>
      <div className={s.pantryInput}>Aggiungi alimento...</div>
      <div className={s.pantryAddBtn}>+</div>
    </div>

    {[
      { name: 'Petto di pollo', qty: '300 g' },
      { name: 'Zucchine',       qty: '200 g' },
      { name: 'Pomodori',       qty: '150 g' },
      { name: 'Olio evo',       qty: '5 cucch.' },
      { name: 'Parmigiano',     qty: '30 g' },
    ].map((item) => (
      <div key={item.name} className={s.pantryItem}>
        <div className={s.pantryItemDot} />
        <span className={s.pantryItemName}>{item.name}</span>
        <span className={s.pantryItemQty}>{item.qty}</span>
      </div>
    ))}

    <div className={s.pantryFab}>📷 Scansiona scontrino</div>
  </div>
);

/* ─── LISTA SPESA ──────────────────────────────────────────────────────────── */
const ScreenShopping = ({ s }: { s: typeof styles }) => (
  <div className={s.screenShopping}>
    <div className={s.budgetBanner}>
      <div className={s.budgetRow}>
        <span className={s.budgetLabel}>💰 Spesa stimata</span>
        <span className={s.budgetValue}>€ 42,50 <span className={s.budgetOf}>/ €80</span></span>
      </div>
      <div className={s.budgetBarTrack}>
        <div className={s.budgetBarFill} />
      </div>
    </div>

    <div className={s.shopActions}>
      <button className={s.shopBtn}>📤 Condividi</button>
      <button className={`${s.shopBtn} ${s.shopBtnActive}`}>📁 Raggruppato</button>
    </div>

    {[
      { cat: '🥩 Carne & Pesce', items: [
        { name: 'Petto di pollo 450g', done: false },
        { name: 'Salmone 360g',        done: true  },
      ]},
      { cat: '🥦 Frutta & Verdura', items: [
        { name: 'Zucchine 400g',  done: false },
        { name: 'Pomodori 300g',  done: false },
        { name: 'Mele 4 pz',      done: true  },
      ]},
      { cat: '🌾 Cereali & Pane', items: [
        { name: 'Riso integrale 400g', done: false },
      ]},
    ].map((cat) => (
      <div key={cat.cat} className={s.shopCat}>
        <p className={s.shopCatLabel}>{cat.cat}</p>
        {cat.items.map((item) => (
          <div key={item.name} className={`${s.shopItem} ${item.done ? s.shopItemDone : ''}`}>
            <div className={`${s.shopCheck} ${item.done ? s.shopCheckDone : ''}`}>
              {item.done && <span>✓</span>}
            </div>
            <span>{item.name}</span>
          </div>
        ))}
      </div>
    ))}
  </div>
);

/* ─── CHAT ─────────────────────────────────────────────────────────────────── */
const ScreenChat = ({ s }: { s: typeof styles }) => (
  <div className={s.screenChat}>
    <div className={s.chatMessages}>
      <div className={`${s.chatMsg} ${s.chatMsgIn}`}>
        <p>Ciao! Come stai andando con il piano questa settimana? 😊</p>
        <span className={s.chatTime}>10:30</span>
      </div>
      <div className={`${s.chatMsg} ${s.chatMsgOut}`}>
        <p>Bene! Ho rispettato quasi tutti i pasti. La cena di mercoledì è stata difficile.</p>
        <span className={s.chatTime}>10:35</span>
      </div>
      <div className={`${s.chatMsg} ${s.chatMsgIn}`}>
        <p>Ottimo! Puoi sostituire il salmone con il merluzzo se preferisci 🐟</p>
        <span className={s.chatTime}>10:38</span>
      </div>
      <div className={`${s.chatMsg} ${s.chatMsgOut}`}>
        <p>Perfetto, grazie! 🙏</p>
        <span className={s.chatTime}>10:40</span>
      </div>
    </div>
    <div className={s.chatInput}>
      <input placeholder="Scrivi un messaggio..." readOnly className={s.chatInputField} />
      <button className={s.chatSend}>➤</button>
    </div>
  </div>
);

/* ─── SUGGERIMENTI AI ──────────────────────────────────────────────────────── */
const ScreenAI = ({ s }: { s: typeof styles }) => (
  <div className={s.screenAI}>
    <div className={s.aiFilters}>
      {['Tutti','Pranzo','Cena','Vegano'].map((f, i) => (
        <div key={f} className={`${s.aiFilter} ${i === 0 ? s.aiFilterActive : ''}`}>{f}</div>
      ))}
    </div>

    {[
      { name: 'Salmone al Limone con Asparagi', time: '20 min', kcal: '480 kcal', meal: 'Cena',
        grad: 'linear-gradient(135deg,#0d2b1a,#1a4a2a)' },
      { name: 'Pollo Grigliato con Zucchine', time: '25 min', kcal: '520 kcal', meal: 'Pranzo',
        grad: 'linear-gradient(135deg,#1a2b0d,#2a4a1a)' },
      { name: 'Insalata di Ceci e Verdure', time: '10 min', kcal: '380 kcal', meal: 'Pranzo',
        grad: 'linear-gradient(135deg,#1a1a0d,#3a3a1a)' },
    ].map((r) => (
      <div key={r.name} className={s.aiCard}>
        <div className={s.aiCardImage} style={{ background: r.grad }}>
          <span className={s.aiCardMealBadge}>{r.meal}</span>
          <span className={s.aiCardEmoji}>🍽️</span>
        </div>
        <div className={s.aiCardBody}>
          <p className={s.aiCardName}>{r.name}</p>
          <div className={s.aiCardMeta}>
            <span>⏱ {r.time}</span>
            <span>🔥 {r.kcal}</span>
          </div>
          <div className={s.aiCardBtn}>Vedi ricetta →</div>
        </div>
      </div>
    ))}
  </div>
);

/* ─── MAIN COMPONENT ───────────────────────────────────────────────────────── */

const navTabs = [
  { id: 'pantry'   as NavTab, label: 'Dispensa', icon: '🥘' },
  { id: 'diet'     as NavTab, label: 'Piano',    icon: '📅' },
  { id: 'shopping' as NavTab, label: 'Lista',    icon: '🛒' },
];

export default function AppMockup() {
  const [activeNav,    setActiveNav]    = useState<NavTab>('diet');
  const [activeScreen, setActiveScreen] = useState<Screen>('diet');
  const [animating,    setAnimating]    = useState(false);
  const sectionRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const initGsap = async () => {
      const { gsap } = await import('gsap');
      const { ScrollTrigger } = await import('gsap/ScrollTrigger');
      gsap.registerPlugin(ScrollTrigger);
      if (sectionRef.current) {
        gsap.fromTo(
          sectionRef.current,
          { opacity: 0, y: 60 },
          {
            opacity: 1, y: 0, duration: 0.8, ease: 'power3.out',
            scrollTrigger: { trigger: sectionRef.current, start: 'top 80%', once: true },
          }
        );
      }
    };
    initGsap();
  }, []);

  const go = (screen: Screen) => {
    if (screen === activeScreen || animating) return;
    setAnimating(true);
    setTimeout(() => { setActiveScreen(screen); setAnimating(false); }, 200);
  };

  const goNav = (tab: NavTab) => {
    setActiveNav(tab);
    go(tab);
  };

  const goBack = () => go(activeNav);

  const isDetail = activeScreen === 'chat' || activeScreen === 'ai';

  /* ── AppBar content ── */
  const renderAppBar = () => {
    if (activeScreen === 'chat') {
      return (
        <div className={styles.appBar}>
          <button className={styles.appBarBack} onClick={goBack}>←</button>
          <div className={styles.appBarChatInfo}>
            <div className={styles.appBarChatAvatar}>R</div>
            <div>
              <p className={styles.appBarChatName}>Dott.ssa Rossi</p>
              <p className={styles.appBarChatOnline}>● Online</p>
            </div>
          </div>
          <div className={styles.appBarSpacer} />
        </div>
      );
    }
    if (activeScreen === 'ai') {
      return (
        <div className={styles.appBar}>
          <button className={styles.appBarBack} onClick={goBack}>←</button>
          <span className={styles.appBarTitle}>✨ Suggerimenti AI</span>
          <div className={styles.appBarSpacer} />
        </div>
      );
    }
    /* Main screens */
    return (
      <div className={styles.appBar}>
        <span className={styles.appBarMenu}>≡</span>
        <span className={styles.appBarTitle}>Kybo</span>
        <div className={styles.appBarActions}>
          <button className={styles.appBarIconBtn} onClick={() => go('chat')} title="Chat">
            💬
          </button>
          <button className={styles.appBarIconBtn} onClick={() => go('ai')} title="Suggerimenti AI">
            ✨
          </button>
          <span className={styles.appBarLeaf}>🌿</span>
        </div>
      </div>
    );
  };

  const renderScreen = () => {
    switch (activeScreen) {
      case 'diet':     return <ScreenDiet     s={styles} />;
      case 'pantry':   return <ScreenPantry   s={styles} />;
      case 'shopping': return <ScreenShopping s={styles} />;
      case 'chat':     return <ScreenChat     s={styles} />;
      case 'ai':       return <ScreenAI       s={styles} />;
    }
  };

  return (
    <section id="gallery" className={styles.section} ref={sectionRef}>
      <div className={styles.container}>
        <div className={styles.textSide}>
          <span className={styles.eyebrow}>App Mobile</span>
          <h2 className={styles.heading}>
            Tutto quello che ti serve,<br />
            <span className={styles.highlight}>sempre con te</span>
          </h2>
          <p className={styles.subtext}>
            L&apos;app Kybo accompagna il paziente ogni giorno: piani alimentari interattivi,
            lista della spesa automatica, chat diretta con il nutrizionista e suggerimenti AI personalizzati.
          </p>
          <div className={styles.featureList}>
            {[
              { icon: '📅', text: 'Piano alimentare settimanale interattivo' },
              { icon: '🥘', text: 'Dispensa smart con scanner scontrino' },
              { icon: '🛒', text: 'Lista spesa con budget e categorie' },
              { icon: '💬', text: 'Chat diretta con il nutrizionista' },
              { icon: '✨', text: 'Ricette AI dalla tua dispensa' },
            ].map((f) => (
              <div key={f.text} className={styles.featureItem}>
                <span className={styles.featureIcon}>{f.icon}</span>
                <span>{f.text}</span>
              </div>
            ))}
          </div>
        </div>

        <div className={styles.phoneSide}>
          <div className={styles.phone}>
            <div className={styles.phoneSpeaker} />
            <div className={styles.phoneScreen}>

              {/* Status bar */}
              <div className={styles.statusBar}>
                <span>9:41</span>
                <div className={styles.statusIcons}>
                  <span>●●●</span>
                  <span>WiFi</span>
                  <span>🔋</span>
                </div>
              </div>

              {/* AppBar — always visible, content varies per screen */}
              {renderAppBar()}

              {/* Screen content */}
              <div className={`${styles.screenContent} ${animating ? styles.fadeOut : styles.fadeIn}`}>
                {renderScreen()}
              </div>

              {/* Bottom nav — 3 tabs matching real app, hidden on detail screens */}
              <div className={`${styles.bottomNav} ${isDetail ? styles.bottomNavHidden : ''}`}>
                {navTabs.map((t) => (
                  <button
                    key={t.id}
                    className={`${styles.navBtn} ${activeNav === t.id && !isDetail ? styles.navBtnActive : ''}`}
                    onClick={() => goNav(t.id)}
                  >
                    <span className={styles.navIcon}>{t.icon}</span>
                    <span className={styles.navLabel}>{t.label}</span>
                  </button>
                ))}
              </div>
            </div>
            <div className={styles.phoneHome} />
          </div>

          <div className={`${styles.chip} ${styles.chip1}`}>
            <span>✅</span> Piano rispettato!
          </div>
          <div className={`${styles.chip} ${styles.chip2}`}>
            <span>🔔</span> Ora della Cena
          </div>
          <div className={`${styles.chip} ${styles.chip3}`}>
            <span>🏆</span> Nuovo badge!
          </div>
        </div>
      </div>
    </section>
  );
}
