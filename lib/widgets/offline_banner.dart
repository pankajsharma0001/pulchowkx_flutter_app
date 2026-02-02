import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';

/// A reusable offline banner widget that shows when there's no internet connection.
/// Can be used in both Sliver and regular widget contexts.
class OfflineBanner extends StatelessWidget {
  /// Custom message to display (default: 'Offline Mode: Showing cached data')
  final String? message;

  /// Whether to show as a SliverToBoxAdapter (for CustomScrollView/slivers)
  final bool asSliver;

  /// Custom margin around the banner
  final EdgeInsets? margin;

  const OfflineBanner({
    super.key,
    this.message,
    this.asSliver = false,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ConnectivityResult>>(
      future: Connectivity().checkConnectivity(),
      builder: (context, snapshot) {
        final isOffline =
            snapshot.hasData && snapshot.data!.first == ConnectivityResult.none;

        if (!isOffline) {
          return asSliver
              ? const SliverToBoxAdapter(child: SizedBox.shrink())
              : const SizedBox.shrink();
        }

        final banner = Container(
          margin:
              margin ??
              const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.warning),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 16,
                color: AppColors.warning,
              ),
              const SizedBox(width: 8),
              Text(
                message ?? 'Offline Mode: Showing cached data',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        );

        return asSliver ? SliverToBoxAdapter(child: banner) : banner;
      },
    );
  }
}

/// A sliver version of OfflineBanner for use in CustomScrollView
class SliverOfflineBanner extends StatelessWidget {
  /// Custom message to display
  final String? message;

  /// Custom margin around the banner
  final EdgeInsets? margin;

  const SliverOfflineBanner({super.key, this.message, this.margin});

  @override
  Widget build(BuildContext context) {
    return OfflineBanner(message: message, margin: margin, asSliver: true);
  }
}
