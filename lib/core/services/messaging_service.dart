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
        // Only react to a fresh session — token refresh / sign-out
        // events fire here too and we don't want to spam.
        if (event.event == AuthChangeEvent.signedIn) {
          debugPrint('Auth signed in — uploading FCM token');
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

  /// Snapshot of the current push state — used by the diagnostic
  /// screen so the user (or us) can see exactly what's broken.
  static Future<PushDiagnostics> diagnostics() async {
    NotificationSettings? settings;
    try {
      settings = await _messaging.getNotificationSettings();
    } catch (_) {}

    String? apns;
    if (!kIsWeb && Platform.isIOS) {
      try {
        apns = await _messaging.getAPNSToken();
      } catch (_) {}
    }

    final fcm = _lastToken ?? await _fetchTokenWithRetry(attempts: 2);
    final user = SupabaseService.auth.currentUser;

    Map<String, dynamic>? backendRow;
    if (user != null && fcm != null) {
      try {
        backendRow = await SupabaseService.client
            .from('device_push_tokens')
            .select('id, platform, last_used_at')
            .eq('user_id', user.id)
            .eq('token', fcm)
            .maybeSingle();
      } catch (_) {}
    }

    return PushDiagnostics(
      platform: kIsWeb
          ? 'web'
          : (Platform.isIOS ? 'ios' : Platform.isAndroid ? 'android' : 'other'),
      authStatus: settings?.authorizationStatus.name ?? 'unknown',
      apnsToken: apns,
      fcmToken: fcm,
      backendRowFound: backendRow != null,
      backendRowId: backendRow?['id'] as String?,
      userId: user?.id,
    );
  }

  /// Sends a test push to *this* user via the same Edge Function the
  /// backend uses for invitations. If push doesn't arrive after this
  /// returns true, the failure is server-side.
  static Future<void> sendTestPushToSelf() async {
    final user = SupabaseService.auth.currentUser;
    if (user == null) {
      throw StateError('Not signed in');
    }
    await SupabaseService.invokeFunction(
      'send-native-push',
      body: {
        'user_ids': [user.id],
        'payload': {
          'title': 'Test push',
          'body': 'Jeśli to widzisz, FCM działa end-to-end.',
          'tag': 'test-push',
        },
      },
    );
  }
}

class PushDiagnostics {
  final String platform;
  final String authStatus;
  final String? apnsToken;
  final String? fcmToken;
  final bool backendRowFound;
  final String? backendRowId;
  final String? userId;

  const PushDiagnostics({
    required this.platform,
    required this.authStatus,
    this.apnsToken,
    this.fcmToken,
    this.backendRowFound = false,
    this.backendRowId,
    this.userId,
  });

  bool get permissionGranted =>
      authStatus == 'authorized' || authStatus == 'provisional';
  bool get hasFcmToken => fcmToken != null && fcmToken!.isNotEmpty;
  bool get hasApnsToken => apnsToken != null && apnsToken!.isNotEmpty;

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

    try {
      // Upsert keyed on token: each FCM token must be unique across
      // installs (a token identifies a single device install). If the
      // user re-installs, FCM gives a new token, so old rows just sit
      // until the backend prunes them.
      await SupabaseService.client.from('device_push_tokens').upsert(
        {
          'user_id': user.id,
          'token': token,
          'platform': platform,
          'last_used_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'token',
      );
      // Read-back verification — confirms the row landed and matches.
      final verify = await SupabaseService.client
          .from('device_push_tokens')
          .select('id, user_id, platform')
          .eq('token', token)
          .maybeSingle();
      if (verify == null) {
        debugPrint('FCM token upsert returned no row on read-back '
            '(RLS may be blocking SELECT)');
        return false;
      }
      debugPrint('FCM token verified row=${verify['id']} for user=${verify['user_id']}');
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
