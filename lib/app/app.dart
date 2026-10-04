import 'dart:async';

import 'package:flutter/material.dart';

import '../features/calender/models/calendar_view_mode.dart';
import '../features/calender/calender_screen.dart';
import '../features/notes/notes_screen.dart';
import '../features/reminders/screens/add_reminder_screen.dart';
import '../features/reminders/services/reminder_storage.dart';
import '../features/reminders/reminders_screen.dart';
import '../features/settings/services/reminder_preferences_store.dart';
import '../features/settings/settings_screen.dart';
import '../features/time_tools/stopwatch_screen.dart';
import '../features/time_tools/timer_screen.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_preference_store.dart';

enum _AppMenuAction { settings, help, feedback }

class AppSmarana extends StatefulWidget {
  const AppSmarana({
    super.key,
    this.initialThemeMode = ThemeMode.system,
    this.initialAccentColor = defaultAccentColor,
    this.themePreferenceStore = const ThemePreferenceStore(),
  });

  final ThemeMode initialThemeMode;
  final Color initialAccentColor;
  final ThemePreferenceStore themePreferenceStore;

  @override
  State<AppSmarana> createState() => _AppSmaranaState();
}

class _AppSmaranaState extends State<AppSmarana> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late ThemeMode _themeMode;
  late Color _accentColor;
  StreamSubscription<String>? _notificationSubscription;
  bool _openingNotificationReminder = false;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;
    _accentColor = widget.initialAccentColor;
    final notifications = NotificationService.instance;
    _notificationSubscription = notifications.openedReminderIds.listen(
      _openReminderFromNotification,
    );
    final launchReminderId = notifications.takeInitialReminderId();
    if (launchReminderId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openReminderFromNotification(launchReminderId);
      });
    }
  }

  @override
  void dispose() {
    final subscription = _notificationSubscription;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  Future<void> _openReminderFromNotification(String reminderId) async {
    if (_openingNotificationReminder || !mounted) {
      return;
    }

    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openReminderFromNotification(reminderId);
      });
      return;
    }

    _openingNotificationReminder = true;
    try {
      final reminders = await ReminderStorage().getReminders();
      for (final reminder in reminders) {
        if (reminder.id == reminderId && mounted) {
          await navigator.push<void>(
            MaterialPageRoute<void>(
              builder: (_) => AddReminderScreen(reminder: reminder),
            ),
          );
          return;
        }
      }
    } on Exception catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stackTrace),
      );
    } finally {
      _openingNotificationReminder = false;
    }
  }

  Future<void> _changeThemeMode(ThemeMode themeMode) async {
    if (_themeMode == themeMode) {
      return;
    }

    setState(() {
      _themeMode = themeMode;
    });
    await widget.themePreferenceStore.saveThemeMode(themeMode);
  }

  Future<void> _changeAccentColor(Color accentColor) async {
    if (_accentColor == accentColor) {
      return;
    }

    setState(() => _accentColor = accentColor);
    await widget.themePreferenceStore.saveAccentColor(accentColor);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Total Reminders',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(_accentColor),
      darkTheme: buildDarkTheme(_accentColor),
      themeMode: _themeMode,
      home: HomeScreen(
        selectedThemeMode: _themeMode,
        onThemeModeChanged: _changeThemeMode,
        selectedAccentColor: _accentColor,
        onAccentColorChanged: _changeAccentColor,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.selectedThemeMode = ThemeMode.system,
    this.onThemeModeChanged,
    this.selectedAccentColor = defaultAccentColor,
    this.onAccentColorChanged,
  });

  final ThemeMode selectedThemeMode;
  final Future<void> Function(ThemeMode)? onThemeModeChanged;
  final Color selectedAccentColor;
  final Future<void> Function(Color)? onAccentColorChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final Set<int> _visitedTabs = {0};
  final ReminderPreferencesStore _preferencesStore =
      const ReminderPreferencesStore();
  CalendarViewMode _calendarViewMode = CalendarViewMode.month;

  @override
  void initState() {
    super.initState();
    _loadCalendarViewMode();
  }

  Future<void> _loadCalendarViewMode() async {
    try {
      final defaults = await _preferencesStore.loadDefaults();
      if (!mounted) {
        return;
      }
      setState(() {
        _calendarViewMode = defaults.calendarViewMode;
      });
    } on Exception {
      // Keep default view mode if preferences cannot be read.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: List<Widget>.generate(5, _buildTab),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        indicatorColor: Theme.of(context).colorScheme.primary,
        onDestinationSelected: (index) {
          setState(() {
            _visitedTabs.add(index);
            _currentIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            key: ValueKey('nav-calendar'),
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(
              Icons.calendar_month,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            label: 'Calendar',
          ),
          NavigationDestination(
            key: ValueKey('nav-notes'),
            icon: Icon(Icons.sticky_note_2_outlined),
            selectedIcon: Icon(
              Icons.sticky_note_2,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            label: 'Notes',
          ),
          NavigationDestination(
            key: ValueKey('nav-alarms'),
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(
              Icons.notifications_active,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            label: 'Alarms',
          ),
          NavigationDestination(
            key: ValueKey('nav-stopwatch'),
            icon: Icon(Icons.av_timer_outlined),
            selectedIcon: Icon(
              Icons.av_timer,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            label: 'Stopwatch',
          ),
          NavigationDestination(
            key: ValueKey('nav-timer'),
            icon: Icon(Icons.hourglass_bottom_outlined),
            selectedIcon: Icon(
              Icons.hourglass_bottom,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            label: 'Timer',
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index) {
    if (!_visitedTabs.contains(index)) {
      return const SizedBox.shrink();
    }

    return switch (index) {
      0 => CalendarScreen(
        viewMode: _calendarViewMode,
        onViewModeChanged: _changeCalendarViewMode,
        appMenu: _buildAppMenu(),
      ),
      1 => NotesScreen(
        appMenu: _buildAppMenu(),
        onBackToSmarana: _returnToCalendar,
      ),
      2 => RemindersScreen(title: 'Alarms', appMenu: _buildAppMenu()),
      3 => StopwatchScreen(appMenu: _buildAppMenu()),
      4 => TimerScreen(appMenu: _buildAppMenu()),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildAppMenu() {
    return PopupMenuButton<_AppMenuAction>(
      key: const ValueKey('app-overflow-menu'),
      tooltip: 'More options',
      icon: const Icon(Icons.more_vert),
      onSelected: _handleAppMenuAction,
      itemBuilder: (context) => const [
        PopupMenuItem<_AppMenuAction>(
          value: _AppMenuAction.settings,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.settings_outlined),
            title: Text('Settings'),
          ),
        ),
        PopupMenuItem<_AppMenuAction>(
          value: _AppMenuAction.help,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.help_outline),
            title: Text('Help'),
          ),
        ),
        PopupMenuItem<_AppMenuAction>(
          value: _AppMenuAction.feedback,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.feedback_outlined),
            title: Text('Send Feedback'),
          ),
        ),
      ],
    );
  }

  Future<void> _handleAppMenuAction(_AppMenuAction action) async {
    switch (action) {
      case _AppMenuAction.settings:
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => SettingsScreen(
              selectedThemeMode: widget.selectedThemeMode,
              selectedAccentColor: widget.selectedAccentColor,
              selectedCalendarViewMode: _calendarViewMode,
              onCalendarViewModeChanged: _changeCalendarViewMode,
              onThemeModeChanged: _changeThemeMode,
              onAccentColorChanged: widget.onAccentColorChanged,
            ),
          ),
        );
      case _AppMenuAction.help:
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.help_outline),
            title: const Text('Help'),
            content: const Text(
              'Use Calendar to view reminders, Notes to save ideas, and '
              'Alarms to manage your reminders.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      case _AppMenuAction.feedback:
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.feedback_outlined),
            title: const Text('Send Feedback'),
            content: const Text('Feedback delivery is not configured yet.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
    }
  }

  Future<void> _changeThemeMode(ThemeMode themeMode) async {
    await widget.onThemeModeChanged?.call(themeMode);
  }

  Future<void> _changeCalendarViewMode(CalendarViewMode viewMode) async {
    if (_calendarViewMode == viewMode) {
      return;
    }
    setState(() {
      _calendarViewMode = viewMode;
    });
    final defaults = await _preferencesStore.loadDefaults();
    await _preferencesStore.saveDefaults(
      defaults.copyWith(calendarViewMode: viewMode),
    );
  }

  void _returnToCalendar() {
    if (_currentIndex == 0) {
      return;
    }
    setState(() {
      _currentIndex = 0;
    });
  }
}
