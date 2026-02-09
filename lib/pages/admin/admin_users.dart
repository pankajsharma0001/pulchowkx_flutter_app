import 'package:flutter/material.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<dynamic> _users = [];
  String _currentRoleFilter = ''; // Empty means all

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.getAdminUsers(
        search: _searchController.text,
        role: _currentRoleFilter.isNotEmpty ? _currentRoleFilter : null,
        forceRefresh: forceRefresh,
      );

      if (response['success'] == true && mounted) {
        setState(() {
          _users = response['data'] ?? [];
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
        ).showSnackBar(SnackBar(content: Text('Failed to load users: $e')));
      }
    }
  }

  Future<void> _toggleSellerVerification(
    String userId,
    bool currentStatus,
  ) async {
    try {
      final success = await _apiService.toggleSellerVerification(
        userId,
        !currentStatus,
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentStatus ? 'Verification removed' : 'Seller verified',
            ),
          ),
        );
        _loadUsers(forceRefresh: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating verification: $e')),
        );
      }
    }
  }

  void _showRoleDialog(Map<String, dynamic> user) {
    String selectedRole = user['role'] ?? 'student';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Update User Role'),
          content: DropdownButtonFormField<String>(
            initialValue: selectedRole,
            decoration: const InputDecoration(labelText: 'Role'),
            items: ['student', 'teacher', 'admin', 'notice_manager', 'guest']
                .map(
                  (role) => DropdownMenuItem(
                    value: role,
                    child: Text(role.toUpperCase()),
                  ),
                )
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => selectedRole = val);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final messenger = ScaffoldMessenger.of(context);
                final success = await _apiService.updateAdminUserRole(
                  user['id'],
                  selectedRole,
                );
                if (success && mounted) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('User role updated')),
                  );
                  _loadUsers(forceRefresh: true);
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search users...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadUsers();
                        },
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 16,
                      ),
                    ),
                    onSubmitted: (_) => _loadUsers(forceRefresh: true),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.filter_list),
                  onSelected: (val) {
                    setState(() {
                      _currentRoleFilter = val;
                    });
                    _loadUsers(forceRefresh: true);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: '', child: Text('All Roles')),
                    const PopupMenuItem(
                      value: 'student',
                      child: Text('Student'),
                    ),
                    const PopupMenuItem(
                      value: 'teacher',
                      child: Text('Teacher'),
                    ),
                    const PopupMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadUsers(forceRefresh: true),
              child: _users.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        return _buildUserCard(_users[index]);
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off_outlined, size: 64, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No users found',
            style: AppTextStyles.h4.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final bool isVerified = user['isVerifiedSeller'] == true;
    final Map<String, dynamic> reputation = user['reputation'] ?? {};

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: user['image'] != null
              ? NetworkImage(user['image'])
              : null,
          child: user['image'] == null
              ? Text(user['name'][0].toUpperCase())
              : null,
        ),
        title: Row(
          children: [
            Text(user['name'], style: AppTextStyles.labelLarge),
            if (isVerified)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.verified, color: AppColors.primary, size: 16),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user['email'], style: AppTextStyles.bodySmall),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    user['role'].toUpperCase(),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.star, size: 14, color: Colors.amber),
                Text(
                  ' ${reputation['averageRating'] ?? 0} (${reputation['totalRatings'] ?? 0})',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (val) {
            if (val == 'role') _showRoleDialog(user);
            if (val == 'verify') {
              _toggleSellerVerification(user['id'], isVerified);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'role', child: Text('Change Role')),
            PopupMenuItem(
              value: 'verify',
              child: Text(isVerified ? 'Revoke Verification' : 'Verify Seller'),
            ),
          ],
        ),
      ),
    );
  }
}
