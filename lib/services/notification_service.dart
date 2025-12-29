import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Initialize the notification plugin
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize Timezones
    tz.initializeTimeZones();

    // Android Settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS Settings
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap logic here
      },
    );

    _isInitialized = true;
  }

  // --- FEATURE 16: DAILY REMINDER ---
  Future<void> scheduleDailyMealReminder() async {
    try {
      await _notificationsPlugin.zonedSchedule(
        0, // ID
        'MealMate Daily',
        'Will you eat lunch today? Check the meal plan!',
        _nextInstanceOfEightAM(),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminders',
            'Daily Reminders',
            channelDescription: 'Daily reminders for meal attendance',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        // CRITICAL FIX: Changed from exactAllowWhileIdle to inexactAllowWhileIdle
        // This prevents the "exact_alarms_not_permitted" crash on Android 12+
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      print('Error scheduling notification: $e');
      // App continues running even if notification scheduling fails
    }
  }

  // Helper to calculate 8:00 AM
  tz.TZDateTime _nextInstanceOfEightAM() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
      tz.TZDateTime(tz.local, now.year, now.month, now.day, 1, 50);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  // --- INSTANT NOTIFICATION ---
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await _notificationsPlugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'general_channel',
          'General Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }
}