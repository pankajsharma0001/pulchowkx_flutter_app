import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pulchowkx_app/models/club.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';

class ClubAdminTab extends StatefulWidget {
  final Club club;
  final ClubProfile? profile;
  final Function() onInfoUpdated;

  const ClubAdminTab({
    super.key,
    required this.club,
    this.profile,
    required this.onInfoUpdated,
  });

  @override
  State<ClubAdminTab> createState() => _ClubAdminTabState();
}

class _ClubAdminTabState extends State<ClubAdminTab> {
  final _apiService = ApiService();
  bool _isLoading = false;

  // Edit mode flags
  bool _isEditingClubInfo = false;
  bool _isEditingProfile = false;

  final _picker = ImagePicker();
  File? _clubLogoFile;

  // Edit Info State
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _logoController = TextEditingController();

  // Edit Profile State
  final _aboutController = TextEditingController();
  final _missionController = TextEditingController();
  final _visionController = TextEditingController();
  final _benefitsController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();

  // Social Links
  final _facebookController = TextEditingController();
  final _instagramController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _githubController = TextEditingController();

  // Manage Admins State
  final _newAdminEmailController = TextEditingController();
  List<Map<String, dynamic>> _admins = [];
  bool _loadingAdmins = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadAdmins();
  }

  void _initializeControllers() {
    // Club Info
    _nameController.text = widget.club.name;
    _descController.text = widget.club.description ?? '';
    _logoController.text = widget.club.logoUrl ?? '';

    // Profile
    if (widget.profile != null) {
      _aboutController.text = widget.profile!.aboutClub ?? '';
      _missionController.text = widget.profile!.mission ?? '';
      _visionController.text = widget.profile!.vision ?? '';
      _benefitsController.text = widget.profile!.benefits ?? '';
      _phoneController.text = widget.profile!.contactPhone ?? '';
      _websiteController.text = widget.profile!.websiteUrl ?? '';

      final socials = widget.profile!.socialLinks ?? {};
      _facebookController.text = socials['facebook'] ?? '';
      _instagramController.text = socials['instagram'] ?? '';
      _linkedinController.text = socials['linkedin'] ?? '';
      _githubController.text = socials['github'] ?? '';
    }
  }

  @override
  void didUpdateWidget(ClubAdminTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.club != widget.club || oldWidget.profile != widget.profile) {
      _initializeControllers();
    }
  }

  Future<void> _loadAdmins() async {
    setState(() => _loadingAdmins = true);
    try {
      final admins = await _apiService.getClubAdmins(widget.club.id);
      if (mounted) {
        setState(() => _admins = admins);
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => _loadingAdmins = false);
    }
  }

  Future<void> _pickClubLogo() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _clubLogoFile = File(pickedFile.path);
        _logoController.clear();
      });
    }
  }

  Future<void> _saveClubInfo() async {
    setState(() => _isLoading = true);
    try {
      String? logoUrl = _logoController.text.trim();

      if (_clubLogoFile != null) {
        final uploadResult = await _apiService.uploadClubLogo(
          widget.club.id,
          _clubLogoFile!,
        );
        if (uploadResult['success'] == true) {
          logoUrl = uploadResult['url'];
        } else {
          throw Exception(uploadResult['message'] ?? 'Logo upload failed');
        }
      }

      final result = await _apiService.updateClubInfo(widget.club.id, {
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'logoUrl': logoUrl,
      });

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Club info updated successfully')),
          );
          setState(() => _isEditingClubInfo = false);
          widget.onInfoUpdated();
        }
      } else {
        throw Exception(result['message']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final data = {
        'aboutClub': _aboutController.text.trim(),
        'mission': _missionController.text.trim(),
        'vision': _visionController.text.trim(),
        'benefits': _benefitsController.text.trim(),
        'contactPhone': _phoneController.text.trim(),
        'websiteUrl': _websiteController.text.trim(),
        'socialLinks': {
          'facebook': _facebookController.text.trim(),
          'instagram': _instagramController.text.trim(),
          'linkedin': _linkedinController.text.trim(),
          'github': _githubController.text.trim(),
        },
      };

      final result = await _apiService.updateClubProfile(widget.club.id, data);

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
          setState(() => _isEditingProfile = false);
          widget.onInfoUpdated();
        }
      } else {
        throw Exception(result['message']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addAdmin() async {
    final email = _newAdminEmailController.text.trim();
    if (email.isEmpty) return;

    // Check if duplicate
    if (_admins.any((a) => a['email'] == email)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User is already an admin')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await _apiService.addClubAdmin(
        clubId: widget.club.id,
        email: email,
        ownerId: widget.club.authClubId,
      );

      if (result['success'] == true) {
        _newAdminEmailController.clear();
        await _loadAdmins();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Admin added successfully')),
          );
        }
      } else {
        throw Exception(result['message']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeAdmin(String odataUserId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Admin'),
        content: const Text('Are you sure you want to remove this admin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final result = await _apiService.removeClubAdmin(
        clubId: widget.club.id,
        userId: odataUserId,
        ownerId: widget.club.authClubId,
      );

      if (result['success'] == true) {
        await _loadAdmins();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Admin removed successfully')),
          );
        }
      } else {
        throw Exception(result['message']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _cancelClubInfoEdit() {
    _nameController.text = widget.club.name;
    _descController.text = widget.club.description ?? '';
    _logoController.text = widget.club.logoUrl ?? '';
    setState(() {
      _isEditingClubInfo = false;
      _clubLogoFile = null;
    });
  }

  void _cancelProfileEdit() {
    if (widget.profile != null) {
      _aboutController.text = widget.profile!.aboutClub ?? '';
      _missionController.text = widget.profile!.mission ?? '';
      _visionController.text = widget.profile!.vision ?? '';
      _benefitsController.text = widget.profile!.benefits ?? '';
      _phoneController.text = widget.profile!.contactPhone ?? '';
      _websiteController.text = widget.profile!.websiteUrl ?? '';
      final socials = widget.profile!.socialLinks ?? {};
      _facebookController.text = socials['facebook'] ?? '';
      _instagramController.text = socials['instagram'] ?? '';
      _linkedinController.text = socials['linkedin'] ?? '';
      _githubController.text = socials['github'] ?? '';
    }
    setState(() => _isEditingProfile = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _logoController.dispose();
    _aboutController.dispose();
    _missionController.dispose();
    _visionController.dispose();
    _benefitsController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _linkedinController.dispose();
    _githubController.dispose();
    _newAdminEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // Club Information Section
        _buildSectionCard(
          title: 'Club Information',
          isEditing: _isEditingClubInfo,
          onEdit: () => setState(() => _isEditingClubInfo = true),
          onSave: _saveClubInfo,
          onCancel: _cancelClubInfoEdit,
          viewContent: _buildClubInfoView(),
          editContent: _buildClubInfoEdit(),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Club Profile Section
        _buildSectionCard(
          title: 'Club Profile',
          isEditing: _isEditingProfile,
          onEdit: () => setState(() => _isEditingProfile = true),
          onSave: _saveProfile,
          onCancel: _cancelProfileEdit,
          viewContent: _buildProfileView(),
          editContent: _buildProfileEdit(),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Manage Admins Section (always visible)
        _buildAdminsSection(),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required bool isEditing,
    required VoidCallback onEdit,
    required VoidCallback onSave,
    required VoidCallback onCancel,
    required Widget viewContent,
    required Widget editContent,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            child: Row(
              children: [
                Text(title, style: AppTextStyles.h3),
                const Spacer(),
                if (!isEditing)
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: isEditing ? editContent : viewContent,
          ),
          // Action buttons when editing
          if (isEditing)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: onCancel, child: const Text('Cancel')),
                  const SizedBox(width: AppSpacing.sm),
                  ElevatedButton(
                    onPressed: onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save Changes'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClubInfoView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Club Name', widget.club.name),
        _buildInfoRow(
          'Description',
          widget.club.description ?? 'No description',
        ),
        _buildInfoRow('Logo URL', widget.club.logoUrl ?? 'Not set'),
      ],
    );
  }

  Widget _buildClubInfoEdit() {
    return Column(
      children: [
        _buildTextField('Club Name', _nameController),
        _buildTextField('Description', _descController, maxLines: 3),
        _buildImagePickerSection(),
        if (_clubLogoFile != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _clubLogoFile!,
                height: 100,
                width: 100,
                fit: BoxFit.cover,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImagePickerSection() {
    return Row(
      children: [
        Expanded(
          child: _buildTextField(
            'Logo URL',
            _logoController,
            onChanged: (value) {
              if (value.isNotEmpty && _clubLogoFile != null) {
                setState(() => _clubLogoFile = null);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        const Text('OR'),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _pickClubLogo,
          icon: const Icon(Icons.file_upload),
          label: const Text('Upload'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileView() {
    final profile = widget.profile;
    final socials = profile?.socialLinks ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('About', profile?.aboutClub ?? 'Not set'),
        _buildInfoRow('Mission', profile?.mission ?? 'Not set'),
        _buildInfoRow('Vision', profile?.vision ?? 'Not set'),
        _buildInfoRow('Benefits', profile?.benefits ?? 'Not set'),
        _buildInfoRow('Contact Phone', profile?.contactPhone ?? 'Not set'),
        _buildInfoRow('Website', profile?.websiteUrl ?? 'Not set'),
        const Divider(height: 24),
        Text(
          'Social Links',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _buildInfoRow('Facebook', socials['facebook'] ?? 'Not set'),
        _buildInfoRow('Instagram', socials['instagram'] ?? 'Not set'),
        _buildInfoRow('LinkedIn', socials['linkedin'] ?? 'Not set'),
        _buildInfoRow('GitHub', socials['github'] ?? 'Not set'),
      ],
    );
  }

  Widget _buildProfileEdit() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField('About', _aboutController, maxLines: 4),
        _buildTextField('Mission', _missionController, maxLines: 2),
        _buildTextField('Vision', _visionController, maxLines: 2),
        _buildTextField('Benefits', _benefitsController, maxLines: 3),
        _buildTextField(
          'Contact Phone',
          _phoneController,
          keyboardType: TextInputType.phone,
        ),
        _buildTextField(
          'Website URL',
          _websiteController,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 8),
        Text(
          'Social Links',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _buildTextField('Facebook', _facebookController),
        _buildTextField('Instagram', _instagramController),
        _buildTextField('LinkedIn', _linkedinController),
        _buildTextField('GitHub', _githubController),
      ],
    );
  }

  Widget _buildAdminsSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            child: Row(
              children: [
                Text('Manage Admins', style: AppTextStyles.h3),
                const Spacer(),
                Text(
                  '${_admins.length} admin${_admins.length != 1 ? 's' : ''}',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Add new admin
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newAdminEmailController,
                        decoration: InputDecoration(
                          labelText: 'Add Admin by Email',
                          hintText: 'student@example.com',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _addAdmin,
                      icon: const Icon(Icons.person_add),
                      tooltip: 'Add Admin',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Admin list
                if (_loadingAdmins)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_admins.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 40,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No additional admins',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            'Add admins by email above',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: _admins.map((user) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage:
                                user['image'] != null &&
                                    user['image'].isNotEmpty
                                ? NetworkImage(user['image'])
                                : null,
                            child:
                                (user['image'] == null || user['image'].isEmpty)
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(
                            user['name'] ?? 'Unknown',
                            style: AppTextStyles.labelLarge.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            user['email'] ?? '',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.error,
                            ),
                            onPressed: () => _removeAdmin(user['id']),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final isNotSet = value == 'Not set';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isNotSet
                  ? AppColors.textSecondary.withValues(alpha: 0.6)
                  : AppColors.textPrimary,
              fontStyle: isNotSet ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType? keyboardType,
    Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
