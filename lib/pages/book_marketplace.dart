import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pulchowkx_app/models/book_listing.dart';
import 'package:pulchowkx_app/pages/book_details.dart';
import 'package:pulchowkx_app/pages/sell_book.dart';
import 'package:pulchowkx_app/pages/my_books.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/custom_app_bar.dart';

class BookMarketplacePage extends StatefulWidget {
  const BookMarketplacePage({super.key});

  @override
  State<BookMarketplacePage> createState() => _BookMarketplacePageState();
}

class _BookMarketplacePageState extends State<BookMarketplacePage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<BookListing> _listings = [];
  List<BookCategory> _categories = [];
  BookFilters _filters = BookFilters();
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;

  // Filter state
  BookCategory? _selectedCategory;
  BookCondition? _selectedCondition;
  String _sortBy = 'newest';
  RangeValues _priceRange = const RangeValues(0, 10000);
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadListings();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreListings();
    }
  }

  Future<void> _loadCategories() async {
    final categories = await _apiService.getBookCategories();
    if (mounted) {
      setState(() => _categories = categories);
    }
  }

  Future<void> _loadListings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.getBookListings(_filters);
      if (mounted) {
        setState(() {
          if (response != null) {
            _listings = response.listings;
            _hasMore = response.pagination.hasNextPage;
          } else {
            _errorMessage = 'Failed to load listings';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreListings() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    final newFilters = _filters.copyWith(page: _filters.page + 1);
    final response = await _apiService.getBookListings(newFilters);

    if (mounted) {
      setState(() {
        if (response != null) {
          _listings.addAll(response.listings);
          _filters = newFilters;
          _hasMore = response.pagination.hasNextPage;
        }
        _isLoadingMore = false;
      });
    }
  }

  void _applyFilters() {
    _filters = BookFilters(
      search: _searchController.text.isNotEmpty ? _searchController.text : null,
      categoryId: _selectedCategory?.id,
      condition: _selectedCondition?.value,
      minPrice: _priceRange.start > 0 ? _priceRange.start : null,
      maxPrice: _priceRange.end < 10000 ? _priceRange.end : null,
      sortBy: _sortBy,
      page: 1,
    );
    _loadListings();
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _selectedCategory = null;
      _selectedCondition = null;
      _sortBy = 'newest';
      _priceRange = const RangeValues(0, 10000);
      _showFilters = false;
    });
    _filters = BookFilters();
    _loadListings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(currentPage: AppPage.bookMarketplace),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SellBookPage()),
          ).then((_) => _loadListings());
        },
        icon: const Icon(Icons.add),
        label: const Text('Sell Book'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchAndFilters(),
            if (_showFilters) _buildFilterPanel(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Book Marketplace', style: AppTextStyles.h3),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Buy and sell textbooks with fellow students',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyBooksPage()),
              ).then((_) => _loadListings());
            },
            icon: const Icon(Icons.library_books_outlined),
            label: const Text('My Books'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by title, author, or ISBN...',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textMuted,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.textMuted,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _applyFilters();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                    ),
                    onSubmitted: (_) => _applyFilters(),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                decoration: BoxDecoration(
                  color: _showFilters
                      ? AppColors.primaryLight
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: _showFilters ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.tune,
                    color: _showFilters
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  onPressed: () => setState(() => _showFilters = !_showFilters),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Quick filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'Newest',
                  isSelected: _sortBy == 'newest',
                  onTap: () {
                    setState(() => _sortBy = 'newest');
                    _applyFilters();
                  },
                ),
                _FilterChip(
                  label: 'Price: Low',
                  isSelected: _sortBy == 'price_asc',
                  onTap: () {
                    setState(() => _sortBy = 'price_asc');
                    _applyFilters();
                  },
                ),
                _FilterChip(
                  label: 'Price: High',
                  isSelected: _sortBy == 'price_desc',
                  onTap: () {
                    setState(() => _sortBy = 'price_desc');
                    _applyFilters();
                  },
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(width: 1, height: 20, color: AppColors.border),
                const SizedBox(width: AppSpacing.sm),
                ...BookCondition.values.map(
                  (condition) => _FilterChip(
                    label: condition.label,
                    isSelected: _selectedCondition == condition,
                    onTap: () {
                      setState(() {
                        _selectedCondition = _selectedCondition == condition
                            ? null
                            : condition;
                      });
                      _applyFilters();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filters', style: AppTextStyles.labelLarge),
              TextButton(
                onPressed: _resetFilters,
                child: const Text('Reset All'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Category dropdown
          if (_categories.isNotEmpty) ...[
            Text('Category', style: AppTextStyles.labelMedium),
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<BookCategory?>(
                  value: _selectedCategory,
                  isExpanded: true,
                  hint: const Text('All Categories'),
                  items: [
                    const DropdownMenuItem<BookCategory?>(
                      value: null,
                      child: Text('All Categories'),
                    ),
                    ..._categories.map(
                      (cat) =>
                          DropdownMenuItem(value: cat, child: Text(cat.name)),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedCategory = value),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          // Price range
          Text(
            'Price Range: Rs. ${_priceRange.start.toInt()} - Rs. ${_priceRange.end.toInt()}',
            style: AppTextStyles.labelMedium,
          ),
          RangeSlider(
            values: _priceRange,
            min: 0,
            max: 10000,
            divisions: 100,
            labels: RangeLabels(
              'Rs. ${_priceRange.start.toInt()}',
              'Rs. ${_priceRange.end.toInt()}',
            ),
            onChanged: (values) => setState(() => _priceRange = values),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _applyFilters();
                setState(() => _showFilters = false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              ),
              child: const Text('Apply Filters'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(_errorMessage!, style: AppTextStyles.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: _loadListings,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_listings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.menu_book_outlined,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('No books found', style: AppTextStyles.h4),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Be the first to list a book for sale!',
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadListings,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: GridView.builder(
          controller: _scrollController,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.65,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
          ),
          itemCount: _listings.length + (_isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _listings.length) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            return _BookCard(
              listing: _listings[index],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        BookDetailsPage(bookId: _listings[index].id),
                  ),
                ).then((_) => _loadListings());
              },
            );
          },
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final BookListing listing;
  final VoidCallback onTap;

  const _BookCard({required this.listing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
              child: AspectRatio(
                aspectRatio: 1,
                child: listing.primaryImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: listing.primaryImageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppColors.backgroundSecondary,
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.backgroundSecondary,
                          child: const Icon(
                            Icons.menu_book_rounded,
                            size: 40,
                            color: AppColors.textMuted,
                          ),
                        ),
                      )
                    : Container(
                        color: AppColors.backgroundSecondary,
                        child: const Center(
                          child: Icon(
                            Icons.menu_book_rounded,
                            size: 40,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      style: AppTextStyles.labelMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      listing.author,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          listing.formattedPrice,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getConditionColor(
                              listing.condition,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: Text(
                            listing.condition.label,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: _getConditionColor(listing.condition),
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getConditionColor(BookCondition condition) {
    switch (condition) {
      case BookCondition.newBook:
        return AppColors.success;
      case BookCondition.likeNew:
        return const Color(0xFF22C55E);
      case BookCondition.good:
        return AppColors.accent;
      case BookCondition.fair:
        return Colors.orange;
      case BookCondition.poor:
        return AppColors.error;
    }
  }
}
