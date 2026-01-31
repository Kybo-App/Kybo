import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'dark_mode';
  static const String _themeSetKey = 'theme_set'; // Per sapere se l'utente ha già scelto

  bool _isDarkMode = false;
  bool _isInitialized = false;
  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final hasUserSetTheme = prefs.getBool(_themeSetKey) ?? false;

    if (hasUserSetTheme) {
      // Utente ha già scelto, usa la sua preferenza
      _isDarkMode = prefs.getBool(_themeKey) ?? false;
    } else {
      // Prima apertura: usa tema del sistema
      final brightness = SchedulerBinding.instance.platformDispatcher.platformBrightness;
      _isDarkMode = brightness == Brightness.dark;
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
    await prefs.setBool(_themeSetKey, true); // Marca che l'utente ha scelto
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
    await prefs.setBool(_themeSetKey, true);
    notifyListeners();
  }
}
