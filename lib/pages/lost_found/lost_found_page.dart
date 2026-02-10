import 'package:flutter/material.dart';
import 'package:pulchowkx_app/models/lost_found.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/lost_found_card.dart';
import 'package:pulchowkx_app/widgets/shimmer_loaders.dart';
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

  Future<void> _fetchItems() async {
    setState(() => _isLoading = true);

    String? type;
    if (_tabController.index == 1) type = 'lost';
    if (_tabController.index == 2) type = 'found';

    final items = await _apiService.getLostFoundItems(
      itemType: type,
      category: _selectedCategory,
      q: _searchQuery.isNotEmpty ? _searchQuery : null,
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
      appBar: AppBar(
        title: const Text('Lost & Found'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyLostFoundPage()),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Lost'),
                  Tab(text: 'Found'),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.surfaceDark
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.1),
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search items...',
                            prefixIcon: Icon(Icons.search_rounded, size: 20),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          onSubmitted: (val) {
                            setState(() => _searchQuery = val);
                            _fetchItems();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _buildCategoryFilter(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchItems,
        child: _isLoading
            ? ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.sm),
                itemCount: 5,
                itemBuilder: (context, index) => const ShimmerCard(),
              )
            : _items.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  return LostFoundCard(
                    item: _items[index],
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              LostFoundDetailsPage(itemId: _items[index].id),
                        ),
                      );
                      _fetchItems();
                    },
                  );
                },
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
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          hint: const Text('Category', style: TextStyle(fontSize: 12)),
          onChanged: (val) {
            setState(() => _selectedCategory = val);
            _fetchItems();
          },
          items: [
            const DropdownMenuItem(value: null, child: Text('All')),
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
