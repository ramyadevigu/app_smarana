import 'package:flutter/material.dart';

import '../calender/models/calendar_view_mode.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../reminders/models/reminder.dart';
import '../../theme/app_design_tokens.dart';
import '../../theme/app_theme.dart';
import '../../theme/premium_surface.dart';
import 'services/reminder_preferences_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.selectedThemeMode,
    required this.selectedCalendarViewMode,
    required this.onThemeModeChanged,
    required this.onCalendarViewModeChanged,
    this.selectedAccentColor = defaultAccentColor,
    this.onAccentColorChanged,
    this.preferencesStore,
  });

  final ThemeMode selectedThemeMode;
  final CalendarViewMode selectedCalendarViewMode;
  final Future<void> Function(ThemeMode) onThemeModeChanged;
  final Future<void> Function(CalendarViewMode) onCalendarViewModeChanged;
  final Color selectedAccentColor;
  final Future<void> Function(Color)? onAccentColorChanged;
  final ReminderPreferencesStore? preferencesStore;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final ReminderPreferencesStore _preferencesStore;
  late Color _selectedAccentColor;
  ReminderDefaults _defaults = const ReminderDefaults();
  List<ReminderSoundOption> _availableSounds = const [];
  Future<void> _saveQueue = Future<void>.value();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedAccentColor = widget.selectedAccentColor;
    _preferencesStore =
        widget.preferencesStore ?? const ReminderPreferencesStore();
    _loadDefaults();
    _loadSounds();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedAccentColor != widget.selectedAccentColor) {
      _selectedAccentColor = widget.selectedAccentColor;
    }
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

  Future<void> _selectAccentColor() async {
    final accentColor = await showDialog<Color>(
      context: context,
      builder: (_) =>
          _AccentColorPickerDialog(initialColor: _selectedAccentColor),
    );
    if (accentColor != null && mounted) {
      await _changeAccentColor(accentColor);
    }
  }

  Future<void> _changeAccentColor(Color accentColor) async {
    if (_selectedAccentColor == accentColor) {
      return;
    }

    setState(() => _selectedAccentColor = accentColor);
    try {
      await widget.onAccentColorChanged?.call(accentColor);
    } on Exception {
      if (mounted) {
        _showSaveError();
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
              ListTile(
                key: const ValueKey('settings-accent-color-picker'),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _selectedAccentColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                ),
                title: const Text('Accent color'),
                subtitle: const Text('Customize the app color'),
                trailing: const Icon(Icons.tune),
                onTap: _selectAccentColor,
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
                child: Wrap(
                  key: const ValueKey('settings-calendar-view-mode'),
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final mode in CalendarViewMode.values)
                      ChoiceChip(
                        label: Text(
                          mode.name == 'threeDay'
                              ? '3 Day'
                              : '${mode.name[0].toUpperCase()}${mode.name.substring(1)}',
                        ),
                        selected: _defaults.calendarViewMode == mode,
                        onSelected: (_) => _changeCalendarViewMode(mode),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
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
                title: const Text('Alarm snooze duration'),
                subtitle: const Text('15 minutes'),
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
    return PremiumSurface(
      color: colorScheme.surfaceContainerLow,
      radius: AppRadius.card,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Material(
          color: Colors.transparent,
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

class _AccentColorPickerDialog extends StatefulWidget {
  const _AccentColorPickerDialog({required this.initialColor});

  final Color initialColor;

  @override
  State<_AccentColorPickerDialog> createState() =>
      _AccentColorPickerDialogState();
}

class _AccentColorPickerDialogState extends State<_AccentColorPickerDialog> {
  late HSLColor _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = HSLColor.fromColor(widget.initialColor);
  }

  Color get _color => _selectedColor.toColor();

  String get _hexColor {
    final rgb = (_color.toARGB32() & 0x00FFFFFF)
        .toRadixString(16)
        .padLeft(6, '0')
        .toUpperCase();
    return '#$rgb';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Choose accent color'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: 'Accent color preview $_hexColor',
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: AppColors.highContrastForeground(_color),
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(_hexColor, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 12),
            _buildSlider(
              label: 'Hue',
              value: _selectedColor.hue,
              min: 0,
              max: 360,
              divisions: 360,
              valueLabel: '${_selectedColor.hue.round()}°',
              sliderKey: const ValueKey('accent-hue-slider'),
              onChanged: (value) => setState(
                () => _selectedColor = _selectedColor.withHue(value),
              ),
            ),
            _buildSlider(
              label: 'Saturation',
              value: _selectedColor.saturation,
              min: 0,
              max: 1,
              divisions: 100,
              valueLabel: '${(_selectedColor.saturation * 100).round()}%',
              sliderKey: const ValueKey('accent-saturation-slider'),
              onChanged: (value) => setState(
                () => _selectedColor = _selectedColor.withSaturation(value),
              ),
            ),
            _buildSlider(
              label: 'Lightness',
              value: _selectedColor.lightness,
              min: 0,
              max: 1,
              divisions: 100,
              valueLabel: '${(_selectedColor.lightness * 100).round()}%',
              sliderKey: const ValueKey('accent-lightness-slider'),
              onChanged: (value) => setState(
                () => _selectedColor = _selectedColor.withLightness(value),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_color),
          child: const Text('Use color'),
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String valueLabel,
    required Key sliderKey,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(valueLabel, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
        Semantics(
          label: label,
          child: Slider(
            key: sliderKey,
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
