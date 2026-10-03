import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/reminder.dart';
import '../services/reminder_storage.dart';
import '../../../services/notification_service.dart';
import '../../settings/services/reminder_preferences_store.dart';

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
  final ReminderPreferencesStore? preferencesStore;
  final DateTime? initialDate;

  const AddReminderScreen({
    super.key,
    this.reminder,
    this.storage,
    this.preferencesStore,
    this.initialDate,
  });

  bool get isEditing => reminder != null;

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _uuid = const Uuid();
  late final ReminderStorage _storage;
  late final ReminderPreferencesStore _preferencesStore;

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
  bool _defaultsReady = false;
  bool _textFieldsCanRequestFocus = true;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? ReminderStorage();
    _preferencesStore =
        widget.preferencesStore ?? const ReminderPreferencesStore();

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
      _defaultsReady = true;
      _titleController.text = reminder.title;
      _selectedDate = DateTime(
        reminder.dateTime.year,
        reminder.dateTime.month,
        reminder.dateTime.day,
      );
      _selectedTime = TimeOfDay.fromDateTime(reminder.dateTime);
      return;
    }

    _titleController.text = 'Untitled Reminder';
    final initialDateTime = DateTime.now().add(const Duration(minutes: 5));
    final today = DateUtils.dateOnly(DateTime.now());
    final requestedDate = widget.initialDate;
    final initialDate = requestedDate ?? today;
    _selectedDate = DateTime(
      initialDate.year,
      initialDate.month,
      initialDate.day,
    );
    _selectedTime = TimeOfDay.fromDateTime(initialDateTime);
    _loadReminderDefaults();
  }

  Future<void> _loadReminderDefaults() async {
    try {
      final defaults = await _preferencesStore.loadDefaults();
      if (!mounted) {
        return;
      }
      setState(() {
        _notificationMode = defaults.notificationMode;
        _soundUri = defaults.soundUri;
        _soundName = defaults.soundName;
        _snoozeDurationMinutes = defaults.snoozeDurationMinutes;
        _vibrate = defaults.vibrate;
        _defaultsReady = true;
      });
    } on Exception {
      if (mounted) {
        setState(() => _defaultsReady = true);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  Future<T?> _showOptionOverlay<T>(Future<T?> Function() showOverlay) async {
    setState(() => _textFieldsCanRequestFocus = false);
    _dismissKeyboard();
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) {
        return null;
      }
      return await showOverlay();
    } finally {
      if (mounted) {
        setState(() => _textFieldsCanRequestFocus = true);
        _dismissKeyboard();
      }
    }
  }

  Future<void> _selectDate(FormFieldState<DateTime> field) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final firstDate = widget.isEditing ? DateTime(1900) : today;
    final selectedDate = _selectedDate ?? today;
    final date = await _showOptionOverlay(
      () => showDatePicker(
        context: context,
        initialDate: selectedDate.isBefore(firstDate)
            ? firstDate
            : selectedDate,
        firstDate: firstDate,
        lastDate: DateTime(2100),
      ),
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
    final time = await _showOptionOverlay(
      () => showTimePicker(
        context: context,
        initialTime: _selectedTime ?? TimeOfDay.now(),
        initialEntryMode: TimePickerEntryMode.dial,
      ),
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
    _dismissKeyboard();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a title for this reminder.')),
      );
      return;
    }
    final date = _selectedDate;
    final time = _selectedTime;
    if (date == null || time == null) {
      return;
    }

    final existing = widget.reminder;
    final reminder = Reminder(
      id: existing?.id ?? _uuid.v4(),
      title: title,
      description: existing?.description,
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
    final selection = await _showOptionOverlay(
      () => showModalBottomSheet<_RecurrenceSelection>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => _RecurrenceSheet(
          initialRule: _recurrenceRule,
          initialDate: _selectedDate ?? DateTime.now(),
        ),
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
    final selection = await _showOptionOverlay(
      () => showModalBottomSheet<ReminderSoundOption>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                'Sound',
                style: Theme.of(context).textTheme.titleLarge,
              ),
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
    final selection = await _showOptionOverlay(
      () => showModalBottomSheet<ReminderNotificationMode>(
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
      ),
    );
    if (selection != null && mounted) {
      setState(() => _notificationMode = selection);
    }
  }

  Future<void> _selectSnoozeDuration() async {
    const durations = [5, 10, 15, 30, 60];
    final selection = await _showOptionOverlay(
      () => showModalBottomSheet<Object>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                'Snooze',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final minutes in durations)
              ListTile(
                title: Text('$minutes minutes'),
                trailing: _snoozeDurationMinutes == minutes
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(context).pop(minutes),
              ),
            ListTile(
              title: const Text('Custom'),
              trailing: !durations.contains(_snoozeDurationMinutes)
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(context).pop('custom'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (selection == 'custom' && mounted) {
      final minutes = await _showCustomSnoozeDialog();
      if (minutes != null && mounted) {
        setState(() => _snoozeDurationMinutes = minutes);
      }
    } else if (selection is int && mounted) {
      setState(() => _snoozeDurationMinutes = selection);
    }
  }

  Future<int?> _showCustomSnoozeDialog() async {
    final controller = TextEditingController(
      text: _snoozeDurationMinutes > 60
          ? _snoozeDurationMinutes.toString()
          : '',
    );
    final formKey = GlobalKey<FormState>();
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom snooze'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Minutes',
              helperText: 'Enter a value from 1 to 1440 minutes.',
            ),
            validator: (value) {
              final minutes = int.tryParse(value?.trim() ?? '');
              return minutes == null || minutes < 1 || minutes > 1440
                  ? 'Enter a value from 1 to 1440.'
                  : null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }
              Navigator.of(context).pop(int.parse(controller.text.trim()));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return minutes;
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
    final colorScheme = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 68,
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          titleSpacing: 0,
          title: Semantics(
            label: 'Reminder title',
            textField: true,
            child: TextField(
              key: const ValueKey('title-field'),
              controller: _titleController,
              canRequestFocus: _textFieldsCanRequestFocus,
              textInputAction: TextInputAction.done,
              maxLines: 1,
              onSubmitted: (_) => _saveReminder(),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.3),
              decoration: InputDecoration(
                hintText: 'Untitled Reminder',
                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          actions: [
            IconButton(
              key: const ValueKey('save-reminder'),
              tooltip: 'Save reminder',
              onPressed: _isSaving || !_defaultsReady ? null : _saveReminder,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeading(context, 'WHEN'),
                const SizedBox(height: 4),
                FormField<DateTime>(
                  initialValue: _selectedDate,
                  validator: (value) => value == null ? 'Choose a date.' : null,
                  builder: (field) => Column(
                    children: [
                      _scheduleRow(
                        key: const ValueKey('date-field'),
                        icon: Icons.calendar_today_outlined,
                        label: 'Date',
                        value: _formatDate(context, _selectedDate),
                        onTap: () => _selectDate(field),
                      ),
                      _fieldError(field.errorText),
                    ],
                  ),
                ),
                _rowDivider(context),
                FormField<TimeOfDay>(
                  initialValue: _selectedTime,
                  validator: (value) => value == null ? 'Choose a time.' : null,
                  builder: (field) => Column(
                    children: [
                      _scheduleRow(
                        key: const ValueKey('time-field'),
                        icon: Icons.access_time_rounded,
                        label: 'Time',
                        value: _formatTime(context, field.value),
                        onTap: () => _selectTime(field),
                      ),
                      _fieldError(field.errorText),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _sectionHeading(context, 'REPEAT'),
                const SizedBox(height: 4),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const ValueKey('repeat-field'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: _selectRecurrence,
                    child: SizedBox(
                      height: 64,
                      child: Row(
                        children: [
                          _rowIcon(context, Icons.repeat_rounded),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Repeat',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 2),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: Text(
                                    _recurrenceLabel(
                                      _recurrenceRule,
                                      _selectedDate,
                                    ),
                                    key: ValueKey(
                                      'repeat-${_recurrenceLabel(_recurrenceRule, _selectedDate)}',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _sectionHeading(context, 'ALERTS'),
                const SizedBox(height: 4),
                _preferenceRow(
                  key: const ValueKey('sound-option'),
                  icon: Icons.music_note_outlined,
                  title: 'Sound',
                  value: _soundName,
                  onTap: _selectSound,
                ),
                _rowDivider(context),
                _preferenceRow(
                  key: const ValueKey('vibrate-option'),
                  icon: Icons.vibration_outlined,
                  title: 'Vibrate',
                  value: _vibrate ? 'On' : 'Off',
                  trailing: Switch.adaptive(
                    value: _vibrate,
                    onChanged: (value) {
                      _dismissKeyboard();
                      setState(() => _vibrate = value);
                    },
                  ),
                ),
                _rowDivider(context),
                _preferenceRow(
                  key: const ValueKey('notification-mode-option'),
                  icon: Icons.notifications_active_outlined,
                  title: 'Alert style',
                  value: _notificationModeLabel,
                  onTap: _selectNotificationMode,
                ),
                _rowDivider(context),
                _preferenceRow(
                  key: const ValueKey('snooze-option'),
                  icon: Icons.snooze_outlined,
                  title: 'Snooze',
                  value: _snoozeLabel(_snoozeDurationMinutes),
                  onTap: _selectSnoozeDuration,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeading(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _scheduleRow({
    required Key key,
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      key: key,
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              _rowIcon(context, icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Text(
                        value,
                        key: ValueKey(value),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _preferenceRow({
    required Key key,
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      key: key,
      color: Colors.transparent,
      child: InkWell(
        onTap: trailing == null ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _rowIcon(context, icon),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              if (trailing == null) ...[
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
              ] else
                trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _rowIcon(BuildContext context, IconData icon) {
    return SizedBox(
      width: 24,
      child: Icon(
        icon,
        size: 21,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _rowDivider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.6,
      indent: 38,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }

  String _snoozeLabel(int minutes) {
    return minutes == 60 ? '1 hour' : '$minutes minutes';
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
    if (weekdays.toSet().containsAll(const [
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
        ]) &&
        weekdays.length == 5 &&
        rule.interval == 1) {
      return 'Weekdays';
    }
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
    ('custom', 'Custom'),
    ('none', 'Does not repeat'),
    ('daily', 'Every day'),
    ('weekly', 'Every week'),
    ('biweekly', 'Every 2 weeks'),
    ('alternateWeeks', 'Alternate weeks'),
    ('monthly', 'Every month'),
    ('bimonthly', 'Every 2 months'),
    ('alternateMonths', 'Alternate months'),
    ('yearly', 'Every year'),
    ('weekdays', 'Weekdays'),
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
      if (rule.interval == 1 &&
          rule.weekdays.toSet().containsAll(const [
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
            DateTime.friday,
          ]) &&
          rule.weekdays.length == 5) {
        return 'weekdays';
      }
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
      switch (preset) {
        case 'none':
          break;
        case 'daily':
          _frequency = RecurrenceType.daily;
          _interval = 1;
        case 'weekdays':
          _frequency = RecurrenceType.weekly;
          _interval = 1;
          _weekdays = {
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
            DateTime.friday,
          };
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
                    DropdownButtonFormField<String>(
                      key: const ValueKey('repeat-frequency'),
                      initialValue: _preset,
                      decoration: const InputDecoration(
                        labelText: 'Repeat',
                        prefixIcon: Icon(Icons.repeat_rounded),
                      ),
                      items: [
                        for (final (value, label) in _presets)
                          DropdownMenuItem(value: value, child: Text(label)),
                      ],
                      onChanged: (value) {
                        if (value != null) _choosePreset(value);
                      },
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOutCubic,
                      child: _preset == 'none'
                          ? const SizedBox(width: double.infinity)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 16),
                                if (_isCustom) ...[
                                  DropdownButtonFormField<RecurrenceType>(
                                    initialValue: _frequency,
                                    decoration: const InputDecoration(
                                      labelText: 'Frequency',
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: RecurrenceType.daily,
                                        child: Text('Day'),
                                      ),
                                      DropdownMenuItem(
                                        value: RecurrenceType.weekly,
                                        child: Text('Week'),
                                      ),
                                      DropdownMenuItem(
                                        value: RecurrenceType.monthly,
                                        child: Text('Month'),
                                      ),
                                      DropdownMenuItem(
                                        value: RecurrenceType.yearly,
                                        child: Text('Year'),
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
                                      labelText: 'Repeat every',
                                      helperText: 'Choose how often this reminder repeats',
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
                                  Text(
                                    'Repeat on',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                  const SizedBox(height: 8),
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
                                    decoration: InputDecoration(
                                      labelText: _isYearly
                                          ? 'Day of month'
                                          : 'On day',
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
                                    decoration: const InputDecoration(
                                      labelText: 'Month',
                                    ),
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
                                if (_isCustom)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Starts'),
                                    subtitle: Text(
                                      MaterialLocalizations.of(context)
                                          .formatMediumDate(_startDate),
                                    ),
                                    trailing: const Icon(
                                      Icons.calendar_month_outlined,
                                    ),
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
                                if (_preset != 'none') ...[
                                  const SizedBox(height: 8),
                                  Divider(
                                    height: 1,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Preview',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelMedium?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _previewLabel(),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ],
                            ),
                    ),
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

  String _previewLabel() {
    final localizations = MaterialLocalizations.of(context);
    final selectedWeekdays = _weekdays.toList()..sort();
    final weekdays = selectedWeekdays
        .map(_weekdayName)
        .where((name) => name.isNotEmpty)
        .join(', ');
    String every(int interval, String unit) =>
        'Every $interval $unit${interval == 1 ? '' : 's'}';

    final label = switch (_preset) {
      'weekdays' => 'Every weekday',
      'daily' => 'Every day',
      'weekly' => 'Every week on $weekdays',
      'biweekly' || 'alternateWeeks' =>
        'Every 2 weeks on $weekdays',
      'monthly' => 'Every month on ${_ordinal(_dayOfMonth)}',
      'bimonthly' || 'alternateMonths' =>
        'Every 2 months on ${_ordinal(_dayOfMonth)}',
      'yearly' =>
        'Every year on ${_monthLabels[_monthOfYear - 1]} '
            '${_ordinal(_dayOfMonth)}',
      _ => switch (_frequency) {
        RecurrenceType.none => 'Does not repeat',
        RecurrenceType.daily => every(_interval, 'day'),
        RecurrenceType.weekly => '${every(_interval, 'week')} on $weekdays',
        RecurrenceType.monthly =>
          '${every(_interval, 'month')} on ${_ordinal(_dayOfMonth)}',
        RecurrenceType.yearly =>
          '${every(_interval, 'year')} on ${_monthLabels[_monthOfYear - 1]} '
              '${_ordinal(_dayOfMonth)}',
      },
    };
    final endDate = _endDate;
    return endDate == null
        ? label
        : '$label until ${localizations.formatMediumDate(endDate)}';
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
