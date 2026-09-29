import 'package:shared_preferences/shared_preferences.dart';

import '../../reminders/models/reminder.dart';

class ReminderDefaults {
  const ReminderDefaults({
    this.notificationMode = ReminderNotificationMode.alarmAndNotification,
    this.soundUri,
    this.soundName = 'Default',
    this.snoozeDurationMinutes = 10,
    this.vibrate = true,
  });

  final ReminderNotificationMode notificationMode;
  final String? soundUri;
  final String soundName;
  final int snoozeDurationMinutes;
  final bool vibrate;

  ReminderDefaults copyWith({
    ReminderNotificationMode? notificationMode,
    String? soundUri,
    bool clearSoundUri = false,
    String? soundName,
    int? snoozeDurationMinutes,
    bool? vibrate,
  }) {
    return ReminderDefaults(
      notificationMode: notificationMode ?? this.notificationMode,
      soundUri: clearSoundUri ? null : soundUri ?? this.soundUri,
      soundName: soundName ?? this.soundName,
      snoozeDurationMinutes:
          snoozeDurationMinutes ?? this.snoozeDurationMinutes,
      vibrate: vibrate ?? this.vibrate,
    );
  }
}

class ReminderPreferencesStore {
  const ReminderPreferencesStore();

  static const _notificationModeKey = 'defaultReminderNotificationMode';
  static const _soundUriKey = 'defaultReminderSoundUri';
  static const _soundNameKey = 'defaultReminderSoundName';
  static const _snoozeDurationKey = 'defaultReminderSnoozeDuration';
  static const _vibrateKey = 'defaultReminderVibrate';

  Future<ReminderDefaults> loadDefaults() async {
    final preferences = await SharedPreferences.getInstance();
    final modeName = preferences.getString(_notificationModeKey);
    final notificationMode = ReminderNotificationMode.values.firstWhere(
      (mode) => mode.name == modeName,
      orElse: () => ReminderNotificationMode.alarmAndNotification,
    );
    final snoozeDuration = preferences.getInt(_snoozeDurationKey);
    const availableSnoozeDurations = [5, 10, 15, 20, 30];

    return ReminderDefaults(
      notificationMode: notificationMode,
      soundUri: preferences.getString(_soundUriKey),
      soundName: preferences.getString(_soundNameKey) ?? 'Default',
      snoozeDurationMinutes: availableSnoozeDurations.contains(snoozeDuration)
          ? snoozeDuration!
          : 10,
      vibrate: preferences.getBool(_vibrateKey) ?? true,
    );
  }

  Future<void> saveDefaults(ReminderDefaults defaults) async {
    final preferences = await SharedPreferences.getInstance();
    final results = await Future.wait([
      preferences.setString(
        _notificationModeKey,
        defaults.notificationMode.name,
      ),
      defaults.soundUri == null
          ? preferences.remove(_soundUriKey)
          : preferences.setString(_soundUriKey, defaults.soundUri!),
      preferences.setString(_soundNameKey, defaults.soundName),
      preferences.setInt(_snoozeDurationKey, defaults.snoozeDurationMinutes),
      preferences.setBool(_vibrateKey, defaults.vibrate),
    ]);
    if (results.any((saved) => !saved)) {
      throw StateError('Unable to save reminder defaults.');
    }
  }
}
