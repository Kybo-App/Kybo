// Gestisce deep link e shortcuts Siri/App Actions emettendo target di navigazione su stream.
// getNavigationTarget — mappa un URI a un NavTarget; getInviteCode — estrae il codice invito da URI.
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

class NavTarget {
  static const String diet = 'diet';
  static const String suggestions = 'suggestions';
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
    return null;
  }

  static String? getInviteCode(Uri? uri) {
    if (uri == null) return null;
    if (uri.path.contains('invite') || uri.host == 'invite') {
      return uri.queryParameters['code'];
    }
    return null;
  }
}
