import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pulchowkx_app/models/book_listing.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';

class SellBookPage extends StatefulWidget {
  final BookListing? existingBook; // For edit mode

  const SellBookPage({super.key, this.existingBook});

  @override
  State<SellBookPage> createState() => _SellBookPageState();
}

class _SellBookPageState extends State<SellBookPage> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _isbnController = TextEditingController();
  final _editionController = TextEditingController();
  final _publisherController = TextEditingController();
  final _yearController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _courseCodeController = TextEditingController();

  BookCondition _condition = BookCondition.good;
  BookCategory? _selectedCategory;
  List<BookCategory> _categories = [];
  final List<File> _selectedImages = [];
  bool _isLoading = false;
  bool _isSaving = false;

  bool get _isEditMode => widget.existingBook != null;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _populateFields();
  }

  void _populateFields() {
    if (_isEditMode) {
      final book = widget.existingBook!;
      _titleController.text = book.title;
      _authorController.text = book.author;
      _isbnController.text = book.isbn ?? '';
      _editionController.text = book.edition ?? '';
      _publisherController.text = book.publisher ?? '';
      _yearController.text = book.publicationYear?.toString() ?? '';
      _priceController.text = book.price;
      _descriptionController.text = book.description ?? '';
      _courseCodeController.text = book.courseCode ?? '';
      _condition = book.condition;
    }
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    final categories = await _apiService.getBookCategories();
    if (mounted) {
      setState(() {
        _categories = categories;
        if (_isEditMode && widget.existingBook!.categoryId != null) {
          _selectedCategory = categories.firstWhere(
            (c) => c.id == widget.existingBook!.categoryId,
            orElse: () => categories.first,
          );
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImages() async {
    final List<XFile> pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isNotEmpty && mounted) {
      setState(() {
        _selectedImages.addAll(pickedFiles.map((f) => File(f.path)));
      });
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final result = _isEditMode
          ? await _apiService.updateBookListing(widget.existingBook!.id, {
              'title': _titleController.text.trim(),
              'author': _authorController.text.trim(),
              'condition': _condition.value,
              'price': _priceController.text.trim(),
              if (_isbnController.text.isNotEmpty)
                'isbn': _isbnController.text.trim(),
              if (_editionController.text.isNotEmpty)
                'edition': _editionController.text.trim(),
              if (_publisherController.text.isNotEmpty)
                'publisher': _publisherController.text.trim(),
              if (_yearController.text.isNotEmpty)
                'publicationYear': int.parse(_yearController.text.trim()),
              if (_descriptionController.text.isNotEmpty)
                'description': _descriptionController.text.trim(),
              if (_courseCodeController.text.isNotEmpty)
                'courseCode': _courseCodeController.text.trim(),
              if (_selectedCategory != null)
                'categoryId': _selectedCategory!.id,
            })
          : await _apiService.createBookListing(
              title: _titleController.text.trim(),
              author: _authorController.text.trim(),
              condition: _condition.value,
              price: _priceController.text.trim(),
              isbn: _isbnController.text.isNotEmpty
                  ? _isbnController.text.trim()
                  : null,
              edition: _editionController.text.isNotEmpty
                  ? _editionController.text.trim()
                  : null,
              publisher: _publisherController.text.isNotEmpty
                  ? _publisherController.text.trim()
                  : null,
              publicationYear: _yearController.text.isNotEmpty
                  ? int.parse(_yearController.text.trim())
                  : null,
              description: _descriptionController.text.isNotEmpty
                  ? _descriptionController.text.trim()
                  : null,
              courseCode: _courseCodeController.text.isNotEmpty
                  ? _courseCodeController.text.trim()
                  : null,
              categoryId: _selectedCategory?.id,
            );

      if (result['success'] == true) {
        // Upload images for new listings
        if (!_isEditMode &&
            result['data'] != null &&
            _selectedImages.isNotEmpty) {
          final listing = result['data'] as BookListing;
          for (final image in _selectedImages) {
            await _apiService.uploadBookImage(listing.id, image);
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isEditMode ? 'Book updated!' : 'Book listed for sale!',
              ),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to save'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _isbnController.dispose();
    _editionController.dispose();
    _publisherController.dispose();
    _yearController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _courseCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditMode ? 'Edit Listing' : 'Sell a Book',
          style: AppTextStyles.h4,
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _submit,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _isEditMode ? 'Save' : 'List',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Images Section
                    if (!_isEditMode) ...[
                      Text('Photos', style: AppTextStyles.labelLarge),
                      const SizedBox(height: AppSpacing.sm),
                      _buildImagePicker(),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    // Basic Info
                    _buildTextField(
                      controller: _titleController,
                      label: 'Book Title *',
                      hint: 'Enter the book title',
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    _buildTextField(
                      controller: _authorController,
                      label: 'Author *',
                      hint: 'Enter author name',
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    _buildTextField(
                      controller: _priceController,
                      label: 'Price (Rs.) *',
                      hint: 'Enter price',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v?.isEmpty == true) return 'Required';
                        if (double.tryParse(v!) == null) return 'Invalid price';
                        return null;
                      },
                    ),

                    // Condition
                    const SizedBox(height: AppSpacing.md),
                    Text('Condition *', style: AppTextStyles.labelMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: BookCondition.values.map((c) {
                        final isSelected = _condition == c;
                        return ChoiceChip(
                          label: Text(c.label),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _condition = c),
                          selectedColor: AppColors.primaryLight,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    const Divider(),
                    const SizedBox(height: AppSpacing.lg),

                    // Optional Details
                    Text('Additional Details', style: AppTextStyles.labelLarge),
                    const SizedBox(height: AppSpacing.md),

                    _buildTextField(
                      controller: _isbnController,
                      label: 'ISBN',
                      hint: 'International Standard Book Number',
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _editionController,
                            label: 'Edition',
                            hint: 'e.g., 3rd',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _buildTextField(
                            controller: _yearController,
                            label: 'Year',
                            hint: 'Publication year',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    _buildTextField(
                      controller: _publisherController,
                      label: 'Publisher',
                      hint: 'Publisher name',
                    ),
                    _buildTextField(
                      controller: _courseCodeController,
                      label: 'Course Code',
                      hint: 'e.g., CE-501',
                    ),

                    // Category
                    if (_categories.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text('Category', style: AppTextStyles.labelMedium),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<BookCategory?>(
                            value: _selectedCategory,
                            isExpanded: true,
                            hint: const Text('Select category'),
                            items: [
                              const DropdownMenuItem<BookCategory?>(
                                value: null,
                                child: Text('No category'),
                              ),
                              ..._categories.map(
                                (cat) => DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat.name),
                                ),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _selectedCategory = value),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.lg),
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Description',
                      hint: 'Add any additional details about the book...',
                      maxLines: 4,
                    ),

                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildImagePicker() {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          GestureDetector(
            onTap: _pickImages,
            child: Container(
              width: 100,
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.border,
                  style: BorderStyle.solid,
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    color: AppColors.primary,
                  ),
                  SizedBox(height: 4),
                  Text('Add Photos', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
          ..._selectedImages.asMap().entries.map((entry) {
            final index = entry.key;
            final file = entry.value;
            return Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Image.file(
                      file,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removeImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide(color: AppColors.primary),
              ),
              contentPadding: const EdgeInsets.all(AppSpacing.md),
            ),
          ),
        ],
      ),
    );
  }
}
