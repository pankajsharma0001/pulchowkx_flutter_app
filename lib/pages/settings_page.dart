import 'package:flutter/material.dart';
import 'package:pulchowkx_app/services/haptic_service.dart';
import 'package:pulchowkx_app/auth/service/google_auth.dart';
import 'package:pulchowkx_app/pages/main_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';

import 'package:pulchowkx_app/services/notification_service.dart';
import 'package:pulchowkx_app/main.dart' show themeProvider;
import 'package:pulchowkx_app/widgets/theme_switcher.dart';
import 'package:pulchowkx_app/pages/marketplace/blocked_users.dart';
import 'package:pulchowkx_app/pages/marketplace/my_reports.dart';
import 'package:pulchowkx_app/pages/support/help_center.dart';
import 'package:pulchowkx_app/pages/support/legal_pages.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _upcomingEvents = true;
  bool _marketplaceAlerts = true;
  bool _universityAnnouncements = true;
  bool _classroomAlerts = true;
  bool _chatMessages = true;
  bool _lostFoundAlerts = true;
  bool _isLoading = true;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final hasPermission = await NotificationService.hasPermission();
    final packageInfo = await PackageInfo.fromPlatform();

    setState(() {
      _upcomingEvents =
          hasPermission && (prefs.getBool('notify_events') ?? true);
      _marketplaceAlerts =
          hasPermission && (prefs.getBool('notify_books') ?? true);
      _universityAnnouncements =
          hasPermission && (prefs.getBool('notify_announcements') ?? true);
      _classroomAlerts =
          hasPermission && (prefs.getBool('notify_classroom') ?? true);
      _chatMessages = hasPermission && (prefs.getBool('notify_chat') ?? true);
      _lostFoundAlerts =
          hasPermission && (prefs.getBool('notify_lost_found') ?? true);
      _appVersion = packageInfo.version;
      _isLoading = false;
    });
  }

  Future<void> _toggleNotification(String key, bool value) async {
    // 1. Instantly update UI (Optimistic update)
    setState(() {
      if (key == 'notify_events') _upcomingEvents = value;
      if (key == 'notify_books') _marketplaceAlerts = value;
      if (key == 'notify_announcements') _universityAnnouncements = value;
      if (key == 'notify_classroom') _classroomAlerts = value;
      if (key == 'notify_chat') _chatMessages = value;
      if (key == 'notify_lost_found') _lostFoundAlerts = value;
    });

    try {
      // 2. Check permissions if turning ON
      if (value) {
        final hasPermission = await NotificationService.hasPermission();
        if (!hasPermission) {
          // Revert if no permission
          _revertToggle(key);
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

      // 3. Persist to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);

      // 4. Sync with Firebase Topics (Background)
      if (key != 'notify_chat' && key != 'notify_classroom') {
        final topic = key.replaceFirst('notify_', '');
        if (value) {
          await NotificationService.subscribeToTopic(topic);
        } else {
          await NotificationService.unsubscribeFromTopic(topic);
        }
      } else if (key == 'notify_classroom') {
        await NotificationService.updateClassroomSubscription(value);
      }
    } catch (e) {
      debugPrint('Error toggling notification $key: $e');
      // Revert on serious error
      _revertToggle(key);
    }
  }

  void _revertToggle(String key) {
    if (!mounted) return;
    setState(() {
      if (key == 'notify_events') _upcomingEvents = !_upcomingEvents;
      if (key == 'notify_books') _marketplaceAlerts = !_marketplaceAlerts;
      if (key == 'notify_announcements') {
        _universityAnnouncements = !_universityAnnouncements;
      }
      if (key == 'notify_classroom') _classroomAlerts = !_classroomAlerts;
      if (key == 'notify_chat') _chatMessages = !_chatMessages;
      if (key == 'notify_lost_found') _lostFoundAlerts = !_lostFoundAlerts;
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
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 16),
                Text('Clearing cache...'),
              ],
            ),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // 1. Clear DefaultCacheManager (Images managed by flutter_cache_manager)
      await DefaultCacheManager().emptyCache();

      // 2. Clear CachedNetworkImage memory cache
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // 3. Deeper cleanup: Clear the entire temporary directory
      // This catches PDFs, picked files, and other plugin debris.
      try {
        final tempDir = await getTemporaryDirectory();
        if (tempDir.existsSync()) {
          tempDir.listSync().forEach((entity) {
            try {
              entity.deleteSync(recursive: true);
            } catch (_) {
              // Some files (like shaders or active logs) might be locked by the OS
            }
          });
        }
      } catch (e) {
        debugPrint('Error clearing temp directory: $e');
      }

      // 4. Clear Hive API cache (Data)
      try {
        final box = Hive.box('api_cache');
        await box.clear();
      } catch (e) {
        debugPrint('Error clearing Hive cache: $e');
      }

      if (mounted) {
        // Trigger haptic feedback
        haptics.mediumImpact();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All caches cleared successfully!'),
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

    // Show a beautiful, non-dismissible loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Signing Out',
                    style: AppTextStyles.h4.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Cleaning up your session...',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

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
                      const SizedBox(height: AppSpacing.md),
                      _buildSettingsGroup([
                        _buildSettingTile(
                          title: 'Haptic Feedback',
                          subtitle: 'Provide physical feedback on tap',
                          value: themeProvider.hapticsEnabled,
                          onChanged: (v) => themeProvider.setHapticsEnabled(v),
                          icon: Icons.vibration_rounded,
                        ),
                      ]),
                      const SizedBox(height: AppSpacing.xl),

                      _buildSectionHeader('Notifications'),
                      _buildSettingsGroup([
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
                          title: 'Classroom Notifications',
                          subtitle: 'Updates about assignments and grades',
                          value: _classroomAlerts,
                          onChanged: (v) =>
                              _toggleNotification('notify_classroom', v),
                          icon: Icons.class_rounded,
                        ),
                        _buildSettingTile(
                          title: 'Chat Messages',
                          subtitle: 'Direct notifications for new messages',
                          value: _chatMessages,
                          onChanged: (v) =>
                              _toggleNotification('notify_chat', v),
                          icon: Icons.chat_bubble_rounded,
                        ),
                        _buildSettingTile(
                          title: 'Lost & Found',
                          subtitle: 'Alerts for new lost or found items',
                          value: _lostFoundAlerts,
                          onChanged: (v) =>
                              _toggleNotification('notify_lost_found', v),
                          icon: Icons.find_in_page_rounded,
                        ),
                      ]),
                      const SizedBox(height: AppSpacing.xl),

                      _buildSectionHeader('Account'),
                      _buildSettingsGroup([
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
                      ]),
                      const SizedBox(height: AppSpacing.xl),

                      _buildSectionHeader('Utilities'),
                      _buildSettingsGroup([
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
                      ]),
                      const SizedBox(height: AppSpacing.xl),

                      _buildSectionHeader('Trust & Safety'),
                      _buildSettingsGroup([
                        ListTile(
                          leading: const Icon(
                            Icons.block_rounded,
                            color: AppColors.error,
                          ),
                          title: const Text('Blocked Users'),
                          subtitle: const Text(
                            'Manage people you have blocked',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const BlockedUsersPage(),
                              ),
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.report_gmailerrorred_rounded,
                            color: AppColors.warning,
                          ),
                          title: const Text('My Reports'),
                          subtitle: const Text('View status of your reports'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const MarketplaceReportsPage(),
                              ),
                            );
                          },
                        ),
                      ]),
                      const SizedBox(height: AppSpacing.xl),

                      _buildSectionHeader('Support'),
                      _buildSettingsGroup([
                        ListTile(
                          leading: const Icon(
                            Icons.help_outline_rounded,
                            color: AppColors.info,
                          ),
                          title: const Text('Help Center'),
                          subtitle: const Text('FAQ, help and contact support'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const HelpCenterPage(),
                              ),
                            );
                          },
                        ),
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
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.privacy_tip_rounded,
                            color: AppColors.primary,
                          ),
                          title: const Text('Privacy Policy'),
                          subtitle: const Text('How we handle your data'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LegalPage(
                                title: 'Privacy Policy',
                                content:
                                    'We value your privacy. Your personal data is only used to provide the services offered by Smart Pulchowk. We do not sell your data to third parties. We collect information such as your name, student ID, and email to provide marketplace and classroom features. All data is securely stored and follows standardized protection protocols.',
                              ),
                            ),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.article_rounded,
                            color: AppColors.primary,
                          ),
                          title: const Text('Terms of Service'),
                          subtitle: const Text(
                            'App usage terms and conditions',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LegalPage(
                                title: 'Terms of Service',
                                content:
                                    'By using Smart Pulchowk, you agree to abide by the rules of the Pulchowk Campus and use the marketplace and classroom features responsibly. Users are responsible for the content they post. Misuse of the platform, including posting fraudulent items or harassing fellow students, will result in account suspension and possible campus disciplinary actions.',
                              ),
                            ),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.info_rounded,
                            color: AppColors.primary,
                          ),
                          title: const Text('About Smart Pulchowk'),
                          subtitle: Text('Version $_appVersion'),
                          onTap: () {
                            showAboutDialog(
                              context: context,
                              applicationName: 'Smart Pulchowk',
                              applicationVersion: _appVersion,
                              applicationLegalese:
                                  '© 2026 Developed for Pulchowk Campus',
                            );
                          },
                        ),
                      ]),
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
        decoration: isSelected
            ? (Theme.of(context).brightness == Brightness.dark
                      ? AppDecorations.glassDark(borderRadius: AppRadius.md)
                      : AppDecorations.glass(borderRadius: AppRadius.md))
                  .copyWith(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    border: Border.all(color: AppColors.primary, width: 2),
                  )
            : (Theme.of(context).brightness == Brightness.dark
                  ? AppDecorations.glassDark(borderRadius: AppRadius.md)
                  : AppDecorations.glass(borderRadius: AppRadius.md)),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: Theme.of(context).brightness == Brightness.dark
          ? AppDecorations.glassDark(borderRadius: AppRadius.lg)
          : AppDecorations.glass(borderRadius: AppRadius.lg),
      child: Column(children: children),
    );
  }
}
