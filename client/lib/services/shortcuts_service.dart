// Dona NSUserActivity shortcuts a Siri su iOS tramite MethodChannel.
// Su Android i shortcuts sono dichiarativi (res/xml/shortcuts.xml) e non richiedono azioni runtime.
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class ShortcutsService {
  static const _channel = MethodChannel('kybo/shortcuts');

  static const String dietActivity = 'it.kybo.app.viewDiet';
  static const String suggestionsActivity = 'it.kybo.app.viewSuggestions';

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
