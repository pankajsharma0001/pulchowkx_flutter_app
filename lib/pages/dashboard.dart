import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pulchowkx_app/pages/main_layout.dart';
import 'package:pulchowkx_app/auth/service/google_auth.dart';
import 'package:pulchowkx_app/pages/marketplace/book_requests_page.dart';
import 'package:pulchowkx_app/pages/book_marketplace.dart';
import 'package:pulchowkx_app/models/event.dart';
import 'package:pulchowkx_app/cards/my_enrollments.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/custom_app_bar.dart';
import 'package:pulchowkx_app/pages/favorites_page.dart';
import 'package:pulchowkx_app/pages/admin/create_club_page.dart';
import 'package:pulchowkx_app/widgets/shimmer_loaders.dart';
import 'package:pulchowkx_app/pages/settings_page.dart';
import 'package:pulchowkx_app/pages/notices.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ApiService _apiService = ApiService();
  bool _isAdmin = false;
  bool _isLoading = true;
  int _totalEnrollments = 0;
  int _upcomingEnrollments = 0;
  int _attendedEnrollments = 0;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final isAdmin = await _apiService.isAdmin();
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final dbId = await _apiService.requireDatabaseUserId();
        if (dbId != null) {
          final enrollments = await _apiService.getEnrollments(dbId);
          final now = DateTime.now();

          if (mounted) {
            setState(() {
              _isAdmin = isAdmin;
              _totalEnrollments = enrollments.length;
              _upcomingEnrollments = enrollments
                  .where(
                    (e) =>
                        e.event != null &&
                        e.event!.eventStartTime.isAfter(now) &&
                        e.status == 'registered',
                  )
                  .length;
              _attendedEnrollments = enrollments
                  .where((e) => e.status.toLowerCase() == 'attended')
                  .length;
              _isLoading = false;
            });
            return;
          }
        }
      }

      if (mounted) {
        setState(() {
          _isAdmin = isAdmin;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRefresh() async {
    await _fetchDashboardData();
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
                // Header area with User Profile
                _isLoading
                    ? const DashboardHeaderShimmer()
                    : _buildProfileHeader(displayName, email, photoUrl),

                const SizedBox(height: AppSpacing.lg),

                // Stats Grid
                _isLoading ? const StatsGridShimmer() : _buildStatsGrid(),
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
                            _QuickActionCard(
                              icon: Icons.shopping_bag_outlined,
                              title: 'Marketplace',
                              description: 'Buy and sell books with others.',
                              color: AppColors.primary,
                              heroTag: 'hero-marketplace',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const BookMarketplacePage(),
                                  ),
                                );
                              },
                            ),
                            _QuickActionCard(
                              icon: Icons.history_rounded,
                              title: 'Requests',
                              description: 'Track your book buy/sell requests.',
                              color: AppColors.accent,
                              heroTag: 'hero-requests',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const BookRequestsPage(),
                                  ),
                                );
                              },
                            ),
                            _QuickActionCard(
                              icon: Icons.notification_important_outlined,
                              title: 'IOE Notices',
                              description:
                                  'View exam results and routines from IOE.',
                              color: AppColors.success,
                              heroTag: 'hero-notices',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const NoticesPage(),
                                  ),
                                );
                              },
                            ),
                            _QuickActionCard(
                              icon: Icons.favorite_outline_rounded,
                              title: 'Favorites',
                              description: 'Access your saved clubs and books.',
                              color: Colors.orange,
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
                            if (_isAdmin)
                              _QuickActionCard(
                                icon: Icons.admin_panel_settings_outlined,
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

  Widget _buildProfileHeader(String name, String email, String? photoUrl) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color?.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(
          color: isDark
              ? AppColors.borderDark.withValues(alpha: 0.5)
              : AppColors.border.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                  image: photoUrl != null
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(photoUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: photoUrl == null
                    ? const Center(
                        child: Icon(
                          Icons.person_rounded,
                          size: 32,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        'Student Dashboard'.toUpperCase(),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      style: AppTextStyles.h4.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      email,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    // Navigate to Classroom (Home usually)
                    Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const MainLayout(initialIndex: 3),
                      ),
                      (route) => false,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    side: BorderSide(
                      color:
                          Theme.of(context).dividerTheme.color ??
                          AppColors.border,
                    ),
                  ),
                  child: Text(
                    'Classroom',
                    style: AppTextStyles.labelMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleSignOut(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double itemWidth = (constraints.maxWidth - AppSpacing.md * 2) / 3;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _buildStatCard(
              'Total Enrollments',
              _totalEnrollments.toString(),
              AppColors.primary,
              width: itemWidth,
            ),
            _buildStatCard(
              'Upcoming Events',
              _upcomingEnrollments.toString(),
              AppColors.accent,
              width: itemWidth,
            ),
            _buildStatCard(
              'Attended',
              _attendedEnrollments.toString(),
              AppColors.success,
              width: itemWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color color, {
    double? width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.h3.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
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
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 1.5,
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            Theme.of(context).cardTheme.color?.withValues(alpha: 0.95) ??
                Colors.white,
            AppColors.primary.withValues(alpha: 0.05),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? AppShadows.sm
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.timer_outlined,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next Up'.toUpperCase(),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  event.title,
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(timeText, style: AppTextStyles.bodySmall),
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
        height: 140,
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(AppRadius.xl),
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
