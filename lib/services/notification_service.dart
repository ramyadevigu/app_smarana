import 'dart:async';
import 'dart:convert';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../features/reminders/models/reminder.dart';
import '../utils/recurrence_utils.dart' as recurrence_utils;
import 'reminder_notification_action_callback.dart';
import 'recurring_reminder_alarm_callback.dart';

class ReminderSoundOption {
  const ReminderSoundOption({required this.name, required this.uri});

  final String name;
  final String? uri;
}

final _openedReminderIds = StreamController<String>.broadcast();
String? _initialReminderId;

void _handleNotificationResponse(NotificationResponse response) {
  final reminderId = response.payload;
  if (reminderId != null &&
      reminderId.isNotEmpty &&
      response.actionId == null) {
    _openedReminderIds.add(reminderId);
  }
}

abstract interface class ReminderNotificationScheduler {
  Future<void> scheduleReminder(Reminder reminder);

  Future<void> cancelReminder(String reminderId);
}

abstract interface class NotificationPlatform {
  Future<bool> initialize({required bool requestPermissions});

  Future<void> schedule({
    required int id,
    required DateTime dateTime,
    required String title,
    required String? body,
    required String payload,
    required bool exactAlarmAllowed,
    required String? soundUri,
    required ReminderNotificationMode notificationMode,
    required bool vibrate,
  });

  Future<void> cancel(int id);
}

abstract interface class RecurrenceAlarmPlatform {
  Future<void> initialize();

  Future<void> schedule({
    required DateTime dateTime,
    required int id,
    required String reminderId,
    required bool exactAlarmAllowed,
  });

  Future<void> cancel(int id);
}

class NotificationService implements ReminderNotificationScheduler {
  NotificationService._(
    this._notificationPlatform,
    this._recurrenceAlarmPlatform,
    this._isAndroid,
    this._now,
    this._localTimezone,
  );

  @visibleForTesting
  NotificationService.forTesting({
    required NotificationPlatform notificationPlatform,
    required RecurrenceAlarmPlatform recurrenceAlarmPlatform,
    required bool isAndroid,
    required DateTime Function() now,
    Future<String> Function()? localTimezone,
  }) : this._(
         notificationPlatform,
         recurrenceAlarmPlatform,
         isAndroid,
         now,
         localTimezone ?? _readLocalTimezone,
       );

  static final NotificationService instance = NotificationService._(
    _FlutterLocalNotificationPlatform(),
    _AndroidRecurrenceAlarmPlatform(),
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
    DateTime.now,
    _readLocalTimezone,
  );

  static const _rearmDelay = Duration(seconds: 10);
  static const _notificationIdsKey = 'reminderNotificationIds';
  static const _exactAlarmAllowedKey = 'reminderExactAlarmAllowed';
  static const _soundCatalogChannel = MethodChannel('smarana/reminder_sounds');
  static Future<void> _notificationIdQueue = Future<void>.value();

  final NotificationPlatform _notificationPlatform;
  final RecurrenceAlarmPlatform _recurrenceAlarmPlatform;
  final bool _isAndroid;
  final DateTime Function() _now;
  final Future<String> Function() _localTimezone;
  bool _exactAlarmAllowed = true;

  Stream<String> get openedReminderIds => _openedReminderIds.stream;

  String? takeInitialReminderId() {
    final reminderId = _initialReminderId;
    _initialReminderId = null;
    return reminderId;
  }

  Future<void> initialize() async {
    await _initializeTimezone();
    _exactAlarmAllowed = await _notificationPlatform.initialize(
      requestPermissions: true,
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_exactAlarmAllowedKey, _exactAlarmAllowed);
    if (_isAndroid) {
      await _recurrenceAlarmPlatform.initialize();
    }
  }

  Future<void> initializeInBackground({required bool exactAlarmAllowed}) async {
    await _initializeTimezone();
    _exactAlarmAllowed = exactAlarmAllowed;
    await _notificationPlatform.initialize(requestPermissions: false);
    if (_isAndroid) {
      await _recurrenceAlarmPlatform.initialize();
    }
  }

  Future<List<ReminderSoundOption>> availableAlarmSounds() async {
    try {
      final sounds = await _soundCatalogChannel.invokeListMethod<Object?>(
        'listAlarmSounds',
      );
      if (sounds == null) {
        return const [];
      }

      return [
        for (final sound in sounds)
          if (sound is Map && sound['name'] is String && sound['uri'] is String)
            ReminderSoundOption(
              name: sound['name'] as String,
              uri: sound['uri'] as String,
            ),
      ];
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  /// Keeps one notification and one one-shot Android callback per recurring
  /// reminder. The callback runs after delivery, asks the recurrence engine for
  /// the next valid occurrence, and replaces both schedules. Startup
  /// reconciliation rebuilds these schedules from persisted reminders.
  @override
  Future<void> scheduleReminder(Reminder reminder) async {
    final id = await _notificationIdFor(reminder.id);
    if (_isAndroid) {
      await _recurrenceAlarmPlatform.cancel(id);
    }

    if (!reminder.enabled || reminder.isCompleted) {
      await _notificationPlatform.cancel(id);
      return;
    }

    final now = _now();
    final snoozedUntil = reminder.snoozedUntil;
    final occurrence = snoozedUntil != null && snoozedUntil.isAfter(now)
        ? snoozedUntil
        : reminder.recurrenceRule.type == RecurrenceType.none
        ? (reminder.dateTime.isAfter(now) ? reminder.dateTime : null)
        : recurrence_utils.nextOccurrence(reminder, after: now);
    if (occurrence == null || !occurrence.isAfter(now)) {
      await _notificationPlatform.cancel(id);
      return;
    }

    final description = reminder.description?.trim();
    await _notificationPlatform.schedule(
      id: id,
      dateTime: occurrence,
      title: reminder.title,
      body: description == null || description.isEmpty ? null : description,
      payload: reminder.id,
      exactAlarmAllowed: _exactAlarmAllowed,
      soundUri:
          reminder.notificationMode ==
              ReminderNotificationMode.alarmAndNotification
          ? reminder.soundUri
          : null,
      notificationMode: reminder.notificationMode,
      vibrate: reminder.vibrate,
    );

    if (_isAndroid && reminder.recurrenceRule.type != RecurrenceType.none) {
      await _recurrenceAlarmPlatform.schedule(
        dateTime: occurrence.add(_rearmDelay),
        id: id,
        reminderId: reminder.id,
        exactAlarmAllowed: _exactAlarmAllowed,
      );
    }
  }

  @override
  Future<void> cancelReminder(String reminderId) async {
    final id =
        await _storedNotificationIdFor(reminderId) ??
        _notificationIdHash(reminderId);
    await _notificationPlatform.cancel(id);
    if (_isAndroid) {
      await _recurrenceAlarmPlatform.cancel(id);
    }
    await _releaseNotificationId(reminderId);
  }

  Future<void> _initializeTimezone() async {
    timezone_data.initializeTimeZones();
    if (_isAndroid) {
      timezone.setLocalLocation(timezone.getLocation(await _localTimezone()));
    }
  }

  Future<int> _notificationIdFor(String reminderId) {
    return _runSerializedNotificationIdOperation(() async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      final ids = _readNotificationIds(
        preferences.getString(_notificationIdsKey),
      );
      final storedId = ids[reminderId];
      if (storedId != null) {
        return storedId;
      }

      final usedIds = ids.values.toSet();
      var id = _notificationIdHash(reminderId);
      while (usedIds.contains(id)) {
        id = id == 0x7fffffff ? 1 : id + 1;
      }
      ids[reminderId] = id;
      await _saveNotificationIds(preferences, ids);
      return id;
    });
  }

  Future<int?> _storedNotificationIdFor(String reminderId) {
    return _runSerializedNotificationIdOperation(() async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      return _readNotificationIds(
        preferences.getString(_notificationIdsKey),
      )[reminderId];
    });
  }

  Future<void> _releaseNotificationId(String reminderId) {
    return _runSerializedNotificationIdOperation(() async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      final ids = _readNotificationIds(
        preferences.getString(_notificationIdsKey),
      );
      if (ids.remove(reminderId) == null) {
        return;
      }
      await _saveNotificationIds(preferences, ids);
    });
  }

  Future<void> _saveNotificationIds(
    SharedPreferences preferences,
    Map<String, int> ids,
  ) async {
    final saved = ids.isEmpty
        ? await preferences.remove(_notificationIdsKey)
        : await preferences.setString(_notificationIdsKey, jsonEncode(ids));
    if (!saved) {
      throw StateError('Unable to save notification IDs.');
    }
  }

  Map<String, int> _readNotificationIds(String? encodedIds) {
    if (encodedIds == null || encodedIds.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(encodedIds);
      if (decoded is! Map) {
        return {};
      }

      final ids = <String, int>{};
      final usedIds = <int>{};
      for (final entry in decoded.entries) {
        final id = entry.value;
        if (entry.key is String &&
            id is int &&
            id > 0 &&
            id <= 0x7fffffff &&
            usedIds.add(id)) {
          ids[entry.key as String] = id;
        }
      }
      return ids;
    } on FormatException {
      return {};
    }
  }

  Future<T> _runSerializedNotificationIdOperation<T>(
    Future<T> Function() operation,
  ) {
    final result = _notificationIdQueue.then((_) => operation());
    _notificationIdQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  int _notificationIdHash(String reminderId) {
    var hash = 0x811c9dc5;
    for (final codeUnit in reminderId.codeUnits) {
      hash = ((hash ^ codeUnit) * 0x01000193) & 0xffffffff;
    }

    final id = hash & 0x7fffffff;
    return id == 0 ? 1 : id;
  }
}

Future<String> _readLocalTimezone() async {
  final timezoneInfo = await FlutterTimezone.getLocalTimezone();
  final identifier = timezoneInfo.identifier;

  // Android may return the legacy alias "Asia/Calcutta".
  // The timezone package uses the canonical "Asia/Kolkata" identifier.
  if (identifier == 'Asia/Calcutta') {
    return 'Asia/Kolkata';
  }

  return identifier;
}

class _FlutterLocalNotificationPlatform implements NotificationPlatform {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  @override
  Future<bool> initialize({required bool requestPermissions}) async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      windows: WindowsInitializationSettings(
        appName: 'Reminder',
        appUserModelId: 'com.ramyadevi.reminder',
        guid: '8f3c1a72-7d8a-4c1f-9c65-2f6a4e9b12a7',
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          reminderNotificationActionCallback,
    );
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchResponse?.actionId == null) {
      _initialReminderId = launchResponse?.payload;
    }

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) {
      return true;
    }

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'reminders',
        'Reminders',
        description: 'Scheduled reminder notifications',
        importance: Importance.max,
      ),
    );
    if (!requestPermissions) {
      return true;
    }

    await android.requestNotificationsPermission();
    final exactPermission = await android.requestExactAlarmsPermission();
    return exactPermission != false;
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime dateTime,
    required String title,
    required String? body,
    required String payload,
    required bool exactAlarmAllowed,
    required String? soundUri,
    required ReminderNotificationMode notificationMode,
    required bool vibrate,
  }) async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final channelId = _channelIdFor(
      notificationMode: notificationMode,
      soundUri: soundUri,
      vibrate: vibrate,
    );
    final sound =
        notificationMode == ReminderNotificationMode.alarmAndNotification
        ? UriAndroidNotificationSound(
            soundUri ?? 'content://settings/system/alarm_alert',
          )
        : null;
    final audioUsage =
        notificationMode == ReminderNotificationMode.alarmAndNotification
        ? AudioAttributesUsage.alarm
        : AudioAttributesUsage.notification;
    if (android != null) {
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          channelId,
          notificationMode == ReminderNotificationMode.alarmAndNotification
              ? 'Alarm reminders'
              : 'Notification reminders',
          description: 'Scheduled reminder notifications',
          importance: Importance.max,
          sound: sound,
          enableVibration: vibrate,
          audioAttributesUsage: audioUsage,
        ),
      );
    }

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      payload: payload,
      scheduledDate: timezone.TZDateTime.from(dateTime, timezone.local),
      androidScheduleMode: exactAlarmAllowed
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          notificationMode == ReminderNotificationMode.alarmAndNotification
              ? 'Alarm reminders'
              : 'Notification reminders',
          channelDescription: 'Scheduled reminder notifications',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: sound,
          enableVibration: vibrate,
          audioAttributesUsage: audioUsage,
          additionalFlags:
              notificationMode == ReminderNotificationMode.alarmAndNotification
              ? Int32List.fromList([4])
              : null,
          category:
              notificationMode == ReminderNotificationMode.alarmAndNotification
              ? AndroidNotificationCategory.alarm
              : AndroidNotificationCategory.reminder,
          actions:
              notificationMode == ReminderNotificationMode.alarmAndNotification
              ? const [
                  AndroidNotificationAction('snooze', 'Snooze'),
                  AndroidNotificationAction('dismiss', 'Dismiss'),
                ]
              : null,
        ),
        windows: const WindowsNotificationDetails(),
      ),
    );
  }

  String _channelIdFor({
    required ReminderNotificationMode notificationMode,
    required String? soundUri,
    required bool vibrate,
  }) {
    final value = '${notificationMode.name}|${soundUri ?? 'default'}|$vibrate';
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash = ((hash ^ codeUnit) * 0x01000193) & 0xffffffff;
    }
    return 'reminder_${hash.toRadixString(16)}';
  }

  @override
  Future<void> cancel(int id) async {
    await _plugin.cancel(id: id);
  }
}

class _AndroidRecurrenceAlarmPlatform implements RecurrenceAlarmPlatform {
  @override
  Future<void> initialize() async {
    final initialized = await AndroidAlarmManager.initialize();
    if (!initialized) {
      throw StateError('Unable to initialize Android alarm scheduling.');
    }
  }

  @override
  Future<void> schedule({
    required DateTime dateTime,
    required int id,
    required String reminderId,
    required bool exactAlarmAllowed,
  }) async {
    final scheduled = await AndroidAlarmManager.oneShotAt(
      dateTime,
      id,
      recurringReminderAlarmCallback,
      allowWhileIdle: true,
      exact: exactAlarmAllowed,
      wakeup: true,
      rescheduleOnReboot: true,
      params: {
        'reminderId': reminderId,
        'exactAlarmAllowed': exactAlarmAllowed,
      },
    );
    if (!scheduled) {
      throw StateError('Unable to schedule the next reminder occurrence.');
    }
  }

  @override
  Future<void> cancel(int id) async {
    await AndroidAlarmManager.cancel(id);
  }
}
