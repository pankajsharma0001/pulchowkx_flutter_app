import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/event_card.dart' show EventCardType;

class ShimmerLoader extends StatelessWidget {
  final Widget child;

  const ShimmerLoader({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark
          ? const Color(0xFF334155) // Lighter than card background (0xFF1E293B)
          : AppColors.primary.withValues(alpha: 0.1),
      highlightColor: isDark
          ? const Color(0xFF475569) // Even lighter for the shimmer effect
          : AppColors.accent.withValues(alpha: 0.15),
      period: const Duration(milliseconds: 1200),
      child: child,
    );
  }
}

class EventCardShimmer extends StatelessWidget {
  final EventCardType type;

  const EventCardShimmer({super.key, this.type = EventCardType.grid});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBackground = isDark
        ? AppColors.cardBackgroundDark
        : AppColors.surface;

    if (type == EventCardType.grid) {
      return Container(
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.border,
          ),
        ),
        child: ShimmerLoader(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppRadius.xl),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Container(
                        height: 12,
                        width: 140,
                        color: AppColors.surface,
                      ),
                      Container(
                        height: 8,
                        width: 100,
                        color: AppColors.surface,
                      ),
                      Container(height: 8, width: 80, color: AppColors.surface),
                      Container(
                        height: 8,
                        width: 120,
                        color: AppColors.surface,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.border,
          ),
        ),
        child: ShimmerLoader(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 14, width: 150, color: AppColors.surface),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          height: 20,
                          width: 60,
                          color: AppColors.surface,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          height: 20,
                          width: 80,
                          color: AppColors.surface,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}

class ClubCardShimmer extends StatelessWidget {
  const ClubCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBackground = isDark
        ? AppColors.cardBackgroundDark
        : AppColors.surface;

    return Container(
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      child: ShimmerLoader(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 4,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppRadius.xl),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(height: 12, width: 100, color: AppColors.surface),
                    const SizedBox(height: 6),
                    Container(
                      height: 8,
                      width: double.infinity,
                      color: AppColors.surface,
                    ),
                    const SizedBox(height: 4),
                    Container(height: 8, width: 140, color: AppColors.surface),
                    const Spacer(),
                    Row(
                      children: [
                        Container(
                          height: 8,
                          width: 40,
                          color: AppColors.surface,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          height: 8,
                          width: 40,
                          color: AppColors.surface,
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
}

class BookCardShimmer extends StatelessWidget {
  const BookCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBackground = isDark
        ? AppColors.cardBackgroundDark
        : AppColors.surface;

    return Container(
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      child: ShimmerLoader(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppRadius.lg),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 12,
                      width: double.infinity,
                      color: AppColors.surface,
                    ),
                    const SizedBox(height: 4),
                    Container(height: 12, width: 80, color: AppColors.surface),
                    const SizedBox(height: 6),
                    Container(height: 10, width: 60, color: AppColors.surface),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          height: 12,
                          width: 50,
                          color: AppColors.surface,
                        ),
                        Container(
                          height: 12,
                          width: 40,
                          color: AppColors.surface,
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
}

class StatsGridShimmer extends StatelessWidget {
  const StatsGridShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double itemWidth = (constraints.maxWidth - AppSpacing.md * 2) / 3;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            BoxShimmer(
              height: 80,
              width: itemWidth,
              borderRadius: AppRadius.xl,
            ),
            BoxShimmer(
              height: 80,
              width: itemWidth,
              borderRadius: AppRadius.xl,
            ),
            BoxShimmer(
              height: 80,
              width: itemWidth,
              borderRadius: AppRadius.xl,
            ),
          ],
        );
      },
    );
  }
}

class DashboardHeaderShimmer extends StatelessWidget {
  const DashboardHeaderShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBackground = isDark
        ? AppColors.cardBackgroundDark
        : AppColors.surface;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: ShimmerLoader(
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuickActionShimmer extends StatelessWidget {
  const QuickActionShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color maskColor = isDark ? Colors.grey[800]! : AppColors.surface;

    return ShimmerLoader(
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: maskColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    );
  }
}

class ClassroomShimmer extends StatelessWidget {
  final bool isTeacher;

  const ClassroomShimmer({super.key, this.isTeacher = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: BoxShimmer(height: 80, borderRadius: AppRadius.lg)),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: BoxShimmer(height: 80, borderRadius: AppRadius.lg)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: BoxShimmer(height: 140, borderRadius: AppRadius.lg),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const CardShimmer(),
        const CardShimmer(),
      ],
    );
  }
}

class GridShimmer extends StatelessWidget {
  final Widget itemShimmer;
  final int itemCount;
  final double childAspectRatio;

  const GridShimmer({
    super.key,
    required this.itemShimmer,
    this.itemCount = 6,
    this.childAspectRatio = 0.7,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => itemShimmer,
    );
  }
}

class CardShimmer extends StatelessWidget {
  const CardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBackground = isDark
        ? AppColors.cardBackgroundDark
        : AppColors.surface;

    return Container(
      height: 120,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      child: ShimmerLoader(child: Container(color: AppColors.surface)),
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
                color: AppColors.surface,
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
                    color: AppColors.surface,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(height: 10, width: 150, color: AppColors.surface),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailsPageShimmer extends StatelessWidget {
  const DetailsPageShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Skeleton
          ShimmerLoader(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : AppColors.surface,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Cards Grid
                const GridShimmer(
                  itemShimmer: BoxShimmer(
                    height: 80,
                    borderRadius: AppRadius.md,
                  ),
                  itemCount: 4,
                  childAspectRatio: 2.0,
                ),
                const SizedBox(height: AppSpacing.xl),
                // Heading
                ShimmerLoader(
                  child: Container(
                    height: 24,
                    width: 200,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : AppColors.surface,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Content Block
                ShimmerLoader(
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                // List Items
                const ListTileShimmer(),
                const ListTileShimmer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BoxShimmer extends StatelessWidget {
  final double height;
  final double? width;
  final double borderRadius;

  const BoxShimmer({
    super.key,
    required this.height,
    this.width,
    this.borderRadius = AppRadius.md,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color maskColor = isDark ? Colors.grey[800]! : AppColors.surface;

    return ShimmerLoader(
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: maskColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class BookListTileShimmer extends StatelessWidget {
  const BookListTileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBackground = isDark
        ? AppColors.cardBackgroundDark
        : AppColors.surface;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      child: ShimmerLoader(
        child: Row(
          children: [
            Container(
              width: 80,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 150, color: AppColors.surface),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 100, color: AppColors.surface),
                  const SizedBox(height: 12),
                  Container(height: 14, width: 60, color: AppColors.surface),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RequestCardShimmer extends StatelessWidget {
  const RequestCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBackground = isDark
        ? AppColors.cardBackgroundDark
        : AppColors.surface;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      child: ShimmerLoader(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12,
                        width: 120,
                        color: AppColors.surface,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 10,
                        width: 80,
                        color: AppColors.surface,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 60,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              height: 30,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SellBookShimmer extends StatelessWidget {
  const SellBookShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      physics: const NeverScrollableScrollPhysics(),
      child: ShimmerLoader(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Images
            Container(height: 14, width: 80, color: AppColors.surface),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                BoxShimmer(height: 100, width: 100, borderRadius: AppRadius.md),
                const SizedBox(width: AppSpacing.sm),
                BoxShimmer(height: 100, width: 100, borderRadius: AppRadius.md),
                const SizedBox(width: AppSpacing.sm),
                BoxShimmer(height: 100, width: 100, borderRadius: AppRadius.md),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Text Fields
            _buildFieldShimmer(),
            _buildFieldShimmer(),
            _buildFieldShimmer(),

            const SizedBox(height: AppSpacing.md),
            Container(height: 14, width: 100, color: AppColors.surface),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                BoxShimmer(height: 32, width: 80, borderRadius: AppRadius.full),
                const SizedBox(width: 8),
                BoxShimmer(height: 32, width: 80, borderRadius: AppRadius.full),
                const SizedBox(width: 8),
                BoxShimmer(height: 32, width: 80, borderRadius: AppRadius.full),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),
            _buildFieldShimmer(),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldShimmer() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 14, width: 120, color: AppColors.surface),
          const SizedBox(height: 8),
          BoxShimmer(height: 50, borderRadius: AppRadius.sm),
        ],
      ),
    );
  }
}
