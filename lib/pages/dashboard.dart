import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pulchowkx_app/pages/main_layout.dart';
import 'package:pulchowkx_app/auth/service/google_auth.dart';
import 'package:pulchowkx_app/pages/marketplace/book_requests_page.dart';
import 'package:pulchowkx_app/models/event.dart';
import 'package:intl/intl.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/services/api_service.dart';

import 'package:pulchowkx_app/widgets/custom_app_bar.dart';
import 'package:pulchowkx_app/pages/settings_page.dart';
import 'package:pulchowkx_app/models/classroom.dart';
import 'package:pulchowkx_app/models/notice.dart';
import 'package:pulchowkx_app/models/book_listing.dart';
import 'package:pulchowkx_app/pages/classroom/shared_widgets.dart';
import 'package:pulchowkx_app/pages/admin/create_club_page.dart';
import 'package:pulchowkx_app/pages/favorites_page.dart';
import 'package:pulchowkx_app/pages/event_details.dart';
import 'package:pulchowkx_app/pages/my_books.dart';
import 'package:pulchowkx_app/widgets/shimmer_loaders.dart';
import 'package:pulchowkx_app/pages/admin/admin_reports.dart';
import 'package:pulchowkx_app/pages/admin/admin_users.dart';

class _AdminTask {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _AdminTask({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ApiService _apiService = ApiService();
  bool _isAdmin = false;
  bool _isLoading = true;
  int _upcomingEnrollmentsCount = 0;
  List<EventRegistration> _enrolledEvents = [];

  // Additional stats to match webapp
  int _pendingAssignmentsCount = 0;
  int _adminPendingCount = 0;
  int _newNoticesCount = 0;
  int _myBooksCount = 0;

  List<Assignment> _pendingAssignments = [];
  List<ClubEvent> _upcomingEvents = [];
  List<BookListing> _myBooks = [];
  List<_AdminTask> _adminTasks = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final dbId = await _apiService.requireDatabaseUserId();
      if (dbId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Fetch all data in parallel
      // Fetch all data in parallel

      // Temporary admin check to decide if we fetch admin stats
      // We need to await isAdmin first effectively, or just handle it after
      // But parallel is better. Let's do isAdmin first.
      final isAdminResult = await _apiService.isAdmin();

      Map<String, dynamic>? adminOverview;
      if (isAdminResult) {
        try {
          adminOverview = await _apiService.getAdminOverview();
        } catch (e) {
          debugPrint('Error fetching admin overview: $e');
        }
      }

      final results = await Future.wait([
        _apiService.getEnrollments(dbId),
        _apiService.getMySubjects(),
        _apiService.getNoticeStats(),
        _apiService.getMyBookListings(),
        _apiService.getUpcomingEvents(),
      ]);

      final enrollments = results[0] as List<EventRegistration>;
      final subjects = results[1] as List<Subject>;
      final noticeStats = results[2] as NoticeStats?;
      final myBooksResult = results[3] as List<BookListing>;
      final upcomingEventsResult = results[4] as List<ClubEvent>;

      final now = DateTime.now();

      // Aggregate assignments
      List<Assignment> pendingAssignments = [];
      for (var subject in subjects) {
        if (subject.assignments != null) {
          for (var assignment in subject.assignments!) {
            if (assignment.submission == null) {
              pendingAssignments.add(assignment);
            }
          }
        }
      }

      // Process Admin Tasks
      List<_AdminTask> adminTasks = [];
      if (isAdminResult && adminOverview != null) {
        final openReports = adminOverview['openReports'] ?? 0;
        final activeBlocks = adminOverview['activeBlocks'] ?? 0;

        if (openReports > 0) {
          adminTasks.add(
            _AdminTask(
              title: 'Review Reports',
              subtitle: '$openReports open reports',
              icon: Icons.flag_outlined,
              color: AppColors.error,
              onTap: () {
                Navigator.of(context, rootNavigator: true)
                    .push(
                      MaterialPageRoute(
                        builder: (_) => const AdminReportsPage(),
                      ),
                    )
                    .then((_) => _fetchDashboardData());
              },
            ),
          );
        }

        if (activeBlocks > 0) {
          adminTasks.add(
            _AdminTask(
              title: 'User Management',
              subtitle: '$activeBlocks Active Blocks',
              icon: Icons.people_outline,
              color: Colors.orange,
              onTap: () {
                Navigator.of(context, rootNavigator: true)
                    .push(
                      MaterialPageRoute(builder: (_) => const AdminUsersPage()),
                    )
                    .then((_) => _fetchDashboardData());
              },
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _isAdmin = isAdminResult;
          final comingEvents = enrollments
              .where(
                (e) =>
                    e.event != null &&
                    e.event!.eventStartTime.isAfter(now) &&
                    e.status == 'registered',
              )
              .toList();

          _upcomingEnrollmentsCount = comingEvents.length;
          _enrolledEvents = comingEvents;

          _pendingAssignmentsCount = pendingAssignments.length;
          _adminPendingCount = adminTasks.length;
          _newNoticesCount = noticeStats?.newCount ?? 0;
          _myBooksCount = myBooksResult.length;

          _pendingAssignments = pendingAssignments;
          _upcomingEvents = upcomingEventsResult;
          _myBooks = myBooksResult;
          _adminTasks = adminTasks;

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

    // Show a beautiful, non-dismissible loading dialog
    if (context.mounted) {
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
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainLayout()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: const CustomAppBar(currentPage: AppPage.dashboard),
        body: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? AppColors.heroGradientDark
                : AppColors.heroGradient,
          ),
          child: RefreshIndicator(
            onRefresh: _fetchDashboardData,
            displacement: 20,
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header
                  _isLoading
                      ? const DashboardHeaderShimmer()
                      : _buildProfileHeader(
                          FirebaseAuth.instance.currentUser?.displayName ??
                              'Student',
                          FirebaseAuth.instance.currentUser?.email ?? '',
                          FirebaseAuth.instance.currentUser?.photoURL,
                        ),

                  const SizedBox(height: AppSpacing.lg),

                  // Stats Grid
                  _isLoading ? const StatsGridShimmer() : _buildStatsGrid(),
                  const SizedBox(height: AppSpacing.md), // Reduced from lg
                  // Coming Up Section
                  _buildComingUpSection(),
                  const SizedBox(height: AppSpacing.lg),

                  // Quick Actions Header
                  _buildSectionHeader('Quick Actions'),
                  const SizedBox(height: AppSpacing.sm),
                  _isLoading
                      ? Column(
                          children: const [
                            QuickActionShimmer(),
                            SizedBox(height: AppSpacing.md),
                            QuickActionShimmer(),
                          ],
                        )
                      : Column(
                          children: [
                            if (_isAdmin) ...[
                              _QuickActionCard(
                                icon: Icons.add_circle_outline_rounded,
                                title: 'Create Club',
                                description:
                                    'Set up a new student organization',
                                color: AppColors.primary,
                                heroTag: 'create-club',
                                onTap: () =>
                                    Navigator.of(
                                      context,
                                      rootNavigator: true,
                                    ).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const CreateClubPage(),
                                      ),
                                    ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            _QuickActionCard(
                              icon: Icons.favorite_rounded,
                              title: 'Favorites',
                              description: 'View your saved events and clubs',
                              color: Colors.redAccent,
                              heroTag: 'favorites',
                              onTap: () =>
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const FavoritesPage(),
                                    ),
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _QuickActionCard(
                              icon: Icons.shopping_bag_rounded,
                              title: 'Book Requests',
                              description: 'View active book requests',
                              color: Colors.orange,
                              heroTag: 'book-requests',
                              onTap: () =>
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const BookRequestsPage(
                                            showAppBar: true,
                                          ),
                                    ),
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _QuickActionCard(
                              icon: Icons.settings_rounded,
                              title: 'Settings',
                              description: 'App preferences and info',
                              color: Colors.grey,
                              heroTag: 'settings',
                              onTap: () =>
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const SettingsPage(),
                                    ),
                                  ),
                            ),
                          ],
                        ),

                  const SizedBox(height: AppSpacing.xxl),

                  // Activity Section
                  _buildActivitySection(),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Recent Activity'),
        const SizedBox(height: AppSpacing.md),
        Container(
          height: 400,
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: Theme.of(context).dividerTheme.color ?? AppColors.border,
            ),
          ),
          child: Column(
            children: [
              TabBar(
                tabs: [
                  Tab(text: _isAdmin ? 'Pending Tasks' : 'Assignments'),
                  const Tab(text: 'Events'),
                  const Tab(text: 'Books'),
                ],
                labelStyle: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.primary,
                dividerColor: Colors.transparent,
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _isAdmin
                        ? _buildActivityTabList(
                            _adminTasks,
                            Icons.task_alt_rounded,
                            'No pending admin tasks',
                          )
                        : _buildActivityTabList(
                            _pendingAssignments,
                            Icons.assignment_outlined,
                            'No pending assignments',
                          ),
                    _buildActivityTabList(
                      _upcomingEvents,
                      Icons.event_outlined,
                      'No upcoming events',
                    ),
                    _buildActivityTabList(
                      _myBooks,
                      Icons.library_books_outlined,
                      'No books listed',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityTabList(List items, IconData icon, String emptyText) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: AppColors.textMuted.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              emptyText,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: items.length > 10 ? 10 : items.length, // Limit for dashboard
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        String title = '';
        String subtitle = '';
        VoidCallback? onTap;
        Color? itemColor;

        if (item is Assignment) {
          title = item.title;
          subtitle = item.dueAt != null
              ? 'Due ${DateFormat('MMM dd').format(item.dueAt!)}'
              : 'Pending';
        } else if (item is ClubEvent) {
          title = item.title;
          subtitle = DateFormat('MMM dd, hh:mm a').format(item.eventStartTime);
        } else if (item is BookListing) {
          title = item.title;
          subtitle = 'Rs. ${item.price} • ${item.condition}';
        } else if (item is _AdminTask) {
          title = item.title;
          subtitle = item.subtitle;
          onTap = item.onTap;
          itemColor = item.color;
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (itemColor ?? AppColors.primary).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              (item is _AdminTask) ? item.icon : icon,
              color: itemColor ?? AppColors.primary,
              size: 20,
            ),
          ),
          title: Text(
            title,
            style: AppTextStyles.labelMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, size: 18),
          onTap:
              onTap ??
              () {
                // Add navigation if needed
              },
        );
      },
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  gradient: AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xl - 2),
                    child: photoUrl != null
                        ? CachedNetworkImage(
                            imageUrl: ApiService().optimizeCloudinaryUrl(
                              photoUrl,
                              width: 200,
                            ),
                            fit: BoxFit.cover,
                            memCacheWidth: 200,
                            placeholder: (context, url) => Container(
                              color: AppColors.primary.withValues(alpha: 0.1),
                            ),
                          )
                        : Container(
                            color: Colors.white,
                            child: const Icon(
                              Icons.person_rounded,
                              size: 36,
                              color: AppColors.primary,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
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
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_user_rounded,
                            size: 12,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              (_isAdmin
                                      ? 'Admin Dashboard'
                                      : 'Student Dashboard')
                                  .toUpperCase(),
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      style: AppTextStyles.h4.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      email,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              IconButton(
                onPressed: () => _handleSignOut(context),
                icon: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.error,
                  size: 22,
                ),
                tooltip: 'Sign Out',
                padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
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
        final isWide = constraints.maxWidth > 600;
        final int crossAxisCount = isWide ? 4 : 2;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: isWide ? 2.2 : 2.4,
          children: [
            StatCard(
              label: _isAdmin ? 'Pending Tasks' : 'Assignments',
              value: _isAdmin
                  ? _adminPendingCount.toString()
                  : _pendingAssignmentsCount.toString(),
              icon: Icons.assignment_outlined,
              color: AppColors.primary,
              onTap: () {
                if (_isAdmin) {
                  // For admins, scroll to activity section where tasks are listed
                  // Or we could have a specific page.
                  // Since we listed them in tabs below, let's just do nothing or scroll?
                  // The user can scroll down.
                } else {
                  MainLayout.of(context)?.setSelectedIndex(2);
                }
              },
            ),
            StatCard(
              label: 'Notices',
              value: _newNoticesCount.toString(),
              icon: Icons.notification_important_outlined,
              color: AppColors.success,
              onTap: () {
                // Use tab switching for instant navigation
                MainLayout.of(context)?.setSelectedIndex(8);
              },
            ),
            StatCard(
              label: 'Events',
              value: _upcomingEnrollmentsCount.toString(),
              icon: Icons.event_available_outlined,
              color: Colors.orange,
              onTap: () {
                MainLayout.of(context)?.setSelectedIndex(6);
              },
            ),
            StatCard(
              label: 'Books',
              value: _myBooksCount.toString(),
              icon: Icons.library_books_outlined,
              color: Colors.purple,
              onTap: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(builder: (context) => const MyBooksPage()),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildComingUpSection() {
    final List<Widget> items = [];

    // Add Assignments (only if not admin or if we want to show student stuff too? User asked to hide it)
    if (!_isAdmin) {
      for (var assignment in _pendingAssignments) {
        items.add(
          _ComingUpItem(
            title: assignment.title,
            subtitle: assignment.dueAt != null
                ? 'Due: ${DateFormat('MMM dd').format(assignment.dueAt!)}'
                : 'Pending',
            icon: Icons.assignment_outlined,
            color: assignment.isDueSoon ? AppColors.error : AppColors.primary,
            onTap: () {
              // Navigate to classroom tab
              MainLayout.of(context)?.setSelectedIndex(2);
            },
          ),
        );
      }
    }

    // Add Enrolled Events
    for (var enrollment in _enrolledEvents) {
      if (enrollment.event != null) {
        items.add(
          _ComingUpItem(
            title: enrollment.event!.title,
            subtitle: DateFormat(
              'MMM d, h:mm a',
            ).format(enrollment.event!.eventStartTime),
            icon: Icons.event_available_rounded,
            color: Colors.orange,
            onTap: () {
              // Navigate to specific event details
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (context) => EventDetailsPage(
                    event: enrollment.event,
                    eventId: enrollment.event!.id,
                  ),
                ),
              );
            },
          ),
        );
      }
    }

    if (items.isEmpty && !_isLoading) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color?.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.success,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              'All caught up!',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Coming Up'),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 70,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) => items[index],
          ),
        ),
      ],
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

class _ComingUpItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ComingUpItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.labelLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
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
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Hero(
                      tag: widget.heroTag,
                      child: Icon(widget.icon, color: widget.color, size: 20),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.title,
                          style: AppTextStyles.labelLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.description,
                          style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
          ),
        ),
      ),
    );
  }
}
