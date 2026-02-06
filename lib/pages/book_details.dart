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
    final result = wasSaved
        ? await _apiService.unsaveBook(_book!.id)
        : await _apiService.saveBook(_book!.id);

    if (result['success'] == true) {
      await _loadBook();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wasSaved ? 'Removed from saved' : 'Saved to your list',
            ),
            backgroundColor: AppColors.success,
          ),
        );
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
                  _buildStatusBadge(),
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
                  const SizedBox(height: AppSpacing.lg),
                  _buildPriceSection(),
                  const SizedBox(height: AppSpacing.lg),
                  _buildInfoCards(),
                  if (_book!.description != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _buildDescription(),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  _buildSellerSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildStatusBadge() {
    final color = _book!.isAvailable
        ? AppColors.success
        : _book!.status == BookStatus.sold
        ? AppColors.error
        : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        _book!.status.label,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPriceSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Price',
                style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
              ),
              Text(
                _book!.formattedPrice,
                style: AppTextStyles.h2.copyWith(color: Colors.white),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              _book!.condition.label,
              style: AppTextStyles.labelMedium.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCards() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        if (_book!.isbn != null) _InfoChip(label: 'ISBN', value: _book!.isbn!),
        if (_book!.edition != null)
          _InfoChip(label: 'Edition', value: _book!.edition!),
        if (_book!.publisher != null)
          _InfoChip(label: 'Publisher', value: _book!.publisher!),
        if (_book!.publicationYear != null)
          _InfoChip(label: 'Year', value: _book!.publicationYear.toString()),
        if (_book!.courseCode != null)
          _InfoChip(label: 'Course', value: _book!.courseCode!),
        if (_book!.category != null)
          _InfoChip(label: 'Category', value: _book!.category!.name),
      ],
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Description', style: AppTextStyles.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Text(_book!.description!, style: AppTextStyles.bodyMedium),
        ),
      ],
    );
  }

  Widget _buildSellerSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Seller', style: AppTextStyles.labelLarge),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: _book!.seller?.image != null
                    ? CachedNetworkImageProvider(_book!.seller!.image!)
                    : null,
                child: _book!.seller?.image == null
                    ? const Icon(Icons.person, color: AppColors.primary)
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _showReputationDetails,
                      child: Row(
                        children: [
                          Text(
                            _book!.seller?.name ?? 'Unknown Seller',
                            style: AppTextStyles.labelLarge,
                          ),
                          if (_sellerReputation != null &&
                              _sellerReputation!.totalRatings > 0) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Colors.amber[700],
                            ),
                            Text(
                              _sellerReputation!.averageRating.toStringAsFixed(
                                1,
                              ),
                              style: AppTextStyles.labelSmall.copyWith(
                                color: Colors.amber[900],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              ' (${_sellerReputation!.totalRatings})',
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_book!.seller?.email != null)
                      Text(
                        _book!.seller!.email!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
              if (_book!.isOwner)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    'You',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                ),
              const SizedBox(width: AppSpacing.md),
              if (!_book!.isOwner) ...[
                if (_myRequest?.status == RequestStatus.accepted)
                  IconButton(
                    onPressed: _openChat,
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: AppColors.primary,
                    ),
                    tooltip: 'Message Seller',
                  ),
                IconButton(
                  onPressed: () async {
                    if (_myRequest?.status == RequestStatus.accepted) {
                      final email = _book!.seller?.email;
                      if (email != null) {
                        final emailUri = Uri.parse(
                          'mailto:$email?subject=Interested in: ${_book!.title}',
                        );
                        if (await canLaunchUrl(emailUri)) {
                          await launchUrl(emailUri);
                        }
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'You can contact the seller once your request is accepted.',
                          ),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  icon: Icon(
                    Icons.email_outlined,
                    color: _myRequest?.status == RequestStatus.accepted
                        ? AppColors.accent
                        : AppColors.textMuted,
                  ),
                  tooltip: _myRequest?.status == RequestStatus.accepted
                      ? 'Email Seller'
                      : 'Request acceptance required',
                ),
                IconButton(
                  onPressed: () {
                    showMenu(
                      context: context,
                      position: const RelativeRect.fromLTRB(100, 400, 0, 0),
                      items: [
                        PopupMenuItem(
                          value: 'report',
                          child: Row(
                            children: const [
                              Icon(Icons.report_outlined, size: 20),
                              SizedBox(width: 8),
                              Text('Report Listing'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'block',
                          child: Row(
                            children: const [
                              Icon(
                                Icons.block_rounded,
                                size: 20,
                                color: AppColors.error,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Block User',
                                style: TextStyle(color: AppColors.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ).then((value) {
                      if (value == 'report') _reportListing();
                      if (value == 'block') _blockUser();
                    });
                  },
                  icon: const Icon(Icons.more_vert_rounded),
                  tooltip: 'Options',
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 14,
                color: Theme.of(context).disabledColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Posted ${_formatDate(_book!.createdAt)}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(context).disabledColor,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Icon(
                Icons.visibility,
                size: 14,
                color: Theme.of(context).disabledColor,
              ),
              const SizedBox(width: 6),
              Text(
                '${_book!.viewCount} views',
                style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(context).disabledColor,
                ),
              ),
            ],
          ),
        ],
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
      padding: const EdgeInsets.all(AppSpacing.lg),
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
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
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
          Navigator.pop(context); // Go back as we shouldn't see this listing
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

  void _showReputationDetails() {
    if (_sellerReputation == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Seller Reputation', style: AppTextStyles.h4),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Column(
                  children: [
                    Text(
                      _sellerReputation!.averageRating.toStringAsFixed(1),
                      style: AppTextStyles.h2.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < _sellerReputation!.averageRating.floor()
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: Colors.amber[700],
                          size: 20,
                        );
                      }),
                    ),
                    Text(
                      '${_sellerReputation!.totalRatings} ratings',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.xl),
                Expanded(
                  child: Column(
                    children: [5, 4, 3, 2, 1].map((star) {
                      final count = _sellerReputation!.distribution[star] ?? 0;
                      final percent = _sellerReputation!.totalRatings > 0
                          ? count / _sellerReputation!.totalRatings
                          : 0.0;
                      return Row(
                        children: [
                          Text('$star', style: AppTextStyles.labelSmall),
                          const SizedBox(width: 8),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: percent,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.amber[700]!,
                              ),
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 25,
                            child: Text(
                              '$count',
                              style: AppTextStyles.bodySmall,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Recent Reviews', style: AppTextStyles.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            if (_sellerReputation!.recentRatings.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text('No reviews yet.', style: AppTextStyles.bodySmall),
              )
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _sellerReputation!.recentRatings.length,
                  itemBuilder: (context, index) {
                    final rating = _sellerReputation!.recentRatings[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Row(
                                children: List.generate(5, (i) {
                                  return Icon(
                                    i < rating.rating
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    color: Colors.amber[700],
                                    size: 14,
                                  );
                                }),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                rating.rater?.name ?? 'Anonymous',
                                style: AppTextStyles.labelSmall,
                              ),
                            ],
                          ),
                          if (rating.review != null &&
                              rating.review!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                rating.review!,
                                style: AppTextStyles.bodySmall,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
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

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: Theme.of(context).disabledColor,
            ),
          ),
          Text(value, style: AppTextStyles.labelMedium),
        ],
      ),
    );
  }
}
