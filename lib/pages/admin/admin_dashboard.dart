import 'package:flutter/material.dart';
import 'package:pulchowkx_app/pages/admin/create_club_page.dart';
import 'package:pulchowkx_app/pages/admin/admin_reports.dart';
import 'package:pulchowkx_app/pages/admin/admin_users.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/pages/main_layout.dart';
import 'package:pulchowkx_app/widgets/custom_app_bar.dart';
import 'package:pulchowkx_app/widgets/shimmer_loaders.dart';

/// Admin Dashboard page that replaces Classroom for admin users.
/// Shows platform management options and quick stats.
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _adminOverview;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final overview = await _apiService.getAdminOverview(
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _adminOverview = overview;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load admin data';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomAppBar(currentPage: AppPage.classroom),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.heroGradientDark
              : AppColors.heroGradient,
        ),
        child: RefreshIndicator(
          onRefresh: () => _loadAdminData(forceRefresh: true),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: AppSpacing.lg),
                if (_isLoading)
                  const StatsGridShimmer()
                else if (_error != null)
                  _buildErrorState()
                else ...[
                  _buildStatsGrid(),
                  const SizedBox(height: AppSpacing.xl),
                  _buildQuickActions(),
                  const SizedBox(height: AppSpacing.xl),
                  _buildPendingTasks(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: AppColors.surface,
              size: 28,
            ),
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
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    'ADMIN DASHBOARD',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Platform Management',
                  style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage users, clubs, events, and content moderation',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final stats = _adminOverview ?? {};
    final totalUsers = stats['users'] ?? 0;
    final admins = stats['admins'] ?? 0;
    final teachers = stats['teachers'] ?? 0;
    final activeListings = stats['listingsAvailable'] ?? 0;
    final openReports = stats['openReports'] ?? 0;
    final activeBlocks = stats['activeBlocks'] ?? 0;
    final avgRating = stats['averageSellerRating'] ?? 0.0;
    final ratingCount = stats['ratingsCount'] ?? 0;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.3,
      children: [
        _StatCard(
          label: 'TOTAL USERS',
          value: totalUsers.toString(),
          subtitle: '$teachers Teachers, $admins Admins',
          icon: Icons.people_outline_rounded,
          color: Colors.purple,
        ),
        _StatCard(
          label: 'ACTIVE LISTINGS',
          value: activeListings.toString(),
          subtitle: 'Marketplace is active',
          icon: Icons.menu_book_rounded,
          color: AppColors.success,
        ),
        _StatCard(
          label: 'OPEN REPORTS',
          value: openReports.toString(),
          subtitle: '$activeBlocks blocked users',
          icon: Icons.flag_outlined,
          color: AppColors.warning,
        ),
        _StatCard(
          label: 'AVG RATING',
          value: avgRating.toString(),
          subtitle: '$ratingCount reviews total',
          icon: Icons.star_rounded,
          color: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.add_circle_outline_rounded,
                title: 'Create Club',
                color: AppColors.primary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateClubPage()),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _ActionCard(
                icon: Icons.event_note_rounded,
                title: 'Manage Events',
                color: Colors.orange,
                onTap: () {
                  final MainLayoutState? layout = MainLayout.of(context);
                  if (layout != null) {
                    layout.setSelectedIndex(6); // Navigate to Events tab
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPendingTasks() {
    final stats = _adminOverview ?? {};
    final pendingReports = stats['openReports'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pending Tasks',
          style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            children: [
              _TaskItem(
                icon: Icons.flag_outlined,
                title: 'Review Reports',
                count: pendingReports,
                color: AppColors.warning,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminReportsPage()),
                ).then((_) => _loadAdminData()),
              ),
              const Divider(),
              _TaskItem(
                icon: Icons.verified_user_outlined,
                title: 'Seller Verifications',
                count: stats['pendingVerifications'] ?? 0,
                color: AppColors.primary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminUsersPage()),
                ).then((_) => _loadAdminData()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
          const SizedBox(height: AppSpacing.md),
          Text(_error ?? 'An error occurred', style: AppTextStyles.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(
            onPressed: () => _loadAdminData(forceRefresh: true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    this.subtitle = '',
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(
                value,
                style: AppTextStyles.h2.copyWith(
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyMedium?.color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          if (subtitle.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  subtitle,
                  style: AppTextStyles.labelSmall.copyWith(
                    fontSize: 10,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              style: AppTextStyles.labelMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  const _TaskItem({
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(title, style: AppTextStyles.labelMedium)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: count > 0
                    ? color.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                count.toString(),
                style: AppTextStyles.labelSmall.copyWith(
                  color: count > 0 ? color : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
