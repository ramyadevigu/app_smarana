import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const windowsSettings = WindowsInitializationSettings(
      appName: 'Reminder',
      appUserModelId: 'com.ramyadevi.reminder',
      guid: '8f3c1a72-7d8a-4c1f-9c65-2f6a4e9b12a7',
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      windows: windowsSettings,
    );

    await _notifications.initialize(settings: initializationSettings);
  }

  Future<void> showTestNotification() async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails('reminders', 'Reminders'),
      windows: WindowsNotificationDetails(),
    );

    await _notifications.show(
      id: 1,
      title: 'Reminder',
      body: 'This is a test reminder.',
      notificationDetails: details,
    );
  }
}
