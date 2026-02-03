import 'package:flutter/foundation.dart';
import 'package:safe_device/safe_device.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Servizio per rilevare dispositivi jailbroken/rooted
class JailbreakService {
  static final JailbreakService _instance = JailbreakService._internal();
  factory JailbreakService() => _instance;
  JailbreakService._internal();

  bool? _isJailbroken;
  bool? _isRealDevice;

  /// Controlla se il dispositivo è compromesso
  Future<bool> checkDevice() async {
    try {
      // Esegui i controlli con safe_device
      _isJailbroken = await SafeDevice.isJailBroken;
      _isRealDevice = await SafeDevice.isRealDevice;

      debugPrint('🔐 Device Security Check:');
      debugPrint('  Jailbroken/Rooted: $_isJailbroken');
      debugPrint('  Real Device: $_isRealDevice');

      // Log su Firebase Analytics (must use String or num, not bool)
      await FirebaseAnalytics.instance.logEvent(
        name: 'device_security_check',
        parameters: {
          'jailbroken': (_isJailbroken ?? false).toString(),
          'real_device': (_isRealDevice ?? true).toString(),
        },
      );

      return _isJailbroken ?? false;
    } catch (e) {
      debugPrint('⚠️ Jailbreak detection error: $e');
      // In caso di errore, assume dispositivo sicuro
      return false;
    }
  }

  /// Getter per stato jailbreak
  bool get isJailbroken => _isJailbroken ?? false;

  /// Getter per verificare se è un dispositivo reale
  bool get isRealDevice => _isRealDevice ?? true;

  /// Controlla se il dispositivo è considerato "a rischio"
  bool get isDeviceAtRisk {
    return isJailbroken;
  }
}
