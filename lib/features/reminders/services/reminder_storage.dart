import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/reminder.dart';

class ReminderStorage {
  static const String _key = 'reminders';

  Future<List<Reminder>> getReminders() async {
    final preferences = await SharedPreferences.getInstance();

    final jsonString = preferences.getString(_key);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    final List<dynamic> jsonList = jsonDecode(jsonString);

    return jsonList
        .map(
          (json) => Reminder.fromJson(
            Map<String, dynamic>.from(json),
          ),
        )
        .toList();
  }

  Future<void> saveReminders(List<Reminder> reminders) async {
    final preferences = await SharedPreferences.getInstance();

    final jsonList = reminders
        .map((reminder) => reminder.toJson())
        .toList();

    final jsonString = jsonEncode(jsonList);

    await preferences.setString(
      _key,
      jsonString,
    );
  }

  Future<void> addReminder(Reminder reminder) async {
    final reminders = await getReminders();

    reminders.add(reminder);

    await saveReminders(reminders);
  }

  Future<void> updateReminder(Reminder reminder) async {
    final reminders = await getReminders();

    final index = reminders.indexWhere(
      (item) => item.id == reminder.id,
    );

    if (index == -1) {
      return;
    }

    reminders[index] = reminder;

    await saveReminders(reminders);
  }

  Future<void> deleteReminder(String id) async {
    final reminders = await getReminders();

    reminders.removeWhere(
      (reminder) => reminder.id == id,
    );

    await saveReminders(reminders);
  }
}