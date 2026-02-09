import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/models/club.dart';
import 'package:pulchowkx_app/models/event.dart';
import 'package:pulchowkx_app/models/book_listing.dart';
import 'package:pulchowkx_app/models/notice.dart';
import 'package:pulchowkx_app/pages/club_details.dart';
import 'package:pulchowkx_app/pages/event_details.dart';
import 'package:pulchowkx_app/pages/book_details.dart';
import 'package:pulchowkx_app/pages/notices.dart';
import 'package:pulchowkx_app/pages/main_layout.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();
  GlobalSearchResult? _searchResult;
  bool _isLoading = false;
  String _error = '';

  Future<void> _performSearch(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _searchResult = null;
        _error = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final result = await _apiService.searchEverything(
        query.trim(),
        limit: 10,
      );
      setState(() {
        _searchResult = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to perform search. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Theme colors for consistent look
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: FirebaseAuth.instance.currentUser != null
                ? 'Search clubs, events, books...'
                : 'Search campus locations...',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
          style: AppTextStyles.bodyLarge.copyWith(
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
          ),
          onChanged: _performSearch,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: () {
                _searchController.clear();
                _performSearch('');
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: isDark
                  ? AppColors.heroGradientDark
                  : AppColors.heroGradient,
            ),
          ),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                ? Center(
                    child: Text(
                      _error,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  )
                : _searchResult == null
                ? _buildInitialState()
                : _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_rounded,
            size: 64,
            color: AppColors.textMuted.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Search everything on campus',
            style: AppTextStyles.h4.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Try searching for "robotics", "dean", or "computer"',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final results = _searchResult!;
    if (results.total == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppColors.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No results found for "${_searchController.text}"',
              style: AppTextStyles.bodyLarge,
            ),
          ],
        ),
      );
    }

    final bool isLoggedIn = FirebaseAuth.instance.currentUser != null;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        if (results.places.isNotEmpty)
          _buildSection(
            'Places',
            results.places.map((e) => _buildPlaceItem(e)).toList(),
          ),
        if (isLoggedIn && results.clubs.isNotEmpty)
          _buildSection(
            'Clubs',
            results.clubs.map((e) => _buildClubItem(e)).toList(),
          ),
        if (isLoggedIn && results.events.isNotEmpty)
          _buildSection(
            'Events',
            results.events.map((e) => _buildEventItem(e)).toList(),
          ),
        if (isLoggedIn && results.books.isNotEmpty)
          _buildSection(
            'Books',
            results.books.map((e) => _buildBookItem(e)).toList(),
          ),
        if (isLoggedIn && results.notices.isNotEmpty)
          _buildSection(
            'Notices',
            results.notices.map((e) => _buildNoticeItem(e)).toList(),
          ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Text(
            title.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...items,
        const Divider(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildPlaceItem(SearchPlace place) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.infoLight.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.location_on_rounded,
          color: AppColors.info,
          size: 20,
        ),
      ),
      title: Text(
        place.name,
        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        place.description,
        style: AppTextStyles.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () {
        final mainLayout = MainLayout.of(context);
        // Pop the search page first so that returning to the Home tab shows HomePage
        Navigator.pop(context);

        if (mainLayout != null) {
          mainLayout.navigateToMapLocation(
            place.coordinates.lat,
            place.coordinates.lng,
            place.name,
          );
        }
      },
    );
  }

  Widget _buildClubItem(Club club) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
        backgroundImage: club.logoUrl != null
            ? CachedNetworkImageProvider(club.logoUrl!)
            : null,
        child: club.logoUrl == null
            ? Text(
                club.name[0],
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Text(
        club.name,
        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClubDetailsPage(clubId: club.id),
          ),
        );
      },
    );
  }

  Widget _buildEventItem(ClubEvent event) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          image: event.bannerUrl != null
              ? DecorationImage(
                  image: CachedNetworkImageProvider(event.bannerUrl!),
                  fit: BoxFit.cover,
                )
              : null,
          color: AppColors.accentLight.withValues(alpha: 0.2),
        ),
        child: event.bannerUrl == null
            ? const Icon(
                Icons.calendar_today_rounded,
                color: AppColors.accent,
                size: 20,
              )
            : null,
      ),
      title: Text(
        event.title,
        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: event.description != null
          ? Text(
              event.description!,
              style: AppTextStyles.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventDetailsPage(eventId: event.id),
          ),
        );
      },
    );
  }

  Widget _buildBookItem(BookListing book) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.successLight.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.book_rounded,
          color: AppColors.success,
          size: 20,
        ),
      ),
      title: Text(
        book.title,
        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(book.author, style: AppTextStyles.bodySmall),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookDetailsPage(bookId: book.id),
          ),
        );
      },
    );
  }

  Widget _buildNoticeItem(Notice notice) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.warningLight.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.notifications_rounded,
          color: AppColors.warning,
          size: 20,
        ),
      ),
      title: Text(
        notice.title,
        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${notice.section} / ${notice.subsection}',
        style: AppTextStyles.bodySmall,
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NoticesPage()),
        );
      },
    );
  }
}
