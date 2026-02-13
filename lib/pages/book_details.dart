import 'package:flutter/material.dart';
import 'package:pulchowkx_app/services/haptic_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pulchowkx_app/models/book_listing.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/shimmer_loaders.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pulchowkx_app/pages/marketplace/chat_room.dart';
import 'package:pulchowkx_app/models/chat.dart';
import 'package:pulchowkx_app/models/trust.dart';

class BookDetailsPage extends StatefulWidget {
  final int bookId;
  final BookListing? initialBook;

  const BookDetailsPage({super.key, required this.bookId, this.initialBook});

  @override
  State<BookDetailsPage> createState() => _BookDetailsPageState();
}

class _BookDetailsPageState extends State<BookDetailsPage> {
  final ApiService _apiService = ApiService();
  BookListing? _book;
  BookPurchaseRequest? _myRequest;
  SellerReputation? _sellerReputation;
  bool _isLoading = true;
  bool _isRequesting = false;
  String? _errorMessage;
  int _currentImageIndex = 0;
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialBook != null) {
      // Use initial data immediately for UI
      _book = widget.initialBook;
      _isLoading = false;
      // Always fetch full book details to get correct isOwner status (without showing loading)
      _loadBook(showLoading: false);
    } else {
      _loadBook();
    }
  }

  Future<void> _loadBook({bool showLoading = true}) async {
    // Only show loading if we don't have any data yet
    if (showLoading && _book == null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final book = await _apiService.getBookListingById(widget.bookId);
      BookPurchaseRequest? myRequest;

      if (book != null && !book.isOwner) {
        myRequest = await _apiService.getPurchaseRequestStatus(widget.bookId);
      }

      if (mounted) {
        setState(() {
          _book = book;
          _myRequest = myRequest;
          _isLoading = false;
          if (book == null) _errorMessage = 'Book not found';
        });

        // Fetch seller reputation if book found
        if (book != null) {
          _apiService.getSellerReputation(book.sellerId).then((reputation) {
            if (mounted) {
              setState(() => _sellerReputation = reputation);
            }
          });
        }
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

  Future<void> _toggleSave() async {
    if (_book == null) return;

    final wasSaved = _book!.isSaved;

    // Optimistic Update
    setState(() {
      _book = _book!.copyWith(isSaved: !wasSaved);
    });
    haptics.lightImpact();

    try {
      final result = wasSaved
          ? await _apiService.unsaveBook(_book!.id)
          : await _apiService.saveBook(_book!.id);

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                wasSaved ? 'Removed from saved' : 'Saved to your list',
              ),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        // Rollback on failure
        if (mounted) {
          setState(() {
            _book = _book!.copyWith(isSaved: wasSaved);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Action failed'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      // Rollback on error
      if (mounted) {
        setState(() {
          _book = _book!.copyWith(isSaved: wasSaved);
        });
      }
    }
  }

  Future<void> _contactSeller() async {
    if (_book == null) return;

    if (_myRequest != null) {
      if (_myRequest!.status == RequestStatus.accepted) {
        // Show choice dialog
        _showContactOptions();
      } else {
        // Pending or Rejected, show status
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request is ${_myRequest!.status.label}'),
            backgroundColor: _myRequest!.status == RequestStatus.rejected
                ? AppColors.error
                : AppColors.primary,
          ),
        );
      }
      return;
    }

    final message = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request to Buy'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Send a message to the seller:'),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText:
                    'e.g., I am interested in this book, when can we meet?',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _messageController.text),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );

    if (message != null) {
      setState(() => _isRequesting = true);
      final result = await _apiService.createPurchaseRequest(
        _book!.id,
        message,
      );
      if (mounted) {
        setState(() => _isRequesting = false);
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request sent successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          _loadBook(); // Reload to get request status
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to send request'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _openChat() async {
    if (_book == null) return;

    setState(() => _isRequesting = true);

    // Issue 5: Fill message box instead of sending automatically.
    // Check if conversation exists.
    final conversations = await _apiService.getConversations();
    MarketplaceConversation? existingConvo;
    try {
      existingConvo = conversations.firstWhere((c) => c.listingId == _book!.id);
    } catch (_) {
      existingConvo = null;
    }

    if (mounted) {
      setState(() => _isRequesting = false);
      if (existingConvo != null) {
        // Just navigate to existing chat
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatRoomPage(conversation: existingConvo!),
          ),
        );
      } else {
        // Navigate to new chat with pre-filled message
        final userId = await _apiService.getDatabaseUserId();
        if (!mounted) return;
        final dummyConvo = MarketplaceConversation(
          id: 0, // 0 indicates a new conversation
          listingId: _book!.id,
          buyerId: userId ?? '',
          sellerId: _book!.sellerId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          listing: _book,
          seller: _book!.seller,
        );

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatRoomPage(
              conversation: dummyConvo,
              initialMessage:
                  "Hi, I'm interested in this book: ${_book!.title}",
            ),
          ),
        );
      }
    }
  }

  Future<void> _showContactOptions() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Contact Seller', style: AppTextStyles.h4),
              const SizedBox(height: AppSpacing.lg),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.chat_outlined,
                    color: AppColors.primary,
                  ),
                ),
                title: const Text('In-app Chat'),
                subtitle: const Text('Chat instantly with the seller'),
                onTap: () {
                  Navigator.pop(context);
                  _openChat();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.email_outlined,
                    color: AppColors.accent,
                  ),
                ),
                title: const Text('Email Seller'),
                subtitle: Text(_book!.seller?.email ?? 'Send an email'),
                onTap: () async {
                  Navigator.pop(context);
                  final email = _book!.seller?.email;
                  if (email != null) {
                    final emailUri = Uri.parse(
                      'mailto:$email?subject=Interested in: ${_book!.title}',
                    );
                    if (await canLaunchUrl(emailUri)) {
                      await launchUrl(emailUri);
                    }
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).iconTheme.color,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Book Details', style: AppTextStyles.h4),
        actions: [
          if (_book != null && !_book!.isOwner) ...[
            if (_myRequest?.status == RequestStatus.accepted)
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                onPressed: _openChat,
              ),
            IconButton(
              icon: Icon(
                _book!.isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: _book!.isSaved
                    ? AppColors.primary
                    : Theme.of(context).iconTheme.color,
              ),
              onPressed: _toggleSave,
            ),
          ],
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar:
          _book != null && !_book!.isOwner && _book!.isAvailable
          ? _buildContactBar()
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const DetailsPageShimmer();
    }

    if (_errorMessage != null || _book == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              _errorMessage ?? 'Book not found',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(onPressed: _loadBook, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        haptics.mediumImpact();
        await _loadBook();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageGallery(),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConditionBadge(),
                  const SizedBox(height: AppSpacing.sm),
                  Text(_book!.title, style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'by ${_book!.author}',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color:
                          Theme.of(context).textTheme.bodyMedium?.color ??
                          AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _book!.formattedPrice,
                    style: AppTextStyles.h2.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _buildMetadataGrid(),
                  if (_book!.description != null &&
                      _book!.description!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    _buildDescription(),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  _buildSellerTrustProfile(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionBadge() {
    final style = _getConditionStyle(_book!.condition);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.bgColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: style.borderColor),
      ),
      child: Text(
        _book!.condition.label,
        style: AppTextStyles.labelSmall.copyWith(
          color: style.textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  _ConditionStyle _getConditionStyle(BookCondition condition) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (condition) {
      case BookCondition.newBook:
        return _ConditionStyle(
          bgColor: isDark
              ? const Color(0xFF065F46).withValues(alpha: 0.3)
              : const Color(0xFFD1FAE5),
          textColor: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
          borderColor: isDark
              ? const Color(0xFF059669)
              : const Color(0xFFA7F3D0),
        );
      case BookCondition.likeNew:
        return _ConditionStyle(
          bgColor: isDark
              ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
              : const Color(0xFFDBEAFE),
          textColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
          borderColor: isDark
              ? const Color(0xFF2563EB)
              : const Color(0xFFBFDBFE),
        );
      case BookCondition.good:
      case BookCondition.fair:
        return _ConditionStyle(
          bgColor: isDark
              ? const Color(0xFF78350F).withValues(alpha: 0.3)
              : const Color(0xFFFEF3C7),
          textColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
          borderColor: isDark
              ? const Color(0xFFD97706)
              : const Color(0xFFFDE68A),
        );
      case BookCondition.poor:
        return _ConditionStyle(
          bgColor: isDark
              ? const Color(0xFF7F1D1D).withValues(alpha: 0.3)
              : const Color(0xFFFFE4E6),
          textColor: isDark ? const Color(0xFFFB7185) : const Color(0xFFB91C1C),
          borderColor: isDark
              ? const Color(0xFFE11D48)
              : const Color(0xFFFECDD3),
        );
    }
  }

  Widget _buildImageGallery() {
    final images = _book!.images ?? [];
    if (images.isEmpty) {
      return Container(
        height: 300,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.menu_book_rounded,
            size: 80,
            color: Theme.of(context).disabledColor,
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 300,
          child: PageView.builder(
            itemCount: images.length,
            onPageChanged: (index) =>
                setState(() => _currentImageIndex = index),
            itemBuilder: (context, index) {
              final imageWidget = CachedNetworkImage(
                imageUrl: images[index].imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    const BoxShimmer(height: double.infinity, borderRadius: 0),
                errorWidget: (context, url, error) => Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.error, color: AppColors.error),
                ),
              );

              if (index == 0) {
                return Hero(tag: 'book_image_${_book!.id}', child: imageWidget);
              }
              return imageWidget;
            },
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              images.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index == _currentImageIndex
                      ? AppColors.primary
                      : Theme.of(context).disabledColor,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetadataGrid() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildMetadataCell('Edition', _book!.edition ?? 'N/A'),
              _buildMetadataDivider(),
              _buildMetadataCell('Publisher', _book!.publisher ?? 'N/A'),
            ],
          ),
          _buildMetadataHorizontalDivider(),
          Row(
            children: [
              _buildMetadataCell(
                'Year',
                _book!.publicationYear?.toString() ?? 'N/A',
              ),
              _buildMetadataDivider(),
              _buildMetadataCell('Course', _book!.courseCode ?? 'N/A'),
            ],
          ),
          _buildMetadataHorizontalDivider(),
          Row(
            children: [
              _buildMetadataCell('Category', _book!.category?.name ?? 'N/A'),
              _buildMetadataDivider(),
              _buildMetadataCell('ISBN', _book!.isbn ?? 'N/A'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataCell(String label, String value) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: AppTextStyles.labelSmall.copyWith(
                color: Theme.of(context).disabledColor,
                fontSize: 9,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Theme.of(context).dividerColor,
    );
  }

  Widget _buildMetadataHorizontalDivider() {
    return Divider(height: 1, color: Theme.of(context).dividerColor);
  }

  Widget _buildSellerTrustProfile() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E293B), // slate-800
                  const Color(0xFF164E63), // cyan-900
                  const Color(0xFF1E3A8A), // blue-900
                ]
              : [
                  const Color(0xFFF8FAFC), // slate-50
                  const Color(0xFFECFEFF), // cyan-50
                  const Color(0xFFEFF6FF), // blue-50
                ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: isDark
              ? const Color(0xFF0891B2).withValues(alpha: 0.3)
              : const Color(0xFFCFFAFE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Seller Trust Profile',
                style: AppTextStyles.labelLarge.copyWith(
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF475569),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_sellerReputation != null &&
                  _sellerReputation!.totalRatings >= 5)
                _buildVerifiedBadge(isDark),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildSellerHeader(isDark),
          const SizedBox(height: AppSpacing.lg),
          _buildTrustStatsGrid(isDark),
          if (!_book!.isOwner) ...[
            const SizedBox(height: AppSpacing.lg),
            _buildSafetyActions(isDark),
          ],
          const SizedBox(height: AppSpacing.md),
          Divider(color: isDark ? Colors.white24 : Colors.black12),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 14,
                color: isDark
                    ? Colors.white54
                    : Theme.of(context).disabledColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Posted ${_formatDate(_book!.createdAt)}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDark
                      ? Colors.white54
                      : Theme.of(context).disabledColor,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Icon(
                Icons.visibility,
                size: 14,
                color: isDark
                    ? Colors.white54
                    : Theme.of(context).disabledColor,
              ),
              const SizedBox(width: 6),
              Text(
                '${_book!.viewCount} views',
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDark
                      ? Colors.white54
                      : Theme.of(context).disabledColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedBadge(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF065F46).withValues(alpha: 0.5)
            : const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: isDark ? const Color(0xFF10B981) : const Color(0xFFA7F3D0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_rounded,
            size: 14,
            color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
          ),
          const SizedBox(width: 4),
          Text(
            'Verified',
            style: AppTextStyles.labelSmall.copyWith(
              color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerHeader(bool isDark) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: isDark
              ? const Color(0xFF1E40AF)
              : const Color(0xFFDBEAFE),
          backgroundImage: _book!.seller?.image != null
              ? CachedNetworkImageProvider(_book!.seller!.image!)
              : null,
          child: _book!.seller?.image == null
              ? Text(
                  (_book!.seller?.name ?? 'S')[0].toUpperCase(),
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                )
              : null,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _book!.seller?.name ?? 'Unknown Seller',
                style: AppTextStyles.labelLarge.copyWith(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_book!.seller?.email != null)
                Text(
                  _book!.seller!.email!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark
                        ? const Color(0xFF06B6D4)
                        : const Color(0xFF0E7490),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrustStatsGrid(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildReputationStatCard(
            label: 'RATING',
            value: _sellerReputation?.averageRating.toStringAsFixed(1) ?? '0.0',
            suffix: '/5.0',
            isDark: isDark,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildReputationStatCard(
            label: 'RATINGS',
            value: _sellerReputation?.totalRatings.toString() ?? '0',
            isDark: isDark,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildReputationStatCard(
            label: 'SOLD',
            value: _sellerReputation?.soldCount.toString() ?? '0',
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyActions(bool isDark) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _buildTrustActionButton(
          label: 'Rate Seller',
          onTap: _rateSeller,
          color: const Color(0xFF0891B2),
          bgColor: isDark
              ? const Color(0xFF164E63).withValues(alpha: 0.5)
              : Colors.white,
          borderColor: isDark
              ? const Color(0xFF06B6D4)
              : const Color(0xFFCFFAFE),
          isDark: isDark,
        ),
        _buildTrustActionButton(
          label: 'Report Safety',
          onTap: _reportListing,
          color: const Color(0xFFD97706),
          bgColor: isDark
              ? const Color(0xFF78350F).withValues(alpha: 0.5)
              : Colors.white,
          borderColor: isDark
              ? const Color(0xFFF59E0B)
              : const Color(0xFFFDE68A),
          isDark: isDark,
        ),
        _buildTrustActionButton(
          label: 'Block User',
          onTap: _blockUser,
          color: const Color(0xFFDC2626),
          bgColor: isDark
              ? const Color(0xFF7F1D1D).withValues(alpha: 0.5)
              : Colors.white,
          borderColor: isDark
              ? const Color(0xFFEF4444)
              : const Color(0xFFFECACA),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: AppTextStyles.labelLarge.copyWith(
            color: Theme.of(context).disabledColor,
            fontSize: 10,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _book!.description!,
          style: AppTextStyles.bodyMedium.copyWith(
            height: 1.5,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildReputationStatCard({
    required String label,
    required String value,
    String? suffix,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showSellerProfileSheet,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isDark ? const Color(0xFF164E63) : const Color(0xFFCFFAFE),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  if (suffix != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2, left: 1),
                      child: Text(
                        suffix,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrustActionButton({
    required String label,
    required VoidCallback onTap,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required bool isDark,
  }) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: () {
          haptics.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactBar() {
    String buttonText = 'Request to Buy';
    IconData icon = Icons.shopping_cart_outlined;
    Color buttonColor = AppColors.primary;

    if (_myRequest != null) {
      if (_myRequest!.status == RequestStatus.pending) {
        buttonText = 'Request Pending';
        icon = Icons.hourglass_empty;
        buttonColor = Colors.orange;
      } else if (_myRequest!.status == RequestStatus.accepted) {
        buttonText = 'Contact Seller';
        icon = Icons.mail_outline;
        buttonColor = AppColors.success;
      } else if (_myRequest!.status == RequestStatus.rejected) {
        buttonText = 'Request Rejected';
        icon = Icons.cancel_outlined;
        buttonColor = AppColors.error;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _isRequesting ? null : _contactSeller,
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isRequesting)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              else ...[
                Icon(icon),
                const SizedBox(width: AppSpacing.sm),
                Text(buttonText),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _blockUser() async {
    if (_book == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User?'),
        content: Text(
          'Are you sure you want to block ${_book!.seller?.name ?? "this user"}? You will no longer see their listings and they won\'t be able to contact you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (result == true) {
      final apiResult = await _apiService.blockMarketplaceUser(_book!.sellerId);
      if (mounted) {
        if (apiResult['success'] == true) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('User blocked')));
          Navigator.pop(
            context,
            true,
          ); // Return true to signal marketplace refresh
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(apiResult['message'] ?? 'Failed to block user'),
            ),
          );
        }
      }
    }
  }

  Future<void> _reportListing() async {
    if (_book == null) return;

    ReportCategory? selectedCategory;
    final descriptionController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report Listing'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Why are you reporting this?'),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<ReportCategory>(
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: ReportCategory.values
                      .map(
                        (cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => selectedCategory = val),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Details',
                    hintText: 'Describe the issue...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedCategory != null) {
      final apiResult = await _apiService.createMarketplaceReport(
        reportedUserId: _book!.sellerId,
        listingId: _book!.id,
        category: selectedCategory!,
        description: descriptionController.text,
      );

      if (mounted) {
        if (apiResult['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report submitted successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(apiResult['message'] ?? 'Failed to submit report'),
            ),
          );
        }
      }
    }
  }

  void _showSellerProfileSheet() {
    if (_book == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SellerProfileSheet(
        sellerId: _book!.sellerId,
        sellerName: _book!.seller?.name ?? 'Seller',
        sellerImage: _book!.seller?.image,
        sellerEmail: _book!.seller?.email,
        initialReputation: _sellerReputation,
        currentListingId: _book!.id,
      ),
    );
  }

  Future<void> _rateSeller() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          _RatingDialog(sellerName: _book?.seller?.name ?? 'Seller'),
    );

    if (result != null && result['rating'] != null) {
      setState(() => _isLoading = true);
      final apiResult = await _apiService.rateSeller(
        sellerId: _book!.sellerId,
        listingId: _book!.id,
        rating: result['rating'],
        review: result['review'],
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (apiResult['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rating submitted! Thank you.')),
          );
          // Refresh reputation data
          _apiService.getSellerReputation(_book!.sellerId).then((reputation) {
            if (mounted) {
              setState(() {
                _sellerReputation = reputation;
              });
            }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(apiResult['message'] ?? 'Failed to submit rating.'),
            ),
          );
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    return '${(diff.inDays / 30).floor()} months ago';
  }
}

class _RatingDialog extends StatefulWidget {
  final String sellerName;
  const _RatingDialog({required this.sellerName});

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  int _rating = 0;
  final _reviewController = TextEditingController();

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.stars_rounded,
                  color: AppColors.primary,
                  size: 40,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Rate Seller',
                style: AppTextStyles.h4,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'How was your experience with ${widget.sellerName}?',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).disabledColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starValue = index + 1;
                  final isSelected = starValue <= _rating;
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 1.0, end: isSelected ? 1.2 : 1.0),
                    duration: const Duration(milliseconds: 200),
                    builder: (context, scale, child) => Transform.scale(
                      scale: scale,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          haptics.selectionClick();
                          setState(() => _rating = starValue);
                        },
                        icon: Icon(
                          isSelected
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: isSelected
                              ? Colors.amber[700]
                              : (isDark ? Colors.white24 : Colors.grey[300]),
                          size: 32,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _reviewController,
                decoration: InputDecoration(
                  hintText: 'Share your review (optional)',
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(AppSpacing.md),
                ),
                maxLines: 4,
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'MAYBE LATER',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: Theme.of(context).disabledColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _rating == 0
                          ? null
                          : () => Navigator.pop(context, {
                              'rating': _rating,
                              'review': _reviewController.text.trim(),
                            }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                      ),
                      child: const Text('SUBMIT'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConditionStyle {
  final Color bgColor;
  final Color textColor;
  final Color borderColor;

  _ConditionStyle({
    required this.bgColor,
    required this.textColor,
    required this.borderColor,
  });
}

class _SellerProfileSheet extends StatefulWidget {
  final String sellerId;
  final String sellerName;
  final String? sellerImage;
  final String? sellerEmail;
  final SellerReputation? initialReputation;
  final int currentListingId;

  const _SellerProfileSheet({
    required this.sellerId,
    required this.sellerName,
    this.sellerImage,
    this.sellerEmail,
    this.initialReputation,
    required this.currentListingId,
  });

  @override
  State<_SellerProfileSheet> createState() => _SellerProfileSheetState();
}

class _SellerProfileSheetState extends State<_SellerProfileSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  SellerReputation? _reputation;
  List<BookListing> _otherListings = [];
  bool _isLoadingReputation = false;
  bool _isLoadingListings = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _reputation = widget.initialReputation;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoadingReputation = _reputation == null;
      _isLoadingListings = true;
    });

    try {
      final results = await Future.wait([
        _apiService.getSellerReputation(widget.sellerId),
        _apiService.getSellerListings(widget.sellerId),
      ]);

      if (mounted) {
        setState(() {
          _reputation = results[0] as SellerReputation?;
          _otherListings = (results[1] as List<BookListing>)
              .where((b) => b.id != widget.currentListingId && b.isAvailable)
              .toList();
          _isLoadingReputation = false;
          _isLoadingListings = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading seller profile data: $e');
      if (mounted) {
        setState(() {
          _isLoadingReputation = false;
          _isLoadingListings = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: isDark
                      ? const Color(0xFF1E40AF)
                      : const Color(0xFFDBEAFE),
                  backgroundImage: widget.sellerImage != null
                      ? CachedNetworkImageProvider(widget.sellerImage!)
                      : null,
                  child: widget.sellerImage == null
                      ? Text(
                          widget.sellerName[0].toUpperCase(),
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.sellerName, style: AppTextStyles.h4),
                      if (widget.sellerEmail != null)
                        Text(
                          widget.sellerEmail!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Theme.of(context).disabledColor,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Stats Bar
          if (_reputation != null) _buildStatsBar(isDark),

          const SizedBox(height: AppSpacing.md),

          // Tabs
          TabBar(
            controller: _tabController,
            labelStyle: AppTextStyles.labelMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelColor: Theme.of(context).disabledColor,
            labelColor: AppColors.primary,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [
              Tab(text: 'ACTIVE LISTINGS'),
              Tab(text: 'REVIEWS'),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildListingsTab(isDark), _buildReviewsTab(isDark)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(
            'RATING',
            _reputation!.averageRating.toStringAsFixed(1),
            Icons.star_rounded,
            Colors.amber,
          ),
          _buildVerticalDivider(),
          _buildStatItem(
            'SOLD',
            _reputation!.soldCount.toString(),
            Icons.shopping_bag_rounded,
            Colors.blue,
          ),
          _buildVerticalDivider(),
          _buildStatItem(
            'RATINGS',
            _reputation!.totalRatings.toString(),
            Icons.people_rounded,
            Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: Theme.of(context).disabledColor,
            fontSize: 9,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 30,
      color: Theme.of(context).dividerColor,
    );
  }

  Widget _buildListingsTab(bool isDark) {
    if (_isLoadingListings) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_otherListings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No other active listings',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).disabledColor,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: _otherListings.length,
      itemBuilder: (context, index) {
        final book = _otherListings[index];
        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
          child: InkWell(
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      BookDetailsPage(bookId: book.id, initialBook: book),
                ),
              );
            },
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: book.images?.isNotEmpty == true
                        ? CachedNetworkImage(
                            imageUrl: book.images![0].imageUrl,
                            width: 60,
                            height: 80,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 60,
                            height: 80,
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.book),
                          ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          style: AppTextStyles.labelLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          book.author,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Theme.of(context).disabledColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          book.formattedPrice,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReviewsTab(bool isDark) {
    if (_isLoadingReputation) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reputation == null || _reputation!.recentRatings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 48,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No reviews yet',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).disabledColor,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: _reputation!.recentRatings.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final rating = _reputation!.recentRatings[index];
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                    backgroundImage: rating.rater?.image != null
                        ? CachedNetworkImageProvider(rating.rater!.image!)
                        : null,
                    child: rating.rater?.image == null
                        ? Text(
                            (rating.rater?.name ?? 'A')[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rating.rater?.name ?? 'Anonymous',
                          style: AppTextStyles.labelSmall.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            Row(
                              children: List.generate(5, (i) {
                                return Icon(
                                  i < rating.rating
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: Colors.amber[700],
                                  size: 12,
                                );
                              }),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDate(rating.createdAt),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Theme.of(context).disabledColor,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (rating.review != null && rating.review!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  rating.review!,
                  style: AppTextStyles.bodySmall.copyWith(
                    height: 1.4,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 30) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    } else {
      return 'Just now';
    }
  }
}
