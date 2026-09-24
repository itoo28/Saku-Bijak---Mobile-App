import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/database/database_service.dart';
import 'core/notifications/notification_service.dart';
import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/security/app_lock_state_provider.dart';
import 'features/onboarding/onboarding_page.dart';
import 'features/app_lock/setup_pin_page.dart';
import 'features/app_lock/lock_page.dart';
import 'features/main_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Indonesian locale formatting for dates and currency
  await initializeDateFormatting('id_ID', null);

  final dbService = DatabaseService();
  final notificationService = NotificationService();

  if (!kIsWeb) {
    // Initialize Core Services on Native
    await dbService.init();
    await notificationService.init();
    await notificationService.requestPermissions();
  }

  runApp(
    ProviderScope(
      overrides: [
        if (!kIsWeb) ...[
          databaseServiceProvider.overrideWithValue(dbService),
          notificationServiceProvider.overrideWithValue(notificationService),
        ],
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Check and trigger lock screen when user returns or leaves
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      ref.read(securityServiceProvider).updateLastInteraction();
    } else if (state == AppLifecycleState.resumed) {
      _checkAutoLock();
    }
  }

  Future<void> _checkAutoLock() async {
    final shouldLock = await ref.read(securityServiceProvider).shouldLock();
    if (shouldLock) {
      ref.read(appLockStateProvider.notifier).lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final appLockState = ref.watch(appLockStateProvider);

    // Resolve current root page based on app lock state
    Widget homeScreen;
    switch (appLockState) {
      case AppLockState.onboarding:
        homeScreen = const OnboardingPage();
        break;
      case AppLockState.setupPin:
        homeScreen = const SetupPinPage();
        break;
      case AppLockState.locked:
        homeScreen = const LockPage();
        break;
      case AppLockState.authorized:
        homeScreen = const MainLayout();
        break;
    }

    return MaterialApp(
      title: 'Saku Bijak',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: homeScreen,
    );
  }
}
