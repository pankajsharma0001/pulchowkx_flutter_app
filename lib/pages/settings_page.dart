import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/services/notification_service.dart';
import 'package:pulchowkx_app/main.dart' show themeProvider;

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _upcomingEvents = true;
  bool _marketplaceAlerts = true;
  bool _universityAnnouncements = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _upcomingEvents = prefs.getBool('notify_events') ?? true;
      _marketplaceAlerts = prefs.getBool('notify_books') ?? true;
      _universityAnnouncements = prefs.getBool('notify_announcements') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _toggleNotification(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);

    // Sync with Firebase Topics
    final topic = key.replaceFirst('notify_', '');
    if (value) {
      await NotificationService.subscribeToTopic(topic);
    } else {
      await NotificationService.unsubscribeFromTopic(topic);
    }

    setState(() {
      if (key == 'notify_events') _upcomingEvents = value;
      if (key == 'notify_books') _marketplaceAlerts = value;
      if (key == 'notify_announcements') _universityAnnouncements = value;
    });
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache?'),
        content: const Text(
          'This will delete all cached images and data. They will be re-downloaded when needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Clear',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DefaultCacheManager().emptyCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache cleared successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _sendFeedback() async {
    final Uri params = Uri(
      scheme: 'mailto',
      path: 'support@pulchowkx.com',
      query: 'subject=App Feedback (v1.0.0)&body=Type your feedback here...',
    );
    if (await canLaunchUrl(params)) {
      await launchUrl(params);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: AppTextStyles.h4),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.heroGradientDark
              : AppColors.heroGradient,
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                children: [
                  // Hero Header
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            boxShadow: AppShadows.colored(AppColors.primary),
                          ),
                          child: Hero(
                            tag: 'hero-settings',
                            child: const Icon(
                              Icons.settings_rounded,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text('Settings', style: AppTextStyles.h4),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Personalize your experience',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                  _buildSectionHeader('Appearance'),
                  _buildThemeSelector(),
                  const SizedBox(height: AppSpacing.xl),

                  _buildSectionHeader('Notifications'),
                  _buildSettingTile(
                    title: 'Upcoming Events',
                    subtitle: 'Alerts for registration and event starts',
                    value: _upcomingEvents,
                    onChanged: (v) => _toggleNotification('notify_events', v),
                  ),
                  _buildSettingTile(
                    title: 'Marketplace Alerts',
                    subtitle: 'New requests for your book listings',
                    value: _marketplaceAlerts,
                    onChanged: (v) => _toggleNotification('notify_books', v),
                  ),
                  _buildSettingTile(
                    title: 'University Announcements',
                    subtitle: 'Important updates from the campus',
                    value: _universityAnnouncements,
                    onChanged: (v) =>
                        _toggleNotification('notify_announcements', v),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  _buildSectionHeader('Utilities'),
                  ListTile(
                    leading: const Icon(
                      Icons.cleaning_services_rounded,
                      color: AppColors.primary,
                    ),
                    title: const Text('Clear Image Cache'),
                    subtitle: const Text(
                      'Free up storage space on your device',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _clearCache,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  _buildSectionHeader('Support'),
                  ListTile(
                    leading: const Icon(
                      Icons.feedback_rounded,
                      color: AppColors.primary,
                    ),
                    title: const Text('Send Feedback'),
                    subtitle: const Text('Help us improve the app'),
                    trailing: const Icon(Icons.launch_rounded, size: 18),
                    onTap: _sendFeedback,
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.info_rounded,
                      color: AppColors.primary,
                    ),
                    title: const Text('About Pulchowk-X'),
                    subtitle: const Text('Version 1.0.0'),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'Pulchowk-X',
                        applicationVersion: '1.0.0',
                        applicationLegalese:
                            '© 2026 Developed for Pulchowk Campus',
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.primary,
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildThemeSelector() {
    return ListenableBuilder(
      listenable: themeProvider,
      builder: (context, _) => Column(
        children: [
          _buildThemeOption(
            icon: Icons.light_mode_rounded,
            title: 'Light',
            isSelected: themeProvider.themeMode == ThemeMode.light,
            onTap: () => themeProvider.setThemeMode(ThemeMode.light),
          ),
          _buildThemeOption(
            icon: Icons.dark_mode_rounded,
            title: 'Dark',
            isSelected: themeProvider.themeMode == ThemeMode.dark,
            onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
          ),
          _buildThemeOption(
            icon: Icons.brightness_auto_rounded,
            title: 'System',
            isSelected: themeProvider.themeMode == ThemeMode.system,
            onTap: () => themeProvider.setThemeMode(ThemeMode.system),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : (isDark
                    ? AppColors.backgroundSecondaryDark
                    : AppColors.backgroundSecondary),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.borderDark : AppColors.border),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              title,
              style: AppTextStyles.labelLarge.copyWith(
                color: isSelected
                    ? AppColors.primary
                    : (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimary),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: AppTextStyles.labelLarge),
      subtitle: Text(subtitle, style: AppTextStyles.bodySmall),
      value: value,
      activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
      activeThumbColor: AppColors.primary,
      onChanged: (v) {
        HapticFeedback.lightImpact();
        onChanged(v);
      },
    );
  }
}
