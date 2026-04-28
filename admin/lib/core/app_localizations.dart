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
