import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pulchowkx_app/models/lost_found.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/custom_toast.dart';

class ReportLostFoundPage extends StatefulWidget {
  const ReportLostFoundPage({super.key});

  @override
  State<ReportLostFoundPage> createState() => _ReportLostFoundPageState();
}

class _ReportLostFoundPageState extends State<ReportLostFoundPage> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _contactNoteController = TextEditingController();
  final _rewardController = TextEditingController();

  LostFoundItemType _itemType = LostFoundItemType.lost;
  LostFoundCategory _category = LostFoundCategory.other;
  DateTime _selectedDate = DateTime.now();
  final List<XFile> _images = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _contactNoteController.dispose();
    _rewardController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _images.add(image);
      });
    }
  }

  Future<void> _takePhoto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _images.add(image);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_images.isEmpty && _itemType == LostFoundItemType.found) {
      CustomToast.error(
        context,
        'Please add at least one image if you found an item.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'itemType': _itemType.name,
        'category': _category.name,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'lostFoundDate': _selectedDate.toIso8601String(),
        'locationText': _locationController.text.trim(),
        'contactNote': _contactNoteController.text.trim(),
        'rewardText': _rewardController.text.isNotEmpty
            ? _rewardController.text.trim()
            : null,
      };

      final result = await _apiService.createLostFoundItem(payload);

      if (mounted) {
        if (result.success && result.data != null) {
          // Upload images one by one
          for (var image in _images) {
            await _apiService.uploadLostFoundImage(
              result.data!.id,
              File(image.path),
            );
          }
          if (mounted) {
            CustomToast.success(context, 'Report submitted successfully!');
            Navigator.pop(context);
          }
        } else {
          CustomToast.error(
            context,
            result.message ?? 'Failed to submit report',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        CustomToast.error(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: const Text('Report Item'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTypeSelector(isDark),
                    const SizedBox(height: AppSpacing.lg),
                    _buildInputField(
                      'Title',
                      _titleController,
                      'e.g., Black Wallet, Keys',
                      isDark,
                    ),
                    _buildCategoryDropdown(isDark),
                    _buildInputField(
                      'Description',
                      _descriptionController,
                      'Describe the item...',
                      isDark,
                      maxLines: 3,
                    ),
                    _buildDatePicker(isDark),
                    _buildInputField(
                      'Location',
                      _locationController,
                      'Where did you lose/find it?',
                      isDark,
                    ),
                    _buildInputField(
                      'Contact Note (Optional)',
                      _contactNoteController,
                      'How should people reach out?',
                      isDark,
                    ),
                    if (_itemType == LostFoundItemType.lost)
                      _buildInputField(
                        'Reward (Optional)',
                        _rewardController,
                        'e.g., Coffee, Small cash prize',
                        isDark,
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Images',
                      style: AppTextStyles.h4.copyWith(
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildImagePicker(isDark),
                    const SizedBox(height: AppSpacing.xl),
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: const Text('Submit Report'),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTypeSelector(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _typeButton(
              LostFoundItemType.lost,
              'Lost',
              AppColors.error,
              isDark,
            ),
          ),
          Expanded(
            child: _typeButton(
              LostFoundItemType.found,
              'Found',
              AppColors.success,
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeButton(
    LostFoundItemType type,
    String label,
    Color color,
    bool isDark,
  ) {
    final isSelected = _itemType == type;
    return GestureDetector(
      onTap: () => setState(() => _itemType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textMuted),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    String hint,
    bool isDark, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
              ),
              filled: true,
              fillColor: isDark ? AppColors.surfaceDark : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.border,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.border,
                ),
              ),
            ),
            validator: (val) =>
                val == null || val.isEmpty ? 'This field is required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<LostFoundCategory>(
            initialValue: _category,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
            dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? AppColors.surfaceDark : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.border,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.border,
                ),
              ),
            ),
            items: LostFoundCategory.values.map((cat) {
              return DropdownMenuItem(
                value: cat,
                child: Text(cat.name[0].toUpperCase() + cat.name.substring(1)),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _category = val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Date',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: isDark
                          ? const ColorScheme.dark(
                              primary: AppColors.primary,
                              onPrimary: Colors.white,
                              surface: AppColors.surfaceDark,
                              onSurface: Colors.white,
                            )
                          : const ColorScheme.light(primary: AppColors.primary),
                    ),
                    child: child!,
                  );
                },
              );
              if (date != null) setState(() => _selectedDate = date);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.border,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMM dd, yyyy').format(_selectedDate),
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 20,
                    color: isDark ? AppColors.primary : AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker(bool isDark) {
    return Column(
      children: [
        if (_images.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Image.file(
                          File(_images[index].path),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () => setState(() => _images.removeAt(index)),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Take Photo'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.border,
                  ),
                  foregroundColor: isDark
                      ? Colors.white
                      : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Gallery'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.border,
                  ),
                  foregroundColor: isDark
                      ? Colors.white
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
