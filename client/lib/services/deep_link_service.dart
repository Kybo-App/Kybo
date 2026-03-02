// Gestisce deep link e shortcuts Siri/App Actions emettendo target di navigazione su stream.
// getNavigationTarget — mappa un URI a un NavTarget; getInviteCode — estrae il codice invito da URI.
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

class NavTarget {
  static const String diet = 'diet';
  static const String suggestions = 'suggestions';
  static const String shoppingList = 'shopping_list';
}

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  final StreamController<String> _navigationController =
      StreamController<String>.broadcast();

  Stream<String> get navigationStream => _navigationController.stream;

  Future<Uri?> init() async {
    try {
      final initialLink = await _appLinks.getInitialLink();
      _listenToLinks();
      return initialLink;
    } catch (e) {
      debugPrint("DeepLink Init Error: $e");
      return null;
    }
  }

  void _listenToLinks() {
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      debugPrint("DeepLink Received: $uri");
      final target = getNavigationTarget(uri);
      if (target != null) {
        _navigationController.add(target);
      }
    }, onError: (err) {
      debugPrint("DeepLink Stream Error: $err");
    });
  }

  void dispose() {
    _linkSubscription?.cancel();
    _navigationController.close();
  }

  static String? getNavigationTarget(Uri? uri) {
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (host == NavTarget.diet) return NavTarget.diet;
    if (host == NavTarget.suggestions) return NavTarget.suggestions;
    // kybo.app/list?id=XXX  oppure  kybo://list?id=XXX
    if (uri.path.contains('/list') || host == 'list') {
      return NavTarget.shoppingList;
    }
    return null;
  }

  /// Estrae lo share ID da un link lista condivisa.
  /// Accetta: kybo.app/list?id=XXX  oppure  kybo://list?id=XXX
  static String? getSharedListId(Uri? uri) {
    if (uri == null) return null;
    final isListLink = uri.path.contains('/list') || uri.host == 'list';
    if (!isListLink) return null;
    final id = uri.queryParameters['id'];
    // [SECURITY] Sanity check: solo caratteri URL-safe, max 20 chars
    if (id == null || id.isEmpty || id.length > 20) return null;
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) return null;
    return id;
  }

  static String? getInviteCode(Uri? uri) {
    if (uri == null) return null;
    if (uri.path.contains('invite') || uri.host == 'invite') {
      final code = uri.queryParameters['code'];
      // [SECURITY] Cap a 64 caratteri: evita DoS da deep link con input abnormemente lunghi.
      if (code != null && code.length > 64) return null;
      return code;
    }
    return null;
  }
}
