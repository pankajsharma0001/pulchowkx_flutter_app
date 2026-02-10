import 'package:flutter/material.dart';
import 'package:pulchowkx_app/models/lost_found.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/lost_found_card.dart';
import 'package:pulchowkx_app/pages/lost_found/lost_found_details_page.dart';

class MyLostFoundPage extends StatefulWidget {
  const MyLostFoundPage({super.key});

  @override
  State<MyLostFoundPage> createState() => _MyLostFoundPageState();
}

class _MyLostFoundPageState extends State<MyLostFoundPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  List<LostFoundItem> _myItems = [];
  List<LostFoundClaim> _myClaims = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchMyData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchMyData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _apiService.getMyLostFoundItems(),
      _apiService.getMyLostFoundClaims(),
    ]);

    if (mounted) {
      setState(() {
        _myItems = results[0] as List<LostFoundItem>;
        _myClaims = results[1] as List<LostFoundClaim>;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Lost & Found'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [
            Tab(text: 'My Reports'),
            Tab(text: 'My Claims'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildMyItemsList(), _buildMyClaimsList()],
            ),
    );
  }

  Widget _buildMyItemsList() {
    if (_myItems.isEmpty) {
      return _buildEmptyState('You haven\'t reported any items yet.');
    }

    return RefreshIndicator(
      onRefresh: _fetchMyData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: _myItems.length,
        itemBuilder: (context, index) {
          return LostFoundCard(
            item: _myItems[index],
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      LostFoundDetailsPage(itemId: _myItems[index].id),
                ),
              );
              _fetchMyData();
            },
          );
        },
      ),
    );
  }

  Widget _buildMyClaimsList() {
    if (_myClaims.isEmpty) {
      return _buildEmptyState('You haven\'t claimed any items yet.');
    }

    return RefreshIndicator(
      onRefresh: _fetchMyData,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _myClaims.length,
        itemBuilder: (context, index) {
          final claim = _myClaims[index];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(
                color: AppColors.textMuted.withValues(alpha: 0.1),
              ),
            ),
            child: ListTile(
              title: Text('Claim for Item #${claim.itemId}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    claim.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  _buildStatusChip(claim.status),
                ],
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        LostFoundDetailsPage(itemId: claim.itemId),
                  ),
                );
                _fetchMyData();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(LostFoundClaimStatus status) {
    Color color;
    switch (status) {
      case LostFoundClaimStatus.pending:
        color = AppColors.warning;
        break;
      case LostFoundClaimStatus.accepted:
        color = AppColors.success;
        break;
      case LostFoundClaimStatus.rejected:
        color = AppColors.error;
        break;
      case LostFoundClaimStatus.cancelled:
        color = AppColors.textMuted;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_rounded,
              size: 64,
              color: AppColors.textMuted.withValues(alpha: 0.2),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
