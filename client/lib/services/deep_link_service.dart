import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// Target di navigazione emessi dal navigationStream
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

  // Stream di navigazione per shortcuts Siri / App Actions Android
  final StreamController<String> _navigationController =
      StreamController<String>.broadcast();

  /// Stream che emette NavTarget quando un deep link di navigazione arriva
  Stream<String> get navigationStream => _navigationController.stream;

  /// Initialize deep link listener
  /// Returns the initial link if present
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

  /// Restituisce il target di navigazione da un URI, se riconosciuto.
  /// - kybo://diet → NavTarget.diet
  /// - kybo://suggestions → NavTarget.suggestions
  static String? getNavigationTarget(Uri? uri) {
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (host == NavTarget.diet) return NavTarget.diet;
    if (host == NavTarget.suggestions) return NavTarget.suggestions;
    return null;
  }

  /// Parse invite code from URI
  /// Supported formats:
  /// - kybo://invite?code=123
  /// - https://kybo.app/invite?code=123
  static String? getInviteCode(Uri? uri) {
    if (uri == null) return null;
    // Check path or host depending on scheme
    if (uri.path.contains('invite') || uri.host == 'invite') {
      return uri.queryParameters['code'];
    }
    return null;
  }
}
