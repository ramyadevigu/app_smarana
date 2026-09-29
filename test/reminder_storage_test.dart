import 'package:app_smarana/features/reminders/models/reminder.dart';
import 'package:app_smarana/features/reminders/services/reminder_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_reminder_notification_scheduler.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loads empty storage and tolerates corrupted JSON', () async {
    final storage = ReminderStorage();
    expect(await storage.getReminders(), isEmpty);

    SharedPreferences.setMockInitialValues({'reminders': '{broken json'});
    expect(await ReminderStorage().getReminders(), isEmpty);

    SharedPreferences.setMockInitialValues({'reminders': '{"not":"a list"}'});
    expect(await ReminderStorage().getReminders(), isEmpty);
  });

  test(
    'adds without replacing existing reminders and reloads persisted data',
    () async {
      final storage = _storage();
      await storage.addReminder(_reminder('first'));
      await storage.addReminder(_reminder('second'));

      final preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      final loaded = await ReminderStorage().getReminders();

      expect(loaded.map((reminder) => reminder.id), ['first', 'second']);
    },
  );

  test('updates an existing reminder without changing other records', () async {
    final storage = _storage();
    await storage.saveReminders([_reminder('first'), _reminder('second')]);

    await storage.updateReminder(
      _reminder('first', title: 'Updated title', enabled: false),
    );

    final loaded = await storage.getReminders();
    expect(loaded, hasLength(2));
    expect(loaded.first.title, 'Updated title');
    expect(loaded.first.enabled, isFalse);
    expect(loaded.last.id, 'second');
  });

  test('deletes only the reminder with the requested ID', () async {
    final storage = _storage();
    await storage.saveReminders([_reminder('first'), _reminder('second')]);

    await storage.deleteReminder('first');

    final loaded = await storage.getReminders();
    expect(loaded.map((reminder) => reminder.id), ['second']);
  });

  test('rejects duplicate IDs and retains the original reminder', () async {
    final storage = _storage();
    await storage.addReminder(_reminder('same-id', title: 'Original'));

    await expectLater(
      storage.addReminder(_reminder('same-id', title: 'Duplicate')),
      throwsStateError,
    );

    final loaded = await storage.getReminders();
    expect(loaded, hasLength(1));
    expect(loaded.single.title, 'Original');
  });

  test('serializes concurrent adds from separate storage instances', () async {
    final firstStorage = _storage();
    final secondStorage = _storage();

    await expectLater(
      Future.wait([
        firstStorage.addReminder(_reminder('shared-id', title: 'First')),
        secondStorage.addReminder(_reminder('shared-id', title: 'Second')),
      ]),
      throwsStateError,
    );

    final loaded = await firstStorage.getReminders();
    expect(loaded, hasLength(1));
    expect(loaded.single.id, 'shared-id');
  });

  test('skips malformed records and duplicate IDs in stored JSON', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'reminders',
      '[{"id":"first","title":"Kept"},"invalid",'
          '{"id":"first","title":"Duplicate"}]',
    );

    final loaded = await ReminderStorage().getReminders();

    expect(loaded, hasLength(1));
    expect(loaded.single.title, 'Kept');
  });

  test('keeps notification schedules synchronized with reminder CRUD', () async {
    final scheduler = FakeReminderNotificationScheduler();
    final storage = ReminderStorage(notificationScheduler: scheduler);

    await storage.addReminder(_reminder('lifecycle'));
    await storage.updateReminder(
      _reminder('lifecycle', title: 'Edited reminder'),
    );
    await storage.updateReminder(_reminder('lifecycle', enabled: false));
    await storage.updateReminder(_reminder('lifecycle', enabled: true));
    await storage.deleteReminder('lifecycle');

    expect(scheduler.operations, [
      'schedule:lifecycle',
      'cancel:lifecycle',
      'schedule:lifecycle',
      'cancel:lifecycle',
      'cancel:lifecycle',
      'schedule:lifecycle',
      'cancel:lifecycle',
    ]);
    expect(scheduler.scheduledReminders, isEmpty);
    expect(await storage.getReminders(), isEmpty);
  });
}

ReminderStorage _storage() {
  return ReminderStorage(
    notificationScheduler: FakeReminderNotificationScheduler(),
  );
}

Reminder _reminder(String id, {String? title, bool enabled = true}) {
  return Reminder(
    id: id,
    title: title ?? id,
    dateTime: DateTime(2026, 9, 28, 8),
    enabled: enabled,
    createdAt: DateTime(2026, 9, 1),
  );
}
