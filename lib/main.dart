import 'package:flutter/material.dart';
import 'package:pulchowkx_app/pages/main_layout.dart';
import 'package:pulchowkx_app/pages/onboarding_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/services/theme_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pulchowkx_app/widgets/theme_switcher.dart';
import 'firebase_options.dart';

import 'package:pulchowkx_app/services/analytics_service.dart';
import 'package:pulchowkx_app/services/notification_service.dart';

// Global ThemeProvider instance for easy access
final themeProvider = ThemeProvider();

// Global Navigator Key for context-less navigation (e.g., from NotificationService)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Failed to initialize Firebase: $e');
  }

  try {
    await Hive.initFlutter();
    await Hive.openBox('api_cache');
  } catch (e) {
    debugPrint('Failed to initialize Hive: $e');
  }

  // Non-blocking analytics
  AnalyticsService.logAppOpen().catchError((e) {
    debugPrint('Failed to log app open: $e');
  });

  // Non-blocking notification init
  NotificationService.initialize().catchError((e) {
    debugPrint('Failed to initialize notifications: $e');
  });

  // Load onboarding preference before running app
  final prefs = await SharedPreferences.getInstance();
  final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

  runApp(MyApp(hasSeenOnboarding: hasSeenOnboarding));
}

class MyApp extends StatelessWidget {
  final bool hasSeenOnboarding;

  const MyApp({super.key, required this.hasSeenOnboarding});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeProvider,
      builder: (context, child) {
        return ThemeSwitcher(
          child: MaterialApp(
            navigatorKey: navigatorKey,
            title: 'PulchowkX',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            themeAnimationDuration: Duration.zero,
            navigatorObservers: [AnalyticsService.observer],
            home: hasSeenOnboarding
                ? const MainLayout()
                : const OnboardingPage(),
          ),
        );
      },
    );
  }
}
