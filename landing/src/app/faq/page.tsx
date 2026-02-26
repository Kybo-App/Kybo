'use client';

import React, { useState } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import styles from './faq.module.css';

interface FaqItem {
  question: string;
  answer: string;
}

interface FaqCategory {
  icon: string;
  title: string;
  items: FaqItem[];
}

const categories: FaqCategory[] = [
  {
    icon: '💡',
    title: 'Generale',
    items: [
      {
        question: "Cos'è Kybo?",
        answer:
          "Kybo è una piattaforma di gestione nutrizionale che connette nutrizionisti e clienti. I nutrizionisti possono caricare e gestire piani dietetici personalizzati tramite il pannello admin, mentre i clienti seguono la loro dieta, tracciano i pasti e comunicano direttamente con il proprio professionista tramite l'app mobile.",
      },
      {
        question: 'Chi può utilizzare Kybo?',
        answer:
          "Kybo è pensato per due tipologie di utenti: i professionisti della nutrizione (nutrizionisti, dietisti, biologi nutrizionisti) che cercano uno strumento digitale per gestire i propri clienti, e i pazienti/clienti che vogliono seguire un piano alimentare personalizzato in modo semplice e intuitivo.",
      },
      {
        question: 'Kybo è gratuito?',
        answer:
          "L'app client di Kybo è disponibile gratuitamente per i pazienti. I nutrizionisti accedono alla piattaforma tramite abbonamento professionale. Contattaci per informazioni sui piani disponibili.",
      },
      {
        question: 'Su quali piattaforme è disponibile Kybo?',
        answer:
          "L'app per i clienti è disponibile su iOS e Android. Il pannello di controllo per nutrizionisti è un'app web accessibile da qualsiasi browser. Non è necessario installare nulla per i professionisti.",
      },
    ],
  },
  {
    icon: '🥗',
    title: 'Per i Clienti',
    items: [
      {
        question: 'Come ricevo la mia dieta su Kybo?',
        answer:
          'Il tuo nutrizionista carica il piano alimentare direttamente dalla sua dashboard. Non appena pubblicato, riceverai una notifica e la dieta sarà visibile nella sezione "La mia dieta" dell\'app. I dati sono cifrati con AES-256 per garantire la tua privacy.',
      },
      {
        question: 'Posso chattare con il mio nutrizionista tramite l\'app?',
        answer:
          "Sì. Kybo integra una chat in tempo reale tra cliente e nutrizionista. Puoi inviare messaggi, foto dei pasti e documenti direttamente dall'app, senza dover usare WhatsApp o altri canali esterni.",
      },
      {
        question: 'Come funziona la lista spesa automatica?',
        answer:
          "Kybo analizza il tuo piano alimentare settimanale e genera automaticamente una lista della spesa organizzata per categoria (frutta e verdura, proteine, latticini, ecc.). Puoi spuntare gli articoli mentre fai la spesa e personalizzare la lista aggiungendo o rimuovendo elementi.",
      },
      {
        question: 'Posso vedere le calorie e i macronutrienti dei miei pasti?',
        answer:
          "Sì, Kybo mostra le informazioni nutrizionali dettagliate per ogni pasto: calorie, proteine, carboidrati e grassi. Se preferisci un approccio più rilassato, puoi attivare la \"modalità relax\" nelle impostazioni, che nasconde i valori calorici e mostra solo i pasti senza numeri.",
      },
    ],
  },
  {
    icon: '🩺',
    title: 'Per i Nutrizionisti',
    items: [
      {
        question: 'Come carico una dieta su Kybo?',
        answer:
          'Dal pannello admin puoi caricare piani dietetici in formato PDF. Il sistema di parsing AI (basato su Gemini 2.5 Flash) estrae automaticamente la struttura della dieta — pasti, alimenti, porzioni — e la organizza nel formato corretto. Non devi inserire i dati manualmente.',
      },
      {
        question: 'Posso gestire più clienti contemporaneamente?',
        answer:
          "Sì, il pannello admin è progettato per gestire un portfolio di clienti. Puoi passare rapidamente da un paziente all'altro, consultare la cronologia delle diete, monitorare i progressi e comunicare via chat con ciascuno di loro.",
      },
      {
        question: 'Quanto è preciso il parsing AI dei PDF?',
        answer:
          "Il nostro sistema di parsing AI raggiunge una precisione media del 95% su PDF di piani alimentari italiani standard. Il modello è stato ottimizzato con un prompt personalizzabile per adattarsi al formato specifico che utilizzi. In caso di errori, puoi sempre modificare manualmente la dieta prima di pubblicarla.",
      },
      {
        question: 'Posso analizzare i progressi dei miei pazienti?',
        answer:
          "Kybo genera report mensili automatici per ogni cliente, con grafici di aderenza alla dieta, trend di peso e note sull'andamento. Questi report sono esportabili in PDF e possono essere condivisi direttamente con il paziente durante le sedute.",
      },
    ],
  },
  {
    icon: '🔒',
    title: 'Privacy & Sicurezza',
    items: [
      {
        question: 'I miei dati alimentari sono al sicuro?',
        answer:
          "Assolutamente. I dati dietetici dei clienti sono cifrati con AES-256 a riposo e trasmessi via HTTPS. Il nostro backend è ospitato su infrastruttura sicura con accessi autenticati tramite Firebase Auth. Solo tu e il tuo nutrizionista avete accesso ai tuoi dati.",
      },
      {
        question: 'Kybo è conforme al GDPR?',
        answer:
          "Sì. Kybo è progettato in conformità con il Regolamento Europeo sulla Protezione dei Dati (GDPR). Trattiamo solo i dati strettamente necessari al funzionamento del servizio, manteniamo un registro degli accessi (audit log) per i dati sensibili e non vendiamo né condividiamo i tuoi dati con terze parti.",
      },
      {
        question: 'Posso eliminare il mio account e tutti i miei dati?',
        answer:
          "Sì. Puoi richiedere l'eliminazione completa del tuo account e di tutti i dati associati in qualsiasi momento dalla sezione Impostazioni dell'app, oppure contattando il nostro supporto. I dati vengono rimossi permanentemente dai nostri sistemi entro 30 giorni dalla richiesta.",
      },
    ],
  },
];

function AccordionItem({ item }: { item: FaqItem }) {
  const [open, setOpen] = useState(false);

  return (
    <div className={`${styles.item} ${open ? styles.itemOpen : ''}`}>
      <button
        className={styles.question}
        onClick={() => setOpen(!open)}
        aria-expanded={open}
      >
        <span className={styles.questionText}>{item.question}</span>
        <span className={`${styles.chevron} ${open ? styles.chevronOpen : ''}`}>
          ▼
        </span>
      </button>
      <div className={`${styles.answerWrapper} ${open ? styles.answerWrapperOpen : ''}`}>
        <p className={styles.answer}>{item.answer}</p>
      </div>
    </div>
  );
}

export default function FAQPage() {
  return (
    <div className={styles.pageWrapper}>
      {/* Navbar */}
      <nav className={styles.nav}>
        <div className={styles.navContainer}>
          <Link href="/" className={styles.logo}>
            <Image
              src="/logo no bg.png"
              alt="Kybo"
              width={32}
              height={32}
              className={styles.logoIcon}
              priority
            />
            <span className={styles.logoText}>Kybo</span>
          </Link>
          <Link href="/" className={styles.backBtn}>
            ← Torna alla Home
          </Link>
        </div>
      </nav>

      {/* Hero */}
      <div className={styles.hero}>
        <h1 className={styles.pageTitle}>Domande Frequenti</h1>
        <p className={styles.pageSubtitle}>
          Hai dubbi su Kybo? Qui trovi le risposte alle domande più comuni su clienti, nutrizionisti, privacy e funzionalità.
        </p>
      </div>

      {/* Accordion */}
      <div className={styles.content}>
        {categories.map((cat) => (
          <div key={cat.title} className={styles.category}>
            <div className={styles.categoryHeader}>
              <span className={styles.categoryIcon}>{cat.icon}</span>
              <h2 className={styles.categoryTitle}>{cat.title}</h2>
            </div>
            {cat.items.map((item) => (
              <AccordionItem key={item.question} item={item} />
            ))}
          </div>
        ))}
      </div>

      {/* Footer */}
      <footer className={styles.footer}>
        <p className={styles.footerText}>© 2025 Kybo. Tutti i diritti riservati.</p>
      </footer>
    </div>
  );
}
