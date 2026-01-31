import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  // Flutter imposta automaticamente appFlavor quando usi --flavor
  static const String _flavor = String.fromEnvironment(
    'FLUTTER_APP_FLAVOR',
    defaultValue: 'dev',
  );

  // Usa il flavor per scegliere il file env, non kReleaseMode
  static String get fileName => _flavor == 'prod' ? ".env.prod" : ".env";

  static Future<void> init() async {
    try {
      await dotenv.load(fileName: fileName);
      debugPrint("📁 Loaded env file: $fileName (flavor: $_flavor)");
    } catch (e) {
      debugPrint("Errore caricamento $fileName: $e");
    }
  }

  static String get apiUrl {
    // 1. Priorità al file .env
    final envUrl = dotenv.env['API_URL'];
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl;
    }

    // 2. Fallback hardcoded per Render (come web app)
    if (isProd) {
      return 'https://kybo-prod.onrender.com';
    }
    return 'https://kybo-test.onrender.com';
  }

  static bool get isProd => _flavor == 'prod';
}
