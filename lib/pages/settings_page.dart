import 'package:flutter/material.dart';
import 'package:pulchowkx_app/auth/service/google_auth.dart';
import 'package:pulchowkx_app/pages/main_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/services/notification_service.dart';
import 'package:pulchowkx_app/main.dart' show themeProvider;
import 'package:pulchowkx_app/widgets/theme_switcher.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _upcomingEvents = true;
  bool _marketplaceAlerts = true;
  bool _universityAnnouncements = true;
  bool _chatMessages = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final hasPermission = await NotificationService.hasPermission();

    setState(() {
      _upcomingEvents =
          hasPermission && (prefs.getBool('notify_events') ?? true);
      _marketplaceAlerts =
          hasPermission && (prefs.getBool('notify_books') ?? true);
      _universityAnnouncements =
          hasPermission && (prefs.getBool('notify_announcements') ?? true);
      _chatMessages = hasPermission && (prefs.getBool('notify_chat') ?? true);
      _isLoading = false;
    });
  }

  Future<void> _toggleNotification(String key, bool value) async {
    if (value) {
      final hasPermission = await NotificationService.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please enable notification permissions in system settings.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);

    // Sync with Firebase Topics (for non-chat topics)
    if (key != 'notify_chat') {
      final topic = key.replaceFirst('notify_', '');
      if (value) {
        await NotificationService.subscribeToTopic(topic);
      } else {
        await NotificationService.unsubscribeFromTopic(topic);
      }
    } else {
      // For chat, we only store locally since the backend check was removed
    }

    setState(() {
      if (key == 'notify_events') _upcomingEvents = value;
      if (key == 'notify_books') _marketplaceAlerts = value;
      if (key == 'notify_announcements') _universityAnnouncements = value;
      if (key == 'notify_chat') _chatMessages = value;
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

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final FirebaseServices firebaseServices = FirebaseServices();
    await firebaseServices.googleSignOut();
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainLayout()),
        (route) => false,
      );
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

  void _showLegalDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(title, style: AppTextStyles.h4),
        content: SingleChildScrollView(
          child: Text(
            content,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.heroGradientDark
              : AppColors.heroGradient,
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListenableBuilder(
                listenable: themeProvider,
                builder: (context, _) {
                  return ListView(
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
                                borderRadius: BorderRadius.circular(
                                  AppRadius.lg,
                                ),
                                boxShadow: AppShadows.colored(
                                  AppColors.primary,
                                ),
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
                      _buildSettingTile(
                        title: 'Haptic Feedback',
                        subtitle: 'Provide physical feedback on tap',
                        value: themeProvider.hapticsEnabled,
                        onChanged: (v) => themeProvider.setHapticsEnabled(v),
                        icon: Icons.vibration_rounded,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      _buildSectionHeader('Notifications'),
                      _buildSettingTile(
                        title: 'Upcoming Events',
                        subtitle: 'Alerts for registration and event starts',
                        value: _upcomingEvents,
                        onChanged: (v) =>
                            _toggleNotification('notify_events', v),
                        icon: Icons.event_rounded,
                      ),
                      _buildSettingTile(
                        title: 'Marketplace Alerts',
                        subtitle: 'New requests for your book listings',
                        value: _marketplaceAlerts,
                        onChanged: (v) =>
                            _toggleNotification('notify_books', v),
                        icon: Icons.shopping_bag_rounded,
                      ),
                      _buildSettingTile(
                        title: 'University Announcements',
                        subtitle: 'Important updates from the campus',
                        value: _universityAnnouncements,
                        onChanged: (v) =>
                            _toggleNotification('notify_announcements', v),
                        icon: Icons.campaign_rounded,
                      ),
                      _buildSettingTile(
                        title: 'Chat Messages',
                        subtitle: 'Direct notifications for new messages',
                        value: _chatMessages,
                        onChanged: (v) => _toggleNotification('notify_chat', v),
                        icon: Icons.chat_bubble_rounded,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      _buildSectionHeader('Account'),
                      ListTile(
                        leading: const Icon(
                          Icons.logout_rounded,
                          color: AppColors.error,
                        ),
                        title: const Text(
                          'Sign Out',
                          style: TextStyle(color: AppColors.error),
                        ),
                        subtitle: const Text(
                          'Securely sign out of your account',
                        ),
                        onTap: _handleSignOut,
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
                          Icons.privacy_tip_rounded,
                          color: AppColors.primary,
                        ),
                        title: const Text('Privacy Policy'),
                        subtitle: const Text('How we handle your data'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _showLegalDialog(
                          'Privacy Policy',
                          'We value your privacy. Your personal data is only used to provide the services offered by Pulchowk-X. We do not sell your data to third parties.',
                        ),
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.article_rounded,
                          color: AppColors.primary,
                        ),
                        title: const Text('Terms of Service'),
                        subtitle: const Text('App usage terms and conditions'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _showLegalDialog(
                          'Terms of Service',
                          'By using Pulchowk-X, you agree to abide by the rules of the Pulchowk Campus and use the marketplace and classroom features responsibly.',
                        ),
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
                  );
                },
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
    return Column(
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
      onTapDown: (details) {
        themeProvider.selectionClick();
        ThemeSwitcher.of(context)?.changeTheme(onTap, details.globalPosition);
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
    IconData? icon,
  }) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      secondary: icon != null
          ? Icon(icon, color: AppColors.primary, size: 20)
          : null,
      title: Text(title, style: AppTextStyles.labelLarge),
      subtitle: Text(subtitle, style: AppTextStyles.bodySmall),
      value: value,
      activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
      activeThumbColor: AppColors.primary,
      onChanged: (v) {
        themeProvider.vibrate();
        onChanged(v);
      },
    );
  }
}
