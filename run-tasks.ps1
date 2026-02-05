# ============================================================
# Kybo - Automated Claude Code Task Runner (PowerShell)
# Ogni task viene eseguita in una sessione separata.
# Claude implementa, verifica compilazione, committa e pusha.
# ============================================================

$BRANCH = git rev-parse --abbrev-ref HEAD
$LOG_DIR = "./task-logs"
New-Item -ItemType Directory -Force -Path $LOG_DIR | Out-Null

# --- DEFINISCI LE TASK QUI ---
$TASKS = @(
  "Implementa Feature 1 - GDPR Avanzato Backend: crea il file server/app/routers/gdpr.py con 3 endpoint: GET /admin/gdpr/dashboard (stato consensi utenti, date ultimo accesso, dati da eliminare - verify_admin), POST /admin/gdpr/retention-config (configura periodo retention in mesi - verify_admin), POST /admin/gdpr/purge-inactive (elimina dati utenti inattivi oltre il periodo retention - verify_admin con conferma). Registra il router in server/app/main.py. Segui lo stesso pattern degli altri router (analytics.py, admin.py). Usa Firestore per leggere/scrivere i dati."

  "Implementa Feature 1 - GDPR Avanzato Admin Panel: crea la sezione GDPR nel pannello admin in admin/lib/screens/gdpr_view.dart. Deve contenere: tabella consensi (utente, email, data consenso, ultimo accesso, stato), configurazione retention policy (input mesi + toggle attiva/disattiva), pulsante purge manuale con dialog di conferma doppia, indicatore visivo utenti prossimi alla scadenza. Usa il design system esistente (PillCard, PillButton, PillBadge, KyboColors, StatCard). Aggiungi il tab/sezione nella dashboard (dashboard_screen.dart), visibile solo ad admin. I dati devono venire dai 3 endpoint backend appena creati."
)

# --- ISTRUZIONI COMUNI ---
$COMMON_INSTRUCTIONS = @"
REGOLE IMPORTANTI:
1. Lavora sul branch corrente: $BRANCH
2. Leggi sempre il codice esistente prima di modificare qualcosa
3. Segui lo stile del codice esistente nel progetto (design system, pattern, naming)
4. Dopo aver implementato, verifica la compilazione:
   - Per Flutter admin: cd admin && flutter analyze --no-fatal-infos && cd ..
   - Per Flutter client: cd client && flutter analyze --no-fatal-infos && cd ..
   - Per Python server: cd server && python -m py_compile app/main.py && cd ..
5. Se la compilazione fallisce, correggi gli errori prima di committare
6. Committa con messaggio descrittivo nel formato: type(scope): description
7. Pusha sul branch $BRANCH con: git push -u origin $BRANCH
8. NON modificare file che non c'entrano con la task
9. NON aggiungere feature extra oltre a quelle richieste
10. Leggi CLAUDE.md per capire il progetto
"@

# --- ESECUZIONE ---
$TOTAL = $TASKS.Count
$PASSED = 0
$FAILED = 0

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Kybo Task Runner - $TOTAL task da eseguire" -ForegroundColor Cyan
Write-Host "  Branch: $BRANCH" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

for ($i = 0; $i -lt $TASKS.Count; $i++) {
    $TASK_NUM = $i + 1
    $TASK = $TASKS[$i]
    $LOGFILE = "$LOG_DIR/task-$TASK_NUM.log"

    # Titolo breve
    $TASK_TITLE = if ($TASK.Length -gt 80) { $TASK.Substring(0, 80) } else { $TASK }

    Write-Host "--- Task $TASK_NUM/$TOTAL ---" -ForegroundColor Yellow
    Write-Host "$TASK_TITLE..." -ForegroundColor Yellow
    Write-Host "Log: $LOGFILE"
    Write-Host ""

    # Prompt completo
    $FULL_PROMPT = @"
$COMMON_INSTRUCTIONS

TASK DA IMPLEMENTARE:
$TASK
"@

    # Esegui Claude Code in print mode (sessione isolata)
    try {
        claude -p $FULL_PROMPT --verbose 2>&1 | Tee-Object -FilePath $LOGFILE
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] Task $TASK_NUM completata" -ForegroundColor Green
            $PASSED++
        } else {
            throw "Exit code: $LASTEXITCODE"
        }
    }
    catch {
        Write-Host "[FAIL] Task $TASK_NUM fallita ($_)" -ForegroundColor Red
        $FAILED++

        $CONTINUE = Read-Host "Continuare con la prossima task? (y/n)"
        if ($CONTINUE -ne "y") {
            Write-Host "Interrotto dall'utente." -ForegroundColor Red
            break
        }
    }

    Write-Host ""
}

# --- RIEPILOGO ---
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  RIEPILOGO" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Totali:    $TOTAL"
Write-Host "  Passate:   $PASSED" -ForegroundColor Green
Write-Host "  Fallite:   $FAILED" -ForegroundColor Red
Write-Host "  Log in:    $LOG_DIR/"
Write-Host "==========================================" -ForegroundColor Cyan
