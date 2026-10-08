import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/reminders/models/reminder.dart';
import '../../features/reminders/services/recurrence_service.dart';
import '../../features/reminders/services/reminder_storage.dart';
import '../../widgets/app_navigation_drawer.dart';

class MyDayScreen extends StatefulWidget {
  const MyDayScreen({
    super.key,
    required this.appMenu,
    required this.navigationDrawer,
    this.storage,
    this.clock = DateTime.now,
  });

  final Widget appMenu;
  final Widget navigationDrawer;
  final ReminderStorage? storage;
  final DateTime Function() clock;

  @override
  State<MyDayScreen> createState() => _MyDayScreenState();
}

class _MyDayScreenState extends State<MyDayScreen> {
  static const _completionKey = 'my_day_completed_occurrences_v1';

  late final ReminderStorage _storage;
  final RecurrenceService _recurrenceService = RecurrenceService();
  late Future<void> _loadFuture;
  List<Reminder> _reminders = [];
  Set<String> _completedOccurrences = {};
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? ReminderStorage();
    _loadFuture = _load();
  }

  Future<void> _load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_completionKey);
      final decoded = raw == null ? null : jsonDecode(raw);
      final completed = decoded is List
          ? decoded.whereType<String>().toSet()
          : <String>{};
      final reminders = await _storage.getReminders();
      if (!mounted) return;
      setState(() {
        _reminders = reminders;
        _completedOccurrences = completed;
        _loadError = null;
      });
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'My Day task restore',
        ),
      );
      if (mounted) setState(() => _loadError = 'My Day could not be loaded.');
    }
  }

  String _occurrenceKey(Reminder reminder, DateTime day) =>
      '${day.year}-${day.month}-${day.day}:${reminder.id}';

  bool _occursOn(Reminder reminder, DateTime day) {
    final start = reminder.dateTime.isUtc
        ? reminder.dateTime.toLocal()
        : reminder.dateTime;
    final startDay = DateTime(start.year, start.month, start.day);
    if (reminder.recurrenceRule.type == RecurrenceType.none) {
      return day == startDay;
    }
    final previousDay = day.subtract(const Duration(microseconds: 1));
    final occurrence = _recurrenceService.nextOccurrence(
      reminder,
      after: previousDay,
    );
    if (occurrence == null) return false;
    final occurrenceDate = occurrence.isUtc ? occurrence.toLocal() : occurrence;
    return occurrenceDate.year == day.year &&
        occurrenceDate.month == day.month &&
        occurrenceDate.day == day.day;
  }

  Future<void> _toggleReminder(Reminder reminder, DateTime day) async {
    final key = _occurrenceKey(reminder, day);
    final updated = Set<String>.of(_completedOccurrences);
    final completing = !updated.contains(key);
    if (completing) {
      updated.add(key);
    } else {
      updated.remove(key);
    }

    try {
      final saved = await (await SharedPreferences.getInstance()).setString(
        _completionKey,
        jsonEncode(updated.toList()),
      );
      if (!saved) throw StateError('Unable to save My Day task completion.');
      if (!mounted) return;
      setState(() => _completedOccurrences = updated);
      if (completing) SystemSound.play(SystemSoundType.click);
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'My Day task completion',
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task completion could not be saved.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.clock();
    final today = DateTime(now.year, now.month, now.day);
    final tasks =
        _reminders
            .where((reminder) => reminder.enabled && _occursOn(reminder, today))
            .toList()
          ..sort((first, second) => first.dateTime.compareTo(second.dateTime));
    final completedCount = tasks
        .where(
          (reminder) =>
              _completedOccurrences.contains(_occurrenceKey(reminder, today)),
        )
        .length;

    return Scaffold(
      drawer: widget.navigationDrawer,
      appBar: AppBar(
        title: const Text('My Day'),
        leading: const AppNavigationMenuButton(),
        actions: [widget.appMenu],
      ),
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_loadError != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_loadError!),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: () => setState(() => _loadFuture = _load()),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [
                Text(
                  MaterialLocalizations.of(context).formatFullDate(now),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tasks.isEmpty
                      ? 'A clear day ahead'
                      : '$completedCount of ${tasks.length} completed',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                if (tasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 42),
                        SizedBox(height: 12),
                        Text('No reminders scheduled for today.'),
                      ],
                    ),
                  )
                else
                  for (final reminder in tasks)
                    _taskTile(context, reminder, today),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _taskTile(BuildContext context, Reminder reminder, DateTime day) {
    final key = _occurrenceKey(reminder, day);
    final completed = _completedOccurrences.contains(key);
    final colors = Theme.of(context).colorScheme;
    final scheduledAt = reminder.dateTime.isUtc
        ? reminder.dateTime.toLocal()
        : reminder.dateTime;
    return AnimatedContainer(
      key: ValueKey('my-day-task-${reminder.id}'),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: completed ? colors.surfaceContainerLow : colors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          leading: Checkbox(
            value: completed,
            onChanged: (_) => _toggleReminder(reminder, day),
          ),
          title: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
              color: completed ? colors.onSurfaceVariant : colors.onSurface,
              decoration: completed ? TextDecoration.lineThrough : null,
            ),
            child: Text(reminder.title),
          ),
          subtitle: Row(
            children: [
              if (reminder.notificationMode ==
                  ReminderNotificationMode.alarmAndNotification) ...[
                Icon(
                  Icons.notifications_active_outlined,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                MaterialLocalizations.of(context)
                    .formatTimeOfDay(TimeOfDay.fromDateTime(scheduledAt)),
              ),
            ],
          ),
          onTap: () => _toggleReminder(reminder, day),
        ),
      ),
    );
  }
}
