import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';

class ShimmerLoader extends StatelessWidget {
  final Widget child;

  const ShimmerLoader({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.border.withValues(alpha: 0.5),
      highlightColor: AppColors.surface,
      period: const Duration(milliseconds: 1500),
      child: child,
    );
  }
}

class CardShimmer extends StatelessWidget {
  const CardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoader(
      child: Container(
        height: 120,
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    );
  }
}

class GridShimmer extends StatelessWidget {
  final int itemCount;

  const GridShimmer({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    );
  }
}

class ListTileShimmer extends StatelessWidget {
  const ListTileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoader(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    color: Colors.white,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(height: 10, width: 150, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BannerShimmer extends StatelessWidget {
  const BannerShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoader(
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    );
  }
}
