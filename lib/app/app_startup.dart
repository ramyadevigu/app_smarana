import 'package:flutter/material.dart';

import '../features/reminders/services/reminder_storage.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_preference_store.dart';
import 'app.dart';

class AppStartup extends StatefulWidget {
  const AppStartup({super.key});

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  late Future<_AppStartupConfiguration> _startup;

  @override
  void initState() {
    super.initState();
    _startup = _initializeApplication();
  }

  Future<void> _retryInitialization() async {
    setState(() {
      _startup = _initializeApplication();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AppStartupConfiguration>(
      future: _startup,
      builder: (context, snapshot) {
        final configuration = snapshot.data;
        if (configuration != null) {
          return AppSmarana(
            initialThemeMode: configuration.themeMode,
            initialColorTheme: configuration.colorTheme,
            themePreferenceStore: configuration.themePreferenceStore,
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: _StartupErrorScreen(onRetry: _retryInitialization),
          );
        }

        return const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: StartupSplashScreen(),
        );
      },
    );
  }
}

class StartupSplashScreen extends StatelessWidget {
  const StartupSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SplashScaffold(showLoader: true);
  }
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _SplashScaffold(
      showLoader: false,
      message: 'Smaraṇa could not finish loading.',
      onRetry: onRetry,
    );
  }
}

class _SplashScaffold extends StatelessWidget {
  const _SplashScaffold({required this.showLoader, this.message, this.onRetry});

  final bool showLoader;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/background.png',
            key: const ValueKey('startup-background'),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            excludeFromSemantics: true,
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/transparent-logo.png',
                    key: const ValueKey('startup-logo'),
                    width: 128,
                    height: 160,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(height: 24),
                  if (showLoader)
                    const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                        semanticsLabel: 'Loading Smaraṇa',
                      ),
                    )
                  else ...[
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: onRetry,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<_AppStartupConfiguration> _initializeApplication() async {
  try {
    final reminderStorage = ReminderStorage();
    await reminderStorage.initialize();
    await NotificationService.instance.initialize();
    await reminderStorage.rescheduleAllReminders();

    const themePreferenceStore = ThemePreferenceStore();
    final themeMode = await themePreferenceStore.loadThemeMode();
    final colorTheme = await themePreferenceStore.loadColorTheme();

    return _AppStartupConfiguration(
      themeMode: themeMode,
      colorTheme: colorTheme,
      themePreferenceStore: themePreferenceStore,
    );
  } on Object catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'app startup',
      ),
    );
    rethrow;
  }
}

class _AppStartupConfiguration {
  const _AppStartupConfiguration({
    required this.themeMode,
    required this.colorTheme,
    required this.themePreferenceStore,
  });

  final ThemeMode themeMode;
  final SmaranaColorTheme colorTheme;
  final ThemePreferenceStore themePreferenceStore;
}
