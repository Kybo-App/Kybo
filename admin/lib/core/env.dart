// Carica variabili d'ambiente da .env (dev) o .env.prod (release).
// apiUrl — URL base API; isProd — true in release o se IS_PROD=true.
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

  static bool get isProd => kReleaseMode || dotenv.env['IS_PROD'] == 'true';

  static String get apiUrl {
    final envUrl = dotenv.env['API_URL'];
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl;
    }
    return isProd
        ? 'https://kybo-prod.onrender.com'
        : 'https://kybo-test.onrender.com';
  }
}
