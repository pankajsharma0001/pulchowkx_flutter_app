import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pulchowkx_app/models/club.dart';
import 'package:pulchowkx_app/models/event.dart';
import 'package:pulchowkx_app/pages/event_details.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/custom_app_bar.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ClubDetailsPage extends StatefulWidget {
  final int clubId;

  const ClubDetailsPage({super.key, required this.clubId});

  @override
  State<ClubDetailsPage> createState() => _ClubDetailsPageState();
}

class _ClubDetailsPageState extends State<ClubDetailsPage>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  late Future<Club?> _clubFuture;
  late Future<ClubProfile?> _profileFuture;
  late Future<List<ClubEvent>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  void _loadData() {
    _clubFuture = _apiService.getClub(widget.clubId);
    _profileFuture = _apiService.getClubProfile(widget.clubId);
    _eventsFuture = _apiService.getClubEvents(widget.clubId);
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
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final club = clubSnapshot.data;
          if (club == null) {
            return _buildErrorState('Club not found');
          }

          return Container(
            decoration: const BoxDecoration(gradient: AppColors.heroGradient),
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                // Club Header
                SliverToBoxAdapter(child: _ClubHeader(club: club)),

                // Offline Warning
                FutureBuilder(
                  future: Connectivity().checkConnectivity(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData &&
                        snapshot.data!.first == ConnectivityResult.none) {
                      return SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.sm,
                          ),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: AppColors.warning),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.wifi_off_rounded,
                                size: 16,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Offline Mode',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  },
                ),

                // Tab Bar
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverTabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.primary,
                      indicatorWeight: 3,
                      labelStyle: AppTextStyles.labelMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      tabs: const [
                        Tab(text: 'About'),
                        Tab(text: 'Events'),
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
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
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
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        );
                      }
                      return _EventsTab(events: snapshot.data ?? []);
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
          // Club Logo
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: AppShadows.lg,
              border: Border.all(color: Colors.white, width: 3),
            ),
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
          const SizedBox(height: AppSpacing.md),
          // Club Name
          Text(
            club.name,
            style: AppTextStyles.h2.copyWith(color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          if (club.description != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              club.description!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(context, shrinkOffset, overlapsContent) {
    return Container(color: AppColors.surface, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) => false;
}

class _AboutTab extends StatelessWidget {
  final Club club;
  final ClubProfile? profile;

  const _AboutTab({required this.club, this.profile});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Brief Intro / Template Text
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
            'About ${club.name}',
            style: AppTextStyles.h2.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            "Welcome to the official page of ${club.name}. Our club is a vibrant community where creativity, innovation, and collaboration come together. We host various events throughout the year, from workshops and seminars to social gatherings and competitions.\n\nMembers of ${club.name} gain access to a network of like minded individuals, hands on experience in various projects, and the opportunity to lead and organize campus wide events.",
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // 2. Club Statistics
          // if (profile?.establishedYear != null) ...[
          //   Container(
          //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          //     decoration: BoxDecoration(
          //       border: Border.all(color: AppColors.border),
          //       borderRadius: BorderRadius.circular(AppRadius.md),
          //     ),
          //     // child: Row(
          //     //   mainAxisSize: MainAxisSize.min,
          //     //   children: [
          //     //     const Icon(
          //     //       Icons.calendar_today_outlined,
          //     //       size: 16,
          //     //       color: AppColors.textSecondary,
          //     //     ),
          //     //     // const SizedBox(width: 8),
          //     //     // Text(
          //     //     //   'Est. ${profile!.establishedYear}',
          //     //     //   style: AppTextStyles.labelMedium.copyWith(
          //     //     //     fontWeight: FontWeight.bold,
          //     //     //   ),
          //     //     // ),
          //     //   ],
          //     // ),
          //   ),
          //   const SizedBox(height: AppSpacing.lg),
          // ],

          // 3. Contact Info
          _ContactCard(club: club, profile: profile),
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

  Future<void> _launchEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final socialLinks = profile?.socialLinks;
    final hasSocialLinks = socialLinks != null && socialLinks.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Contact Info', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.lg),
          if (club.email != null)
            _ContactItem(
              icon: Icons.mail_outline_rounded,
              text: club.email!,
              onTap: () => _launchEmail(club.email!),
            ),
          if (profile?.contactPhone != null)
            _ContactItem(
              icon: Icons.phone_outlined,
              text: profile!.contactPhone!,
              onTap: () => _launchPhone(profile!.contactPhone!),
            ),
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
                      : AppColors.textPrimary,
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
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
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
                            color: AppColors.textPrimary,
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
