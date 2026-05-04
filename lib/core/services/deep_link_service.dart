import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

/// Receives universal links + custom-scheme deep links and routes them
/// into go_router. Handles both cold start (initial URI when the app
/// is launched from a link) and warm start (URIs while running).
///
/// Supported URLs (more can be added centrally in [_resolve]):
/// - `https://paragonpro.app/receipt/{id}`        → /receipts (with hash)
/// - `https://paragonpro.app/warranty/{id}`       → /warranties
/// - `https://paragonpro.app/challenge/{id}`      → /
/// - `paragonpro://invite?code=ABC123`            → /register?invite=ABC123
class DeepLinkService {
  DeepLinkService._();

  static final _appLinks = AppLinks();
  static StreamSubscription<Uri>? _sub;
  static GoRouter? _router;

  /// Call once after the GoRouter is built — typically from
  /// ParagonProApp.initState or the routerProvider.
  static Future<void> attach(GoRouter router) async {
    _router = router;

    // Handle the URI that launched the app, if any.
    try {
      final initial = await _appLinks.getInitialAppLink();
      if (initial != null) _handle(initial);
    } catch (e) {
      debugPrint('DeepLinkService initial uri failed: $e');
    }

    // Handle subsequent URIs while the app is alive.
    _sub?.cancel();
    _sub = _appLinks.uriLinkStream.listen(
      _handle,
      onError: (Object e) {
        debugPrint('DeepLinkService stream error: $e');
      },
    );
  }

  static void detach() {
    _sub?.cancel();
    _sub = null;
    _router = null;
  }

  static void _handle(Uri uri) {
    final route = _resolve(uri);
    if (route == null) return;
    debugPrint('DeepLink → $route');
    _router?.go(route);
  }

  /// Pure mapping from URI to in-app route. Public so it can be tested
  /// without a real router.
  @visibleForTesting
  static String? resolveForTest(Uri uri) => _resolve(uri);

  static String? _resolve(Uri uri) {
    // OAuth callback for Google sign-in lives on the same scheme — let
    // the auth library handle it instead of routing into the app.
    if (uri.scheme.startsWith('com.googleusercontent') ||
        uri.path.contains('oauth2redirect')) {
      return null;
    }

    // App Store / Supabase auth recovery URLs — let supabase_flutter
    // handle them, do not redirect.
    if (uri.host == 'login-callback' ||
        uri.path.contains('auth/callback')) {
      return null;
    }

    final segments = uri.pathSegments;
    if (segments.isEmpty && uri.host.isEmpty) return null;

    if (segments.contains('receipt') || uri.host == 'receipt') {
      return '/receipts';
    }
    if (segments.contains('warranty') || uri.host == 'warranty') {
      return '/'; // warranties tab on dashboard
    }
    if (segments.contains('invite') || uri.host == 'invite') {
      final code = uri.queryParameters['code'];
      return code == null ? '/register' : '/register?invite=$code';
    }
    if (segments.contains('paywall') ||
        segments.contains('pricing') ||
        uri.host == 'paywall') {
      return '/pricing';
    }
    return null;
  }
}
