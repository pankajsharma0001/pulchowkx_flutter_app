import 'package:flutter/material.dart';
import 'package:pulchowkx_app/pages/calendar_page.dart';
import 'package:pulchowkx_app/services/haptic_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:pulchowkx_app/models/event.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/custom_app_bar.dart'
    show CustomAppBar, AppPage;
import 'package:pulchowkx_app/widgets/shimmer_loaders.dart';
import 'package:pulchowkx_app/widgets/empty_states.dart';
import 'package:pulchowkx_app/widgets/event_card.dart';
import 'package:pulchowkx_app/widgets/offline_banner.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final ApiService _apiService = ApiService();
  late Future<List<ClubEvent>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _eventsFuture = _apiService.getAllEvents();
  }

  void _refreshEvents() {
    setState(() {
      _eventsFuture = _apiService.getAllEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(currentPage: AppPage.events),
      body: Container(
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.light
              ? AppColors.heroGradient
              : AppColors.heroGradientDark,
        ),
        child: RefreshIndicator(
          onRefresh: () async {
            haptics.mediumImpact();
            _refreshEvents();
            // Check connectivity on refresh
            final connectivityResult = await Connectivity().checkConnectivity();
            if (connectivityResult.first == ConnectivityResult.none) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No internet connection.'),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            }
          },
          color: AppColors.primary,
          child: FutureBuilder<List<ClubEvent>>(
            future: _eventsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: GridShimmer(itemShimmer: EventCardShimmer()),
                      ),
                    ),
                  ],
                );
              }

              if (snapshot.hasError) {
                return _buildErrorState(snapshot.error.toString());
              }

              final events = snapshot.data ?? [];

              // Only check on initial load/rebuild if we have data and assume it might be cached if offline
              // A better check would be explicitly asking ApiService if it used cache, but checking connectivity is a good proxy.
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                final connectivityResult = await Connectivity()
                    .checkConnectivity();
                if (connectivityResult.first == ConnectivityResult.none &&
                    events.isNotEmpty) {
                  if (mounted) {
                    // Simple de-bouncing could be added here if needed, but for now this is okay
                    // We can't easily check if specific snackbar is showing, but we can rely on standard behavior or use a boolean flag in state if it spams.
                    // For this iteration, let's keep it simple.
                  }
                }
              });

              final categorized = _categorizeEvents(events);

              return CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              boxShadow: AppShadows.colored(AppColors.primary),
                            ),
                            child: const Icon(
                              Icons.event_rounded,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Campus Events',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Discover workshops, seminars, and gatherings',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          OutlinedButton.icon(
                            onPressed: () {
                              haptics.lightImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CalendarPage(),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.calendar_month_rounded,
                              size: 20,
                            ),
                            label: const Text('View Calendar'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Offline Banner
                  const SliverOfflineBanner(),

                  // Ongoing Events
                  if (categorized['ongoing']!.isNotEmpty) ...[
                    _buildSectionHeader(
                      'Ongoing Events',
                      AppColors.success,
                      'LIVE NOW',
                      categorized['ongoing']!.length,
                    ),
                    _buildEventsGrid(categorized['ongoing']!, isOngoing: true),
                  ],

                  // Upcoming Events
                  _buildSectionHeader(
                    'Upcoming Events',
                    AppColors.primary,
                    null,
                    categorized['upcoming']!.length,
                  ),
                  if (categorized['upcoming']!.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyStateWidget(type: EmptyStateType.events),
                    )
                  else
                    _buildEventsGrid(categorized['upcoming']!),

                  // Completed Events
                  if (categorized['completed']!.isNotEmpty) ...[
                    _buildSectionHeader(
                      'Completed Events',
                      AppColors.textSecondary,
                      null,
                      categorized['completed']!.length,
                    ),
                    _buildEventsGrid(
                      categorized['completed']!,
                      isCompleted: true,
                    ),
                  ],

                  // Cancelled Events
                  if (categorized['cancelled']!.isNotEmpty) ...[
                    _buildSectionHeader(
                      'Cancelled Events',
                      AppColors.error,
                      null,
                      categorized['cancelled']!.length,
                    ),
                    _buildEventsGrid(
                      categorized['cancelled']!,
                      isCompleted: true,
                    ),
                  ],

                  // Bottom padding
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.xl),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Map<String, List<ClubEvent>> _categorizeEvents(List<ClubEvent> events) {
    final sorted = List<ClubEvent>.from(events)
      ..sort((a, b) => b.eventStartTime.compareTo(a.eventStartTime));

    return {
      'ongoing': sorted.where((e) => e.isOngoing && !e.isCancelled).toList(),
      'upcoming': sorted.where((e) => e.isUpcoming && !e.isCancelled).toList(),
      'cancelled': sorted.where((e) => e.isCancelled).toList(),
      'completed': sorted
          .where((e) => e.isCompleted && !e.isCancelled)
          .toList(),
    };
  }

  Widget _buildSectionHeader(
    String title,
    Color color,
    String? badge,
    int count,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 60,
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.5), Colors.transparent],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Spacer(),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  badge,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '$count Events',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsGrid(
    List<ClubEvent> events, {
    bool isOngoing = false,
    bool isCompleted = false,
  }) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      sliver: AnimationLimiter(
        child: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.65,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => AnimationConfiguration.staggeredGrid(
              position: index,
              duration: const Duration(milliseconds: 600),
              columnCount: 2,
              child: SlideAnimation(
                verticalOffset: 50.0,
                curve: Curves.easeOutQuart,
                child: ScaleAnimation(
                  scale: 0.9,
                  curve: Curves.easeOutQuart,
                  child: FadeInAnimation(
                    curve: Curves.easeOutQuart,
                    child: EventCard(
                      event: events[index],
                      type: EventCardType.grid,
                    ),
                  ),
                ),
              ),
            ),
            childCount: events.length,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Failed to load events',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Please check your connection and try again.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: _refreshEvents,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
