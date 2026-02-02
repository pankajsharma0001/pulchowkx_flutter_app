import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pulchowkx_app/pages/main_layout.dart';
import 'package:pulchowkx_app/auth/service/google_auth.dart';
import 'package:pulchowkx_app/cards/my_enrollments.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/custom_app_bar.dart';
import 'package:pulchowkx_app/pages/favorites_page.dart';
import 'package:pulchowkx_app/pages/admin/create_club_page.dart';
import 'package:pulchowkx_app/widgets/shimmer_loaders.dart';
import 'package:pulchowkx_app/pages/settings_page.dart';
import 'package:pulchowkx_app/models/event.dart';
import 'package:pulchowkx_app/pages/marketplace/conversations_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ApiService _apiService = ApiService();
  bool _isAdmin = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final isAdmin = await _apiService.isAdmin();
      if (mounted) {
        setState(() {
          _isAdmin = isAdmin;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRefresh() async {
    setState(() => _isLoading = true);
    await _checkAdminStatus();
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
            const SizedBox(width: 12),
            Text(
              'Sign Out',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        // removed titleTextStyle as we are styling the Text directly
        content: Text(
          'Are you sure you want to sign out?',
          style: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainLayout()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      // Offline/Auth not initialized
    }

    final String displayName = user?.displayName ?? 'User';
    final String email = user?.email ?? 'No email';
    final String? photoUrl = user?.photoURL;

    return Scaffold(
      appBar: const CustomAppBar(currentPage: AppPage.dashboard),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.light
              ? AppColors.heroGradient
              : AppColors.heroGradientDark,
        ),
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                              Text(
                                'Dashboard',
                                style: Theme.of(context).textTheme.displaySmall,
                              ),
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
                _isLoading
                    ? const DashboardHeaderShimmer()
                    : Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? AppColors.borderDark
                                : AppColors.border,
                          ),
                          boxShadow:
                              Theme.of(context).brightness == Brightness.light
                              ? AppShadows.sm
                              : null,
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
                                      backgroundColor: Theme.of(
                                        context,
                                      ).cardTheme.color,
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.headlineMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          email,
                                          style: AppTextStyles.bodySmall,
                                        ),
                                        const SizedBox(height: AppSpacing.sm),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _isAdmin
                                                ? (Theme.of(
                                                            context,
                                                          ).brightness ==
                                                          Brightness.dark
                                                      ? AppColors.accent
                                                            .withValues(
                                                              alpha: 0.15,
                                                            )
                                                      : AppColors.accentLight)
                                                : (Theme.of(
                                                            context,
                                                          ).brightness ==
                                                          Brightness.dark
                                                      ? AppColors.success
                                                            .withValues(
                                                              alpha: 0.15,
                                                            )
                                                      : AppColors.successLight),
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
                                                _isAdmin
                                                    ? 'Admin'
                                                    : 'Active Student',
                                                style: AppTextStyles.labelSmall
                                                    .copyWith(
                                                      color: _isAdmin
                                                          ? AppColors.accent
                                                          : AppColors.success,
                                                      fontWeight:
                                                          FontWeight.w600,
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
                            Container(
                              height: 1,
                              color: Theme.of(context).dividerTheme.color,
                            ),
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

                // Next Up Section
                _buildNextUpSection(),

                const SizedBox(height: AppSpacing.xl),

                _isLoading
                    ? GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: AppSpacing.md,
                        crossAxisSpacing: AppSpacing.md,
                        childAspectRatio: 1.5,
                        children: const [
                          QuickActionShimmer(),
                          QuickActionShimmer(),
                          QuickActionShimmer(),
                          QuickActionShimmer(),
                        ],
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 600;
                          final cards = [
                            if (_isAdmin)
                              _QuickActionCard(
                                icon: Icons.add_circle_outline,
                                title: 'Create Club',
                                description: 'Start a new club community.',
                                color: Colors.purple,
                                heroTag: 'hero-create-club',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const CreateClubPage(),
                                    ),
                                  );
                                },
                              ),
                            _QuickActionCard(
                              icon: Icons.chat_outlined,
                              title: 'Messages',
                              description:
                                  'View your marketplace conversations.',
                              color: Colors.blue,
                              heroTag: 'hero-messages',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ConversationsPage(),
                                  ),
                                );
                              },
                            ),
                            _QuickActionCard(
                              icon: Icons.favorite_rounded,
                              title: 'My Favorites',
                              description:
                                  'Quickly access your saved clubs and events.',
                              color: Colors.redAccent,
                              heroTag: 'hero-favorites',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const FavoritesPage(),
                                  ),
                                );
                              },
                            ),
                            _QuickActionCard(
                              icon: Icons.settings_rounded,
                              title: 'Settings',
                              description: 'Account settings and preferences.',
                              color: AppColors.textSecondary,
                              heroTag: 'hero-settings',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SettingsPage(),
                                  ),
                                );
                              },
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
      ),
    );
  }

  Widget _buildNextUpSection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return FutureBuilder<String?>(
      future: _apiService.requireDatabaseUserId(),
      builder: (context, idSnapshot) {
        if (!idSnapshot.hasData || idSnapshot.data == null) {
          return const SizedBox.shrink();
        }
        final userId = idSnapshot.data!;

        return FutureBuilder<List<EventRegistration>>(
          future: _apiService.getEnrollments(userId),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }

            final now = DateTime.now();
            // Filter for upcoming events and sort by start time
            final upcoming = snapshot.data!
                .where(
                  (reg) =>
                      reg.status == 'registered' &&
                      reg.event != null &&
                      reg.event!.eventStartTime.isAfter(now),
                )
                .toList();

            if (upcoming.isEmpty) return const SizedBox.shrink();

            upcoming.sort(
              (a, b) =>
                  a.event!.eventStartTime.compareTo(b.event!.eventStartTime),
            );

            final nextEvent = upcoming.first.event!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Up Next'),
                const SizedBox(height: AppSpacing.md),
                _NextUpCard(event: nextEvent),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _NextUpCard extends StatelessWidget {
  final ClubEvent event;

  const _NextUpCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final timeLeft = event.eventStartTime.difference(DateTime.now());

    String timeText;
    if (timeLeft.inDays > 0) {
      timeText = 'In ${timeLeft.inDays} days';
    } else if (timeLeft.inHours > 0) {
      timeText = 'In ${timeLeft.inHours} hours';
    } else {
      timeText = 'In ${timeLeft.inMinutes} minutes';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.colored(AppColors.primary),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.timer_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  timeText,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              'Details',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _SignOutButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFFEF9A9A) : const Color(0xFFD32F2F);

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
                Icon(Icons.logout_rounded, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  'Sign Out',
                  style: AppTextStyles.buttonSmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
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
  final String heroTag;
  final VoidCallback? onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.heroTag,
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
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: _isHovered
                ? widget.color.withValues(alpha: 0.5)
                : Theme.of(context).dividerTheme.color ?? AppColors.border,
          ),
          boxShadow: _isHovered
              ? AppShadows.md
              : (Theme.of(context).brightness == Brightness.light
                    ? AppShadows.sm
                    : null),
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
                    child: Hero(
                      tag: widget.heroTag,
                      child: Icon(widget.icon, color: widget.color, size: 22),
                    ),
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
