import 'package:flutter/material.dart';

import 'models/reminder.dart';
import 'screens/add_reminder_screen.dart';
import 'services/recurrence_service.dart';
import 'services/reminder_storage.dart';

class RemindersScreen extends StatefulWidget {
  final ReminderStorage? storage;

  const RemindersScreen({super.key, this.storage});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  final RecurrenceService _recurrenceService = RecurrenceService();
  late final ReminderStorage _storage;
  late Future<List<Reminder>> _reminders;
  bool _showCompleted = false;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? ReminderStorage();
    _loadReminders();
  }

  void _loadReminders() {
    _reminders = _storage.getReminders();
  }

  Future<void> _openAddReminder() async {
    final Reminder? reminder = await Navigator.of(context).push<Reminder>(
      MaterialPageRoute<Reminder>(
        builder: (_) => AddReminderScreen(storage: _storage),
      ),
    );

    if (reminder != null && mounted) {
      setState(_loadReminders);
    }
  }

  Future<void> _deleteReminder(Reminder reminder) async {
    try {
      await _storage.deleteReminder(reminder.id);

      if (mounted) {
        setState(_loadReminders);
      }
    } catch (_) {
      if (mounted) {
        setState(_loadReminders);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to delete the reminder.')),
        );
      }
    }
  }

  Future<void> _updateReminder(Reminder reminder) async {
    try {
      await _storage.updateReminder(reminder);

      if (mounted) {
        setState(_loadReminders);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update the reminder.')),
        );
      }
    }
  }

  Future<void> _completeReminder(Reminder reminder) async {
    if (reminder.recurrenceRule.type == RecurrenceType.none) {
      await _updateReminder(reminder.copyWith(isCompleted: true));
      return;
    }

    final nextOccurrence = _recurrenceService.nextOccurrence(
      reminder,
      after: DateTime.now(),
    );

    if (nextOccurrence != null) {
      await _updateReminder(reminder.copyWith(dateTime: nextOccurrence));
    }
  }

  Future<void> _openEditReminder(Reminder reminder) async {
    final updatedReminder = await Navigator.of(context).push<Reminder>(
      MaterialPageRoute<Reminder>(
        builder: (_) => AddReminderScreen(
          reminder: reminder,
          storage: _storage,
        ),
      ),
    );

    if (updatedReminder != null && mounted) {
      setState(_loadReminders);
    }
  }

  String _recurrenceLabel(Reminder reminder) {
    final rule = reminder.recurrenceRule;
    return switch (rule.type) {
      RecurrenceType.none => 'Does not repeat',
      RecurrenceType.daily => 'Every day',
      RecurrenceType.weekly =>
        'Every ${_weekdayName(rule.dayOfWeek ?? reminder.dateTime.weekday)}',
      RecurrenceType.monthly =>
        '${_ordinal(rule.dayOfMonth ?? reminder.dateTime.day)} of every month',
      RecurrenceType.yearly =>
        '${reminder.dateTime.day} '
            '${_monthNames[reminder.dateTime.month - 1]} every year',
    };
  }

  String _weekdayName(int day) {
    return switch (day) {
      DateTime.monday => 'Monday',
      DateTime.tuesday => 'Tuesday',
      DateTime.wednesday => 'Wednesday',
      DateTime.thursday => 'Thursday',
      DateTime.friday => 'Friday',
      DateTime.saturday => 'Saturday',
      DateTime.sunday => 'Sunday',
      _ => '',
    };
  }

  String _ordinal(int number) {
    if (number >= 11 && number <= 13) {
      return '${number}th';
    }

    return switch (number % 10) {
      1 => '${number}st',
      2 => '${number}nd',
      3 => '${number}rd',
      _ => '${number}th',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: FutureBuilder<List<Reminder>>(
        future: _reminders,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: Text('Loading reminders...'));
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load reminders.'));
          }

          final remindersById = <String, Reminder>{};
          for (final reminder in snapshot.data ?? <Reminder>[]) {
            remindersById.putIfAbsent(reminder.id, () => reminder);
          }
          final reminders = remindersById.values.toList();
          if (reminders.isEmpty) {
            return const Center(child: Text('No reminders yet.'));
          }

          final visibleReminders =
              reminders
                  .where((reminder) => reminder.isCompleted == _showCompleted)
                  .toList()
                ..sort(
                  (first, second) => first.dateTime.compareTo(second.dateTime),
                );
          final colorScheme = Theme.of(context).colorScheme;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Active'),
                      icon: Icon(Icons.notifications_active_outlined),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Completed'),
                      icon: Icon(Icons.check_circle_outline),
                    ),
                  ],
                  selected: {_showCompleted},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _showCompleted = selection.first;
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Row(
                  children: [
                    Text(
                      _showCompleted
                          ? 'Completed reminders'
                          : 'Active reminders',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${visibleReminders.length}',
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (visibleReminders.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      _showCompleted
                          ? 'No completed reminders.'
                          : 'No active reminders.',
                    ),
                  ),
                ),
              for (final reminder in visibleReminders)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Dismissible(
                    key: ValueKey(reminder.id),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => _deleteReminder(reminder),
                    background: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.error,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    child: Card(
                      margin: EdgeInsets.zero,
                      elevation: 0,
                      color: colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        onTap: () => _openEditReminder(reminder),
                        leading: Checkbox(
                          value: reminder.isCompleted,
                          onChanged: (value) {
                            if (value != null) {
                              if (value) {
                                _completeReminder(reminder);
                              } else {
                                _updateReminder(
                                  reminder.copyWith(isCompleted: false),
                                );
                              }
                            }
                          },
                        ),
                        title: Text(
                          reminder.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: reminder.isCompleted
                              ? const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                )
                              : null,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${MaterialLocalizations.of(context).formatMediumDate(reminder.dateTime)} · '
                                '${TimeOfDay.fromDateTime(reminder.dateTime).format(context)}',
                              ),
                              if (reminder.description case final description?)
                                Text(
                                  description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  [
                                    _recurrenceLabel(reminder),
                                    if (!reminder.enabled) 'Disabled',
                                  ].join(' · '),
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: Switch(
                          value: reminder.enabled,
                          onChanged: (value) {
                            _updateReminder(reminder.copyWith(enabled: value));
                          },
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddReminder,
        tooltip: 'Add reminder',
        child: const Icon(Icons.add),
      ),
    );
  }
}
