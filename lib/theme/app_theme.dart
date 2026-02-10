import 'package:flutter/material.dart';

/// App color palette - Telegram-style clean and modern theme
class AppColors {
  // Primary colors - Telegram Blue
  static const Color primary = Color(0xFF2AABEE); // Telegram Blue
  static const Color primaryDark = Color(0xFF229ED9); // Darker Telegram Blue
  static const Color primaryLight = Color(0xFF6EC6FF); // Lighter Telegram Blue

  // Secondary/Accent colors
  static const Color accent = Color(
    0xFF2AABEE,
  ); // Same as primary for consistency
  static const Color accentLight = Color(0xFFE7F5FF); // Very light blue

  // Background colors (Light) - Clean white like Telegram
  static const Color background = Color(0xFFF2F2F7); // Soft gray background
  static const Color backgroundSecondary = Color(0xFFE5E5EA); // Deeper gray
  static const Color surface = Color(0xFFFFFFFF); // Pure white
  static const Color cardBackground = Color(0xFFFFFFFF); // White cards

  // Background colors (Dark) - True black like Telegram
  static const Color backgroundDark = Color(0xFF000000); // True black
  static const Color backgroundSecondaryDark = Color(0xFF000000); // Pure black
  static const Color surfaceDark = Color(0xFF000000); // Pure black
  static const Color cardBackgroundDark = Color(0xFF000000); // Pure black

  // Text colors (Light)
  static const Color textPrimary = Color(0xFF000000); // Black text
  static const Color textSecondary = Color(0xFF8E8E93); // iOS gray
  static const Color textMuted = Color(0xFFC7C7CC); // Light gray

  // Text colors (Dark)
  static const Color textPrimaryDark = Color(0xFFFFFFFF); // White text
  static const Color textSecondaryDark = Color(0xFF8E8E93); // Same gray
  static const Color textMutedDark = Color(0xFF48484A); // Dark muted

  // Status colors - Telegram style
  static const Color success = Color(0xFF34C759); // iOS green
  static const Color successLight = Color(0xFFD4EDDA);
  static const Color error = Color(0xFFFF3B30); // iOS red
  static const Color errorLight = Color(0xFFFFE5E5);
  static const Color warning = Color(0xFFFF9500); // iOS orange
  static const Color warningLight = Color(0xFFFFF3CD);
  static const Color info = Color(0xFF2AABEE); // Telegram blue
  static const Color infoLight = Color(0xFFE7F5FF);

  // Border colors - Subtle like Telegram
  static const Color border = Color(0xFFE5E5EA); // iOS separator
  static const Color borderLight = Color(0xFFF2F2F7);
  static const Color borderDark = Color(0xFF38383A); // Dark separator

  // Gradients - More subtle, Telegram-inspired
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2AABEE), Color(0xFF229ED9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFFF2F2F7), Color(0xFFE5E5EA)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient heroGradientDark = LinearGradient(
    colors: [Color(0xFF000000), Color(0xFF000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF2AABEE), Color(0xFF6EC6FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// App text styles - Clean, minimal typography like Telegram
class AppTextStyles {
  static const String fontFamily = 'Inter';

  // Master Text styles without hardcoded colors
  static const TextStyle _base = TextStyle(fontFamily: fontFamily, height: 1.4);

  static final TextStyle h1 = _base.copyWith(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.4,
  );

  static final TextStyle h2 = _base.copyWith(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.3,
  );

  static final TextStyle h3 = _base.copyWith(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static final TextStyle h4 = _base.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static final TextStyle bodyLarge = _base.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static final TextStyle bodyMedium = _base.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static final TextStyle bodySmall = _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static final TextStyle labelLarge = _base.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  static final TextStyle labelMedium = _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );

  static final TextStyle labelSmall = _base.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );

  static final TextStyle button = _base.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  static final TextStyle buttonSmall = _base.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
}

/// App spacing constants
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// App border radius constants - More rounded like Telegram
class AppRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double full = 999;
}

/// App shadows - Subtle and clean
class AppShadows {
  static List<BoxShadow> sm = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> md = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> lg = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> colored(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.25),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}

/// App theme data - Telegram-inspired
class AppTheme {
  static TextTheme _buildTextTheme(Brightness brightness) {
    final color = brightness == Brightness.light
        ? AppColors.textPrimary
        : AppColors.textPrimaryDark;
    final secondaryColor = brightness == Brightness.light
        ? AppColors.textSecondary
        : AppColors.textSecondaryDark;
    final mutedColor = brightness == Brightness.light
        ? AppColors.textMuted
        : AppColors.textMutedDark;

    return TextTheme(
      displayLarge: AppTextStyles.h1.copyWith(color: color),
      displayMedium: AppTextStyles.h2.copyWith(color: color),
      displaySmall: AppTextStyles.h3.copyWith(color: color),
      headlineMedium: AppTextStyles.h4.copyWith(color: color),
      bodyLarge: AppTextStyles.bodyLarge.copyWith(color: secondaryColor),
      bodyMedium: AppTextStyles.bodyMedium.copyWith(color: secondaryColor),
      bodySmall: AppTextStyles.bodySmall.copyWith(color: mutedColor),
      labelLarge: AppTextStyles.labelLarge.copyWith(color: color),
      labelMedium: AppTextStyles.labelMedium.copyWith(color: secondaryColor),
      labelSmall: AppTextStyles.labelSmall.copyWith(color: mutedColor),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTextStyles.fontFamily,
      textTheme: _buildTextTheme(Brightness.light),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.accent,
        onSecondary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        onSurfaceVariant: AppColors.textSecondary,
        outline: AppColors.border,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppColors.primary),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: AppTextStyles.buttonSmall,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.backgroundSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 0.5,
        space: 0.5,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTextStyles.fontFamily,
      brightness: Brightness.dark,
      textTheme: _buildTextTheme(Brightness.dark),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.accent,
        onSecondary: Colors.white,
        surface: AppColors.surfaceDark,
        onSurface: AppColors.textPrimaryDark,
        error: AppColors.error,
        onSurfaceVariant: AppColors.textSecondaryDark,
        outline: AppColors.borderDark,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppColors.primary),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimaryDark,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBackgroundDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: AppTextStyles.buttonSmall,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.backgroundSecondaryDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderDark,
        thickness: 0.5,
        space: 0.5,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimaryDark,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
