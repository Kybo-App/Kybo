# Deploy Notes — Azioni manuali richieste

Questo file raccoglie tutte le configurazioni e azioni che richiedono intervento manuale
(variabili d'ambiente, account esterni, configurazioni infrastruttura).

---

## 🔴 SMTP — Notifiche email messaggi non letti

**Quando**: Appena vuoi attivare gli alert email per i nutrizionisti (Feature 5)

**Dove**: Render → kybo-test / kybo-prod → Environment → Environment Variables

Aggiungere le seguenti variabili:

| Variabile | Valore | Note |
|---|---|---|
| `SMTP_HOST` | es. `smtp.gmail.com` | Host del tuo provider email |
| `SMTP_PORT` | `587` | Porta TLS standard |
| `SMTP_USERNAME` | es. `noreply@kybo.it` | Account mittente |
| `SMTP_PASSWORD` | (password o app password) | Per Gmail: usa "App Password" |
| `SMTP_FROM_EMAIL` | `noreply@kybo.it` | Indirizzo visibile al destinatario |
| `SMTP_FROM_NAME` | `Kybo` | Nome visibile al destinatario |

**Come testare**: Dopo il deploy, un nutrizionista può attivare gli alert dal pannello Chat → icona campanella 🔔. Le email vengono inviate automaticamente quando un messaggio non letto supera la soglia impostata.

**Se SMTP non è configurato**: il sistema si avvia comunque senza errori, le email sono semplicemente skippate.

---

## 🟡 Da fare in futuro (bassa urgenza)

_(Aggiungi qui altri task manuali man mano che emergono)_

---

*Ultimo aggiornamento: 2026-02-19*
