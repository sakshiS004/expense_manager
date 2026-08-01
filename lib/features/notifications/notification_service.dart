import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz_data.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
  }

  Future<void> requestPermissions() async {
    final androidGranted = await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    debugPrint('NotificationService: notification permission granted = $androidGranted');
  }

  Future<void> scheduleDailyReminders() async {
    await _scheduleDaily(
      id: 1,
      hour: 9,
      minute: 0,
      title: 'Morning check-in',
      body: "Don't forget to log today's expenses.",
    );
    await _scheduleDaily(
      id: 2,
      hour: 14,
      minute: 0,
      title: 'Midday reminder',
      body: 'Add any purchases from this morning.',
    );
    await _scheduleDaily(
      id: 3,
      hour: 20,
      minute: 30,
      title: 'Evening wrap-up',
      body: "Log today's spending before you forget.",
    );
  }

  Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        _nextInstanceOf(hour, minute),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminders',
            'Daily Reminders',
            channelDescription: 'Reminders to log your income and expenses',
            importance: Importance.defaultImportance,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      // On Android 12+, exactAllowWhileIdle requires the SCHEDULE_EXACT_ALARM
      // permission. If it isn't granted, this throws and every reminder
      // silently fails to schedule — fall back to an inexact schedule
      // instead of losing the reminder entirely.
      debugPrint('NotificationService: exact schedule failed for id=$id ($e), falling back to inexact');
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          _nextInstanceOf(hour, minute),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'daily_reminders',
              'Daily Reminders',
              channelDescription: 'Reminders to log your income and expenses',
              importance: Importance.defaultImportance,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (e2) {
        debugPrint('NotificationService: inexact fallback also failed for id=$id ($e2)');
      }
    }
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  /// Alias kept for call sites (e.g. settings_screen.dart) that expect
  /// this name specifically.
  Future<void> cancelAllNotifications() => cancelAll();
}
