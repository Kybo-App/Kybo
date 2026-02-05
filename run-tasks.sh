#!/bin/bash
set -euo pipefail

# ============================================================
# Kybo - Automated Claude Code Task Runner
# Ogni task viene eseguita in una sessione separata.
# Claude implementa, verifica compilazione, committa e pusha.
# ============================================================

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
LOG_DIR="./task-logs"
mkdir -p "$LOG_DIR"

# --- DEFINISCI LE TASK QUI ---
# Ogni elemento e' una task completa da passare a Claude Code.
# Modifica questo array per aggiungere/rimuovere task.
TASKS=(
  "Implementa Feature 1 - GDPR Avanzato Backend: crea il file server/app/routers/gdpr.py con 3 endpoint: GET /admin/gdpr/dashboard (stato consensi utenti, date ultimo accesso, dati da eliminare - verify_admin), POST /admin/gdpr/retention-config (configura periodo retention in mesi - verify_admin), POST /admin/gdpr/purge-inactive (elimina dati utenti inattivi oltre il periodo retention - verify_admin con conferma). Registra il router in server/app/main.py. Segui lo stesso pattern degli altri router (analytics.py, admin.py). Usa Firestore per leggere/scrivere i dati."

  "Implementa Feature 1 - GDPR Avanzato Admin Panel: crea la sezione GDPR nel pannello admin in admin/lib/screens/gdpr_view.dart. Deve contenere: tabella consensi (utente, email, data consenso, ultimo accesso, stato), configurazione retention policy (input mesi + toggle attiva/disattiva), pulsante purge manuale con dialog di conferma doppia, indicatore visivo utenti prossimi alla scadenza. Usa il design system esistente (PillCard, PillButton, PillBadge, KyboColors, StatCard). Aggiungi il tab/sezione nella dashboard (dashboard_screen.dart), visibile solo ad admin. I dati devono venire dai 3 endpoint backend appena creati."
)

# --- ISTRUZIONI COMUNI ---
# Queste istruzioni vengono passate a ogni sessione Claude Code.
COMMON_INSTRUCTIONS="
REGOLE IMPORTANTI:
1. Lavora sul branch corrente: ${BRANCH}
2. Leggi sempre il codice esistente prima di modificare qualcosa
3. Segui lo stile del codice esistente nel progetto (design system, pattern, naming)
4. Dopo aver implementato, verifica la compilazione:
   - Per Flutter admin: cd admin && flutter analyze --no-fatal-infos && cd ..
   - Per Flutter client: cd client && flutter analyze --no-fatal-infos && cd ..
   - Per Python server: cd server && python -m py_compile app/main.py && cd ..
5. Se la compilazione fallisce, correggi gli errori prima di committare
6. Committa con messaggio descrittivo nel formato: type(scope): description
7. Pusha sul branch ${BRANCH} con: git push -u origin ${BRANCH}
8. NON modificare file che non c'entrano con la task
9. NON aggiungere feature extra oltre a quelle richieste
10. Leggi CLAUDE.md per capire il progetto
"

# --- COLORI OUTPUT ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- ESECUZIONE ---
TOTAL=${#TASKS[@]}
PASSED=0
FAILED=0

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}  Kybo Task Runner - ${TOTAL} task da eseguire${NC}"
echo -e "${BLUE}  Branch: ${BRANCH}${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

for i in "${!TASKS[@]}"; do
  TASK_NUM=$((i + 1))
  TASK="${TASKS[$i]}"
  LOGFILE="${LOG_DIR}/task-${TASK_NUM}.log"

  # Titolo breve (prima riga o primi 80 char)
  TASK_TITLE=$(echo "$TASK" | head -c 80)

  echo -e "${YELLOW}--- Task ${TASK_NUM}/${TOTAL} ---${NC}"
  echo -e "${YELLOW}${TASK_TITLE}...${NC}"
  echo -e "Log: ${LOGFILE}"
  echo ""

  # Prompt completo per questa sessione
  FULL_PROMPT="${COMMON_INSTRUCTIONS}

TASK DA IMPLEMENTARE:
${TASK}
"

  # Esegui Claude Code in print mode (sessione isolata)
  if claude -p "$FULL_PROMPT" --verbose 2>&1 | tee "$LOGFILE"; then
    echo -e "${GREEN}[OK] Task ${TASK_NUM} completata${NC}"
    PASSED=$((PASSED + 1))
  else
    echo -e "${RED}[FAIL] Task ${TASK_NUM} fallita (exit code: $?)${NC}"
    FAILED=$((FAILED + 1))

    # Chiedi se continuare
    echo -e "${YELLOW}Continuare con la prossima task? (y/n)${NC}"
    read -r CONTINUE
    if [[ "$CONTINUE" != "y" ]]; then
      echo -e "${RED}Interrotto dall'utente.${NC}"
      break
    fi
  fi

  echo ""
done

# --- RIEPILOGO ---
echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}  RIEPILOGO${NC}"
echo -e "${BLUE}==========================================${NC}"
echo -e "  Totali:    ${TOTAL}"
echo -e "  ${GREEN}Passate:   ${PASSED}${NC}"
echo -e "  ${RED}Fallite:   ${FAILED}${NC}"
echo -e "  Log in:    ${LOG_DIR}/"
echo -e "${BLUE}==========================================${NC}"
