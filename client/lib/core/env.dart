// Carica variabili d'ambiente dal file .env o .env.prod in base al flavor dell'app.
// apiUrl — restituisce l'URL dell'API con priorità al file .env, poi fallback hardcoded per prod/dev.
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static const String _flavor = String.fromEnvironment(
    'FLUTTER_APP_FLAVOR',
    defaultValue: 'dev',
  );

  static String get fileName => _flavor == 'prod' ? ".env.prod" : ".env";

  static Future<void> init() async {
    try {
      await dotenv.load(fileName: fileName);
      debugPrint("Loaded env file: $fileName (flavor: $_flavor)");
    } catch (e) {
      debugPrint("Errore caricamento $fileName: $e");
    }
  }

  static String get apiUrl {
    final envUrl = dotenv.env['API_URL'];
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl;
    }

    if (isProd) {
      return 'https://kybo-prod.onrender.com';
    }
    return 'https://kybo-test.onrender.com';
  }

  static bool get isProd => _flavor == 'prod';
}
