import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';

class CreateEventPage extends StatefulWidget {
  final int clubId;
  final String clubName;

  const CreateEventPage({
    super.key,
    required this.clubId,
    required this.clubName,
  });

  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  // Form controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _venueController = TextEditingController();
  final _maxParticipantsController = TextEditingController();
  final _picker = ImagePicker();
  File? _imageFile;
  final _bannerUrlController = TextEditingController();

  // Form state
  String _selectedEventType = 'workshop';
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _endTime = const TimeOfDay(hour: 14, minute: 0);
  DateTime _registrationDeadline = DateTime.now();
  TimeOfDay _registrationTime = const TimeOfDay(hour: 23, minute: 59);

  bool _isLoading = false;
  String? _errorMessage;
  bool _success = false;

  final List<String> _eventTypes = [
    'workshop',
    'seminar',
    'competition',
    'hackathon',
    'meetup',
    'conference',
    'webinar',
    'other',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    _maxParticipantsController.dispose();
    _bannerUrlController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime date, TimeOfDay time) {
    final dt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    return dt.toIso8601String();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _selectRegistrationDeadline(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _registrationDeadline,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: _startDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _registrationDeadline = picked;
      });

      // Also select time
      final TimeOfDay? timePicked = await showTimePicker(
        context: context,
        initialTime: _registrationTime,
      );
      if (timePicked != null) {
        setState(() {
          _registrationTime = timePicked;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _bannerUrlController.clear(); // Clear URL if file is picked
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(
        () => _errorMessage = 'You must be logged in to create an event',
      );
      return;
    }

    final dbUserId = await _apiService.getDatabaseUserId();
    if (dbUserId == null) {
      setState(() => _errorMessage = 'User not synced with database');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? bannerUrl = _bannerUrlController.text.trim();

      // Upload image first if picked
      if (_imageFile != null) {
        final uploadResult = await _apiService.uploadEventBanner(_imageFile!);
        if (uploadResult['success'] == true) {
          bannerUrl = uploadResult['url'];
        } else {
          throw Exception(uploadResult['message'] ?? 'Image upload failed');
        }
      }
      final result = await _apiService.createEvent(
        authId: dbUserId,
        clubId: widget.clubId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        eventType: _selectedEventType,
        venue: _venueController.text.trim(),
        maxParticipants: _maxParticipantsController.text.trim().isEmpty
            ? null
            : int.tryParse(_maxParticipantsController.text.trim()),
        registrationDeadline: _formatDateTime(
          _registrationDeadline,
          _registrationTime,
        ),
        eventStartTime: _formatDateTime(_startDate, _startTime),
        eventEndTime: _formatDateTime(_endDate, _endTime),
        bannerUrl: bannerUrl?.isNotEmpty == true ? bannerUrl : null,
      );

      if (result['success'] == true) {
        setState(() => _success = true);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pop(context, true); // Return true to indicate success
        }
      } else {
        setState(
          () => _errorMessage = result['message'] ?? 'Failed to create event',
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_success) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 80,
                  color: Colors.green.shade600,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Event Created!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Redirecting...',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Event'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.1),
                    AppColors.accent.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create New Event',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'For ${widget.clubName}',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),

            // Basic Info Section
            _buildSectionHeader('Basic Information'),
            const SizedBox(height: 12),

            // Title
            _buildTextField(
              controller: _titleController,
              label: 'Event Title',
              hint: 'e.g. Flutter Workshop 2026',
              icon: Icons.title,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Title is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Event Type
            _buildDropdownField(),
            const SizedBox(height: 16),

            // Description
            _buildTextField(
              controller: _descriptionController,
              label: 'Description',
              hint: 'Describe your event...',
              icon: Icons.description,
              maxLines: 4,
            ),
            const SizedBox(height: 24),

            // Schedule Section
            _buildSectionHeader('Event Schedule'),
            const SizedBox(height: 12),

            // Start Date & Time
            Row(
              children: [
                Expanded(
                  child: _buildDateTimeCard(
                    label: 'Start Date',
                    value:
                        '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                    icon: Icons.calendar_today,
                    onTap: () => _selectDate(context, true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateTimeCard(
                    label: 'Start Time',
                    value: _startTime.format(context),
                    icon: Icons.access_time,
                    onTap: () => _selectTime(context, true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // End Date & Time
            Row(
              children: [
                Expanded(
                  child: _buildDateTimeCard(
                    label: 'End Date',
                    value: '${_endDate.day}/${_endDate.month}/${_endDate.year}',
                    icon: Icons.calendar_today,
                    onTap: () => _selectDate(context, false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateTimeCard(
                    label: 'End Time',
                    value: _endTime.format(context),
                    icon: Icons.access_time,
                    onTap: () => _selectTime(context, false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Registration Deadline
            _buildDateTimeCard(
              label: 'Registration Deadline',
              value:
                  '${_registrationDeadline.day}/${_registrationDeadline.month}/${_registrationDeadline.year} at ${_registrationTime.format(context)}',
              icon: Icons.timer,
              onTap: () => _selectRegistrationDeadline(context),
            ),
            const SizedBox(height: 24),

            // Location Section
            _buildSectionHeader('Location & Capacity'),
            const SizedBox(height: 12),

            _buildTextField(
              controller: _venueController,
              label: 'Venue',
              hint: 'e.g. Block A, Room 101',
              icon: Icons.location_on,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Venue is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _maxParticipantsController,
              label: 'Max Participants',
              hint: 'Leave empty for unlimited',
              icon: Icons.people,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

            // Media Section
            _buildSectionHeader('Media (Optional)'),
            const SizedBox(height: 16),
            _buildImagePickerSection(),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline),
                          SizedBox(width: 8),
                          Text(
                            'Create Event',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildImagePickerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Banner Image',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _bannerUrlController,
                label: 'Banner Image URL',
                hint: 'e.g. https://example.com/banner.jpg',
                icon: Icons.image,
                onChanged: (value) {
                  if (value.isNotEmpty && _imageFile != null) {
                    setState(() => _imageFile = null);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            const Text('OR'),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.file_upload),
              label: const Text('Upload'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        if (_imageFile != null) ...[
          const SizedBox(height: 12),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _imageFile!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: IconButton(
                  onPressed: () => setState(() => _imageFile = null),
                  icon: const Icon(Icons.close, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildDropdownField() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedEventType,
      decoration: InputDecoration(
        labelText: 'Event Type',
        prefixIcon: Icon(Icons.category, color: AppColors.primary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      items: _eventTypes.map((type) {
        return DropdownMenuItem(
          value: type,
          child: Text(type[0].toUpperCase() + type.substring(1)),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedEventType = value);
        }
      },
    );
  }

  Widget _buildDateTimeCard({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
