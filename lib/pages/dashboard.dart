import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pulchowkx_app/auth/service/google_auth.dart';
import 'package:pulchowkx_app/pages/clubs.dart';
import 'package:pulchowkx_app/pages/home_page.dart';
import 'package:pulchowkx_app/pages/map.dart';
import 'package:pulchowkx_app/cards/my_enrollments.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/custom_app_bar.dart';
import 'package:pulchowkx_app/pages/admin/create_club_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ApiService _apiService = ApiService();
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _apiService.isAdmin();
    if (mounted) {
      setState(() => _isAdmin = isAdmin);
    }
  }

  Future<void> _handleSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppColors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Sign Out'),
          ],
        ),
        titleTextStyle: AppTextStyles.h4,
        content: const Text(
          'Are you sure you want to sign out?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final FirebaseServices firebaseServices = FirebaseServices();
    await firebaseServices.googleSignOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String displayName = user?.displayName ?? 'User';
    final String email = user?.email ?? 'No email';
    final String? photoUrl = user?.photoURL;

    return Scaffold(
      appBar: const CustomAppBar(currentPage: AppPage.dashboard),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                              child: const Icon(
                                Icons.dashboard_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text('Dashboard', style: AppTextStyles.h3),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Manage your account and view your enrollments',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  _SignOutButton(onPressed: () => _handleSignOut(context)),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Profile Card
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppShadows.sm,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Row(
                        children: [
                          // Avatar with gradient border
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 36,
                              backgroundColor: AppColors.surface,
                              backgroundImage: photoUrl != null
                                  ? CachedNetworkImageProvider(photoUrl)
                                  : null,
                              child: photoUrl == null
                                  ? const Icon(
                                      Icons.person_rounded,
                                      size: 36,
                                      color: AppColors.primary,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(displayName, style: AppTextStyles.h4),
                                const SizedBox(height: 4),
                                Text(email, style: AppTextStyles.bodySmall),
                                const SizedBox(height: AppSpacing.sm),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isAdmin
                                        ? AppColors.accentLight
                                        : AppColors.successLight,
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.full,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _isAdmin
                                            ? Icons.admin_panel_settings
                                            : Icons.verified_rounded,
                                        size: 12,
                                        color: _isAdmin
                                            ? AppColors.accent
                                            : AppColors.success,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _isAdmin ? 'Admin' : 'Active Student',
                                        style: AppTextStyles.labelSmall
                                            .copyWith(
                                              color: _isAdmin
                                                  ? AppColors.accent
                                                  : AppColors.success,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 1, color: AppColors.border),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Member since ${user?.metadata.creationTime?.year ?? 2026}',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Event Enrollments Section
              const MyEnrollments(),

              const SizedBox(height: AppSpacing.xl),

              // Quick Actions Grid
              Text('Quick Actions', style: AppTextStyles.h4),
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 600;
                  final cards = [
                    if (_isAdmin)
                      _QuickActionCard(
                        icon: Icons.add_circle_outline,
                        title: 'Create Club',
                        description: 'Start a new club community.',
                        color: Colors.purple,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CreateClubPage(),
                            ),
                          );
                        },
                      ),
                    _QuickActionCard(
                      icon: Icons.groups_rounded,
                      title: 'Campus Clubs',
                      description:
                          'Explore clubs and discover upcoming events.',
                      color: AppColors.accent,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ClubsPage(),
                          ),
                        );
                      },
                    ),
                    _QuickActionCard(
                      icon: Icons.map_rounded,
                      title: 'Campus Map',
                      description:
                          'Navigate the campus, find classrooms, and explore.',
                      color: AppColors.primary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MapPage(),
                          ),
                        );
                      },
                    ),
                    _QuickActionCard(
                      icon: Icons.settings_rounded,
                      title: 'Settings',
                      description: 'Account settings and preferences.',
                      color: AppColors.textSecondary,
                      onTap: null,
                    ),
                  ];

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: cards
                          .asMap()
                          .entries
                          .map(
                            (entry) => Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: entry.key < cards.length - 1
                                      ? AppSpacing.md
                                      : 0,
                                ),
                                child: entry.value,
                              ),
                            ),
                          )
                          .toList(),
                    );
                  }

                  return Column(
                    children: cards
                        .map(
                          (card) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: card,
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _SignOutButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.logout_rounded, size: 16, color: AppColors.error),
                const SizedBox(width: 6),
                Text(
                  'Sign Out',
                  style: AppTextStyles.buttonSmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback? onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    this.onTap,
  });

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 150,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: _isHovered
                ? widget.color.withValues(alpha: 0.5)
                : AppColors.border,
          ),
          boxShadow: _isHovered ? AppShadows.md : AppShadows.sm,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 22),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(widget.title, style: AppTextStyles.labelLarge),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      widget.description,
                      style: AppTextStyles.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
