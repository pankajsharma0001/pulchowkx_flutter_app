import 'package:flutter/services.dart';
import 'package:pulchowkx_app/services/theme_provider.dart';

/// A singleton service to handle haptic feedback throughout the app.
/// This respects the user's haptic feedback preference from ThemeProvider.
class HapticService {
  static HapticService? _instance;
  ThemeProvider? _themeProvider;

  HapticService._();

  static HapticService get instance {
    _instance ??= HapticService._();
    return _instance!;
  }

  /// Initialize the service with a ThemeProvider reference
  void init(ThemeProvider themeProvider) {
    _themeProvider = themeProvider;
  }

  /// Check if haptics are enabled
  bool get isEnabled => _themeProvider?.hapticsEnabled ?? true;

  /// Light impact haptic feedback
  void lightImpact() {
    if (isEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  /// Medium impact haptic feedback
  void mediumImpact() {
    if (isEnabled) {
      HapticFeedback.mediumImpact();
    }
  }

  /// Heavy impact haptic feedback
  void heavyImpact() {
    if (isEnabled) {
      HapticFeedback.heavyImpact();
    }
  }

  /// Selection click haptic feedback
  void selectionClick() {
    if (isEnabled) {
      HapticFeedback.selectionClick();
    }
  }

  /// Vibrate haptic feedback
  void vibrate() {
    if (isEnabled) {
      HapticFeedback.vibrate();
    }
  }
}

/// Global instance for easy access
final haptics = HapticService.instance;
