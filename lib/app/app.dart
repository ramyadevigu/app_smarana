import 'package:flutter/material.dart';

import '../features/calender/calender_screen.dart';
import '../features/reminders/reminders_screen.dart';
import '../features/settings/settings_screen.dart';
import '../theme/app_theme.dart';
import '../theme/theme_preference_store.dart';

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
      const CalendarScreen(),
      const RemindersScreen(),
      SettingsScreen(
        selectedThemeMode: widget.selectedThemeMode,
        onThemeModeChanged: _changeThemeMode,
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
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
            label: 'Reminders',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Future<void> _changeThemeMode(ThemeMode themeMode) async {
    await widget.onThemeModeChanged?.call(themeMode);
  }
}
