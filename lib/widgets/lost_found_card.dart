import 'package:flutter/material.dart';
import 'package:pulchowkx_app/models/lost_found.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class LostFoundCard extends StatelessWidget {
  final LostFoundItem item;
  final VoidCallback? onTap;

  const LostFoundCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLost = item.itemType == LostFoundItemType.lost;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: (isLost ? AppColors.error : AppColors.success).withValues(
            alpha: 0.1,
          ),
          width: 1,
        ),
      ),
      color: isDark ? AppColors.surfaceDark : AppColors.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Thumbnail
              Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      color: (isLost ? AppColors.error : AppColors.success)
                          .withValues(alpha: 0.05),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: item.images.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: ApiService().optimizeCloudinaryUrl(
                              item.images.first.imageUrl,
                              width: 200,
                            ),
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey.withValues(alpha: 0.1),
                            ),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.image_not_supported_rounded,
                              color: AppColors.textMuted,
                            ),
                          )
                        : Icon(
                            isLost
                                ? Icons.search_rounded
                                : Icons.inventory_2_rounded,
                            color:
                                (isLost ? AppColors.error : AppColors.success)
                                    .withValues(alpha: 0.5),
                            size: 32,
                          ),
                  ),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: (isLost ? AppColors.error : AppColors.success),
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Text(
                        isLost ? 'LOST' : 'FOUND',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.status != LostFoundStatus.open)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (item.status == LostFoundStatus.resolved
                                          ? AppColors.success
                                          : AppColors.primary)
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                              border: Border.all(
                                color:
                                    (item.status == LostFoundStatus.resolved
                                            ? AppColors.success
                                            : AppColors.primary)
                                        .withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              item.status.displayName.toUpperCase(),
                              style: AppTextStyles.labelSmall.copyWith(
                                color: item.status == LostFoundStatus.resolved
                                    ? AppColors.success
                                    : AppColors.primary,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.locationText,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.timeAgo,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                        if (item.rewardText != null &&
                            item.rewardText!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warningLight.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.xs),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.card_giftcard_rounded,
                                  size: 10,
                                  color: AppColors.warning,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'Reward',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.warning,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
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
    );
  }
}
