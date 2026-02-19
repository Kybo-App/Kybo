'use client';

import React, { useState, useEffect, useRef } from 'react';
import styles from './AppMockup.module.css';

type Screen = 'home' | 'diet' | 'shopping' | 'chat' | 'stats';

interface MockupScreen {
  id: Screen;
  label: string;
  icon: string;
}

const screens: MockupScreen[] = [
  { id: 'home', label: 'Home', icon: '🏠' },
  { id: 'diet', label: 'Piano', icon: '🥗' },
  { id: 'shopping', label: 'Lista', icon: '🛒' },
  { id: 'chat', label: 'Chat', icon: '💬' },
  { id: 'stats', label: 'Stats', icon: '📊' },
];

const screenContent: Record<Screen, React.ReactNode> = {
  home: (
    <div className={styles.screenHome}>
      <div className={styles.homeHeader}>
        <div className={styles.homeGreeting}>
          <span className={styles.homeEmoji}>👋</span>
          <div>
            <p className={styles.homeHello}>Ciao, Marco!</p>
            <p className={styles.homeDate}>Lunedì, 17 Feb</p>
          </div>
        </div>
        <div className={styles.homeAvatar}>M</div>
      </div>

      <div className={styles.nextMealBanner}>
        <span>🍽️</span>
        <div>
          <p className={styles.nextMealLabel}>Prossimo pasto: Pranzo</p>
          <p className={styles.nextMealItems}>Riso integrale, Pollo, Verdure</p>
        </div>
      </div>

      <div className={styles.statsRow}>
        <div className={styles.statChip}>
          <span className={styles.statNum}>1.840</span>
          <span className={styles.statLbl}>kcal oggi</span>
        </div>
        <div className={styles.statChip}>
          <span className={styles.statNum}>5/7</span>
          <span className={styles.statLbl}>giorni streak</span>
        </div>
        <div className={styles.statChip}>
          <span className={styles.statNum}>🏆</span>
          <span className={styles.statLbl}>3 badge</span>
        </div>
      </div>

      <p className={styles.sectionLabel}>Piano di oggi</p>
      {[
        { meal: 'Colazione', items: 'Yogurt greco, Frutta, Caffè', done: true },
        { meal: 'Pranzo', items: 'Riso integrale, Pollo', done: false },
        { meal: 'Cena', items: 'Salmone, Patate, Insalata', done: false },
      ].map((m) => (
        <div key={m.meal} className={`${styles.mealCard} ${m.done ? styles.mealDone : ''}`}>
          <div className={styles.mealIcon}>{m.done ? '✅' : '⏳'}</div>
          <div>
            <p className={styles.mealName}>{m.meal}</p>
            <p className={styles.mealItems}>{m.items}</p>
          </div>
        </div>
      ))}
    </div>
  ),

  diet: (
    <div className={styles.screenDiet}>
      <p className={styles.screenTitle}>Piano Alimentare</p>
      <div className={styles.dayTabs}>
        {['Lun', 'Mar', 'Mer', 'Gio', 'Ven'].map((d, i) => (
          <div key={d} className={`${styles.dayTab} ${i === 0 ? styles.dayActive : ''}`}>{d}</div>
        ))}
      </div>
      {[
        { meal: 'Colazione', kcal: 320, items: ['Yogurt greco 150g', 'Mela 1 pz', 'Caffè'] },
        { meal: 'Pranzo', kcal: 580, items: ['Riso integrale 80g', 'Petto di pollo 150g', 'Verdure miste'] },
        { meal: 'Merenda', kcal: 150, items: ['Mandorle 30g'] },
        { meal: 'Cena', kcal: 510, items: ['Salmone 180g', 'Patate al forno 200g', 'Insalata'] },
      ].map((m) => (
        <div key={m.meal} className={styles.dietCard}>
          <div className={styles.dietCardHeader}>
            <span className={styles.dietMealName}>{m.meal}</span>
            <span className={styles.dietKcal}>{m.kcal} kcal</span>
          </div>
          {m.items.map((item) => (
            <div key={item} className={styles.dietItem}>
              <span className={styles.dietDot}>•</span>
              <span>{item}</span>
            </div>
          ))}
        </div>
      ))}
    </div>
  ),

  shopping: (
    <div className={styles.screenShopping}>
      <p className={styles.screenTitle}>Lista della Spesa</p>
      <div className={styles.shopActions}>
        <button className={styles.shopBtn}>📤 Condividi</button>
        <button className={styles.shopBtn}>📁 Raggruppa</button>
      </div>
      {[
        { cat: '🥩 Carne & Pesce', items: ['Petto di pollo 500g', 'Salmone 360g'] },
        { cat: '🥦 Frutta & Verdura', items: ['Mele 4 pz', 'Insalata mista', 'Patate 1kg', 'Verdure miste'] },
        { cat: '🌾 Cereali', items: ['Riso integrale 500g'] },
        { cat: '🥛 Latticini', items: ['Yogurt greco 6x150g', 'Mandorle 200g'] },
      ].map((cat) => (
        <div key={cat.cat} className={styles.shopCat}>
          <p className={styles.shopCatLabel}>{cat.cat}</p>
          {cat.items.map((item) => (
            <div key={item} className={styles.shopItem}>
              <div className={styles.shopCheck} />
              <span>{item}</span>
            </div>
          ))}
        </div>
      ))}
    </div>
  ),

  chat: (
    <div className={styles.screenChat}>
      <div className={styles.chatHeader}>
        <div className={styles.chatAvatar}>N</div>
        <div>
          <p className={styles.chatName}>Dott.ssa Rossi</p>
          <p className={styles.chatOnline}>● Online</p>
        </div>
      </div>
      <div className={styles.chatMessages}>
        <div className={`${styles.chatMsg} ${styles.chatMsgIn}`}>
          <p>Ciao Marco! Come stai andando con il piano questa settimana? 😊</p>
          <span className={styles.chatTime}>10:30</span>
        </div>
        <div className={`${styles.chatMsg} ${styles.chatMsgOut}`}>
          <p>Bene! Ho rispettato quasi tutti i pasti. La cena di mercoledì è stata difficile.</p>
          <span className={styles.chatTime}>10:35</span>
        </div>
        <div className={`${styles.chatMsg} ${styles.chatMsgIn}`}>
          <p>Ottimo progresso! Per la cena puoi sostituire il salmone con il merluzzo se preferisci 🐟</p>
          <span className={styles.chatTime}>10:38</span>
        </div>
        <div className={`${styles.chatMsg} ${styles.chatMsgOut}`}>
          <p>Perfetto, grazie! 🙏</p>
          <span className={styles.chatTime}>10:40</span>
        </div>
      </div>
      <div className={styles.chatInput}>
        <input placeholder="Scrivi un messaggio..." readOnly className={styles.chatInputField} />
        <button className={styles.chatSend}>➤</button>
      </div>
    </div>
  ),

  stats: (
    <div className={styles.screenStats}>
      <p className={styles.screenTitle}>Statistiche</p>
      <div className={styles.weightCard}>
        <p className={styles.weightLabel}>Peso attuale</p>
        <p className={styles.weightValue}>78.4 <span>kg</span></p>
        <p className={styles.weightDelta}>↓ 1.6 kg questo mese</p>
      </div>
      <p className={styles.sectionLabel}>Aderenza piano (ultimi 7 giorni)</p>
      <div className={styles.barsChart}>
        {[85, 100, 70, 90, 100, 60, 80].map((v, i) => (
          <div key={i} className={styles.barWrapper}>
            <div className={styles.bar} style={{ height: `${v}%` }} />
            <span className={styles.barLabel}>{['L', 'M', 'M', 'G', 'V', 'S', 'D'][i]}</span>
          </div>
        ))}
      </div>
      <div className={styles.badgesRow}>
        <p className={styles.sectionLabel}>Badge sbloccati</p>
        <div className={styles.badges}>
          {['🏆', '🔥', '🥗', '⭐'].map((b, i) => (
            <div key={i} className={styles.badge}>{b}</div>
          ))}
        </div>
      </div>
    </div>
  ),
};

export default function AppMockup() {
  const [activeScreen, setActiveScreen] = useState<Screen>('home');
  const [animating, setAnimating] = useState(false);
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
            opacity: 1,
            y: 0,
            duration: 0.8,
            ease: 'power3.out',
            scrollTrigger: {
              trigger: sectionRef.current,
              start: 'top 80%',
              once: true,
            },
          }
        );
      }
    };
    initGsap();
  }, []);

  const handleScreenChange = (screen: Screen) => {
    if (screen === activeScreen || animating) return;
    setAnimating(true);
    setTimeout(() => {
      setActiveScreen(screen);
      setAnimating(false);
    }, 200);
  };

  return (
    <section className={styles.section} ref={sectionRef}>
      <div className={styles.container}>
        <div className={styles.textSide}>
          <span className={styles.eyebrow}>App Mobile</span>
          <h2 className={styles.heading}>
            Tutto quello che ti serve,<br />
            <span className={styles.highlight}>sempre con te</span>
          </h2>
          <p className={styles.subtext}>
            L'app Kybo accompagna il paziente ogni giorno: piani alimentari interattivi,
            lista della spesa automatica, chat diretta con il nutrizionista e statistiche in tempo reale.
          </p>
          <div className={styles.featureList}>
            {[
              { icon: '🥗', text: 'Piano alimentare settimanale interattivo' },
              { icon: '🛒', text: 'Lista spesa generata automaticamente' },
              { icon: '💬', text: 'Chat diretta con il nutrizionista' },
              { icon: '📊', text: 'Statistiche e grafici progresso' },
              { icon: '🏆', text: 'Badge e sfide gamification' },
            ].map((f) => (
              <div key={f.text} className={styles.featureItem}>
                <span className={styles.featureIcon}>{f.icon}</span>
                <span>{f.text}</span>
              </div>
            ))}
          </div>
        </div>

        <div className={styles.phoneSide}>
          {/* Phone frame */}
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

              {/* Screen content */}
              <div className={`${styles.screenContent} ${animating ? styles.fadeOut : styles.fadeIn}`}>
                {screenContent[activeScreen]}
              </div>

              {/* Bottom nav */}
              <div className={styles.bottomNav}>
                {screens.map((s) => (
                  <button
                    key={s.id}
                    className={`${styles.navBtn} ${activeScreen === s.id ? styles.navBtnActive : ''}`}
                    onClick={() => handleScreenChange(s.id)}
                  >
                    <span className={styles.navIcon}>{s.icon}</span>
                    <span className={styles.navLabel}>{s.label}</span>
                  </button>
                ))}
              </div>
            </div>
            <div className={styles.phoneHome} />
          </div>

          {/* Floating chips */}
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
