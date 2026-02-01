import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pulchowkx_app/models/book_listing.dart';
import 'package:pulchowkx_app/pages/book_details.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/shimmer_loaders.dart';

class BookRequestsPage extends StatefulWidget {
  const BookRequestsPage({super.key});

  @override
  State<BookRequestsPage> createState() => _BookRequestsPageState();
}

class _BookRequestsPageState extends State<BookRequestsPage>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  List<BookPurchaseRequest> _sentRequests = [];
  List<BookPurchaseRequest> _receivedRequests = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final sentFuture = _apiService.getMyPurchaseRequests();
      final listingsFuture = _apiService.getMyBookListings();

      final results = await Future.wait([sentFuture, listingsFuture]);

      final sent = results[0] as List<BookPurchaseRequest>;
      final myListings = results[1] as List<BookListing>;

      // Parallel fetch for all listing requests
      final requestsNested = await Future.wait(
        myListings.map((listing) => _apiService.getListingRequests(listing.id)),
      );

      final received = requestsNested.expand((r) => r).toList();

      if (mounted) {
        setState(() {
          _sentRequests = sent;
          _receivedRequests = received;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading requests: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _respondToRequest(
    BookPurchaseRequest request,
    bool accept,
  ) async {
    final result = await _apiService.respondToPurchaseRequest(
      request.id,
      accept,
    );
    if (result['success'] == true) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? 'Request accepted!' : 'Request rejected.'),
            backgroundColor: accept ? AppColors.success : AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _cancelRequest(BookPurchaseRequest request) async {
    final result = await _apiService.cancelPurchaseRequest(request.id);
    if (result['success'] == true) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request cancelled.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteRequest(BookPurchaseRequest request) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Request?'),
        content: const Text(
          'Are you sure you want to remove this request from your history?',
        ),
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
      final result = await _apiService.deletePurchaseRequest(request.id);
      if (result['success'] == true) {
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request deleted.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Sent'),
              Tab(text: 'Received'),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: 3,
                  itemBuilder: (context, index) => const RequestCardShimmer(),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [_buildSentList(), _buildReceivedList()],
                ),
        ),
      ],
    );
  }

  Widget _buildSentList() {
    if (_sentRequests.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: _buildEmptyState(
              'You haven\'t sent any requests yet.',
              Icons.outbox_outlined,
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _sentRequests.length,
        itemBuilder: (context, index) {
          final request = _sentRequests[index];
          return _RequestCard(
            request: request,
            isSent: true,
            onCancel: () => _cancelRequest(request),
            onRemove: () => _deleteRequest(request),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      BookDetailsPage(bookId: request.listingId),
                ),
              ).then((_) => _loadData());
            },
          );
        },
      ),
    );
  }

  Widget _buildReceivedList() {
    if (_receivedRequests.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: _buildEmptyState(
              'No requests received for your books.',
              Icons.inbox_outlined,
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _receivedRequests.length,
        itemBuilder: (context, index) {
          final request = _receivedRequests[index];
          return _RequestCard(
            request: request,
            isSent: false,
            onAccept: () => _respondToRequest(request, true),
            onReject: () => _respondToRequest(request, false),
            onRemove: () => _deleteRequest(request),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      BookDetailsPage(bookId: request.listingId),
                ),
              ).then((_) => _loadData());
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
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
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final BookPurchaseRequest request;
  final bool isSent;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _RequestCard({
    required this.request,
    required this.isSent,
    this.onAccept,
    this.onReject,
    this.onCancel,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(request.status);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: request.listing?.primaryImageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: request.listing!.primaryImageUrl!,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.backgroundSecondaryDark
                                  : AppColors.backgroundSecondary,
                            ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.listing?.title ?? 'Unknown Book',
                          style: AppTextStyles.labelMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          isSent
                              ? 'Seller: ${request.listing?.seller?.name ?? "..."}'
                              : 'Buyer: ${request.buyer?.name ?? "..."}',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: AppColors.error,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Delete Request',
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      request.status.label,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (request.message != null && request.message!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.backgroundSecondaryDark
                        : AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    request.message!,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
              if (request.status == RequestStatus.pending) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isSent)
                      TextButton(
                        onPressed: onCancel,
                        child: const Text('Cancel Request'),
                      )
                    else ...[
                      OutlinedButton(
                        onPressed: onReject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                        child: const Text('Reject'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      ElevatedButton(
                        onPressed: onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Accept'),
                      ),
                    ],
                  ],
                ),
              ] else if (!isSent &&
                  request.status == RequestStatus.accepted) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Contact information shared with buyer.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.success,
                  ),
                ),
              ] else if (isSent &&
                  request.status == RequestStatus.accepted) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Seller contact shared! Tap for details.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return Colors.orange;
      case RequestStatus.accepted:
        return AppColors.success;
      case RequestStatus.rejected:
        return AppColors.error;
      case RequestStatus.cancelled:
        return AppColors.textMuted;
    }
  }
}
