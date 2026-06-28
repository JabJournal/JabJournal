import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/peptide_provider.dart';
import 'providers/dose_history_provider.dart';
import 'providers/calculator_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/schedule_provider.dart';
import 'providers/backup_provider.dart';
import 'providers/foreground_service_provider.dart';
import 'providers/notification_status_provider.dart';
import 'providers/weight_provider.dart';
import 'screens/home/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'services/backup_scheduler.dart';
import 'services/notification_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Required by flutter_foreground_task — sets up the isolate communication
  // channel between the main app and the foreground service. Must be called
  // before any other foreground task API.
  FlutterForegroundTask.initCommunicationPort();

  final themeProvider = ThemeProvider();
  await themeProvider.load();

  // Load backup settings eagerly so BackupScheduler has the correct
  // autoBackupEnabled flag before any provider can trigger a backup.
  final backupProvider = BackupProvider();
  await backupProvider.load();
  BackupScheduler.instance.configure(backupProvider);

  final prefs = await SharedPreferences.getInstance();
  final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

  runApp(PeptideTrackerApp(
    themeProvider: themeProvider,
    backupProvider: backupProvider,
    showOnboarding: !onboardingComplete,
  ));
}

class PeptideTrackerApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  final BackupProvider backupProvider;
  final bool showOnboarding;

  const PeptideTrackerApp({
    super.key,
    required this.themeProvider,
    required this.backupProvider,
    required this.showOnboarding,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => PeptideProvider()),
        ChangeNotifierProvider(create: (_) => DoseHistoryProvider()),
        ChangeNotifierProvider(create: (_) => CalculatorProvider()),
        ChangeNotifierProvider(create: (_) {
          final notificationProvider = NotificationProvider();
          notificationProvider.initialize();
          return notificationProvider;
        }),
        ChangeNotifierProvider(create: (_) {
          final scheduleProvider = ScheduleProvider();
          scheduleProvider.loadAllSchedules();
          return scheduleProvider;
        }),
        // Injected via .value — already fully loaded before runApp.
        ChangeNotifierProvider.value(value: backupProvider),
        ChangeNotifierProvider(create: (_) => WeightProvider()),
        ChangeNotifierProvider(create: (_) {
          final p = NotificationStatusProvider();
          p.refresh();
          return p;
        }),
        ChangeNotifierProvider(create: (_) {
          final p = ForegroundServiceProvider();
          p.load();
          return p;
        }),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp(
          title: 'JabJournal',
          navigatorKey: NotificationRouter.navigatorKey,
          themeMode: theme.themeMode,
          theme: theme.lightTheme,
          darkTheme: theme.darkTheme,
          home: WithForegroundTask(
            child: showOnboarding
                ? const OnboardingScreen()
                : const HomeScreen(),
          ),
        ),
      ),
    );
  }
}
