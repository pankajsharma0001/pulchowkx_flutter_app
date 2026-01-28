import 'package:flutter/material.dart';
import 'package:pulchowkx_app/models/club.dart';
import 'package:pulchowkx_app/models/event.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/services/favorites_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/club_card.dart';
import 'package:pulchowkx_app/widgets/empty_states.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Favorites'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.h4.copyWith(color: AppColors.textPrimary),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
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
      body: TabBarView(
        controller: _tabController,
        children: [_buildEventsList(), _buildClubsList()],
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

    if (_favoriteEvents == null || _favoriteEvents!.isEmpty) {
      return const EmptyStateWidget(
        type: EmptyStateType.events,
        title: 'No Favorite Events',
        message: 'Events you save will appear here',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.75, // Match events page grid ratio
      ),
      itemCount: _favoriteEvents!.length,
      itemBuilder: (context, index) {
        return EventCard(
          event: _favoriteEvents![index],
          type: EventCardType.grid,
        );
      },
    );
  }

  Widget _buildClubsList() {
    if (_isLoadingClubs) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: GridShimmer(itemShimmer: ClubCardShimmer()),
      );
    }

    if (_favoriteClubs == null || _favoriteClubs!.isEmpty) {
      return const EmptyStateWidget(
        type: EmptyStateType.clubs,
        title: 'No Favorite Clubs',
        message: 'Clubs you save will appear here',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.85,
      ),
      itemCount: _favoriteClubs!.length,
      itemBuilder: (context, index) {
        return ClubCard(club: _favoriteClubs![index]);
      },
    );
  }
}
