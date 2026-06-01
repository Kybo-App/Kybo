import 'package:flutter/material.dart';

/// Provider per la gestione della lingua dell'app (IT / EN)
class LanguageProvider extends ChangeNotifier {
  static final LanguageProvider _instance = LanguageProvider._internal();
  factory LanguageProvider() => _instance;
  LanguageProvider._internal();

  Locale _locale = const Locale('it');
  Locale get locale => _locale;
  bool get isItalian => _locale.languageCode == 'it';

  void toggleLanguage() {
    _locale = isItalian ? const Locale('en') : const Locale('it');
    notifyListeners();
  }
}
