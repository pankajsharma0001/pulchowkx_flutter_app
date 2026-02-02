import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pulchowkx_app/models/club.dart';
import 'package:pulchowkx_app/models/event.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/services/favorites_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/club_card.dart';

import 'package:pulchowkx_app/widgets/event_card.dart';
import 'package:pulchowkx_app/widgets/shimmer_loaders.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  List<ClubEvent>? _favoriteEvents;
  List<Club>? _favoriteClubs;
  bool _isLoadingEvents = true;
  bool _isLoadingClubs = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllFavorites();

    // Listen to changes in favorites service
    favoritesService.addListener(_onFavoritesChanged);
  }

  @override
  void dispose() {
    favoritesService.removeListener(_onFavoritesChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onFavoritesChanged() {
    if (mounted) {
      _loadAllFavorites();
    }
  }

  Future<void> _loadAllFavorites() async {
    await Future.wait([_loadFavoriteEvents(), _loadFavoriteClubs()]);
  }

  Future<void> _loadFavoriteEvents() async {
    setState(() => _isLoadingEvents = true);
    try {
      final eventIds = favoritesService.favoriteEventIds.toList();
      if (eventIds.isEmpty) {
        setState(() {
          _favoriteEvents = [];
          _isLoadingEvents = false;
        });
        return;
      }

      // Fetch all events and filter by favorites
      // Note: Ideally we'd have a bulk fetch by IDs, but for now we fetch all
      // and filter, which is okay for MVP given we have caching.
      final allEvents = await _apiService.getAllEvents();
      final filtered = allEvents
          .where((e) => eventIds.contains(e.id.toString()))
          .toList();

      if (mounted) {
        setState(() {
          _favoriteEvents = filtered;
          _isLoadingEvents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingEvents = false);
      }
    }
  }

  Future<void> _loadFavoriteClubs() async {
    setState(() => _isLoadingClubs = true);
    try {
      final clubIds = favoritesService.favoriteClubIds.toList();
      if (clubIds.isEmpty) {
        setState(() {
          _favoriteClubs = [];
          _isLoadingClubs = false;
        });
        return;
      }

      final allClubs = await _apiService.getClubs();
      final filtered = allClubs
          .where((c) => clubIds.contains(c.id.toString()))
          .toList();

      if (mounted) {
        setState(() {
          _favoriteClubs = filtered;
          _isLoadingClubs = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingClubs = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Favorites'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.h4.copyWith(
          color: Theme.of(context).textTheme.titleLarge?.color,
        ),
        iconTheme: IconThemeData(color: Theme.of(context).iconTheme.color),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: AppTextStyles.labelLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: AppTextStyles.labelLarge,
          tabs: const [
            Tab(text: 'Events'),
            Tab(text: 'Clubs'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildEventsList(), _buildClubsList()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerTheme.color!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.redAccent, Colors.pinkAccent],
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.colored(Colors.redAccent),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              size: 24,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Favorites',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('Access your saved items', style: AppTextStyles.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String message,
    required String assetPath,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(assetPath, height: 180, fit: BoxFit.contain),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList() {
    if (_isLoadingEvents) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: GridShimmer(itemShimmer: EventCardShimmer()),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        await _loadFavoriteEvents();
      },
      color: AppColors.primary,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          if (_favoriteEvents == null || _favoriteEvents!.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(
                title: 'No Favorite Events',
                message: 'Events you save will appear here',
                assetPath: 'assets/images/empty_events.png',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 400,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: 0.75, // Match events page grid ratio
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  return EventCard(
                    event: _favoriteEvents![index],
                    type: EventCardType.grid,
                  );
                }, childCount: _favoriteEvents!.length),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClubsList() {
    if (_isLoadingClubs) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: GridShimmer(itemShimmer: ClubCardShimmer()),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        await _loadFavoriteClubs();
      },
      color: AppColors.primary,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          if (_favoriteClubs == null || _favoriteClubs!.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(
                title: 'No Favorite Clubs',
                message: 'Clubs you save will appear here',
                assetPath: 'assets/images/empty_clubs.png',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 400,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  return ClubCard(club: _favoriteClubs![index]);
                }, childCount: _favoriteClubs!.length),
              ),
            ),
        ],
      ),
    );
  }
}
