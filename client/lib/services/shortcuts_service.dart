import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Servizio per donare NSUserActivity shortcuts a Siri (iOS).
/// Su Android i shortcuts sono dichiarativi (res/xml/shortcuts.xml) — nessuna azione richiesta.
class ShortcutsService {
  static const _channel = MethodChannel('kybo/shortcuts');

  // Identificatori activity
  static const String dietActivity = 'it.kybo.app.viewDiet';
  static const String suggestionsActivity = 'it.kybo.app.viewSuggestions';

  /// Dona uno shortcut Siri per la schermata aperta.
  /// Chiamare da initState() delle schermate principali su iOS.
  Future<void> donateShortcut(String activityType) async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod('donateShortcut', activityType);
      debugPrint('✅ Shortcut donato: $activityType');
    } catch (e) {
      debugPrint('⚠️ ShortcutsService error: $e');
    }
  }
}
