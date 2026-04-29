import 'package:flutter/material.dart';

// Sistema di localizzazione italiano/inglese per l'admin panel.
// Aggiungere nuove chiavi in AppLocalizations e nei delegate corrispondenti.

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  bool get isItalian => locale.languageCode == 'it';

  String get navUsers => isItalian ? 'Utenti' : 'Users';
  String get navChat => 'Chat';
  String get navCalculator => isItalian ? 'Calcolatrice' : 'Calculator';
  String get navAnalytics => 'Analytics';
  String get navReports => isItalian ? 'Report' : 'Reports';
  String get navSettings => isItalian ? 'Impostazioni' : 'Settings';
  String get navGdpr => 'GDPR';
  String get navAuditLog => isItalian ? 'Audit Log' : 'Audit Log';
  String get navRewards => isItalian ? 'Premi' : 'Rewards';
  String get navWorkout => 'Workout';
  String get navServer => isItalian ? 'Server' : 'Server';

  String get confirm => isItalian ? 'Conferma' : 'Confirm';
  String get cancel => isItalian ? 'Annulla' : 'Cancel';
  String get save => isItalian ? 'Salva' : 'Save';
  String get delete => isItalian ? 'Elimina' : 'Delete';
  String get close => isItalian ? 'Chiudi' : 'Close';
  String get search => isItalian ? 'Cerca...' : 'Search...';
  String get loading => isItalian ? 'Caricamento...' : 'Loading...';
  String get error => isItalian ? 'Errore' : 'Error';
  String get success => isItalian ? 'Successo' : 'Success';
  String get yes => isItalian ? 'Sì' : 'Yes';
  String get no => 'No';
  String get back => isItalian ? 'Indietro' : 'Back';
  String get user => isItalian ? 'Utente' : 'User';
  String get noResults => isItalian ? 'Nessun risultato' : 'No results';

  String get logout => isItalian ? 'Esci' : 'Logout';
  String get logoutConfirm =>
      isItalian ? 'Sei sicuro di voler uscire?' : 'Are you sure you want to logout?';
  String get logoutTitle => isItalian ? 'Conferma Logout' : 'Confirm Logout';
  String get login => isItalian ? 'Accedi' : 'Login';
  String get loginButton =>
      isItalian ? 'ACCEDI AL PANNELLO' : 'ACCESS PANEL';
  String get loginReserved =>
      isItalian
          ? 'Accesso riservato al pannello di controllo'
          : 'Restricted access to control panel';
  String get email => 'Email';
  String get password => isItalian ? 'Password' : 'Password';

  String get adminPanel => isItalian ? 'Admin Panel' : 'Admin Panel';
  String get darkMode => isItalian ? 'Modalità Scura' : 'Dark Mode';
  String get lightMode => isItalian ? 'Modalità Chiara' : 'Light Mode';

  String get globalSearch =>
      isItalian ? 'Ricerca Globale' : 'Global Search';
  String get searchHint =>
      isItalian
          ? 'Cerca utenti, diete, chat...'
          : 'Search users, diets, chats...';
  String get searchUsersSection => isItalian ? 'Utenti' : 'Users';
  String get searchNoResults =>
      isItalian ? 'Nessun risultato trovato' : 'No results found';
  String get searchTypeToStart =>
      isItalian
          ? 'Inizia a digitare per cercare...'
          : 'Start typing to search...';

  String get keyboardShortcuts =>
      isItalian ? 'Scorciatoie da tastiera' : 'Keyboard Shortcuts';
  String get shortcutNewUser =>
      isItalian ? 'Nuovo utente' : 'New user';
  String get shortcutSearch =>
      isItalian ? 'Ricerca globale' : 'Global search';
  String get shortcutNavigation =>
      isItalian ? 'Navigazione tab' : 'Tab navigation';
  String get shortcutTheme =>
      isItalian ? 'Cambia tema' : 'Toggle theme';

  String get newUser => isItalian ? 'Nuovo Utente' : 'New User';
  String get searchUser =>
      isItalian ? 'Cerca utente per nome o email...' : 'Search user by name or email...';
  String get allRoles => isItalian ? 'Tutti i ruoli' : 'All roles';
  String get syncUsers => isItalian ? 'Sincronizza' : 'Sync';
  String get noUsersFound =>
      isItalian ? 'Nessun utente trovato' : 'No users found';

  String get language => isItalian ? 'Lingua' : 'Language';
  String get italian => isItalian ? 'Italiano' : 'Italian';
  String get english => isItalian ? 'Inglese' : 'English';

  // Login / role check
  String get webAccessDeniedTitle =>
      isItalian ? 'Accesso Web non consentito' : 'Web access not allowed';
  String get webAccessDeniedBody =>
      isItalian
          ? 'Questa dashboard è riservata ai Nutrizionisti.\n\nSe sei un cliente, scarica l\'App Kybo sul tuo smartphone per gestire il piano.'
          : 'This dashboard is reserved for Nutritionists.\n\nIf you are a client, download the Kybo app on your smartphone to manage your plan.';
  String get goBack => isItalian ? 'Torna indietro' : 'Go back';
  String get loginError => isItalian ? 'Errore: ' : 'Error: ';

  // User management dialog
  String get firstName => isItalian ? 'Nome' : 'First name';
  String get lastName => isItalian ? 'Cognome' : 'Last name';
  String get role => isItalian ? 'Ruolo' : 'Role';
  String get professionalProfile =>
      isItalian ? 'Profilo Professionale' : 'Professional Profile';
  String get phone => isItalian ? 'Telefono' : 'Phone';
  String get bio => isItalian ? 'Bio (presentazione)' : 'Bio (introduction)';
  String get specializations =>
      isItalian
          ? 'Specializzazioni (es. Sportivo, Vegano)'
          : 'Specializations (e.g. Sports, Vegan)';
  String get studioName =>
      isItalian
          ? 'Nome Studio (mostrato in app ai clienti)'
          : 'Studio Name (shown in app to clients)';
  String get studioNameHint =>
      isItalian
          ? 'Es. Studio Nutrizionistico Rossi'
          : 'E.g. Rossi Nutrition Studio';
  String get clientLimit =>
      isItalian ? 'Limite Clienti (Admin Only)' : 'Client Limit (Admin Only)';

  // Role labels
  String get roleClient => isItalian ? 'Cliente (user)' : 'Client (user)';
  String get roleIndependent => isItalian ? 'Indipendente' : 'Independent';
  String get roleNutritionist => isItalian ? 'Nutrizionista' : 'Nutritionist';
  String get rolePersonalTrainer => 'Personal Trainer';
  String get roleCoach =>
      isItalian ? 'Coach (nutri + PT)' : 'Coach (nutri + PT)';
  String get roleAdmin => 'Admin';

  // --- "La mia giornata" (MyDayView) ---
  String get myDayTab => isItalian ? 'La mia giornata' : 'My day';
  String get goodMorning => isItalian ? 'Buongiorno' : 'Good morning';
  String get goodAfternoon => isItalian ? 'Buon pomeriggio' : 'Good afternoon';
  String get goodEvening => isItalian ? 'Buonasera' : 'Good evening';
  String get statUnreadChats => isItalian ? 'Chat non lette' : 'Unread chats';
  String get statExpiredDiets => isItalian ? 'Diete scadute' : 'Expired diets';
  String get statInactiveClients =>
      isItalian ? 'Clienti inattivi' : 'Inactive clients';
  String get statInactiveSubtitle =>
      isItalian ? '>14 giorni' : '>14 days';
  String get clientsToContact =>
      isItalian ? 'Clienti da ricontattare' : 'Clients to contact';
  String get allUnderControl =>
      isItalian ? 'Tutto sotto controllo!' : 'All under control!';
  String get noClientsAttention =>
      isItalian
          ? 'Nessun cliente richiede attenzione oggi.'
          : 'No client needs attention today.';
  String get reasonExpiredDiet =>
      isItalian ? 'Dieta scaduta' : 'Expired diet';
  String get reasonNeverActive =>
      isItalian ? 'Mai attivo' : 'Never active';
  String reasonInactive(int days) =>
      isItalian ? 'Inattivo da ${days}gg' : 'Inactive for ${days}d';
  String get tooltipOpenChat => isItalian ? 'Apri chat' : 'Open chat';
  String get tooltipOpenProfile =>
      isItalian ? 'Vai al profilo' : 'Open profile';
  String lastActivity(String label) =>
      isItalian ? '· Ultima attività $label' : '· Last activity $label';

  // --- Bulk actions / templates / export PDF ---
  String selectedCount(int n) =>
      isItalian ? '$n selezionati' : '$n selected';
  String get bulkAssign => isItalian ? 'ASSEGNA' : 'ASSIGN';
  String get bulkExportCsv =>
      isItalian ? 'ESPORTA CSV' : 'EXPORT CSV';
  String get bulkCancelTooltip =>
      isItalian ? 'Annulla selezione' : 'Cancel selection';
  String get bulkAssignTitle =>
      isItalian ? 'Assegna utenti' : 'Assign users';
  String get exportReportTooltip =>
      isItalian ? 'Esporta Report PDF' : 'Export PDF Report';
  String get reportGenerating =>
      isItalian ? 'Generazione report in corso...' : 'Generating report...';
  String get reportDownloaded =>
      isItalian ? 'Report PDF scaricato' : 'PDF report downloaded';

  // Workout templates
  String get templatesSection => isItalian ? 'Template' : 'Templates';
  String get plansSection => isItalian ? 'Schede' : 'Plans';
  String get saveAsTemplate =>
      isItalian ? 'Salva come template' : 'Save as template';
  String get saveAsTemplateSubtitle =>
      isItalian
          ? 'Riutilizzabile su più utenti — non lo assegna a nessuno'
          : 'Reusable across users — not assigned to anyone';
  String get useTemplate => isItalian ? 'Usa template' : 'Use template';
  String get useTemplateTooltip =>
      isItalian
          ? 'Usa template — clona e assegna'
          : 'Use template — clone and assign';
  String get cloneAndAssign =>
      isItalian ? 'Crea e assegna' : 'Create and assign';
  String get templateBadge => isItalian ? 'Template' : 'Template';
  String get templateClonedOk =>
      isItalian ? 'Template clonato e assegnato ✓' : 'Template cloned and assigned ✓';

  // Virtualization
  String loadMoreUsers(int next, int visible, int total) =>
      isItalian
          ? 'Mostra altri $next  ($visible/$total)'
          : 'Show $next more  ($visible/$total)';

  // --- Common labels ---
  String get edit => isItalian ? 'Modifica' : 'Edit';
  String get create => isItalian ? 'Crea' : 'Create';
  String get add => isItalian ? 'Aggiungi' : 'Add';
  String get update => isItalian ? 'Aggiorna' : 'Update';
  String get assign => isItalian ? 'Assegna' : 'Assign';
  String get refresh => isItalian ? 'Ricarica' : 'Refresh';
  String get download => isItalian ? 'Scarica' : 'Download';
  String get upload => isItalian ? 'Carica' : 'Upload';
  String get details => isItalian ? 'Dettagli' : 'Details';
  String get notes => isItalian ? 'Note' : 'Notes';
  String get description => isItalian ? 'Descrizione' : 'Description';
  String get name => isItalian ? 'Nome' : 'Name';
  String get date => isItalian ? 'Data' : 'Date';
  String get status => isItalian ? 'Stato' : 'Status';
  String get actions => isItalian ? 'Azioni' : 'Actions';
  String get optional => isItalian ? 'Opzionale' : 'Optional';
  String get required => isItalian ? 'Obbligatorio' : 'Required';
  String get unknown => isItalian ? 'Sconosciuto' : 'Unknown';
  String get loadingDots => isItalian ? 'Caricamento...' : 'Loading...';
  String get genericError =>
      isItalian ? 'Si è verificato un errore' : 'An error occurred';
  String get retry => isItalian ? 'Riprova' : 'Retry';
  String get noData => isItalian ? 'Nessun dato' : 'No data';
  String get noDataAvailable =>
      isItalian ? 'Nessun dato disponibile' : 'No data available';

  // --- Change password ---
  String get pwdSecurityUpdate =>
      isItalian ? 'Aggiornamento sicurezza' : 'Security Update Required';
  String get pwdWelcome =>
      isItalian
          ? 'Benvenuto! Trattandosi di un nuovo account, devi cambiare la password temporanea per procedere.'
          : 'Welcome! Since this is a new account, you must change your temporary password to proceed.';
  String get pwdNew => isItalian ? 'Nuova password' : 'New Password';
  String get pwdConfirm => isItalian ? 'Conferma password' : 'Confirm Password';
  String get pwdSet => isItalian
      ? 'IMPOSTA PASSWORD E CONTINUA'
      : 'SET PASSWORD & ENTER';
  String get pwdMismatch =>
      isItalian ? 'Le password non corrispondono' : 'Passwords do not match';
  String get pwdPolicyError =>
      isItalian
          ? 'La password deve avere almeno 12 caratteri, una maiuscola, una minuscola e un numero'
          : 'Password must have at least 12 characters, including uppercase, lowercase, and a digit';
  String get pwdChangeError =>
      isItalian
          ? 'Errore durante il cambio password. Riprova.'
          : 'Error changing password. Please try again.';

  // --- Audit log ---
  String get auditTitle => isItalian ? 'Audit Log' : 'Audit Log';
  String get auditExportCsv =>
      isItalian ? 'Esporta CSV' : 'Export CSV';
  String get auditTimestamp => isItalian ? 'Data e ora' : 'Timestamp';
  String get auditAdmin => isItalian ? 'Admin richiedente' : 'Requesting admin';
  String get auditAction => isItalian ? 'Azione' : 'Action';
  String get auditTargetUser =>
      isItalian ? 'Utente target' : 'Target user';
  String get auditReason =>
      isItalian ? 'Motivazione legale' : 'Legal reason';
  String get auditUserAgent => 'User Agent';
  String get auditNoLogs =>
      isItalian ? 'Nessun log disponibile' : 'No logs available';

  // --- GDPR ---
  String get gdprTitle =>
      isItalian ? 'GDPR & Privacy' : 'GDPR & Privacy';
  String get gdprConsents => isItalian ? 'Consensi' : 'Consents';
  String get gdprRetention =>
      isItalian ? 'Retention policy' : 'Retention policy';
  String get gdprPurgeInactive =>
      isItalian ? 'Elimina utenti inattivi' : 'Purge inactive users';
  String get gdprMonthsRetention =>
      isItalian ? 'Mesi di retention' : 'Retention months';
  String get gdprConfigSaved =>
      isItalian ? 'Configurazione salvata' : 'Configuration saved';
  String get gdprPurgeSimulation =>
      isItalian ? 'Simulazione Purge' : 'Purge Simulation';
  String get gdprWarning =>
      isItalian ? 'ATTENZIONE' : 'WARNING';
  String gdprPurgeBody(bool isDryRun, String target) =>
      isDryRun
          ? (isItalian
              ? 'Verrà eseguita una SIMULAZIONE della purge per $target.'
              : 'A SIMULATION of the purge will be run for $target.')
          : (isItalian
              ? 'Stai per ELIMINARE PERMANENTEMENTE i dati di $target.'
              : 'You are about to PERMANENTLY DELETE data for $target.');
  String get gdprIrreversible =>
      isItalian
          ? 'Questa operazione è IRREVERSIBILE!'
          : 'This operation is IRREVERSIBLE!';
  String get gdprSimulate => isItalian ? 'Simula' : 'Simulate';
  String gdprSimulationDone(int n) =>
      isItalian
          ? 'Simulazione completata: $n utenti processati'
          : 'Simulation complete: $n users processed';
  String gdprPurgeDone(int n) =>
      isItalian
          ? 'Purge completato: $n utenti eliminati'
          : 'Purge complete: $n users deleted';
  String get gdprStatistics => isItalian ? 'Statistiche' : 'Statistics';
  String get gdprTotalUsers =>
      isItalian ? 'Utenti totali' : 'Total users';
  String get gdprInactiveUsers =>
      isItalian ? 'Inattivi' : 'Inactive';
  String get gdprApproaching =>
      isItalian ? 'In scadenza' : 'Approaching';
  String get gdprConfigTitle =>
      isItalian ? 'Configurazione retention' : 'Retention configuration';
  String get gdprRetentionPeriod =>
      isItalian ? 'Periodo di retention' : 'Retention period';
  String get gdprRetentionPeriodSub =>
      isItalian
          ? 'Mesi di inattività prima della purge'
          : 'Months of inactivity before purge';
  String get gdprAutoRetention =>
      isItalian ? 'Retention automatica' : 'Automatic retention';
  String get gdprAutoRetentionSub =>
      isItalian
          ? 'Abilita purge automatica degli utenti inattivi'
          : 'Enable automatic purge of inactive users';
  String get gdprDryRun =>
      isItalian ? 'Modalità dry run' : 'Dry run mode';
  String get gdprDryRunSub =>
      isItalian
          ? 'Simula le operazioni senza eliminare dati'
          : 'Simulate operations without deleting data';
  String get gdprSaveConfig =>
      isItalian ? 'Salva configurazione' : 'Save configuration';
  String get gdprRunPurge =>
      isItalian ? 'Esegui purge' : 'Run purge';
  String get gdprSimulatePurge =>
      isItalian ? 'Simula purge' : 'Simulate purge';
  String gdprInactiveListTitle(int n) =>
      isItalian ? 'Utenti inattivi ($n)' : 'Inactive users ($n)';
  String gdprApproachingListTitle(int n) =>
      isItalian ? 'Prossimi alla scadenza ($n)' : 'Approaching deadline ($n)';
  String gdprInactiveSubtitle(int days, String? deadline) =>
      isItalian
          ? 'Inattivo da $days giorni${deadline != null ? ' • Scadenza: $deadline' : ''}'
          : 'Inactive for $days days${deadline != null ? ' • Deadline: $deadline' : ''}';
  String get gdprSubtitle =>
      isItalian
          ? 'Gestione retention policy e conformità GDPR'
          : 'Retention policy and GDPR compliance management';
  String get gdprDeleteUserTooltip =>
      isItalian ? 'Elimina utente' : 'Delete user';

  // --- Reports ---
  String get reportsTitle =>
      isItalian ? 'Report mensili' : 'Monthly reports';
  String get reportsMonth => isItalian ? 'Mese' : 'Month';
  String get reportsNutritionist =>
      isItalian ? 'Nutrizionista' : 'Nutritionist';
  String get reportsTotalClients =>
      isItalian ? 'Clienti totali' : 'Total clients';
  String get reportsNewClients =>
      isItalian ? 'Nuovi clienti' : 'New clients';
  String get reportsActiveClients =>
      isItalian ? 'Clienti attivi' : 'Active clients';
  String get reportsDietsUploaded =>
      isItalian ? 'Diete caricate' : 'Diets uploaded';
  String get reportsMessagesSent =>
      isItalian ? 'Messaggi inviati' : 'Messages sent';
  String get reportsResponseTime =>
      isItalian ? 'Tempo risposta medio' : 'Average response time';
  String get reportsDownloadPdf =>
      isItalian ? 'Scarica PDF' : 'Download PDF';
  String get reportsGenerate =>
      isItalian ? 'Genera report' : 'Generate report';
  String get reportsNoData =>
      isItalian ? 'Nessun report per questo mese.' : 'No report for this month.';
  String get reportsPdfDownloaded =>
      isItalian ? 'PDF scaricato' : 'PDF downloaded';

  // --- Analytics ---
  String get analyticsTitle => 'Analytics';
  String get analyticsNoData =>
      isItalian ? 'Nessun dato analytics disponibile' : 'No analytics data available';

  // --- Chat management (admin) ---
  String get chatTitle => 'Chat';
  String get chatNoChats =>
      isItalian ? 'Nessuna chat attiva' : 'No active chats';
  String get chatSelectFromList =>
      isItalian ? 'Seleziona una chat dalla lista' : 'Select a chat from the list';
  String get chatTypeMessage =>
      isItalian ? 'Scrivi un messaggio...' : 'Type a message...';
  String get chatBroadcast => 'Broadcast';
  String get chatBroadcastTitle =>
      isItalian ? 'Messaggio broadcast' : 'Broadcast message';
  String get chatBroadcastSend =>
      isItalian ? 'Invia a tutti i clienti' : 'Send to all clients';
  String get chatAttach =>
      isItalian ? 'Allega file' : 'Attach file';

  // --- Rewards catalog ---
  String get rewardsTitle => isItalian ? 'Premi' : 'Rewards';
  String get rewardsNew => isItalian ? 'Nuovo premio' : 'New reward';
  String get rewardsCost => isItalian ? 'Costo XP' : 'XP cost';
  String get rewardsStock => isItalian ? 'Disponibilità' : 'Stock';
  String get rewardsActive => isItalian ? 'Attivo' : 'Active';
  String get rewardsNoCatalog =>
      isItalian ? 'Catalogo premi vuoto' : 'Rewards catalog empty';
  String get rewardsManagement =>
      isItalian ? 'Gestione Premi' : 'Rewards management';
  String get rewardsEditDialog =>
      isItalian ? 'Modifica premio' : 'Edit reward';
  String get rewardsNamePlaceholder =>
      isItalian ? 'Nome premio' : 'Reward name';
  String get rewardsDescriptionPlaceholder =>
      isItalian ? 'Descrizione (opzionale)' : 'Description (optional)';
  String get rewardsCostHint =>
      isItalian ? 'Costo XP' : 'XP cost';
  String get rewardsStockHint =>
      isItalian
          ? 'Stock (vuoto = illimitato)'
          : 'Stock (empty = unlimited)';
  String get rewardsImageUrl =>
      isItalian ? 'URL immagine (opzionale)' : 'Image URL (optional)';
  String get rewardsRedeemUrl =>
      isItalian
          ? 'URL esterno riscatto (es. https://shop...)'
          : 'External redemption URL (e.g. https://shop...)';
  String get rewardsRedeemUrlHelp =>
      isItalian
          ? 'Link aperto al cliente dopo il riscatto (sconto, shop partner...).'
          : 'Link opened to the client after redemption (discount, partner shop...).';
  String get rewardsActiveStatus =>
      isItalian ? 'Attivo' : 'Active';
  String get rewardsInactiveStatus =>
      isItalian ? 'Disattivato' : 'Inactive';
  String get rewardsNameAndCostRequired =>
      isItalian
          ? 'Nome e costo XP obbligatori'
          : 'Name and XP cost are required';
  String get rewardsCostInvalid =>
      isItalian ? 'Costo XP non valido' : 'XP cost is invalid';
  String get rewardsDeleteTitle =>
      isItalian ? 'Elimina premio' : 'Delete reward';
  String rewardsDeleteConfirm(String name) =>
      isItalian
          ? 'Vuoi eliminare "$name"? L\'azione è irreversibile.'
          : 'Delete "$name"? This action is irreversible.';
  String get rewardsRedeemed =>
      isItalian ? 'Premio segnato come evaso ✓' : 'Reward marked as fulfilled ✓';
  String get rewardsCatalogTab =>
      isItalian ? 'Catalogo' : 'Catalog';
  String get rewardsClaimsTab =>
      isItalian ? 'Riscatti' : 'Claims';
  String get rewardsNoneInCatalog =>
      isItalian ? 'Nessun premio nel catalogo' : 'No rewards in catalog';
  String get rewardsCreateFirst =>
      isItalian
          ? 'Crea il primo premio con il pulsante in alto'
          : 'Create the first reward with the button above';
  String get rewardsNoneRedeemed =>
      isItalian ? 'Nessun premio riscattato' : 'No reward redeemed yet';
  String get rewardsStatusFulfilled =>
      isItalian ? 'Evaso' : 'Fulfilled';
  String get rewardsStatusPending =>
      isItalian ? 'In attesa' : 'Pending';
  String get rewardsFulfill =>
      isItalian ? 'Evadi' : 'Fulfill';

  // --- Matchmaking board ---
  String get matchmakingTitle =>
      isItalian ? 'Bacheca annunci' : 'Matchmaking board';
  String get matchmakingNoRequests =>
      isItalian ? 'Nessuna richiesta attiva' : 'No active requests';
  String get matchmakingBudget => isItalian ? 'Budget' : 'Budget';
  String get matchmakingGoal => isItalian ? 'Obiettivo' : 'Goal';
  String get matchmakingLocation => isItalian ? 'Località' : 'Location';
  String get matchmakingAll => isItalian ? 'Tutti' : 'All';
  String get matchmakingFindNutritionist =>
      isItalian ? 'Cerca Nutrizionista' : 'Looking for Nutritionist';
  String get matchmakingFindPT =>
      isItalian ? 'Cerca Personal Trainer' : 'Looking for Personal Trainer';
  String get matchmakingMakeProposal =>
      isItalian ? 'Fai una proposta' : 'Make a proposal';
  String get matchmakingProposalDescription =>
      isItalian
          ? 'Descrivi perché saresti la scelta migliore per questo utente.'
          : 'Describe why you\'d be the best choice for this user.';
  String get matchmakingMessage =>
      isItalian ? 'Il tuo messaggio/proposta' : 'Your message/proposal';
  String get matchmakingPriceHint =>
      isItalian ? 'Indicazione prezzo (opzionale)' : 'Price indication (optional)';
  String get matchmakingPricePlaceholder =>
      isItalian ? 'Es. 50€/mese, o "Pacchetto Premium"' : 'E.g. €50/month, or "Premium package"';
  String get matchmakingSendOffer =>
      isItalian ? 'Invia offerta' : 'Send offer';
  String get matchmakingOfferSent =>
      isItalian
          ? 'Offerta inviata! L\'utente riceverà la tua proposta.'
          : 'Offer sent! The user will receive your proposal.';
  String get matchmakingWithdrawOffer =>
      isItalian ? 'Ritira offerta' : 'Withdraw offer';
  String get matchmakingWithdrawTitle =>
      isItalian ? 'Ritirare l\'offerta?' : 'Withdraw the offer?';
  String get matchmakingWithdrawBody =>
      isItalian
          ? 'La tua offerta verrà marcata come ritirata. Potrai farne una nuova finché la richiesta è aperta.'
          : 'Your offer will be marked as withdrawn. You can make a new one while the request is open.';
  String get matchmakingWithdrawn =>
      isItalian ? 'Offerta ritirata.' : 'Offer withdrawn.';
  String get matchmakingNoOffer =>
      isItalian
          ? 'Non risulta una tua offerta su questa richiesta.'
          : 'No offer of yours found on this request.';
  String get matchmakingUserNotes =>
      isItalian ? 'Note utente:' : 'User notes:';
  String get matchmakingObjectiveLabel =>
      isItalian ? 'Obiettivo:' : 'Goal:';
  String get matchmakingNoAnnouncements =>
      isItalian ? 'Nessun annuncio presente.' : 'No announcements available.';
  String get missingDate => isItalian ? 'Manca data' : 'Missing date';

  // --- Server metrics ---
  String get serverMetricsTitle =>
      isItalian ? 'Metriche server' : 'Server metrics';
  String get serverHealth => isItalian ? 'Stato' : 'Health';
  String get serverLatency => isItalian ? 'Latenza' : 'Latency';
  String get serverErrors => isItalian ? 'Errori' : 'Errors';
  String get serverThroughput => 'Throughput';

  // --- Diet templates ---
  String get dietTemplatesTab =>
      isItalian ? 'Templates Diete' : 'Diet Templates';
  String get dietTemplateUploadCta =>
      isItalian ? 'Carica template' : 'Upload template';
  String get dietTemplateNew =>
      isItalian ? 'Nuovo template dieta' : 'New diet template';
  String get dietTemplateNoneTitle =>
      isItalian ? 'Nessun template caricato' : 'No template uploaded';
  String get dietTemplateNoneSubtitle =>
      isItalian
          ? 'Carica un PDF dieta per crearne uno riutilizzabile'
          : 'Upload a diet PDF to create a reusable one';
  String get dietTemplateAiWarning =>
      isItalian
          ? 'Il PDF verrà parsato dall\'AI (può richiedere 30-60s).'
          : 'The PDF will be parsed by AI (may take 30-60s).';
  String get dietTemplateNameHint =>
      isItalian
          ? 'Nome template (es. "Dieta dimagrante 1500kcal")'
          : 'Template name (e.g. "Weight loss 1500kcal")';
  String get dietTemplateCreated =>
      isItalian ? 'Template creato ✓' : 'Template created ✓';
  String get dietTemplateAssigned =>
      isItalian ? 'Dieta assegnata ✓' : 'Diet assigned ✓';
  String get dietTemplateDeleted =>
      isItalian ? 'Template eliminato' : 'Template deleted';
  String get dietTemplateDeleteConfirm =>
      isItalian
          ? 'Vuoi eliminare il template? L\'azione è irreversibile.'
          : 'Delete this template? This action is irreversible.';
  String get dietTemplateUseDescription =>
      isItalian
          ? 'Verrà assegnata una copia come dieta corrente del cliente. Il template originale resta riutilizzabile.'
          : 'A copy will be assigned as the client\'s current diet. The original template remains reusable.';

  // --- Workout reminder (client) ---
  String get workoutReminderTitle =>
      isItalian ? 'Promemoria allenamento' : 'Workout reminder';
  String get reminderEnabled => isItalian ? 'Attivo' : 'Active';
  String get reminderNotificationsOn =>
      isItalian
          ? 'Riceverai notifica nei giorni selezionati'
          : 'You\'ll receive a notification on selected days';
  String get reminderNotificationsOff =>
      isItalian ? 'Nessuna notifica' : 'No notifications';
  String get reminderTime => isItalian ? 'Orario' : 'Time';
  String get reminderDays => isItalian ? 'Giorni' : 'Days';
  String get reminderSaved =>
      isItalian ? 'Promemoria salvato ✓' : 'Reminder saved ✓';
  String get reminderDisabled =>
      isItalian ? 'Promemoria disattivato' : 'Reminder disabled';

  // --- User detail pane (split view) ---
  String get clientDetailTitle =>
      isItalian ? 'Dettaglio cliente' : 'Client detail';
  String get clientUid => 'UID';
  String get clientCreated =>
      isItalian ? 'Account creato' : 'Account created';
  String get clientLastActivity =>
      isItalian ? 'Ultima attività' : 'Last activity';
  String get clientLastDiet =>
      isItalian ? 'Ultima dieta' : 'Last diet';
  String get clientHistory => isItalian ? 'STORICO' : 'HISTORY';
  String get closeUpper => isItalian ? 'CHIUDI' : 'CLOSE';
  String get clientUnnamed =>
      isItalian ? 'Senza nome' : 'No name';

  // --- Nutritional calculator ---
  String get calculatorTitle =>
      isItalian ? 'Calcolatrice Nutrizionale' : 'Nutritional Calculator';
  String get calculatorDescription =>
      isItalian
          ? 'Inserisci gli ingredienti e le quantità per calcolare i macro totali del pasto.'
          : 'Enter ingredients and quantities to calculate the meal\'s total macros.';
  String get calculatorIngredients =>
      isItalian ? 'Ingredienti' : 'Ingredients';
  String get calculatorAddIngredient =>
      isItalian ? 'Aggiungi ingrediente' : 'Add ingredient';
  String get calculatorIngredientName =>
      isItalian ? 'Nome ingrediente' : 'Ingredient name';
  String get calculatorIngredientHint =>
      isItalian ? 'es. Pollo' : 'e.g. Chicken';
  String get calculatorQuantity =>
      isItalian ? 'Quantità (g)' : 'Quantity (g)';
  String get calculatorKcal100 => 'Kcal/100g';
  String get calculatorProt100 =>
      isItalian ? 'Prot/100g' : 'Prot/100g';
  String get calculatorCarb100 =>
      isItalian ? 'Carb/100g' : 'Carb/100g';
  String get calculatorFat100 =>
      isItalian ? 'Grassi/100g' : 'Fat/100g';
  String get calculatorKcal => 'Kcal';
  String get calculatorProtein =>
      isItalian ? 'Proteine' : 'Protein';
  String get calculatorCarbs =>
      isItalian ? 'Carboidrati' : 'Carbs';
  String get calculatorFat => isItalian ? 'Grassi' : 'Fat';
  String get remove => isItalian ? 'Rimuovi' : 'Remove';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['it', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
