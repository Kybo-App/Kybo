// Rileva dispositivi jailbroken/rooted tramite safe_device e logga l'esito su Firebase Analytics.
import 'package:flutter/foundation.dart';
import 'package:safe_device/safe_device.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class JailbreakService {
  static final JailbreakService _instance = JailbreakService._internal();
  factory JailbreakService() => _instance;
  JailbreakService._internal();

  bool? _isJailbroken;
  bool? _isRealDevice;

  Future<bool> checkDevice() async {
    try {
      _isJailbroken = await SafeDevice.isJailBroken;
      _isRealDevice = await SafeDevice.isRealDevice;

      debugPrint('🔐 Device Security Check:');
      debugPrint('  Jailbroken/Rooted: $_isJailbroken');
      debugPrint('  Real Device: $_isRealDevice');

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
      return false;
    }
  }

  bool get isJailbroken => _isJailbroken ?? false;

  bool get isRealDevice => _isRealDevice ?? true;

  bool get isDeviceAtRisk {
    return isJailbroken;
  }
}
