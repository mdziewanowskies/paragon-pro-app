import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
    _initialized = true;
    debugPrint('NotificationService initialized');
  }

  static Future<bool> requestPermission() async {
    // iOS
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    // Android 13+
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
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
    final notifyDate =
        expiryDate.subtract(Duration(days: daysBefore));

    if (notifyDate.isBefore(DateTime.now())) return;

    final id = warrantyId.hashCode & 0x7FFFFFFF;

    await _plugin.zonedSchedule(
      id,
      'Gwarancja wygasa wkrótce',
      'Gwarancja z $merchantName wygasa za $daysBefore dni (${_formatDate(expiryDate)})',
      _toTZDateTime(notifyDate),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'warranty_reminders',
          'Przypomnienia o gwarancjach',
          channelDescription: 'Powiadomienia o wygasających gwarancjach',
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
    );

    debugPrint(
        'Scheduled warranty reminder for $merchantName on ${notifyDate.toIso8601String()}');
  }

  // ─── Streak reminder ─────────────────────────────────────

  static Future<void> scheduleDailyStreakReminder({
    required int hour,
    required int minute,
  }) async {
    const id = 999001;

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
  }

  // ─── Instant notification (KSeF, achievements) ───────────

  static Future<void> showInstant({
    required String title,
    required String body,
    String channelId = 'general',
    String channelName = 'Ogólne',
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;

    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
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
    var scheduled = TZDateTime(local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
