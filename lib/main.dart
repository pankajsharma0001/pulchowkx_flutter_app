import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pulchowkx_app/pages/main_layout.dart';
import 'package:pulchowkx_app/pages/onboarding_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/services/theme_provider.dart';
import 'package:pulchowkx_app/services/haptic_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pulchowkx_app/widgets/theme_switcher.dart';
import 'firebase_options.dart';

import 'package:pulchowkx_app/services/analytics_service.dart';
import 'package:pulchowkx_app/services/notification_service.dart';

class GlobalHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

// Global ThemeProvider instance for easy access
final themeProvider = ThemeProvider();

// Global Navigator Key for context-less navigation (e.g., from NotificationService)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  HttpOverrides.global = GlobalHttpOverrides();
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

  // Boost Image Cache to 100MB for smoother scrolling
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024;

  // Initialize haptic service with theme provider
  haptics.init(themeProvider);

  // Non-blocking asset pre-caching
  _precacheCriticalAssets();

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

/// Helper to pre-cache critical images to avoid flash-of-no-content
void _precacheCriticalAssets() {
  // Pre-fetch critical UI assets
  // Note: precacheImage requires a BuildContext, but we can also use
  // evict/fetch methods or simply let CachedNetworkImage handle it if we
  // had URLs. For local assets, we can't easily precache here without context.
  // Instead, handles for CachedNetworkImage are mostly primed by usage.
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
            title: 'Smart Pulchowk',
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
