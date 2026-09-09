'use client';

import React, { useState } from 'react';
import { motion, useReducedMotion } from 'motion/react';
import type { MockupContent, MockupScreen } from '@/content/types';
import { AppIcon, type AppIconKey } from '@/components/icons/AppIcons';
import styles from './AppMockup.module.css';

/*
  Ricostruzione web delle schermate reali dell'app Flutter.

  Riferimenti in client/lib:
    - diet_view.dart          → selettore porzioni, tab dei giorni, card dei pasti
    - shopping_list_view.dart → banner budget, checkbox con barrato
    - pantry_view.dart        → header, riga di aggiunta, tile con icona tonda, FAB scanner
    - home_screen.dart        → app bar (menu / swap / spa), drawer, bottom nav a 3 voci

  I colori vengono da KyboColors in client/lib/widgets/design_system.dart,
  variante scura (background #0F172A, surface #1E293B, primary #2E7D32).
*/

const TABS: Array<{ key: MockupScreen; icon: AppIconKey }> = [
  { key: 'pantry', icon: 'kitchen' },
  { key: 'diet', icon: 'calendar' },
  { key: 'shopping', icon: 'cart' },
];

export default function AppMockup({ content }: { content: MockupContent }) {
  const [screen, setScreen] = useState<MockupScreen>('diet');
  const [menuOpen, setMenuOpen] = useState(false);
  const [portion, setPortion] = useState(0);
  const [day, setDay] = useState(content.diet.activeDayIndex);
  const [checked, setChecked] = useState<Record<number, boolean>>(() =>
    Object.fromEntries(content.shopping.items.map((it, i) => [i, Boolean(it.checked)]))
  );
  const reduced = useReducedMotion();

  /*
    Il cambio schermata sfrutta il remount: cambiando `key` React smonta il
    vecchio contenuto e monta il nuovo, e Motion rigioca initial → animate.
    Basta un fade in ingresso, quindi non serve AnimatePresence.
  */
  const screenMotion = reduced
    ? {}
    : {
        initial: { opacity: 0, y: 8 },
        animate: { opacity: 1, y: 0 },
        transition: { duration: 0.24, ease: [0.16, 1, 0.3, 1] as const },
      };

  return (
    <section id="gallery" className={styles.section}>
      <div className={styles.container}>
        <div className={styles.textSide}>
          <span className={styles.eyebrow}>{content.eyebrow}</span>
          <h2 className={styles.heading}>
            {content.heading}
            <br />
            <span className={styles.highlight}>{content.headingAccent}</span>
          </h2>
          <p className={styles.subtext}>{content.subtext}</p>

          <ul className={styles.bullets}>
            {content.bullets.map((b) => (
              <li key={b}>
                <span className={styles.bulletIcon}>
                  <AppIcon name="check" size={14} />
                </span>
                {b}
              </li>
            ))}
          </ul>

          {/* Selettore fuori dal telefono: dà accesso alle schermate anche da
              tastiera, senza dover colpire i target piccoli della finta UI. */}
          <div className={styles.screenSwitch} role="tablist" aria-label={content.eyebrow}>
            {TABS.map((tab) => (
              <button
                key={tab.key}
                role="tab"
                aria-selected={screen === tab.key}
                className={`${styles.switchBtn} ${screen === tab.key ? styles.switchBtnActive : ''}`}
                onClick={() => {
                  setScreen(tab.key);
                  setMenuOpen(false);
                }}
              >
                <AppIcon name={tab.icon} size={16} />
                {content.screenLabels[tab.key]}
              </button>
            ))}
          </div>
        </div>

        <div className={styles.phoneSide}>
          <div className={styles.phone}>
            <div className={styles.phoneSpeaker} />

            <div className={styles.phoneScreen}>
              <div className={styles.statusBar}>
                <span>9:41</span>
                <span className={styles.statusIcons}>
                  <span className={styles.signal} />
                  <span className={styles.battery} />
                </span>
              </div>

              <div className={styles.appBar}>
                <button
                  className={styles.appBarBtn}
                  onClick={() => setMenuOpen(true)}
                  aria-label={content.appBar.menu}
                >
                  <AppIcon name="menu" size={18} />
                </button>
                <span className={styles.appBarTitle}>{content.appBar.title}</span>
                <div className={styles.appBarActions}>
                  <button className={styles.appBarBtn} aria-label={content.appBar.swapDays}>
                    <AppIcon name="swap" size={17} />
                  </button>
                  <button className={styles.appBarBtn} aria-label={content.appBar.relaxMode}>
                    <AppIcon name="spa" size={17} />
                  </button>
                </div>
              </div>

              <div className={styles.screenBody}>
                <motion.div key={screen} className={styles.screenInner} {...screenMotion}>
                  {screen === 'diet' && (
                    <DietScreen
                      content={content}
                      portion={portion}
                      setPortion={setPortion}
                      day={day}
                      setDay={setDay}
                    />
                  )}
                  {screen === 'shopping' && (
                    <ShoppingScreen
                      content={content}
                      checked={checked}
                      toggle={(i) => setChecked((c) => ({ ...c, [i]: !c[i] }))}
                    />
                  )}
                  {screen === 'pantry' && <PantryScreen content={content} />}
                </motion.div>
              </div>

              {/*
                Drawer: mostra quante funzioni ci sono oltre alle tre schermate.

                Resta sempre montato e si sposta in base a menuOpen, invece di
                essere montato/smontato dentro AnimatePresence. Le voci sono
                <li> non focalizzabili, quindi tenerle nel DOM non aggiunge
                trappole per la tastiera; aria-hidden le nasconde agli screen
                reader quando il pannello è chiuso.
              */}
              <button
                className={styles.scrim}
                data-open={menuOpen}
                aria-label={content.menu.close}
                onClick={() => setMenuOpen(false)}
                tabIndex={menuOpen ? 0 : -1}
                aria-hidden={!menuOpen}
              />
              <nav className={styles.drawer} data-open={menuOpen} aria-hidden={!menuOpen}>
                <div className={styles.drawerHeader}>
                  <span className={styles.drawerAvatar}>M</span>
                  <div>
                    <p className={styles.drawerName}>Marco</p>
                    <p className={styles.drawerMail}>marco@email.it</p>
                  </div>
                </div>
                <ul className={styles.drawerList}>
                  {content.menu.items.map((item) => (
                    <li key={item.label}>
                      <span className={`${styles.drawerIcon} ${styles[item.tone]}`}>
                        <AppIcon name={item.icon as AppIconKey} size={16} />
                      </span>
                      <span className={styles.drawerLabel}>{item.label}</span>
                      {item.badge && <span className={styles.drawerBadge}>{item.badge}</span>}
                    </li>
                  ))}
                </ul>
              </nav>

              <div className={styles.bottomNav}>
                {TABS.map((tab) => (
                  <button
                    key={tab.key}
                    className={`${styles.navBtn} ${screen === tab.key ? styles.navBtnActive : ''}`}
                    onClick={() => {
                      setScreen(tab.key);
                      setMenuOpen(false);
                    }}
                    aria-label={content.screenLabels[tab.key]}
                  >
                    <AppIcon name={tab.icon} size={19} />
                    <span className={styles.navLabel}>{content.screenLabels[tab.key]}</span>
                  </button>
                ))}
              </div>
            </div>

            <div className={styles.phoneHome} />
          </div>

          <p className={styles.hint}>{content.hint}</p>
        </div>
      </div>
    </section>
  );
}

/* ── Piano alimentare — diet_view.dart ─────────────────────────────────── */
function DietScreen({
  content,
  portion,
  setPortion,
  day,
  setDay,
}: {
  content: MockupContent;
  portion: number;
  setPortion: (i: number) => void;
  day: number;
  setDay: (i: number) => void;
}) {
  const { diet } = content;
  return (
    <>
      <div className={styles.dayTabs}>
        {diet.days.map((d, i) => (
          <button
            key={d}
            className={`${styles.dayTab} ${i === day ? styles.dayActive : ''}`}
            onClick={() => setDay(i)}
          >
            {d}
          </button>
        ))}
      </div>

      <div className={styles.portionRow}>
        <AppIcon name="people" size={13} />
        <span className={styles.portionLabel}>{diet.portionsLabel}</span>
        {diet.portions.map((p, i) => (
          <button
            key={p}
            className={`${styles.portionChip} ${i === portion ? styles.portionActive : ''}`}
            onClick={() => setPortion(i)}
          >
            {p}
          </button>
        ))}
      </div>

      {diet.meals.map((meal) => (
        <article key={meal.name} className={styles.mealCard}>
          <header className={styles.mealHeader}>
            <span className={styles.mealName}>{meal.name}</span>
            {meal.allConsumed && (
              <span className={styles.mealDone}>
                <AppIcon name="check" size={11} />
              </span>
            )}
            <span className={styles.mealKcal}>{meal.kcal}</span>
          </header>
          <ul className={styles.foodList}>
            {meal.foods.map((food) => (
              <li key={food.name} className={food.done ? styles.foodDone : undefined}>
                <span className={`${styles.foodCheck} ${food.done ? styles.foodCheckOn : ''}`}>
                  {food.done && <AppIcon name="check" size={11} />}
                </span>
                <span className={styles.foodName}>{food.name}</span>
                <span className={styles.foodQty}>{food.qty}</span>
              </li>
            ))}
          </ul>
        </article>
      ))}
    </>
  );
}

/* ── Lista della spesa — shopping_list_view.dart ───────────────────────── */
function ShoppingScreen({
  content,
  checked,
  toggle,
}: {
  content: MockupContent;
  checked: Record<number, boolean>;
  toggle: (i: number) => void;
}) {
  const { shopping } = content;
  const done = Object.values(checked).filter(Boolean).length;
  const pct = Math.round((done / shopping.items.length) * 100);

  return (
    <>
      <div className={styles.budgetCard}>
        <div className={styles.budgetTop}>
          <span className={styles.budgetIcon}>
            <AppIcon name="euro" size={15} />
          </span>
          <span className={styles.budgetLabel}>{shopping.budgetLabel}</span>
          <AppIcon name="edit" size={12} />
        </div>
        <div className={styles.budgetBarTrack}>
          <div className={styles.budgetBarFill} style={{ width: '69%' }} />
        </div>
        <p className={styles.budgetMeta}>
          <strong>{shopping.budgetSpent}</strong> {shopping.budgetTotal}
        </p>
      </div>

      <div className={styles.groupRow}>
        <span>{shopping.groupLabel}</span>
        <span className={styles.toggle} data-on="false" />
      </div>

      <p className={styles.listProgress}>
        {done}/{shopping.items.length} · {pct}%
      </p>

      <ul className={styles.shopList}>
        {shopping.items.map((item, i) => (
          <li key={item.name}>
            <button
              className={styles.shopRow}
              onClick={() => toggle(i)}
              aria-pressed={Boolean(checked[i])}
            >
              <span className={`${styles.shopBox} ${checked[i] ? styles.shopBoxOn : ''}`}>
                {checked[i] && <AppIcon name="check" size={12} />}
              </span>
              <span className={checked[i] ? styles.shopTextDone : styles.shopText}>
                {item.name}
              </span>
            </button>
          </li>
        ))}
      </ul>
    </>
  );
}

/* ── Dispensa — pantry_view.dart ───────────────────────────────────────── */
function PantryScreen({ content }: { content: MockupContent }) {
  const { pantry } = content;
  return (
    <>
      <div className={styles.pantryHeader}>
        <span className={styles.pantryIcon}>
          <AppIcon name="kitchen" size={16} />
        </span>
        <h3 className={styles.pantryTitle}>{pantry.title}</h3>
        <span className={styles.aiBtn}>
          <AppIcon name="sparkle" size={12} />
          {pantry.aiButton}
        </span>
      </div>

      <div className={styles.addRow}>
        <span className={styles.addPlaceholder}>{pantry.addPlaceholder}</span>
        <span className={styles.addDivider} />
        <span className={styles.addQty}>{pantry.qtyPlaceholder}</span>
        <span className={styles.addBtn}>
          <AppIcon name="add" size={14} />
        </span>
      </div>

      <ul className={styles.pantryList}>
        {pantry.items.map((item) => (
          <li key={item.name}>
            <span className={styles.pantryTileIcon}>
              <AppIcon name="box" size={14} />
            </span>
            <span className={styles.pantryName}>{item.name}</span>
            <span className={styles.pantryQty}>{item.qty}</span>
          </li>
        ))}
      </ul>

      <div className={styles.fab}>
        <AppIcon name="camera" size={15} />
        {pantry.scanButton}
      </div>
    </>
  );
}
