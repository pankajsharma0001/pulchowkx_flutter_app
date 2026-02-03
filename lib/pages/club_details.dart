import 'package:flutter/material.dart';
import 'package:pulchowkx_app/services/haptic_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pulchowkx_app/models/club.dart';
import 'package:pulchowkx_app/models/event.dart';
import 'package:pulchowkx_app/pages/event_details.dart';
import 'package:pulchowkx_app/pages/admin/create_event_page.dart';
import 'package:pulchowkx_app/services/analytics_service.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/services/favorites_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/custom_app_bar.dart';
import 'package:pulchowkx_app/widgets/shimmer_loaders.dart';
import 'package:pulchowkx_app/pages/admin/club_admin_tab.dart';
import 'package:pulchowkx_app/widgets/offline_banner.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ClubDetailsPage extends StatefulWidget {
  final int clubId;

  const ClubDetailsPage({super.key, required this.clubId});

  @override
  State<ClubDetailsPage> createState() => _ClubDetailsPageState();
}

class _ClubDetailsPageState extends State<ClubDetailsPage>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  late Future<Club?> _clubFuture;
  late Future<ClubProfile?> _profileFuture;
  late Future<List<ClubEvent>> _eventsFuture;

  bool _isAuthorized = false;
  Club? _cachedClub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _checkAuthorization();
  }

  void _loadData() {
    _clubFuture = _apiService.getClub(widget.clubId);
    _profileFuture = _apiService.getClubProfile(widget.clubId);
    _eventsFuture = _apiService.getClubEvents(widget.clubId);
  }

  Future<void> _checkAuthorization() async {
    final dbUserId = await _apiService.getDatabaseUserId();
    if (dbUserId != null) {
      final isAuthorized = await _apiService.isClubAdminOrOwner(
        widget.clubId,
        dbUserId,
      );
      if (mounted && isAuthorized && !_isAuthorized) {
        _tabController.dispose();
        setState(() {
          _isAuthorized = true;
          _tabController = TabController(length: 3, vsync: this);
        });
      }
    }
  }

  Future<void> _navigateToCreateEvent() async {
    if (_cachedClub == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CreateEventPage(clubId: widget.clubId, clubName: _cachedClub!.name),
      ),
    );

    if (result == true) {
      // Refresh events list after successful creation
      setState(() {
        _eventsFuture = _apiService.getClubEvents(widget.clubId);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      floatingActionButton: _isAuthorized
          ? FloatingActionButton.extended(
              onPressed: _navigateToCreateEvent,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('New Event'),
            )
          : null,
      body: FutureBuilder<Club?>(
        future: _clubFuture,
        builder: (context, clubSnapshot) {
          // Check connectivity once data is loaded (or if error)
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final connectivityResult = await Connectivity().checkConnectivity();
            if (connectivityResult.first == ConnectivityResult.none) {
              if (mounted) {
                // Could show snackbar here, but might be annoying if navigating between details pages.
                // Using a Banner/Warning inside the UI might be better for details page.
              }
            }
          });

          if (clubSnapshot.connectionState == ConnectionState.waiting) {
            return const DetailsPageShimmer();
          }

          final club = clubSnapshot.data;
          if (club == null) {
            return _buildErrorState('Club not found');
          }

          // Cache the club for later use
          if (_cachedClub == null) {
            _cachedClub = club;
            AnalyticsService.logClubView(club.id.toString(), club.name);
          }

          return Container(
            decoration: BoxDecoration(
              gradient: Theme.of(context).brightness == Brightness.light
                  ? AppColors.heroGradient
                  : AppColors.heroGradientDark,
            ),
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                // Club Header
                SliverToBoxAdapter(child: _ClubHeader(club: club)),

                // Offline Warning
                const SliverOfflineBanner(message: 'Offline Mode'),

                // Tab Bar
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _ClubTabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.primary,
                      indicatorWeight: 3,
                      labelStyle: AppTextStyles.labelMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      tabs: [
                        const Tab(text: 'About'),
                        const Tab(text: 'Events'),
                        if (_isAuthorized) const Tab(text: 'Admin'),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  // About Tab
                  FutureBuilder<ClubProfile?>(
                    future: _profileFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            children: [
                              BoxShimmer(height: 100),
                              SizedBox(height: AppSpacing.md),
                              BoxShimmer(height: 100),
                            ],
                          ),
                        );
                      }
                      return _AboutTab(club: club, profile: snapshot.data);
                    },
                  ),
                  // Events Tab
                  FutureBuilder<List<ClubEvent>>(
                    future: _eventsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: GridShimmer(
                            itemShimmer: EventCardShimmer(),
                            childAspectRatio: 0.85,
                          ),
                        );
                      }
                      return _EventsTab(events: snapshot.data ?? []);
                    },
                  ),
                  // Admin Tab
                  if (_isAuthorized)
                    FutureBuilder<ClubProfile?>(
                      future: _profileFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(AppSpacing.lg),
                            child: BoxShimmer(height: 200),
                          );
                        }
                        return ClubAdminTab(
                          club: club,
                          profile: snapshot.data,
                          onInfoUpdated: () => setState(() => _loadData()),
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: AppSpacing.md),
          Text(message, style: AppTextStyles.bodyLarge),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }
}

class _ClubHeader extends StatelessWidget {
  final Club club;

  const _ClubHeader({required this.club});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          // Club Logo with Favorite Button
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: AppShadows.lg,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Hero(
                  tag: 'club_logo_${club.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xl - 2),
                    child: club.logoUrl != null && club.logoUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: club.logoUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => _buildPlaceholder(),
                            errorWidget: (_, _, _) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),
                ),
              ),
              // Favorite Button
              Positioned(
                top: -8,
                right: -8,
                child: ListenableBuilder(
                  listenable: favoritesService,
                  builder: (context, _) {
                    final isFavorite = favoritesService.isClubFavorite(
                      club.id.toString(),
                    );
                    return GestureDetector(
                      onTap: () {
                        haptics.lightImpact();
                        favoritesService.toggleClubFavorite(club.id.toString());
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isFavorite
                              ? AppColors.error
                              : Theme.of(context).cardTheme.color,
                          shape: BoxShape.circle,
                          boxShadow:
                              Theme.of(context).brightness == Brightness.light
                              ? AppShadows.md
                              : null,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_outline_rounded,
                            key: ValueKey(isFavorite),
                            color: isFavorite
                                ? Colors.white
                                : AppColors.textMuted,
                            size: 18,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Club Name
          Text(
            club.name,
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(fontSize: 28),
            textAlign: TextAlign.center,
          ),
          if (club.description != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              club.description!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          // Stats Row
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _StatChip(
                icon: Icons.event_available_rounded,
                value: '${club.upcomingEvents ?? 0}',
                label: 'Upcoming',
                color: const Color(0xFF2196F3), // Blue
              ),
              _StatChip(
                icon: Icons.event_note_rounded,
                value: '${club.completedEvents ?? 0}',
                label: 'Completed',
                color: const Color(0xFF00C853), // Green
              ),
              _StatChip(
                icon: Icons.people_rounded,
                value: '${club.totalParticipants ?? 0}',
                label: 'Participants',
                color: const Color(0xFFAA00FF), // Purple
              ),
              if (club.createdAt != null)
                _StatChip(
                  icon: Icons.calendar_month_rounded,
                  value: 'Est. ${club.createdAt!.year}',
                  label: '',
                  color: AppColors.textSecondary,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: Center(
        child: Text(
          club.name.isNotEmpty ? club.name[0].toUpperCase() : 'C',
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(0x1A),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withAlpha(0x33)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            value,
            style: AppTextStyles.labelMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClubTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _ClubTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(context, shrinkOffset, overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _ClubTabBarDelegate oldDelegate) => true;
}

class _AboutTab extends StatefulWidget {
  final Club club;
  final ClubProfile? profile;

  const _AboutTab({required this.club, this.profile});

  @override
  State<_AboutTab> createState() => _AboutTabState();
}

class _AboutTabState extends State<_AboutTab> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _admins = [];
  bool _loadingAdmins = true;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    try {
      final admins = await _apiService.getClubAdmins(widget.club.id);
      if (mounted) {
        setState(() {
          _admins = admins;
          _loadingAdmins = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingAdmins = false);
      }
    }
  }

  /// Check if profile has any content
  bool get _hasProfileContent {
    final profile = widget.profile;
    if (profile == null) return false;
    return (profile.aboutClub?.isNotEmpty ?? false) ||
        (profile.mission?.isNotEmpty ?? false) ||
        (profile.vision?.isNotEmpty ?? false) ||
        (profile.benefits?.isNotEmpty ?? false) ||
        (profile.achievements?.isNotEmpty ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Introduction Section
          Text(
            'INTRODUCTION',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'About ${widget.club.name}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.md),

          // About Text - conditional based on profile
          if (_hasProfileContent &&
              widget.profile?.aboutClub?.isNotEmpty == true)
            Text(
              widget.profile!.aboutClub!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            )
          else
            Text(
              "Welcome to the official page of ${widget.club.name}. Our club is a vibrant community where creativity, innovation, and collaboration come together. We host various events throughout the year, from workshops and seminars to social gatherings and competitions.\n\nMembers of ${widget.club.name} gain access to a network of like minded individuals, hands on experience in various projects, and the opportunity to lead and organize campus wide events.",
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),

          // View Website Button
          if (widget.profile?.websiteUrl != null &&
              widget.profile!.websiteUrl!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: () async {
                final uri = Uri.parse(widget.profile!.websiteUrl!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.language_rounded),
              label: const Text('View Website'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ],

          // Mission & Vision (if profile has content)
          if (_hasProfileContent) ...[
            if (widget.profile?.mission?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.xl),
              _buildProfileSection(
                'OUR MISSION',
                widget.profile!.mission!,
                Icons.flag_rounded,
                const Color(0xFF2196F3),
              ),
            ],
            if (widget.profile?.vision?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildProfileSection(
                'OUR VISION',
                widget.profile!.vision!,
                Icons.visibility_rounded,
                const Color(0xFF9C27B0),
              ),
            ],
            if (widget.profile?.benefits?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildProfileSection(
                'MEMBER BENEFITS',
                widget.profile!.benefits!,
                Icons.card_giftcard_rounded,
                const Color(0xFF4CAF50),
              ),
            ],
            if (widget.profile?.achievements?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildProfileSection(
                'ACHIEVEMENTS',
                widget.profile!.achievements!,
                Icons.emoji_events_rounded,
                const Color(0xFFFF9800),
              ),
            ],
          ],

          const SizedBox(height: AppSpacing.xl),

          // Admins Section
          _buildAdminsSection(),

          const SizedBox(height: AppSpacing.xl),

          // Contact Info
          _ContactCard(club: widget.club, profile: widget.profile),
        ],
      ),
    );
  }

  Widget _buildProfileSection(
    String title,
    String content,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withAlpha(0x0D),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withAlpha(0x33)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: AppTextStyles.labelSmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            content,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminsSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: Theme.of(context).dividerTheme.color ?? AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.admin_panel_settings_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Club Administrators',
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(fontSize: 20),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Club Owner (represented by the Club entity itself)
          _buildAdminTile(
            name: widget.club.name,
            email: widget.club.email ?? 'No email',
            image: widget.club.logoUrl,
            isOwner: true,
          ),

          // Admins List
          if (_loadingAdmins)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_admins.isEmpty)
            // Only show message if we want to explicitly say no *additional* admins
            // or we can just show nothing since we already showed the Owner
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'No additional admins',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ..._admins.asMap().entries.map((entry) {
              final user = entry.value;
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: _buildAdminTile(
                  name: user['name'] ?? 'Unknown',
                  email: user['email'] ?? '',
                  image: user['image'],
                  isOwner:
                      false, // Additional admins are not "Owner" in this context
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAdminTile({
    required String name,
    required String email,
    String? image,
    required bool isOwner,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isOwner
            ? AppColors.primary.withValues(alpha: 0.05)
            : Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isOwner
              ? AppColors.primary.withValues(alpha: 0.2)
              : Theme.of(context).dividerTheme.color ?? AppColors.border,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: image != null && image.isNotEmpty
                ? NetworkImage(image)
                : null,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: image == null || image.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: AppTextStyles.labelLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isOwner) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          'OWNER',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  email,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final Club club;
  final ClubProfile? profile;

  const _ContactCard({required this.club, this.profile});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback or secondary check
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('Error launching email: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final socialLinks = profile?.socialLinks;
    final hasSocialLinks = socialLinks != null && socialLinks.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: Theme.of(context).dividerTheme.color ?? AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Info',
            style: Theme.of(
              context,
            ).textTheme.displaySmall?.copyWith(fontSize: 20),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (club.email != null)
            _ContactItem(
              icon: Icons.mail_outline_rounded,
              text: club.email!,
              onTap: () => _launchEmail(club.email!),
            ),
          if (profile?.contactPhone != null &&
              profile!.contactPhone!.isNotEmpty)
            _ContactItem(
              icon: Icons.phone_outlined,
              text: profile!.contactPhone!,
              onTap: () => _launchPhone(profile!.contactPhone!),
            )
          else
            _ContactItem(icon: Icons.phone_outlined, text: 'No contact number'),
          // Always show location as IOE Pulchowk
          const _ContactItem(
            icon: Icons.location_on_outlined,
            text: 'IOE Pulchowk Campus',
          ),
          // Remove specific website URL display as requested, assuming Location replaces it or takes priority

          // Social Links Section
          if (hasSocialLinks) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Follow Us',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: socialLinks.entries
                  .where((e) => e.value.isNotEmpty)
                  .map(
                    (entry) => _SocialLinkButton(
                      platform: entry.key,
                      onTap: () => _launchUrl(entry.value),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _ContactItem({required this.icon, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xs,
          horizontal: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: onTap != null
                      ? AppColors.primary
                      : Theme.of(context).textTheme.bodyMedium?.color,
                  decoration: onTap != null ? TextDecoration.underline : null,
                ),
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.open_in_new_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

class _SocialLinkButton extends StatelessWidget {
  final String platform;
  final VoidCallback onTap;

  const _SocialLinkButton({required this.platform, required this.onTap});

  IconData _getIcon() {
    switch (platform.toLowerCase()) {
      case 'facebook':
        return Icons.facebook_rounded;
      case 'instagram':
        return Icons.camera_alt_rounded;
      case 'twitter':
        return Icons.alternate_email_rounded;
      case 'linkedin':
        return Icons.work_rounded;
      case 'github':
        return Icons.code_rounded;
      case 'discord':
        return Icons.discord_rounded;
      case 'youtube':
        return Icons.play_circle_rounded;
      case 'tiktok':
        return Icons.music_note_rounded;
      default:
        return Icons.link_rounded;
    }
  }

  Color _getColor() {
    switch (platform.toLowerCase()) {
      case 'facebook':
        return const Color(0xFF1877F2);
      case 'instagram':
        return const Color(0xFFE4405F);
      case 'twitter':
        return const Color(0xFF1DA1F2);
      case 'linkedin':
        return const Color(0xFF0A66C2);
      case 'github':
        return const Color(0xFF333333);
      case 'discord':
        return const Color(0xFF5865F2);
      case 'youtube':
        return const Color(0xFFFF0000);
      case 'tiktok':
        return const Color(0xFF000000);
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Icon(_getIcon(), size: 20, color: color),
        ),
      ),
    );
  }
}

class _EventsTab extends StatelessWidget {
  final List<ClubEvent> events;

  const _EventsTab({required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_busy_rounded,
                size: 48,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No events yet',
                style: AppTextStyles.h4.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'This club hasn\'t hosted any events yet. Check back later!',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Sort events: ongoing first, then upcoming, then completed
    final sortedEvents = List<ClubEvent>.from(events)
      ..sort((a, b) {
        if (a.isOngoing && !b.isOngoing) return -1;
        if (!a.isOngoing && b.isOngoing) return 1;
        if (a.isUpcoming && !b.isUpcoming) return -1;
        if (!a.isUpcoming && b.isUpcoming) return 1;
        return b.eventStartTime.compareTo(a.eventStartTime);
      });

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: sortedEvents.length,
      itemBuilder: (context, index) {
        return _EventCard(event: sortedEvents[index]);
      },
    );
  }
}

class _EventCard extends StatelessWidget {
  final ClubEvent event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EventDetailsPage(event: event),
              ),
            );
          },
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: Theme.of(context).dividerTheme.color ?? AppColors.border,
              ),
            ),
            child: Row(
              children: [
                // Event Banner
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(AppRadius.lg),
                  ),
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: event.bannerUrl != null
                        ? CachedNetworkImage(
                            imageUrl: event.bannerUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => _buildPlaceholder(),
                            errorWidget: (_, _, _) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),
                ),
                // Event Info
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _StatusBadge(event: event),
                            const Spacer(),
                            Text(
                              event.eventType,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          event.title,
                          style: AppTextStyles.labelLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 12,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${dateFormat.format(event.eventStartTime)} at ${timeFormat.format(event.eventStartTime)}',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        if (event.venue != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 12,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  event.venue!,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: const Center(
        child: Icon(Icons.event_rounded, color: Colors.white, size: 32),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ClubEvent event;

  const _StatusBadge({required this.event});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String text;

    if (event.isOngoing) {
      bgColor = AppColors.success.withValues(alpha: 0.1);
      textColor = AppColors.success;
      text = 'LIVE';
    } else if (event.isUpcoming) {
      bgColor = AppColors.primary.withValues(alpha: 0.1);
      textColor = AppColors.primary;
      text = 'UPCOMING';
    } else {
      bgColor = AppColors.textSecondary.withValues(alpha: 0.1);
      textColor = AppColors.textSecondary;
      text = 'COMPLETED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 9,
        ),
      ),
    );
  }
}
