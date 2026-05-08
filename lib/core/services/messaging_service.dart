import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Background-isolated handler. Don't touch app state — just log.
  debugPrint('FCM background message: ${message.messageId}');
}

class MessagingService {
  static final _messaging = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static StreamSubscription? _authSub;
  static StreamSubscription<String>? _tokenSub;

  /// Cached most-recent token so we can re-upload on demand without
  /// re-fetching from the platform plugin.
  static String? _lastToken;

  /// Router handle injected after GoRouter is built so push taps can
  /// navigate the app. Wired from `app_router.dart` next to the
  /// `DeepLinkService.attach` call.
  static GoRouter? _router;

  /// Cold-start RemoteMessage captured before the router was attached.
  /// Replayed on first attachRouter() call so a tap from a killed
  /// state still navigates correctly.
  static RemoteMessage? _pendingInitialMessage;

  /// Wires the GoRouter so push taps can navigate. Idempotent — safe
  /// to call repeatedly during hot reload.
  static void attachRouter(GoRouter router) {
    _router = router;
    final pending = _pendingInitialMessage;
    if (pending != null) {
      _pendingInitialMessage = null;
      // Defer one frame so the router is ready to receive .go().
      Future.microtask(() => _routeFromMessage(pending));
    }
  }

  /// Public entry point used by the local-notification tap handler in
  /// NotificationService — accepts the raw `data` map decoded from the
  /// notification payload and walks it through the same routing table.
  static void routeFromData(Map<String, dynamic> data) {
    final route = _resolveRoute(data);
    if (route != null) _router?.go(route);
  }

  static void _routeFromMessage(RemoteMessage m) {
    final route = _resolveRoute(m.data);
    if (route == null) {
      debugPrint('FCM message tapped but no route for data=${m.data}');
      return;
    }
    debugPrint('FCM tap → $route');
    _router?.go(route);
  }

  /// Maps a backend notification payload to an in-app route. The
  /// `type` key matches `NotificationKind.fromRaw` conventions; extra
  /// dispatch fields (`warranty_id`, `family_id`) are passed through
  /// as query params for screens that want to focus a specific row.
  static String? _resolveRoute(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    if (type == null) return null;
    switch (type) {
      case 'family_invitation':
      case 'family_receipt':
      case 'removed_from_family':
      case 'family_removed':
        // Family lives under the "Więcej" tab on the dashboard.
        return '/?tab=4';
      case 'warranty_expiring':
        return '/?tab=3';
      case 'ksef_synced':
      case 'ksef_digest':
        return '/?tab=2';
      case 'monthly_report':
      case 'monthly_report_ready':
        return '/';
      case 'achievement_unlocked':
        return '/';
      case 'subscription_expiring':
      case 'subscription_renewed':
        return '/pricing';
      default:
        return null;
    }
  }

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint(
          'FCM permission: ${settings.authorizationStatus.name}');

      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      // Warm tap: app was backgrounded, user tapped notification.
      FirebaseMessaging.onMessageOpenedApp.listen(_routeFromMessage);
      // Cold tap: app was killed. Fire-and-forget — on iOS simulator
      // (no APNs) `getInitialMessage` can hang indefinitely; awaiting
      // here would block `runApp` and leave a white screen. The
      // pending-message stash + attachRouter replay still covers the
      // real-device cold tap once the call resolves.
      unawaited(_messaging.getInitialMessage().then((initial) {
        if (initial == null) return;
        if (_router != null) {
          _routeFromMessage(initial);
        } else {
          _pendingInitialMessage = initial;
        }
      }).catchError((Object e) {
        debugPrint('FCM getInitialMessage failed: $e');
      }));

      // iOS quirk: getToken() can return null on the very first call
      // because the APNs token isn't ready yet. Retry up to 5 times
      // with a 600ms delay before giving up.
      _lastToken = await _fetchTokenWithRetry();
      if (_lastToken != null) {
        await _uploadToken(_lastToken!);
      } else {
        debugPrint('FCM initial token unavailable — '
            'will retry on auth state change / token refresh');
      }

      _tokenSub?.cancel();
      _tokenSub = _messaging.onTokenRefresh.listen((t) async {
        _lastToken = t;
        debugPrint('FCM token refreshed');
        await _uploadToken(t);
      });

      _authSub?.cancel();
      _authSub =
          SupabaseService.auth.onAuthStateChange.listen((event) async {
        // React to anything that means "we now have a user we didn't
        // have before". `initialSession` fires on cold start with a
        // restored session — without it, returning users never get
        // their token re-uploaded and `send-native-push` has nothing
        // to target.
        final isNewSession = event.event == AuthChangeEvent.signedIn ||
            event.event == AuthChangeEvent.initialSession ||
            event.event == AuthChangeEvent.tokenRefreshed;
        if (isNewSession && SupabaseService.auth.currentUser != null) {
          debugPrint(
              'Auth ${event.event.name} — uploading FCM token');
          final t = _lastToken ?? await _fetchTokenWithRetry();
          _lastToken = t;
          if (t != null) await _uploadToken(t);
        }
      });

      _initialized = true;
    } catch (e) {
      debugPrint('MessagingService init failed: $e');
    }
  }

  /// Public re-bind. Useful as a manual 'register me for push' lever
  /// from settings, or after the user grants permission later.
  static Future<bool> registerCurrentDevice() async {
    final t = await _fetchTokenWithRetry();
    _lastToken = t;
    if (t == null) return false;
    return await _uploadToken(t);
  }

  static Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('FCM getToken failed: $e');
      return null;
    }
  }

  static Future<String?> _fetchTokenWithRetry({
    int attempts = 5,
    Duration delay = const Duration(milliseconds: 600),
  }) async {
    // iOS quirk: getToken() throws apns-token-not-set until APNs has
    // registered the device. Wait on getAPNSToken() first — Firebase
    // exposes that handshake explicitly.
    if (!kIsWeb && Platform.isIOS) {
      for (var i = 0; i < attempts; i++) {
        try {
          final apns = await _messaging.getAPNSToken();
          if (apns != null && apns.isNotEmpty) break;
        } catch (e) {
          debugPrint('APNs token attempt ${i + 1}/$attempts failed: $e');
        }
        await Future<void>.delayed(delay);
      }
    }
    for (var i = 0; i < attempts; i++) {
      try {
        final t = await _messaging.getToken();
        if (t != null && t.isNotEmpty) return t;
      } catch (e) {
        debugPrint('FCM getToken attempt ${i + 1}/$attempts failed: $e');
      }
      await Future<void>.delayed(delay);
    }
    return null;
  }

  /// Upserts the device's FCM token into `device_push_tokens` so the
  /// `send-native-push` Edge Function can target this install.
  /// Schema (per backend): id, user_id, token, platform, user_agent,
  /// created_at, last_used_at — RLS lets users see/edit/delete only
  /// their own rows.
  static Future<bool> _uploadToken(String token) async {
    final user = SupabaseService.auth.currentUser;
    if (user == null) {
      debugPrint('FCM token deferred — no user signed in');
      return false;
    }
    final platform = !kIsWeb && Platform.isIOS
        ? 'ios'
        : (!kIsWeb && Platform.isAndroid ? 'android' : 'web');

    final tokenPreview = token.length > 16
        ? '${token.substring(0, 16)}...'
        : token;
    debugPrint(
        'Uploading FCM token: $tokenPreview (platform=$platform, user=${user.id})');

    final ok = await _doUpsert(token, user.id, platform);
    if (ok) return true;

    // Read-back failed. Most likely cause: a row keyed on this token
    // is owned by a previous user (account switch on the same device
    // install), so RLS blocks both the UPDATE on conflict and the
    // SELECT on read-back. Recovery: invalidate the FCM token so the
    // SDK gives us a fresh one that won't collide with the orphan row.
    debugPrint('FCM upsert blocked (likely orphan row from previous '
        'user) — rotating token');
    try {
      await _messaging.deleteToken();
      // iOS needs APNs; on a working device it's already there.
      final fresh = await _fetchTokenWithRetry();
      if (fresh == null || fresh == token) return false;
      _lastToken = fresh;
      return await _doUpsert(fresh, user.id, platform);
    } catch (e) {
      debugPrint('FCM token rotation failed: $e');
      return false;
    }
  }

  static Future<bool> _doUpsert(
      String token, String userId, String platform) async {
    final tokenPreview = token.length > 16
        ? '${token.substring(0, 16)}...'
        : token;
    debugPrint(
        'Uploading FCM token: $tokenPreview (platform=$platform, user=$userId)');
    try {
      await SupabaseService.client.from('device_push_tokens').upsert(
        {
          'user_id': userId,
          'token': token,
          'platform': platform,
          'last_used_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'token',
      );
      final verify = await SupabaseService.client
          .from('device_push_tokens')
          .select('id, user_id, platform')
          .eq('token', token)
          .eq('user_id', userId)
          .maybeSingle();
      if (verify == null) return false;
      debugPrint('FCM token verified row=${verify['id']} for user=$userId');
      return true;
    } catch (e) {
      debugPrint('FCM token upload failed: $e');
      return false;
    }
  }

  static Future<void> _handleForegroundMessage(RemoteMessage m) async {
    final notif = m.notification;
    if (notif == null) return;
    debugPrint('FCM foreground message: ${notif.title}');
    try {
      final androidId = m.messageId?.hashCode ??
          DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;
      await _local.show(
        androidId,
        notif.title,
        notif.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'fcm_foreground',
            'Powiadomienia push',
            channelDescription:
                'Powiadomienia z chmury wyświetlane w trakcie używania aplikacji',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        // JSON-encoded so NotificationService can decode it back to a
        // routable Map<String, dynamic> on tap.
        payload: jsonEncode(m.data),
      );
    } catch (e) {
      debugPrint('local-notification render failed: $e');
    }
  }
}
