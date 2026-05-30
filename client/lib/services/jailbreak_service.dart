// Rileva dispositivi jailbroken/rooted tramite safe_device e logga l'esito su Firebase Analytics.
import 'package:flutter/foundation.dart';
import 'package:safe_device/safe_device.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class JailbreakService {
  static final JailbreakService _instance = JailbreakService._internal();
  factory JailbreakService() => _instance;
  JailbreakService._internal();

  Future<bool> checkDevice() async {
    try {
      final isJailbroken = await SafeDevice.isJailBroken;
      final isRealDevice = await SafeDevice.isRealDevice;

      debugPrint('🔐 Device Security Check:');
      debugPrint('  Jailbroken/Rooted: $isJailbroken');
      debugPrint('  Real Device: $isRealDevice');

      await FirebaseAnalytics.instance.logEvent(
        name: 'device_security_check',
        parameters: {
          'jailbroken': isJailbroken.toString(),
          'real_device': isRealDevice.toString(),
        },
      );

      return isJailbroken;
    } catch (e) {
      debugPrint('⚠️ Jailbreak detection error: $e');
      return false;
    }
  }
}
