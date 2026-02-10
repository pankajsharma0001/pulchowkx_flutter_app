import 'package:flutter/material.dart';
import 'package:pulchowkx_app/models/lost_found.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pulchowkx_app/widgets/custom_toast.dart';
import 'package:pulchowkx_app/widgets/full_screen_image_viewer.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LostFoundDetailsPage extends StatefulWidget {
  final int itemId;

  const LostFoundDetailsPage({super.key, required this.itemId});

  @override
  State<LostFoundDetailsPage> createState() => _LostFoundDetailsPageState();
}

class _LostFoundDetailsPageState extends State<LostFoundDetailsPage> {
  final ApiService _apiService = ApiService();
  LostFoundItem? _item;
  bool _isLoading = true;
  final TextEditingController _claimController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchItemDetails();
  }

  @override
  void dispose() {
    _claimController.dispose();
    super.dispose();
  }

  Future<void> _fetchItemDetails({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    final item = await _apiService.getLostFoundItem(
      widget.itemId,
      forceRefresh: forceRefresh,
    );
    if (mounted) {
      setState(() {
        _item = item;
        _isLoading = false;
      });
    }
  }

  Future<void> _submitClaim() async {
    if (_claimController.text.trim().isEmpty) {
      CustomToast.error(context, 'Please enter a message to prove ownership.');
      return;
    }

    final result = await _apiService.createLostFoundClaim(
      widget.itemId,
      _claimController.text.trim(),
    );

    if (mounted) {
      if (result.success) {
        CustomToast.success(context, 'Claim submitted successfully!');
        Navigator.pop(context);
        _fetchItemDetails();
      } else {
        CustomToast.error(context, result.message ?? 'Failed to submit claim');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Item not found')),
      );
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = _item!.ownerId == currentUser?.uid;
    final isLost = _item!.itemType == LostFoundItemType.lost;

    return Scaffold(
      body: SafeArea(
        top: true, // Push content below the camera notch
        child: RefreshIndicator(
          onRefresh: () => _fetchItemDetails(forceRefresh: true),
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                leading: BackButton(
                  color: Colors.white,
                  style: IconButton.styleFrom(backgroundColor: Colors.black26),
                ),
                title: _isLoading || _item == null ? null : Text(_item!.title),
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildImageCarousel(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildTag(
                            isLost ? 'LOST' : 'FOUND',
                            isLost ? AppColors.error : AppColors.success,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _buildTag(
                            _item!.category.name.toUpperCase(),
                            AppColors.primary,
                          ),
                          const Spacer(),
                          Text(
                            _item!.dateFormatted,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(_item!.title, style: AppTextStyles.h3),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _item!.locationText,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: AppSpacing.xl),
                      Text('Description', style: AppTextStyles.h4),
                      const SizedBox(height: AppSpacing.sm),
                      Text(_item!.description, style: AppTextStyles.bodyMedium),
                      if (_item!.rewardText != null &&
                          _item!.rewardText!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _buildRewardSection(),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      _buildContactSection(isOwner),
                      const SizedBox(
                        height: 180,
                      ), // Space for fixed bottom banner/button
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomSheet: !isOwner && _item!.status == LostFoundStatus.open
          ? (isLost ? _buildLostItemBanner() : _buildClaimButton())
          : null,
    );
  }

  Widget _buildImageCarousel() {
    if (_item!.images.isEmpty) {
      return Container(
        color: AppColors.primary.withValues(alpha: 0.1),
        child: const Icon(
          Icons.image_not_supported_rounded,
          size: 64,
          color: AppColors.textMuted,
        ),
      );
    }

    return PageView.builder(
      itemCount: _item!.images.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (context) => FullScreenImageViewer(
                  imageUrl: _item!.images[index].imageUrl,
                  title: _item!.title,
                ),
              ),
            );
          },
          child: CachedNetworkImage(
            imageUrl: _item!.images[index].imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                Container(color: Colors.grey.withValues(alpha: 0.1)),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          ),
        );
      },
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildRewardSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard_rounded, color: AppColors.warning),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reward Offered',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
                Text(
                  _item!.rewardText!,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection(bool isOwner) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact Information',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (isOwner ||
              _item!.status == LostFoundStatus.resolved ||
              _item!.itemType == LostFoundItemType.lost)
            Text(
              _item!.contactNote ?? 'No contact note provided.',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            )
          else
            const Text(
              'Contact details will be visible once your claim is accepted by the owner.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildClaimButton() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: () => _showClaimDialog(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          child: const Text('I found this / This is mine'),
        ),
      ),
    );
  }

  Widget _buildLostItemBanner() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppRadius.xxxl),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
          ),
          child: RichText(
            text: TextSpan(
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.warning.withValues(alpha: 0.9),
                height: 1.5,
              ),
              children: [
                const TextSpan(text: 'This is a '),
                const TextSpan(
                  text: 'lost item post',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(
                  text:
                      ', so claim requests are disabled. If you found this item, contact the owner directly using the post details.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showClaimDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Submit a Claim', style: AppTextStyles.h4),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Proof of ownership is required. Please describe unique features of the item or provide any other details that can help identify you as the owner.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _claimController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Describe the item or your situation...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _submitClaim,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Submit Claim'),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
