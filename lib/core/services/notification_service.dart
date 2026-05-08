import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart';
import 'messaging_service.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();

      const androidSettings =
          AndroidInitializationSettings('@mipmap/launcher_icon');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      final result = await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _onTap,
      );
      _initialized = true;
      debugPrint('NotificationService initialized: $result');
    } catch (e) {
      debugPrint('NotificationService init FAILED: $e');
    }
  }

  /// Local-notification tap handler. The payload is the JSON-encoded
  /// `RemoteMessage.data` map (set in MessagingService) for FCM-driven
  /// foreground banners; locally-scheduled reminders pass their own
  /// `{type: ...}` payload so they hit the same routing table.
  static void _onTap(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        MessagingService.routeFromData(decoded);
      }
    } catch (e) {
      debugPrint('local-notification payload decode failed: $e');
    }
  }

  static Future<bool> requestPermission() async {
    if (!_initialized) await initialize();

    try {
      // iOS
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('iOS notification permission: $granted');
        return granted ?? false;
      }

      // Android 13+
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        debugPrint('Android notification permission: $granted');
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('requestPermission error: $e');
    }

    return true;
  }

  // ─── Warranty expiry notifications ────────────────────────

  static Future<void> scheduleWarrantyReminder({
    required String warrantyId,
    required String merchantName,
    required DateTime expiryDate,
    int daysBefore = 30,
  }) async {
    if (!_initialized) await initialize();

    // Schedule at 9:00 AM on the notification day
    final notifyDay = expiryDate.subtract(Duration(days: daysBefore));
    final notifyDate = DateTime(
        notifyDay.year, notifyDay.month, notifyDay.day, 9, 0);

    if (notifyDate.isBefore(DateTime.now())) {
      debugPrint('Warranty reminder skipped — date in past: $notifyDate');
      return;
    }

    final id = warrantyId.hashCode & 0x7FFFFFFF;

    try {
      await _plugin.zonedSchedule(
        id,
        'Gwarancja wygasa wkrótce',
        'Gwarancja z $merchantName wygasa za $daysBefore dni (${_formatDate(expiryDate)})',
        _toTZDateTime(notifyDate),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'warranty_reminders',
            'Przypomnienia o gwarancjach',
            channelDescription:
                'Powiadomienia o wygasających gwarancjach',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: null,
        payload: jsonEncode({
          'type': 'warranty_expiring',
          'warranty_id': warrantyId,
        }),
      );
      debugPrint(
          'Scheduled warranty reminder #$id for $merchantName on $notifyDate');
    } catch (e) {
      debugPrint('scheduleWarrantyReminder error: $e');
    }
  }

  // ─── Streak reminder ─────────────────────────────────────

  static Future<void> scheduleDailyStreakReminder({
    required int hour,
    required int minute,
  }) async {
    if (!_initialized) await initialize();
    const id = 999001;

    try {
      await _plugin.zonedSchedule(
        id,
        'Nie przerwij serii!',
        'Zeskanuj paragon, aby utrzymać swoją serię dni w ParagonPro',
        _nextInstanceOfTime(hour, minute),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'streak_reminders',
            'Przypomnienia o serii',
            channelDescription: 'Codzienne przypomnienia o skanowaniu',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint('Scheduled daily streak reminder at $hour:$minute');
    } catch (e) {
      debugPrint('scheduleDailyStreakReminder error: $e');
    }
  }

  // ─── Retention schedulers (F3-T1, client-side) ───────────────

  /// Schedule a notification N days before [trialEndsAt] reminding the
  /// user their Premium trial is wrapping up. ID is stable so calling
  /// twice replaces the previous schedule rather than stacking.
  static Future<void> scheduleTrialEndReminder({
    required DateTime trialEndsAt,
    int daysBefore = 3,
  }) async {
    if (!_initialized) await initialize();
    final id = 998000 + daysBefore;
    final fireAt = trialEndsAt.subtract(Duration(days: daysBefore));
    if (fireAt.isBefore(DateTime.now())) return;

    try {
      await _plugin.cancel(id);
      await _plugin.zonedSchedule(
        id,
        daysBefore <= 1
            ? 'Twój trial Premium kończy się jutro'
            : 'Twój trial Premium kończy się za $daysBefore dni',
        'Zachowaj nielimitowane skanowanie i pełną integrację KSeF — '
            'zarządzaj subskrypcją w aplikacji.',
        TZDateTime.from(fireAt, local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'trial_reminders',
            'Przypomnienia o trialu',
            channelDescription: 'Powiadomienia o końcu okresu próbnego Premium',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: jsonEncode(const {'type': 'subscription_expiring'}),
      );
      debugPrint('Scheduled trial reminder #$id for $fireAt');
    } catch (e) {
      debugPrint('scheduleTrialEndReminder error: $e');
    }
  }

  /// Schedule a recurring monthly summary on the 1st at the given hour.
  static Future<void> scheduleMonthlySummary({int hour = 10}) async {
    if (!_initialized) await initialize();
    const id = 998500;

    final now = DateTime.now();
    var fire = DateTime(now.year, now.month + 1, 1, hour);
    if (fire.isBefore(now)) {
      fire = DateTime(fire.year, fire.month + 1, 1, hour);
    }

    try {
      await _plugin.cancel(id);
      await _plugin.zonedSchedule(
        id,
        'Twoje podsumowanie miesiąca jest gotowe',
        'Sprawdź ile wydałeś w tym miesiącu i porównaj kategorie.',
        TZDateTime.from(fire, local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'monthly_summary',
            'Podsumowanie miesięczne',
            channelDescription: 'Comiesięczne podsumowanie wydatków',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
        payload: jsonEncode(const {'type': 'monthly_report'}),
      );
      debugPrint('Scheduled monthly summary at $fire');
    } catch (e) {
      debugPrint('scheduleMonthlySummary error: $e');
    }
  }

  // ─── Instant notification (KSeF, achievements) ───────────

  /// Check if notification permission is granted
  static Future<bool> isPermissionGranted() async {
    if (!_initialized) await initialize();
    try {
      final pending = await _plugin.pendingNotificationRequests();
      debugPrint('Pending notifications: ${pending.length}');
      return true;
    } catch (e) {
      debugPrint('Permission check failed: $e');
      return false;
    }
  }

  static Future<void> showInstant({
    required String title,
    required String body,
    String channelId = 'general',
    String channelName = 'Ogólne',
  }) async {
    if (!_initialized) await initialize();

    final id = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;
    debugPrint('Showing instant notification #$id: $title');

    try {
      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            importance: Importance.max,
            priority: Priority.max,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
      debugPrint('Instant notification sent OK');
    } catch (e) {
      debugPrint('showInstant error: $e');
    }
  }

  // ─── Cancel ──────────────────────────────────────────────

  static Future<void> cancelWarrantyReminder(String warrantyId) async {
    final id = warrantyId.hashCode & 0x7FFFFFFF;
    await _plugin.cancel(id);
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ─── Helpers ─────────────────────────────────────────────

  static TZDateTime _toTZDateTime(DateTime dt) {
    return TZDateTime.from(dt, local);
  }

  static TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = TZDateTime.now(local);
    var scheduled =
        TZDateTime(local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
