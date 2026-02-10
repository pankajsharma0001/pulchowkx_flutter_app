import 'package:flutter/material.dart';
import 'package:pulchowkx_app/models/lost_found.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/lost_found_card.dart';
import 'package:pulchowkx_app/widgets/shimmer_loaders.dart';
import 'package:pulchowkx_app/widgets/custom_app_bar.dart';
import 'package:pulchowkx_app/pages/lost_found/lost_found_details_page.dart';
import 'package:pulchowkx_app/pages/lost_found/report_lost_found_page.dart';
import 'package:pulchowkx_app/pages/lost_found/my_lost_found_page.dart';

class LostFoundPage extends StatefulWidget {
  const LostFoundPage({super.key});

  @override
  State<LostFoundPage> createState() => _LostFoundPageState();
}

class _LostFoundPageState extends State<LostFoundPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<LostFoundItem> _items = [];
  bool _isLoading = true;
  String? _selectedCategory;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _fetchItems();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      _fetchItems();
    }
  }

  Future<void> _fetchItems({bool forceRefresh = false}) async {
    // Only show loading shimmer if we don't have items to show
    if (_items.isEmpty) {
      setState(() => _isLoading = true);
    }

    String? type;
    if (_tabController.index == 1) type = 'lost';
    if (_tabController.index == 2) type = 'found';

    final items = await _apiService.getLostFoundItems(
      itemType: type,
      category: _selectedCategory,
      q: _searchQuery.isNotEmpty ? _searchQuery : null,
      forceRefresh: forceRefresh,
    );

    if (mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomAppBar(currentPage: AppPage.lostAndFound),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.heroGradientDark
              : AppColors.heroGradient,
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => _fetchItems(forceRefresh: true),
            color: AppColors.primary,
            child: CustomScrollView(
              slivers: [
                // Header & Search
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xl,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
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
                            Icons.find_in_page_rounded,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Lost & Found',
                              style: AppTextStyles.h3.copyWith(
                                color: isDark
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Report lost items or find what you might have missing',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // My Items Link
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MyLostFoundPage(),
                            ),
                          ),
                          icon: const Icon(
                            Icons.person_outline_rounded,
                            size: 18,
                          ),
                          label: const Text('My Reported Items'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // Search Bar
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.surfaceDark
                                : Colors.white,
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                            boxShadow: AppShadows.sm,
                            border: Border.all(
                              color: isDark
                                  ? AppColors.borderDark
                                  : AppColors.border,
                            ),
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search items...',
                              hintStyle: AppTextStyles.bodyMedium.copyWith(
                                color: isDark
                                    ? AppColors.textMutedDark
                                    : AppColors.textMuted,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: isDark
                                    ? AppColors.textMutedDark
                                    : AppColors.textMuted,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (val) {
                              setState(() => _searchQuery = val);
                              _fetchItems();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Filters & Tabs
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.surfaceDark
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.borderDark
                                  : AppColors.border,
                            ),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            indicatorPadding: const EdgeInsets.all(4),
                            dividerColor: Colors.transparent,
                            labelColor: Colors.white,
                            unselectedLabelColor: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondary,
                            labelStyle: AppTextStyles.labelSmall,
                            unselectedLabelStyle: AppTextStyles.labelSmall,
                            tabs: const [
                              Tab(text: 'All'),
                              Tab(text: 'Lost'),
                              Tab(text: 'Found'),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _buildCategoryFilter(),
                      ],
                    ),
                  ),
                ),

                // Items List
                if (_isLoading)
                  SliverPadding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => const ShimmerCard(),
                        childCount: 5,
                      ),
                    ),
                  )
                else if (_items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        return LostFoundCard(
                          item: _items[index],
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LostFoundDetailsPage(
                                  itemId: _items[index].id,
                                ),
                              ),
                            );
                            _fetchItems();
                          },
                        );
                      }, childCount: _items.length),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ReportLostFoundPage(),
            ),
          );
          _fetchItems();
        },
        label: const Text('Report'),
        icon: const Icon(Icons.add_rounded),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          hint: const Text('Category', style: TextStyle(fontSize: 12)),
          onChanged: (val) {
            setState(() => _selectedCategory = val);
            _fetchItems();
          },
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('Filter by Category'),
            ),
            ...LostFoundCategory.values.map((cat) {
              return DropdownMenuItem(
                value: cat.name,
                child: Text(cat.name[0].toUpperCase() + cat.name.substring(1)),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: AppColors.textMuted.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No items found',
            style: AppTextStyles.h4.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Try changing your filters or browse all items',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ShimmerLoader(child: Container(color: Colors.white)),
    );
  }
}
