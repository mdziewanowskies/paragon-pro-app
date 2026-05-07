import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // iOS shows banners in foreground only when we ask explicitly;
      // Android always does. We still re-display via flutter_local
      // for visual parity + custom UI later.
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Foreground messages: show a local banner so the user sees
      // them even when the app is in front. Without this, FCM
      // payloads get delivered silently in the foreground.
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        debugPrint('FCM message opened: ${message.data}');
      });

      // Token sync — upload to backend now and on every refresh, and
      // re-upload whenever the auth user changes (so the token follows
      // the right account).
      final initialToken = await _messaging.getToken();
      if (initialToken != null) await _uploadToken(initialToken);

      _tokenSub?.cancel();
      _tokenSub = _messaging.onTokenRefresh.listen(_uploadToken);

      _authSub?.cancel();
      _authSub = SupabaseService.auth.onAuthStateChange.listen((event) async {
        if (SupabaseService.auth.currentUser != null) {
          final t = await _messaging.getToken();
          if (t != null) await _uploadToken(t);
        }
      });

      _initialized = true;
    } catch (e) {
      debugPrint('MessagingService init failed: $e');
    }
  }

  static Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('FCM getToken failed: $e');
      return null;
    }
  }

  /// Upserts the device's FCM token onto the backend so push triggers
  /// can target this install. Table name is `user_devices` matching
  /// the typical Supabase pattern — confirm w/ web team.
  static Future<void> _uploadToken(String token) async {
    final user = SupabaseService.auth.currentUser;
    if (user == null) {
      debugPrint('FCM token deferred — no user signed in');
      return;
    }
    final platform = !kIsWeb && Platform.isIOS
        ? 'ios'
        : (!kIsWeb && Platform.isAndroid ? 'android' : 'web');
    try {
      await SupabaseService.client.from('user_devices').upsert(
        {
          'user_id': user.id,
          'fcm_token': token,
          'platform': platform,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'fcm_token',
      );
      debugPrint('FCM token uploaded for ${user.id} ($platform)');
    } catch (e) {
      debugPrint('FCM token upload failed: $e');
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
