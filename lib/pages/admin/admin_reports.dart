import 'package:flutter/material.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:intl/intl.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _reports = [];
  String _currentStatus = 'open';

  // Tabs: Open, In Review, Resolved, Rejected
  final List<String> _statuses = ['open', 'in_review', 'resolved', 'rejected'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadReports();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentStatus = _statuses[_tabController.index];
      });
      _loadReports();
    }
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.getModerationReports(
        status: _currentStatus,
      );
      if (response['success'] == true && mounted) {
        setState(() {
          _reports = response['data'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load reports: $e')));
      }
    }
  }

  Future<void> _updateReportStatus(
    int reportId,
    String newStatus, [
    String? notes,
  ]) async {
    try {
      final success = await _apiService.updateModerationReport(
        reportId,
        newStatus,
        notes,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report updated successfully')),
        );
        _loadReports(); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating report: $e')));
      }
    }
  }

  void _showResolveDialog(Map<String, dynamic> report) {
    final TextEditingController notesController = TextEditingController();
    String selectedStatus = 'resolved';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Resolve Report'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedStatus,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                  DropdownMenuItem(
                    value: 'in_review',
                    child: Text('In Review'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => selectedStatus = val);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Resolution Notes',
                  hintText: 'Explain the action taken...',
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
              onPressed: () {
                Navigator.pop(context);
                _updateReportStatus(
                  report['id'],
                  selectedStatus,
                  notesController.text,
                );
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return AppColors.error;
      case 'in_review':
        return AppColors.warning;
      case 'resolved':
        return AppColors.success;
      case 'rejected':
        return AppColors.textMuted;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderation Reports'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Open'),
            Tab(text: 'In Review'),
            Tab(text: 'Resolved'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: _reports.length,
              itemBuilder: (context, index) {
                final report = _reports[index];
                return _buildReportCard(report);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 64,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No reports found',
            style: AppTextStyles.h4.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final reporter = report['reporter'];
    final reportedUser = report['reportedUser'];
    final listing = report['listing'];
    final createdAt = DateTime.parse(report['createdAt']);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(
                      report['status'],
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: _getStatusColor(
                        report['status'],
                      ).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    report['category'].toString().toUpperCase().replaceAll(
                      '_',
                      ' ',
                    ),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: _getStatusColor(report['status']),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  DateFormat('MMM d, h:mm a').format(createdAt),
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Reported by: ${reporter?['name'] ?? 'Unknown'}',
              style: AppTextStyles.labelMedium,
            ),
            Text(
              'Against: ${reportedUser?['name'] ?? 'Unknown'}',
              style: AppTextStyles.labelMedium.copyWith(color: AppColors.error),
            ),
            if (listing != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Listing: ${listing['title']}',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const Divider(height: 24),
            Text(report['description'], style: AppTextStyles.bodyMedium),
            if (report['resolutionNotes'] != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resolution Notes:',
                      style: AppTextStyles.labelSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      report['resolutionNotes'],
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _showResolveDialog(report),
                icon: const Icon(Icons.edit_note_rounded, size: 16),
                label: const Text('Update Status'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  textStyle: AppTextStyles.buttonSmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
