import 'package:flutter/material.dart';

/// Kybo Admin - Sistema di localizzazione (italiano + inglese)
/// Aggiungere nuove chiavi in AppLocalizations e nei delegate _it / _en

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  bool get isItalian => locale.languageCode == 'it';

  // ───────────────────────────────────────────────────────────────
  // NAVIGATION
  // ───────────────────────────────────────────────────────────────
  String get navUsers => isItalian ? 'Utenti' : 'Users';
  String get navChat => 'Chat';
  String get navCalculator => isItalian ? 'Calcolatrice' : 'Calculator';
  String get navAnalytics => 'Analytics';
  String get navReports => isItalian ? 'Report' : 'Reports';
  String get navSettings => isItalian ? 'Impostazioni' : 'Settings';
  String get navGdpr => 'GDPR';
  String get navAuditLog => isItalian ? 'Audit Log' : 'Audit Log';

  // ───────────────────────────────────────────────────────────────
  // COMMON
  // ───────────────────────────────────────────────────────────────
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

  // ───────────────────────────────────────────────────────────────
  // AUTH
  // ───────────────────────────────────────────────────────────────
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

  // ───────────────────────────────────────────────────────────────
  // DASHBOARD
  // ───────────────────────────────────────────────────────────────
  String get adminPanel => isItalian ? 'Admin Panel' : 'Admin Panel';
  String get darkMode => isItalian ? 'Modalità Scura' : 'Dark Mode';
  String get lightMode => isItalian ? 'Modalità Chiara' : 'Light Mode';

  // ───────────────────────────────────────────────────────────────
  // GLOBAL SEARCH
  // ───────────────────────────────────────────────────────────────
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

  // ───────────────────────────────────────────────────────────────
  // KEYBOARD SHORTCUTS DIALOG
  // ───────────────────────────────────────────────────────────────
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

  // ───────────────────────────────────────────────────────────────
  // USER MANAGEMENT
  // ───────────────────────────────────────────────────────────────
  String get newUser => isItalian ? 'Nuovo Utente' : 'New User';
  String get searchUser =>
      isItalian ? 'Cerca utente per nome o email...' : 'Search user by name or email...';
  String get allRoles => isItalian ? 'Tutti i ruoli' : 'All roles';
  String get syncUsers => isItalian ? 'Sincronizza' : 'Sync';
  String get noUsersFound =>
      isItalian ? 'Nessun utente trovato' : 'No users found';

  // ───────────────────────────────────────────────────────────────
  // LANGUAGE
  // ───────────────────────────────────────────────────────────────
  String get language => isItalian ? 'Lingua' : 'Language';
  String get italian => isItalian ? 'Italiano' : 'Italian';
  String get english => isItalian ? 'Inglese' : 'English';
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
