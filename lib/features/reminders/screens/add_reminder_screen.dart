import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/reminder.dart';
import '../services/reminder_storage.dart';
import '../../../services/notification_service.dart';

const _monthLabels = [
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

class AddReminderScreen extends StatefulWidget {
  final Reminder? reminder;
  final ReminderStorage? storage;
  final DateTime? initialDate;

  const AddReminderScreen({
    super.key,
    this.reminder,
    this.storage,
    this.initialDate,
  });

  bool get isEditing => reminder != null;

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _uuid = const Uuid();
  late final ReminderStorage _storage;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  late RecurrenceRule _recurrenceRule;
  String? _soundUri;
  String _soundName = 'Default';
  ReminderNotificationMode _notificationMode =
      ReminderNotificationMode.alarmAndNotification;
  bool _vibrate = true;
  int _snoozeDurationMinutes = 10;
  List<ReminderSoundOption> _availableAlarmSounds = const [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? ReminderStorage();

    final reminder = widget.reminder;
    _recurrenceRule =
        reminder?.recurrenceRule ??
        const RecurrenceRule(type: RecurrenceType.none);
    _soundUri = reminder?.soundUri;
    _soundName = reminder?.soundName ?? 'Default';
    _notificationMode =
        reminder?.notificationMode ??
        ReminderNotificationMode.alarmAndNotification;
    _vibrate = reminder?.vibrate ?? true;
    _snoozeDurationMinutes = reminder?.snoozeDurationMinutes ?? 10;
    _loadAvailableAlarmSounds();
    if (reminder != null) {
      _titleController.text = reminder.title;
      _descriptionController.text = reminder.description ?? '';
      _selectedDate = DateTime(
        reminder.dateTime.year,
        reminder.dateTime.month,
        reminder.dateTime.day,
      );
      _selectedTime = TimeOfDay.fromDateTime(reminder.dateTime);
      return;
    }

    final initialDateTime = DateTime.now().add(const Duration(minutes: 5));
    final today = DateUtils.dateOnly(DateTime.now());
    final requestedDate = widget.initialDate ?? initialDateTime;
    final initialDate = requestedDate.isBefore(today) ? today : requestedDate;
    _selectedDate = DateTime(
      initialDate.year,
      initialDate.month,
      initialDate.day,
    );
    _selectedTime = TimeOfDay.fromDateTime(initialDateTime);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(FormFieldState<DateTime> field) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final firstDate = widget.isEditing ? DateTime(1900) : today;
    final selectedDate = _selectedDate ?? today;
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate.isBefore(firstDate) ? firstDate : selectedDate,
      firstDate: firstDate,
      lastDate: DateTime(2100),
    );

    if (date == null) {
      return;
    }

    setState(() {
      _selectedDate = date;
    });
    field.didChange(date);
  }

  Future<void> _selectTime(FormFieldState<TimeOfDay> field) async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.dial,
    );

    if (time == null) {
      return;
    }

    setState(() {
      _selectedTime = time;
    });
    field.didChange(time);
  }

  Future<void> _saveReminder() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final title = _titleController.text.trim();
    final date = _selectedDate;
    final time = _selectedTime;
    if (date == null || time == null) {
      return;
    }

    final existing = widget.reminder;
    final reminder = Reminder(
      id: existing?.id ?? _uuid.v4(),
      title: title,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      dateTime: DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
      recurrenceRule: _recurrenceRule,
      enabled: existing?.enabled ?? true,
      isCompleted: existing?.isCompleted ?? false,
      soundUri: _soundUri,
      soundName: _soundName,
      notificationMode: _notificationMode,
      vibrate: _vibrate,
      snoozeDurationMinutes: _snoozeDurationMinutes,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.isEditing) {
        await _storage.updateReminder(reminder);
      } else {
        await _storage.addReminder(reminder);
      }

      if (mounted) {
        Navigator.of(context).pop(reminder);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save the reminder.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _formatDate(BuildContext context, DateTime? date) {
    return date == null
        ? 'Select a date'
        : MaterialLocalizations.of(context).formatMediumDate(date);
  }

  String _formatTime(BuildContext context, TimeOfDay? time) {
    return time?.format(context) ?? 'Select a time';
  }

  String get _notificationModeLabel => switch (_notificationMode) {
    ReminderNotificationMode.alarmAndNotification => 'Alarm + Notification',
    ReminderNotificationMode.notificationOnly => 'Notification only',
  };

  Future<void> _selectRecurrence() async {
    final selection = await showModalBottomSheet<_RecurrenceSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _RecurrenceSheet(
        initialRule: _recurrenceRule,
        initialDate: _selectedDate ?? DateTime.now(),
      ),
    );

    if (selection == null || !mounted) {
      return;
    }

    setState(() {
      _recurrenceRule = selection.rule;
      _selectedDate = selection.startDate;
    });
  }

  Future<void> _loadAvailableAlarmSounds() async {
    final sounds = await NotificationService.instance.availableAlarmSounds();
    if (mounted) {
      setState(() => _availableAlarmSounds = sounds);
    }
  }

  Future<void> _selectSound() async {
    final choices = [
      const ReminderSoundOption(name: 'Default', uri: null),
      ..._availableAlarmSounds,
    ];
    final selection = await showModalBottomSheet<ReminderSoundOption>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text('Sound', style: Theme.of(context).textTheme.titleLarge),
          ),
          for (final sound in choices)
            ListTile(
              leading: Icon(
                _soundUri == sound.uri && _soundName == sound.name
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(sound.name),
              onTap: () => Navigator.of(context).pop(sound),
            ),
          if (_availableAlarmSounds.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text('No additional alarm sounds are available.'),
            ),
        ],
      ),
    );
    if (selection != null && mounted) {
      setState(() {
        _soundUri = selection.uri;
        _soundName = selection.name;
      });
    }
  }

  Future<void> _selectNotificationMode() async {
    final selection = await showModalBottomSheet<ReminderNotificationMode>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          ListTile(
            title: const Text('Alarm + Notification'),
            subtitle: const Text('Ringtone, snooze, and dismiss'),
            trailing:
                _notificationMode ==
                    ReminderNotificationMode.alarmAndNotification
                ? const Icon(Icons.check)
                : null,
            onTap: () =>
                Navigator.of(context)
                    .pop(ReminderNotificationMode.alarmAndNotification),
          ),
          ListTile(
            title: const Text('Notification only'),
            subtitle: const Text('No alarm ringtone'),
            trailing:
                _notificationMode == ReminderNotificationMode.notificationOnly
                ? const Icon(Icons.check)
                : null,
            onTap: () =>
                Navigator.of(context)
                    .pop(ReminderNotificationMode.notificationOnly),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
    if (selection != null && mounted) {
      setState(() => _notificationMode = selection);
    }
  }

  Future<void> _selectSnoozeDuration() async {
    const durations = [5, 10, 15, 30, 60];
    final selection = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          for (final minutes in durations)
            ListTile(
              title: Text('$minutes minutes'),
              trailing: _snoozeDurationMinutes == minutes
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(context).pop(minutes),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
    if (selection != null && mounted) {
      setState(() => _snoozeDurationMinutes = selection);
    }
  }

  Widget _fieldError(String? message) {
    if (message == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenTitle = widget.isEditing ? 'Edit Reminder' : 'Add Reminder';
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(screenTitle)),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SizedBox(
          height: 54,
          child: FilledButton(
            key: const ValueKey('save-reminder'),
            onPressed: _isSaving ? null : _saveReminder,
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.isEditing ? 'Save Changes' : 'Save Reminder'),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const ValueKey('title-field'),
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'What do you want to remember?',
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Title is required.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('description-field'),
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Optional details',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'DATE & TIME',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 10),
              Material(
                color: colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    FormField<DateTime>(
                      initialValue: _selectedDate,
                      validator: (value) =>
                          value == null ? 'Date is required.' : null,
                      builder: (field) => Column(
                        children: [
                          ListTile(
                            key: const ValueKey('date-field'),
                            leading: Icon(
                              Icons.calendar_month_outlined,
                              color: colorScheme.primary,
                            ),
                            title: const Text('Date'),
                            subtitle: Text(_formatDate(context, _selectedDate)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _selectDate(field),
                          ),
                          _fieldError(field.errorText),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: colorScheme.outlineVariant),
                    ListTile(
                      key: const ValueKey('repeat-field'),
                      leading: Icon(
                        Icons.repeat_rounded,
                        color: colorScheme.primary,
                      ),
                      title: const Text('Repeat'),
                      subtitle: Text(
                        _recurrenceLabel(_recurrenceRule, _selectedDate),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _selectRecurrence,
                    ),
                    Divider(height: 1, color: colorScheme.outlineVariant),
                    FormField<TimeOfDay>(
                      initialValue: _selectedTime,
                      validator: (value) =>
                          value == null ? 'Time is required.' : null,
                      builder: (field) => Column(
                        children: [
                          ListTile(
                            key: const ValueKey('time-field'),
                            leading: Icon(
                              Icons.schedule_outlined,
                              color: colorScheme.primary,
                            ),
                            title: const Text('Time'),
                            subtitle: Text(_formatTime(context, field.value)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _selectTime(field),
                          ),
                          _fieldError(field.errorText),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text('ALERTS', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 10),
              Material(
                color: colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      key: const ValueKey('sound-option'),
                      leading: Icon(
                        Icons.music_note_outlined,
                        color: colorScheme.primary,
                      ),
                      title: const Text('Sound'),
                      subtitle: Text(_soundName),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _selectSound,
                    ),
                    Divider(height: 1, color: colorScheme.outlineVariant),
                    ListTile(
                      key: const ValueKey('vibrate-option'),
                      leading: Icon(
                        Icons.vibration_outlined,
                        color: colorScheme.primary,
                      ),
                      title: const Text('Vibrate'),
                      subtitle: Text(_vibrate ? 'On' : 'Off'),
                      trailing: Switch(
                        value: _vibrate,
                        onChanged: (value) => setState(() => _vibrate = value),
                      ),
                    ),
                    Divider(height: 1, color: colorScheme.outlineVariant),
                    ListTile(
                      key: const ValueKey('notification-mode-option'),
                      leading: Icon(
                        Icons.notifications_active_outlined,
                        color: colorScheme.primary,
                      ),
                      title: const Text('Notification'),
                      subtitle: Text(_notificationModeLabel),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _selectNotificationMode,
                    ),
                    Divider(height: 1, color: colorScheme.outlineVariant),
                    ListTile(
                      key: const ValueKey('snooze-option'),
                      leading: Icon(
                        Icons.snooze_outlined,
                        color: colorScheme.primary,
                      ),
                      title: const Text('Snooze'),
                      subtitle: Text('$_snoozeDurationMinutes minutes'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _selectSnoozeDuration,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _recurrenceLabel(RecurrenceRule rule, DateTime? startDate) {
    final date = startDate ?? DateTime.now();
    final interval = rule.interval;
    final label = switch (rule.type) {
      RecurrenceType.none => 'Does not repeat',
      RecurrenceType.daily =>
        interval == 1 ? 'Every day' : 'Every $interval days',
      RecurrenceType.weekly => _weeklyLabel(rule, date),
      RecurrenceType.monthly =>
        interval == 1
            ? '${_ordinal(rule.dayOfMonth ?? date.day)} of every month'
            : 'Every $interval months on '
                  '${_ordinal(rule.dayOfMonth ?? date.day)}',
      RecurrenceType.yearly =>
        'Every ${interval == 1 ? '' : '$interval '}'
            '${interval == 1 ? 'year' : 'years'} on '
            '${_monthName(rule.monthOfYear ?? date.month)} '
            '${_ordinal(rule.dayOfMonth ?? date.day)}',
    };
    final endDate = rule.endDate;
    return endDate == null
        ? label
        : '$label until ${MaterialLocalizations.of(context).formatMediumDate(endDate)}';
  }

  String _weeklyLabel(RecurrenceRule rule, DateTime date) {
    final weekdays = rule.weekdays.isNotEmpty
        ? rule.weekdays
        : [rule.dayOfWeek ?? date.weekday];
    final names = weekdays.map(_weekdayName).join(', ');
    if (rule.interval > 1) {
      return 'Every ${rule.interval} weeks on $names';
    }
    return 'Every $names';
  }

  String _weekdayName(int weekday) => switch (weekday) {
    DateTime.monday => 'Monday',
    DateTime.tuesday => 'Tuesday',
    DateTime.wednesday => 'Wednesday',
    DateTime.thursday => 'Thursday',
    DateTime.friday => 'Friday',
    DateTime.saturday => 'Saturday',
    DateTime.sunday => 'Sunday',
    _ => '',
  };

  String _monthName(int month) => _monthLabels[month - 1];

  String _ordinal(int day) {
    if (day >= 11 && day <= 13) {
      return '${day}th';
    }
    return switch (day % 10) {
      1 => '${day}st',
      2 => '${day}nd',
      3 => '${day}rd',
      _ => '${day}th',
    };
  }
}

class _RecurrenceSelection {
  const _RecurrenceSelection({required this.rule, required this.startDate});

  final RecurrenceRule rule;
  final DateTime startDate;
}

class _RecurrenceSheet extends StatefulWidget {
  const _RecurrenceSheet({
    required this.initialRule,
    required this.initialDate,
  });

  final RecurrenceRule initialRule;
  final DateTime initialDate;

  @override
  State<_RecurrenceSheet> createState() => _RecurrenceSheetState();
}

class _RecurrenceSheetState extends State<_RecurrenceSheet> {
  static const _presets = [
    ('none', 'Does not repeat'),
    ('daily', 'Every day'),
    ('weekly', 'Every week'),
    ('biweekly', 'Every 2 weeks'),
    ('alternateWeeks', 'Alternate weeks'),
    ('monthly', 'Every month'),
    ('bimonthly', 'Every 2 months'),
    ('alternateMonths', 'Alternate months'),
    ('yearly', 'Every year'),
    ('custom', 'Custom'),
  ];

  late String _preset;
  late RecurrenceType _frequency;
  late int _interval;
  late int _dayOfMonth;
  late int _monthOfYear;
  late DateTime _startDate;
  late DateTime? _endDate;
  late Set<int> _weekdays;

  bool get _isWeekly => _frequency == RecurrenceType.weekly;
  bool get _isMonthly => _frequency == RecurrenceType.monthly;
  bool get _isYearly => _frequency == RecurrenceType.yearly;
  bool get _isCustom => _preset == 'custom';
  bool get _showWeeklyOptions => _isWeekly;
  bool get _showDayOfMonth => _isMonthly || _isYearly;
  bool get _showMonthOfYear => _isYearly;

  @override
  void initState() {
    super.initState();
    final rule = widget.initialRule;
    _frequency = rule.type == RecurrenceType.none
        ? RecurrenceType.daily
        : rule.type;
    _interval = rule.interval;
    _dayOfMonth = rule.dayOfMonth ?? widget.initialDate.day;
    _monthOfYear = rule.monthOfYear ?? widget.initialDate.month;
    _startDate = DateUtils.dateOnly(widget.initialDate);
    _endDate = rule.endDate == null ? null : DateUtils.dateOnly(rule.endDate!);
    _weekdays =
        (rule.weekdays.isNotEmpty
                ? rule.weekdays
                : [rule.dayOfWeek ?? widget.initialDate.weekday])
            .toSet();
    _preset = _presetFor(rule);
  }

  String _presetFor(RecurrenceRule rule) {
    if (rule.type == RecurrenceType.none) return 'none';
    if (rule.type == RecurrenceType.daily && rule.interval == 1) return 'daily';
    if (rule.type == RecurrenceType.weekly) {
      return rule.interval == 2 ? 'biweekly' : 'weekly';
    }
    if (rule.type == RecurrenceType.monthly) {
      return rule.interval == 2 ? 'bimonthly' : 'monthly';
    }
    if (rule.type == RecurrenceType.yearly && rule.interval == 1) {
      return 'yearly';
    }
    return 'custom';
  }

  void _choosePreset(String preset) {
    setState(() {
      _preset = preset;
      if (preset != 'custom') {
        _endDate = null;
      }
      switch (preset) {
        case 'none':
          break;
        case 'daily':
          _frequency = RecurrenceType.daily;
          _interval = 1;
        case 'weekly':
          _frequency = RecurrenceType.weekly;
          _interval = 1;
        case 'biweekly' || 'alternateWeeks':
          _frequency = RecurrenceType.weekly;
          _interval = 2;
        case 'monthly':
          _frequency = RecurrenceType.monthly;
          _interval = 1;
        case 'bimonthly' || 'alternateMonths':
          _frequency = RecurrenceType.monthly;
          _interval = 2;
        case 'yearly':
          _frequency = RecurrenceType.yearly;
          _interval = 1;
        case 'custom':
          _interval = _interval < 1 ? 1 : _interval;
      }
    });
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() {
        _startDate = DateUtils.dateOnly(date);
      });
    }
  }

  Future<void> _pickEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() {
        _endDate = DateUtils.dateOnly(date);
      });
    }
  }

  void _finish() {
    final rule = _preset == 'none'
        ? const RecurrenceRule(type: RecurrenceType.none)
        : RecurrenceRule(
            type: _frequency,
            interval: _interval.clamp(1, 999),
            weekdays: _isWeekly ? (_weekdays.toList()..sort()) : const [],
            dayOfMonth: _showDayOfMonth ? _dayOfMonth : null,
            monthOfYear: _showMonthOfYear ? _monthOfYear : null,
            endDate: _endDate,
          );
    Navigator.of(context)
        .pop(_RecurrenceSelection(rule: rule, startDate: _startDate));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Repeat', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RadioGroup<String>(
                      groupValue: _preset,
                      onChanged: (value) {
                        if (value != null) _choosePreset(value);
                      },
                      child: Column(
                        children: [
                          for (final (value, label) in _presets)
                            RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              title: Text(label),
                              value: value,
                            ),
                        ],
                      ),
                    ),
                    if (_preset != 'none') ...[
                      const Divider(),
                      if (_isCustom) ...[
                        DropdownButtonFormField<RecurrenceType>(
                          initialValue: _frequency,
                          decoration: const InputDecoration(
                            labelText: 'Frequency',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: RecurrenceType.daily,
                              child: Text('Daily'),
                            ),
                            DropdownMenuItem(
                              value: RecurrenceType.weekly,
                              child: Text('Weekly'),
                            ),
                            DropdownMenuItem(
                              value: RecurrenceType.monthly,
                              child: Text('Monthly'),
                            ),
                            DropdownMenuItem(
                              value: RecurrenceType.yearly,
                              child: Text('Yearly'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _frequency = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: ValueKey('repeat-interval-$_preset'),
                          initialValue: _interval.toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Interval',
                            helperText:
                                'Repeat every this many frequency units',
                          ),
                          onChanged: (value) {
                            final parsed = int.tryParse(value);
                            if (parsed != null && parsed > 0) {
                              _interval = parsed.clamp(1, 999);
                            }
                          },
                        ),
                      ],
                      if (_showWeeklyOptions) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Weekdays',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Wrap(
                          spacing: 4,
                          children: [
                            for (final (label, weekday) in const [
                              ('S', DateTime.sunday),
                              ('M', DateTime.monday),
                              ('T', DateTime.tuesday),
                              ('W', DateTime.wednesday),
                              ('T', DateTime.thursday),
                              ('F', DateTime.friday),
                              ('S', DateTime.saturday),
                            ])
                              FilterChip(
                                key: ValueKey('weekday-$weekday'),
                                label: Text(label),
                                selected: _weekdays.contains(weekday),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _weekdays.add(weekday);
                                    } else if (_weekdays.length > 1) {
                                      _weekdays.remove(weekday);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                      ],
                      if (_showDayOfMonth) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: _dayOfMonth,
                          decoration: const InputDecoration(
                            labelText: 'Day of month',
                          ),
                          items: [
                            for (var day = 1; day <= 31; day++)
                              DropdownMenuItem(
                                value: day,
                                child: Text(_ordinal(day)),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _dayOfMonth = value);
                            }
                          },
                        ),
                      ],
                      if (_showMonthOfYear) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: _monthOfYear,
                          decoration: const InputDecoration(labelText: 'Month'),
                          items: [
                            for (var month = 1; month <= 12; month++)
                              DropdownMenuItem(
                                value: month,
                                child: Text(_monthLabels[month - 1]),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _monthOfYear = value);
                            }
                          },
                        ),
                      ],
                      if (_isCustom) ...[
                        const SizedBox(height: 8),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Start date'),
                          subtitle: Text(
                            MaterialLocalizations.of(context)
                                .formatMediumDate(_startDate),
                          ),
                          trailing: const Icon(Icons.calendar_month_outlined),
                          onTap: _pickStartDate,
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Ends'),
                          subtitle: Text(
                            _endDate == null
                                ? 'Never'
                                : MaterialLocalizations.of(context)
                                      .formatMediumDate(_endDate!),
                          ),
                          trailing: Wrap(
                            children: [
                              if (_endDate != null)
                                IconButton(
                                  tooltip: 'Remove end date',
                                  onPressed: () =>
                                      setState(() => _endDate = null),
                                  icon: const Icon(Icons.close),
                                ),
                              IconButton(
                                tooltip: 'Choose end date',
                                onPressed: _pickEndDate,
                                icon: const Icon(Icons.event_outlined),
                              ),
                            ],
                          ),
                          onTap: _pickEndDate,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _finish, child: const Text('Done')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _ordinal(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    return switch (day % 10) {
      1 => '${day}st',
      2 => '${day}nd',
      3 => '${day}rd',
      _ => '${day}th',
    };
  }
}
