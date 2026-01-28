import 'package:flutter/material.dart';
import 'package:pulchowkx_app/pages/splash_screen.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/services/theme_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';

import 'package:pulchowkx_app/services/analytics_service.dart';
import 'package:pulchowkx_app/services/notification_service.dart';

// Global ThemeProvider instance for easy access
final themeProvider = ThemeProvider();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();
  await Hive.openBox('api_cache');
  await AnalyticsService.logAppOpen();
  await NotificationService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeProvider,
      builder: (context, child) {
        return MaterialApp(
          title: 'PulchowkX',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          navigatorObservers: [AnalyticsService.observer],
          home: const SplashScreen(),
        );
      },
    );
  }
}
