import 'package:flutter/material.dart';

import 'models/reminder.dart';
import 'screens/add_reminder_screen.dart';
import 'services/recurrence_service.dart';
import 'services/reminder_storage.dart';

class RemindersScreen extends StatefulWidget {
  final ReminderStorage? storage;
  final String title;
  final Widget? appMenu;

  const RemindersScreen({
    super.key,
    this.storage,
    this.title = 'Reminders',
    this.appMenu,
  });

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

  void _retryLoadingReminders() {
    setState(_loadReminders);
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

  Future<void> _confirmDeleteReminder(Reminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('Delete reminder?'),
        content: Text('Delete "${reminder.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _deleteReminder(reminder);
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
        builder: (_) =>
            AddReminderScreen(reminder: reminder, storage: _storage),
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

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading reminders...',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 44,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to load reminders',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your reminders are still saved. Try loading them again.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const ValueKey('retry-reminders'),
                onPressed: _retryLoadingReminders,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({required bool completed}) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                completed ? Icons.task_alt : Icons.notifications_none,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                completed ? 'No completed reminders' : 'No reminders yet',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                completed
                    ? 'Completed reminders will appear here.'
                    : 'Your reminders will appear here.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (!completed) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _openAddReminder,
                  icon: const Icon(Icons.add),
                  label: const Text('Add reminder'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReminderCard(Reminder reminder) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateText = MaterialLocalizations.of(context)
        .formatMediumDate(reminder.dateTime);
    final timeText = TimeOfDay.fromDateTime(reminder.dateTime).format(context);
    final description = reminder.description?.trim();

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openEditReminder(reminder),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: reminder.isCompleted,
                    semanticLabel: reminder.isCompleted
                        ? 'Mark ${reminder.title} active'
                        : 'Mark ${reminder.title} complete',
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      if (value) {
                        _completeReminder(reminder);
                      } else {
                        _updateReminder(reminder.copyWith(isCompleted: false));
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reminder.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: reminder.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        if (description != null && description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    key: ValueKey('reminder-menu-${reminder.id}'),
                    tooltip: 'More actions for ${reminder.title}',
                    onSelected: (action) {
                      if (action == 'edit') {
                        _openEditReminder(reminder);
                      } else if (action == 'delete') {
                        _confirmDeleteReminder(reminder);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem<String>(
                        key: ValueKey('delete-reminder-${reminder.id}'),
                        value: 'delete',
                        child: const ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Delete'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _ReminderDetail(
                    icon: Icons.calendar_today_outlined,
                    label: dateText,
                  ),
                  _ReminderDetail(
                    icon: Icons.schedule_outlined,
                    label: timeText,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  _ReminderDetail(
                    icon: Icons.repeat,
                    label: _recurrenceLabel(reminder),
                    color: colorScheme.onSurfaceVariant,
                  ),
                  Semantics(
                    label: reminder.enabled
                        ? 'Disable ${reminder.title}'
                        : 'Enable ${reminder.title}',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          reminder.enabled ? 'Enabled' : 'Disabled',
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(width: 4),
                        Switch(
                          value: reminder.enabled,
                          onChanged: (value) {
                            _updateReminder(reminder.copyWith(enabled: value));
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [if (widget.appMenu case final appMenu?) appMenu],
      ),
      body: FutureBuilder<List<Reminder>>(
        future: _reminders,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState();
          }

          final remindersById = <String, Reminder>{};
          for (final reminder in snapshot.data ?? <Reminder>[]) {
            remindersById.putIfAbsent(reminder.id, () => reminder);
          }
          final reminders = remindersById.values.toList();
          if (reminders.isEmpty) {
            return _buildEmptyState(completed: false);
          }

          final visibleReminders =
              reminders
                  .where((reminder) => reminder.isCompleted == _showCompleted)
                  .toList()
                ..sort(
                  (first, second) => first.dateTime.compareTo(second.dateTime),
                );
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
                children: [
                  SegmentedButton<bool>(
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
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _showCompleted
                                ? 'Completed reminders'
                                : 'Active reminders',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          '${visibleReminders.length}',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (visibleReminders.isEmpty)
                    _buildEmptyState(completed: _showCompleted),
                  for (final reminder in visibleReminders)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildReminderCard(reminder),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'alarms-add-reminder',
        onPressed: _openAddReminder,
        tooltip: 'Add reminder',
        icon: const Icon(Icons.add),
        label: const Text('Add reminder'),
      ),
    );
  }
}

class _ReminderDetail extends StatelessWidget {
  const _ReminderDetail({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: effectiveColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: effectiveColor),
        ),
      ],
    );
  }
}
