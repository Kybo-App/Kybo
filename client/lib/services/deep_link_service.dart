import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

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
      // Handle foreground links if needed via a callback or stream controller
    }, onError: (err) {
      debugPrint("DeepLink Stream Error: $err");
    });
  }

  void dispose() {
    _linkSubscription?.cancel();
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
