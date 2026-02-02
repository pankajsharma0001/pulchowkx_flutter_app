import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pulchowkx_app/models/book_listing.dart';
import 'package:pulchowkx_app/pages/book_details.dart';
import 'package:pulchowkx_app/pages/sell_book.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/pages/marketplace/book_requests_page.dart';
import 'package:pulchowkx_app/widgets/shimmer_loaders.dart';

class MyBooksPage extends StatefulWidget {
  const MyBooksPage({super.key});

  @override
  State<MyBooksPage> createState() => _MyBooksPageState();
}

class _MyBooksPageState extends State<MyBooksPage>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  List<BookListing> _myListings = [];
  List<SavedBook> _savedBooks = [];
  bool _isLoading = false;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (!_hasLoaded) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final listings = await _apiService.getMyBookListings();
    final saved = await _apiService.getSavedBooks();

    if (mounted) {
      setState(() {
        _myListings = listings;
        _savedBooks = saved;
        _isLoading = false;
        _hasLoaded = true;
      });
    }
  }

  Future<void> _markAsSold(BookListing listing) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Sold?'),
        content: Text('Mark "${listing.title}" as sold?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Mark Sold'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await _apiService.markBookAsSold(listing.id);
      if (result['success'] == true) {
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Marked as sold!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteListing(BookListing listing) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Listing?'),
        content: Text('Are you sure you want to delete "${listing.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await _apiService.deleteBookListing(listing.id);
      if (result['success'] == true) {
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Listing deleted'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    }
  }

  Future<void> _unsaveBook(SavedBook saved) async {
    final result = await _apiService.unsaveBook(saved.listingId);
    if (result['success'] == true) {
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // backgroundColor handled by theme
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).iconTheme.color,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('My Books', style: AppTextStyles.h4),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(text: 'My Listings (${_myListings.length})'),
            Tab(text: 'Requests'),
            Tab(text: 'Saved (${_savedBooks.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: 5,
              itemBuilder: (context, index) => const BookListTileShimmer(),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMyListings(),
                const BookRequestsPage(),
                _buildSavedBooks(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SellBookPage()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Sell Book'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildMyListings() {
    if (_myListings.isEmpty) {
      return _buildEmptyState(
        'You haven\'t listed any books yet.',
        Icons.library_books_outlined,
        'Start Selling',
        () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SellBookPage()),
          );
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _myListings.length,
        itemBuilder: (context, index) {
          return _MyListingCard(
            listing: _myListings[index],
            onDelete: () => _deleteListing(_myListings[index]),
            onMarkSold: () => _markAsSold(_myListings[index]),
            onEdit: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      SellBookPage(existingBook: _myListings[index]),
                ),
              );
            },
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookDetailsPage(
                    bookId: _myListings[index].id,
                    initialBook: _myListings[index],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSavedBooks() {
    if (_savedBooks.isEmpty) {
      return _buildEmptyState(
        'No saved books yet.',
        Icons.bookmark_border,
        'Browse Marketplace',
        () => Navigator.pop(context),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _savedBooks.length,
        itemBuilder: (context, index) {
          return _SavedBookCard(
            savedBook: _savedBooks[index],
            onUnsave: () => _unsaveBook(_savedBooks[index]),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookDetailsPage(
                    bookId: _savedBooks[index].listingId,
                    initialBook: _savedBooks[index].listing,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(
    String message,
    IconData icon,
    String buttonText,
    VoidCallback onAction,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).disabledColor),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).disabledColor,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (buttonText.isNotEmpty)
            ElevatedButton(onPressed: onAction, child: Text(buttonText)),
        ],
      ),
    );
  }
}

class _MyListingCard extends StatelessWidget {
  final BookListing listing;
  final VoidCallback onDelete;
  final VoidCallback onMarkSold;
  final VoidCallback onEdit;
  final VoidCallback onTap;

  const _MyListingCard({
    required this.listing,
    required this.onDelete,
    required this.onMarkSold,
    required this.onEdit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: listing.primaryImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: listing.primaryImageUrl!,
                          width: 80,
                          height: 100,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 80,
                          height: 100,
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.menu_book,
                            color: Theme.of(context).disabledColor,
                          ),
                        ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              listing.title,
                              style: AppTextStyles.labelLarge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _StatusBadge(status: listing.status),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        listing.formattedPrice,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Icon(
                            Icons.visibility,
                            size: 14,
                            color: Theme.of(context).disabledColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${listing.viewCount}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Theme.of(context).disabledColor,
                            ),
                          ),
                          const Spacer(),
                          if (listing.isAvailable)
                            IconButton(
                              icon: const Icon(
                                Icons.edit_note_rounded,
                                color: AppColors.primary,
                              ),
                              onPressed: onEdit,
                              tooltip: 'Edit Listing',
                            ),
                          if (listing.isAvailable)
                            IconButton(
                              icon: const Icon(
                                Icons.check_circle_outline,
                                color: AppColors.success,
                              ),
                              onPressed: onMarkSold,
                              tooltip: 'Mark as Sold',
                            ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.error,
                            ),
                            onPressed: onDelete,
                            tooltip: 'Delete',
                          ),
                        ],
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

class _SavedBookCard extends StatelessWidget {
  final SavedBook savedBook;
  final VoidCallback onUnsave;
  final VoidCallback onTap;

  const _SavedBookCard({
    required this.savedBook,
    required this.onUnsave,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // SavedBook might not have full listing details depending on backend response,
    // assuming it does or has a nested listing object.
    // Based on API model, SavedBook usually wraps a listing.
    // If SavedBook structure is: { id, listingId, listing: BookListing }
    // We'll assume the API returns the listing details populated.

    // Fallback if listing details are missing (though they shouldn't be for this view)
    final listing = savedBook.listing;
    if (listing == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: listing.primaryImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: listing.primaryImageUrl!,
                          width: 80,
                          height: 100,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 80,
                          height: 100,
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.menu_book,
                            color: Theme.of(context).disabledColor,
                          ),
                        ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listing.title,
                        style: AppTextStyles.labelLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        listing.author,
                        style: AppTextStyles.bodySmall.copyWith(
                          color:
                              Theme.of(context).textTheme.bodyMedium?.color ??
                              AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        listing.formattedPrice,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.bookmark, color: AppColors.primary),
                  onPressed: onUnsave,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final BookStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case BookStatus.available:
        color = AppColors.success;
        break;
      case BookStatus.sold:
        color = AppColors.textMuted;
        break;
      case BookStatus.pending:
        color = Colors.orange;
        break;
      default:
        color = AppColors.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.labelSmall.copyWith(color: color),
      ),
    );
  }
}
