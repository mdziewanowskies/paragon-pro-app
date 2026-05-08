import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        debugPrint('FCM message opened: ${message.data}');
      });

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
        payload: m.data.toString(),
      );
    } catch (e) {
      debugPrint('local-notification render failed: $e');
    }
  }
}
