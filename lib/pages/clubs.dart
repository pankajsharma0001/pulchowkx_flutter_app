import 'package:flutter/material.dart';
import 'package:pulchowkx_app/services/haptic_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:pulchowkx_app/models/club.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/custom_app_bar.dart'
    show CustomAppBar, AppPage;
import 'package:pulchowkx_app/widgets/shimmer_loaders.dart';
import 'package:pulchowkx_app/widgets/empty_states.dart';
import 'package:pulchowkx_app/widgets/club_card.dart';
import 'package:pulchowkx_app/widgets/offline_banner.dart';

class ClubsPage extends StatefulWidget {
  const ClubsPage({super.key});

  @override
  State<ClubsPage> createState() => _ClubsPageState();
}

class _ClubsPageState extends State<ClubsPage> {
  final ApiService _apiService = ApiService();
  late Future<List<Club>> _clubsFuture;

  @override
  void initState() {
    super.initState();
    _clubsFuture = _apiService.getClubs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(currentPage: AppPage.clubs),
      body: Container(
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.light
              ? AppColors.heroGradient
              : AppColors.heroGradientDark,
        ),
        child: RefreshIndicator(
          onRefresh: () async {
            haptics.mediumImpact();
            await _refreshClubs();
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
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          boxShadow: AppShadows.colored(AppColors.primary),
                        ),
                        child: Hero(
                          tag: 'hero-clubs',
                          child: const Icon(
                            Icons.groups_rounded,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Campus Clubs',
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Explore the vibrant clubs at Pulchowk Campus',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              // Offline Banner
              const SliverOfflineBanner(),

              // Clubs Grid
              FutureBuilder<List<Club>>(
                future: _clubsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverPadding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      sliver: SliverToBoxAdapter(
                        child: GridShimmer(
                          itemShimmer: ClubCardShimmer(),
                          childAspectRatio: 0.85,
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return SliverFillRemaining(
                      child: _buildErrorState(snapshot.error.toString()),
                    );
                  }

                  final clubs = snapshot.data ?? [];

                  // Only check on initial load/rebuild
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    final connectivityResult = await Connectivity()
                        .checkConnectivity();
                    if (connectivityResult.first == ConnectivityResult.none &&
                        clubs.isNotEmpty) {
                      if (mounted) {
                        // Optional: Do something if cached data loaded
                      }
                    }
                  });

                  if (clubs.isEmpty) {
                    return const SliverFillRemaining(
                      child: EmptyStateWidget(type: EmptyStateType.clubs),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    sliver: AnimationLimiter(
                      child: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: AppSpacing.md,
                              crossAxisSpacing: AppSpacing.md,
                              childAspectRatio: 0.75,
                            ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              AnimationConfiguration.staggeredGrid(
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
                                      child: ClubCard(club: clubs[index]),
                                    ),
                                  ),
                                ),
                              ),
                          childCount: clubs.length,
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
            ],
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
            boxShadow: Theme.of(context).brightness == Brightness.light
                ? AppShadows.md
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 32,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Something went wrong',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Failed to load clubs. Please check your connection.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: _refreshClubs,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refreshClubs() async {
    await _apiService.invalidateClubsCache();
    setState(() {
      _clubsFuture = _apiService.getClubs();
    });
    await _clubsFuture;
  }
}
