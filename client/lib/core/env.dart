import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get fileName => kReleaseMode ? ".env.prod" : ".env";

  static Future<void> init() async {
    try {
      await dotenv.load(fileName: fileName);
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

    // 2. Fallback per Emulatore Android (10.0.2.2 = localhost del PC)
    // Usa defaultTargetPlatform per compatibilità Web
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    // 3. Fallback standard (iOS / Web / Desktop)
    return 'http://127.0.0.1:8000';
  }

  static bool get isProd => kReleaseMode || dotenv.env['IS_PROD'] == 'true';
}
