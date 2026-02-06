import 'package:flutter/material.dart';
import 'package:pulchowkx_app/models/trust.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/shimmer_loaders.dart';

class MarketplaceReportsPage extends StatefulWidget {
  const MarketplaceReportsPage({super.key});

  @override
  State<MarketplaceReportsPage> createState() => _MarketplaceReportsPageState();
}

class _MarketplaceReportsPageState extends State<MarketplaceReportsPage> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<MarketplaceReport> _reports = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final reports = await _apiService.getMyMarketplaceReports();
      if (mounted) {
        setState(() {
          _reports = reports;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load reports';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Reports'), elevation: 0),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView.builder(
        itemCount: 5,
        padding: const EdgeInsets.all(AppSpacing.md),
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.md),
          child: BoxShimmer(height: 100),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(_errorMessage!, style: AppTextStyles.bodyMedium),
            TextButton(onPressed: _loadReports, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.report_gmailerrorred_outlined,
              size: 64,
              color: AppColors.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No reports submitted',
              style: AppTextStyles.h4.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your marketplace reports will appear here.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReports,
      child: ListView.builder(
        itemCount: _reports.length,
        padding: const EdgeInsets.all(AppSpacing.md),
        itemBuilder: (context, index) {
          final report = _reports[index];
          return Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          report.category.displayName,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      _buildStatusChip(report.status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (report.listing != null)
                    Text(
                      'Listing: ${report.listing!.title}',
                      style: AppTextStyles.labelLarge,
                    ),
                  if (report.reportedUser != null)
                    Text(
                      'User: ${report.reportedUser!.name}',
                      style: AppTextStyles.bodyMedium,
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(report.description, style: AppTextStyles.bodySmall),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Reported on: ${_formatDate(report.createdAt)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      if (report.resolutionNotes != null)
                        const Icon(
                          Icons.info_outline,
                          size: 16,
                          color: AppColors.primary,
                        ),
                    ],
                  ),
                  if (report.resolutionNotes != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Resolution Notes:',
                            style: AppTextStyles.labelSmall,
                          ),
                          Text(
                            report.resolutionNotes!,
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(ReportStatus status) {
    Color color;
    switch (status) {
      case ReportStatus.open:
        color = AppColors.info;
        break;
      case ReportStatus.inReview:
        color = AppColors.warning;
        break;
      case ReportStatus.resolved:
        color = AppColors.success;
        break;
      case ReportStatus.rejected:
        color = AppColors.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(color: color, fontSize: 9),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}
