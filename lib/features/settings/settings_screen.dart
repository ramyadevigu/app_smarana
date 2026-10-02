import 'package:flutter/material.dart';

import '../calender/models/calendar_view_mode.dart';
import '../../services/notification_service.dart';
import '../reminders/models/reminder.dart';
import 'services/reminder_preferences_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.selectedThemeMode,
    required this.selectedCalendarViewMode,
    required this.onThemeModeChanged,
    required this.onCalendarViewModeChanged,
    this.preferencesStore,
  });

  final ThemeMode selectedThemeMode;
  final CalendarViewMode selectedCalendarViewMode;
  final Future<void> Function(ThemeMode) onThemeModeChanged;
  final Future<void> Function(CalendarViewMode) onCalendarViewModeChanged;
  final ReminderPreferencesStore? preferencesStore;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final ReminderPreferencesStore _preferencesStore;
  ReminderDefaults _defaults = const ReminderDefaults();
  List<ReminderSoundOption> _availableSounds = const [];
  Future<void> _saveQueue = Future<void>.value();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _preferencesStore =
        widget.preferencesStore ?? const ReminderPreferencesStore();
    _loadDefaults();
    _loadSounds();
  }

  Future<void> _loadDefaults() async {
    try {
      final defaults = await _preferencesStore.loadDefaults();
      if (mounted) {
        setState(() {
          _defaults = defaults;
          _isLoading = false;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSaveError();
      }
    }
  }

  Future<void> _loadSounds() async {
    try {
      final sounds = await NotificationService.instance.availableAlarmSounds();
      if (mounted) {
        setState(() => _availableSounds = sounds);
      }
    } on Exception {
      if (mounted) {
        setState(() => _availableSounds = const []);
      }
    }
  }

  Future<void> _updateDefaults(ReminderDefaults defaults) async {
    setState(() => _defaults = defaults);
    final save = _saveQueue.then(
      (_) => _preferencesStore.saveDefaults(defaults),
    );
    _saveQueue = save.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    try {
      await save;
    } on Exception {
      if (mounted) {
        _showSaveError();
      }
    }
  }

  void _showSaveError() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Unable to save settings.')));
  }

  Future<void> _selectSound() async {
    final sounds = [
      const ReminderSoundOption(name: 'Default', uri: null),
      ..._availableSounds,
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
            child: Text(
              'Default ringtone',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final sound in sounds)
            ListTile(
              leading: Icon(
                _defaults.soundUri == sound.uri &&
                        _defaults.soundName == sound.name
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(sound.name),
              onTap: () => Navigator.of(context).pop(sound),
            ),
          if (_availableSounds.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text('No additional ringtones are available.'),
            ),
        ],
      ),
    );
    if (selection != null && mounted) {
      await _updateDefaults(
        _defaults.copyWith(
          soundUri: selection.uri,
          clearSoundUri: selection.uri == null,
          soundName: selection.name,
        ),
      );
    }
  }

  Future<void> _selectSnoozeDuration() async {
    const durations = [5, 10, 15, 20, 30];
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
              trailing: _defaults.snoozeDurationMinutes == minutes
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(context).pop(minutes),
            ),
        ],
      ),
    );
    if (selection != null && mounted) {
      await _updateDefaults(
        _defaults.copyWith(snoozeDurationMinutes: selection),
      );
    }
  }

  Future<void> _changeThemeMode(ThemeMode themeMode) async {
    try {
      await widget.onThemeModeChanged(themeMode);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save the theme setting.')),
        );
      }
    }
  }

  Future<void> _changeCalendarViewMode(CalendarViewMode mode) async {
    if (_defaults.calendarViewMode == mode) {
      return;
    }

    await _updateDefaults(_defaults.copyWith(calendarViewMode: mode));
    try {
      await widget.onCalendarViewModeChanged(mode);
    } on Exception {
      if (mounted) {
        _showSaveError();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          _sectionHeading(
            context,
            Icons.notifications_active_outlined,
            'Notifications',
          ),
          const SizedBox(height: 12),
          _settingsGroup(
            colorScheme,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'Default notification',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              RadioGroup<ReminderNotificationMode>(
                groupValue: _defaults.notificationMode,
                onChanged: (mode) {
                  if (mode != null) {
                    _updateDefaults(_defaults.copyWith(notificationMode: mode));
                  }
                },
                child: const Column(
                  children: [
                    RadioListTile<ReminderNotificationMode>(
                      dense: true,
                      value: ReminderNotificationMode.alarmAndNotification,
                      title: Text('Alarm + Notification'),
                    ),
                    RadioListTile<ReminderNotificationMode>(
                      dense: true,
                      value: ReminderNotificationMode.notificationOnly,
                      title: Text('Notification only'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                key: const ValueKey('settings-default-ringtone'),
                leading: const Icon(Icons.music_note_outlined),
                title: const Text('Default ringtone'),
                subtitle: Text(_defaults.soundName),
                trailing: const Icon(Icons.chevron_right),
                onTap: _selectSound,
              ),
              const Divider(height: 1),
              ListTile(
                key: const ValueKey('settings-default-snooze'),
                leading: const Icon(Icons.snooze_outlined),
                title: const Text('Default snooze duration'),
                subtitle: Text('${_defaults.snoozeDurationMinutes} minutes'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _selectSnoozeDuration,
              ),
              const Divider(height: 1),
              SwitchListTile(
                key: const ValueKey('settings-default-vibration'),
                secondary: const Icon(Icons.vibration_outlined),
                title: const Text('Vibration'),
                subtitle: Text(_defaults.vibrate ? 'On' : 'Off'),
                value: _defaults.vibrate,
                onChanged: (value) =>
                    _updateDefaults(_defaults.copyWith(vibrate: value)),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _sectionHeading(context, Icons.palette_outlined, 'Appearance'),
          const SizedBox(height: 12),
          _settingsGroup(
            colorScheme,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Text(
                  'Theme',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined),
                      label: Text('System'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text('Light'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: Text('Dark'),
                    ),
                  ],
                  selected: {widget.selectedThemeMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    _changeThemeMode(selection.first);
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Text(
                  'Calendar view',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: SegmentedButton<CalendarViewMode>(
                  key: const ValueKey('settings-calendar-view-mode'),
                  segments: const [
                    ButtonSegment<CalendarViewMode>(
                      value: CalendarViewMode.monthAndWeek,
                      icon: Icon(Icons.view_agenda_outlined),
                      label: Text('Month + Week'),
                    ),
                    ButtonSegment<CalendarViewMode>(
                      value: CalendarViewMode.nextThreeDays,
                      icon: Icon(Icons.view_week_outlined),
                      label: Text('3 Days'),
                    ),
                    ButtonSegment<CalendarViewMode>(
                      value: CalendarViewMode.monthOnly,
                      icon: Icon(Icons.calendar_view_month_outlined),
                      label: Text('Month'),
                    ),
                  ],
                  selected: {_defaults.calendarViewMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    _changeCalendarViewMode(selection.first);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(BuildContext context, IconData icon, String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: colorScheme.primary, size: 20),
        const SizedBox(width: 10),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }

  Widget _settingsGroup(
    ColorScheme colorScheme, {
    required List<Widget> children,
  }) {
    return Material(
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
