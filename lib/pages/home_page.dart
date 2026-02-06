import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pulchowkx_app/pages/main_layout.dart';
import 'package:pulchowkx_app/pages/search_page.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/custom_app_bar.dart';
import 'package:pulchowkx_app/services/haptic_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomAppBar(isHomePage: true, currentPage: AppPage.home),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.heroGradientDark
              : AppColors.heroGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroSection(context),
                const SizedBox(height: AppSpacing.xl),
                _buildStatsPanel(context),
                const SizedBox(height: AppSpacing.xl),
                _buildMissionControl(context),
                const SizedBox(height: AppSpacing.xl),
                _buildQuickActionsGrid(context),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color?.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'STUDENT PRODUCTIVITY LAYER',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          RichText(
            text: TextSpan(
              style: AppTextStyles.h1.copyWith(
                fontSize: 32,
                height: 1.1,
                color: Theme.of(context).textTheme.displayLarge?.color,
              ),
              children: [
                const TextSpan(text: 'Your Campus,\n'),
                TextSpan(
                  text: 'fully connected',
                  style: TextStyle(
                    foreground: Paint()
                      ..shader = AppColors.primaryGradient.createShader(
                        const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0),
                      ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Smart Pulchowk brings maps, clubs, books, events, and notices into one fast interface.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  context,
                  label: 'Open Map',
                  icon: Icons.map_rounded,
                  isPrimary: true,
                  onPressed: () => MainLayout.of(context)?.setSelectedIndex(1),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StreamBuilder<User?>(
                  stream: FirebaseAuth.instance.authStateChanges(),
                  builder: (context, snapshot) {
                    final isLoggedIn = snapshot.hasData;
                    return _buildActionButton(
                      context,
                      label: isLoggedIn ? 'Dashboard' : 'Register',
                      icon: isLoggedIn
                          ? Icons.dashboard_rounded
                          : Icons.person_add_rounded,
                      isPrimary: false,
                      onPressed: () {
                        if (isLoggedIn) {
                          MainLayout.of(context)?.setSelectedIndex(4);
                        } else {
                          MainLayout.of(context)?.setSelectedIndex(7);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsPanel(BuildContext context) {
    final stats = [
      {'label': 'Mapped Spots', 'value': '100+'},
      {'label': 'Utility Modules', 'value': '8'},
      {'label': 'Search Domains', 'value': '5'},
    ];

    return Row(
      children: stats.map((stat) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              right: stat == stats.last ? 0 : AppSpacing.sm,
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color?.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.05),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat['value']!,
                  style: AppTextStyles.h3.copyWith(
                    color: Theme.of(context).textTheme.displaySmall?.color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  stat['label']!,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMissionControl(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LIVE CONTROL PANEL',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Campus Mission Control',
            style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildMissionItem(
            context,
            title: 'Try global search',
            subtitle: 'Example: dean office, robotics, notices',
            icon: Icons.search_rounded,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SearchPage()),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildMissionItem(
            context,
            title: 'Explore events',
            subtitle: 'Workshops, hackathons, and seminars',
            icon: Icons.event_rounded,
            onTap: () => MainLayout.of(context)?.setSelectedIndex(6),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        haptics.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    final actions = [
      {'title': 'Map', 'icon': Icons.map_rounded, 'index': 1},
      {'title': 'Clubs', 'icon': Icons.groups_rounded, 'index': 5},
      {'title': 'Events', 'icon': Icons.event_rounded, 'index': 6},
      {'title': 'Market', 'icon': Icons.shopping_bag_rounded, 'index': 3},
      {'title': 'Class', 'icon': Icons.school_rounded, 'index': 2},
      {
        'title': 'Notices',
        'icon': Icons.notifications_rounded,
        'index': 0,
      }, // Needs separate page usually
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Navigation',
          style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.9,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return _buildQuickActionCard(
              context,
              title: action['title'] as String,
              icon: action['icon'] as IconData,
              onTap: () {
                if (action['title'] == 'Notices') {
                  // Navigate to search with notices filter or a separate notices page
                } else {
                  MainLayout.of(
                    context,
                  )?.setSelectedIndex(action['index'] as int);
                }
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        haptics.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: isPrimary ? AppColors.primaryGradient : null,
        color: isPrimary ? null : Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: isPrimary ? null : Border.all(color: AppColors.border),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            haptics.mediumImpact();
            onPressed();
          },
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isPrimary ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  icon,
                  color: isPrimary ? Colors.white : AppColors.textPrimary,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
