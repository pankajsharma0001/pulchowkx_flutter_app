import 'package:flutter/material.dart';
import 'package:pulchowkx_app/models/trust.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/shimmer_loaders.dart';

class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<BlockedUser> _blockedUsers = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await _apiService.getBlockedMarketplaceUsers();
      if (mounted) {
        setState(() {
          _blockedUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load blocked users';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _unblockUser(String userId, String userName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unblock User?'),
        content: Text('Are you sure you want to unblock $userName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    if (result == true) {
      final apiResult = await _apiService.unblockMarketplaceUser(userId);
      if (mounted) {
        if (apiResult['success'] == true) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$userName unblocked')));
          _loadBlockedUsers();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(apiResult['message'] ?? 'Failed to unblock'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked Users'), elevation: 0),
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
          child: BoxShimmer(height: 70),
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
            TextButton(
              onPressed: _loadBlockedUsers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_blockedUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 64,
              color: AppColors.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No blocked users',
              style: AppTextStyles.h4.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Users you block will appear here.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBlockedUsers,
      child: ListView.builder(
        itemCount: _blockedUsers.length,
        padding: const EdgeInsets.all(AppSpacing.md),
        itemBuilder: (context, index) {
          final blocked = _blockedUsers[index];
          final user = blocked.blockedUser;

          if (user == null) return const SizedBox.shrink();

          return Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                child: const Icon(Icons.person, color: AppColors.primary),
              ),
              title: Text(user.name, style: AppTextStyles.labelLarge),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (blocked.reason != null)
                    Text(
                      'Reason: ${blocked.reason}',
                      style: AppTextStyles.bodySmall,
                    ),
                  Text(
                    'Blocked on: ${_formatDate(blocked.createdAt)}',
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
                  ),
                ],
              ),
              trailing: TextButton(
                onPressed: () => _unblockUser(user.id, user.name),
                child: const Text('Unblock'),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}
