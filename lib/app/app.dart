import 'package:flutter/material.dart';

import '../features/calender/calender_screen.dart';
import '../features/reminders/reminders_screen.dart';
import '../features/settings/settings_screen.dart';
import '../theme/app_theme.dart';
import '../theme/theme_preference_store.dart';

enum _AppMenuAction { settings, help, feedback }

class AppSmarana extends StatefulWidget {
  const AppSmarana({
    super.key,
    this.initialThemeMode = ThemeMode.system,
    this.themePreferenceStore = const ThemePreferenceStore(),
  });

  final ThemeMode initialThemeMode;
  final ThemePreferenceStore themePreferenceStore;

  @override
  State<AppSmarana> createState() => _AppSmaranaState();
}

class _AppSmaranaState extends State<AppSmarana> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smarana',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode,
      home: HomeScreen(
        selectedThemeMode: _themeMode,
        onThemeModeChanged: _changeThemeMode,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.selectedThemeMode = ThemeMode.system,
    this.onThemeModeChanged,
  });

  final ThemeMode selectedThemeMode;
  final Future<void> Function(ThemeMode)? onThemeModeChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      CalendarScreen(appMenu: _buildAppMenu()),
      RemindersScreen(title: 'Alarms', appMenu: _buildAppMenu()),
      _TimeToolScreen(
        title: 'Stop Watch',
        icon: Icons.av_timer,
        appMenu: _buildAppMenu(),
      ),
      _TimeToolScreen(
        title: 'Timer',
        icon: Icons.hourglass_bottom,
        appMenu: _buildAppMenu(),
      ),
      _TimeToolScreen(
        title: 'World Clock',
        icon: Icons.public,
        appMenu: _buildAppMenu(),
      ),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            key: ValueKey('nav-calendar'),
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          NavigationDestination(
            key: ValueKey('nav-alarms'),
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications_active),
            label: 'Alarms',
          ),
          NavigationDestination(
            key: ValueKey('nav-stopwatch'),
            icon: Icon(Icons.av_timer_outlined),
            selectedIcon: Icon(Icons.av_timer),
            label: 'Stop Watch',
          ),
          NavigationDestination(
            key: ValueKey('nav-timer'),
            icon: Icon(Icons.hourglass_bottom_outlined),
            selectedIcon: Icon(Icons.hourglass_bottom),
            label: 'Timer',
          ),
          NavigationDestination(
            key: ValueKey('nav-world-clock'),
            icon: Icon(Icons.public_outlined),
            selectedIcon: Icon(Icons.public),
            label: 'World Clock',
          ),
        ],
      ),
    );
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
              onThemeModeChanged: _changeThemeMode,
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
              'Use Calendar to view reminders by date and Alarms to manage '
              'your reminders.',
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
}

class _TimeToolScreen extends StatelessWidget {
  const _TimeToolScreen({
    required this.title,
    required this.icon,
    required this.appMenu,
  });

  final String title;
  final IconData icon;
  final Widget appMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: [appMenu]),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Coming soon',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
