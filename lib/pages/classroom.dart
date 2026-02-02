import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pulchowkx_app/models/classroom.dart';
import 'package:pulchowkx_app/widgets/shimmer_loaders.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/custom_app_bar.dart';
import 'classroom/shared_widgets.dart';
import 'classroom/student_view.dart';
import 'classroom/teacher_view.dart';
import 'package:pulchowkx_app/services/notification_service.dart';

class ClassroomPage extends StatefulWidget {
  const ClassroomPage({super.key});

  @override
  State<ClassroomPage> createState() => _ClassroomPageState();
}

class _ClassroomPageState extends State<ClassroomPage> {
  final ApiService _apiService = ApiService();

  StudentProfile? _profile;
  List<Faculty> _faculties = [];
  List<Subject> _subjects = [];
  bool _isLoading = true;
  bool _isTeacher = false;
  String? _errorMessage;
  bool _isEditingProfile = false;

  // Setup form state
  Faculty? _selectedFaculty;
  int _selectedSemester = 1;
  DateTime _semesterStartDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _isTeacher = await _apiService.isTeacher();
      _faculties = await _apiService.getFaculties();

      if (_isTeacher) {
        _subjects = await _apiService.getTeacherSubjects();
      } else {
        _profile = await _apiService.getStudentProfile();
        if (_profile != null) {
          _subjects = await _apiService.getMySubjects();

          // Sync setup form state with profile
          if (!_isEditingProfile) {
            _selectedFaculty = _faculties.firstWhere(
              (f) => f.id == _profile!.facultyId,
              orElse: () =>
                  _faculties.isNotEmpty ? _faculties.first : _faculties.first,
            );
            _selectedSemester = _profile!.currentSemester;
            _semesterStartDate = _profile!.semesterStartDate;
          }

          // Subscribe to faculty notifications
          NotificationService.subscribeToFaculty(_profile!.facultyId);
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _setupProfile() async {
    if (_selectedFaculty == null) return;

    final result = await _apiService.upsertStudentProfile(
      StudentProfileRequest(
        facultyId: _selectedFaculty!.id,
        currentSemester: _selectedSemester,
        semesterStartDate: _semesterStartDate.toIso8601String(),
        autoAdvance: true,
      ),
    );

    if (result['success'] == true) {
      if (mounted) {
        setState(() => _isEditingProfile = false);
      }
      await _loadData();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to save profile'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(currentPage: AppPage.classroom),
      body: Container(
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.light
              ? AppColors.heroGradient
              : AppColors.heroGradientDark,
        ),
        child: RefreshIndicator(
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            await _loadData();
          },
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: AppSpacing.lg),
                if (_isLoading)
                  ClassroomShimmer(isTeacher: _isTeacher)
                else if (_errorMessage != null)
                  _buildError()
                else
                  _buildBodyContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(_errorMessage!, style: AppTextStyles.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isTeacher)
          TeacherView(
            subjects: _subjects,
            apiService: _apiService,
            onRefresh: _loadData,
          )
        else if (_profile == null || _isEditingProfile)
          SetupForm(
            faculties: _faculties,
            selectedFaculty: _selectedFaculty,
            selectedSemester: _selectedSemester,
            semesterStartDate: _semesterStartDate,
            isEditingProfile: _isEditingProfile,
            onFacultyChanged: (value) => setState(() {
              _selectedFaculty = value;
              _selectedSemester = 1;
            }),
            onSemesterChanged: (value) =>
                setState(() => _selectedSemester = value),
            onStartDateChanged: (value) =>
                setState(() => _semesterStartDate = value),
            onSubmit: _setupProfile,
            onCancel: () => setState(() => _isEditingProfile = false),
          )
        else
          StudentView(
            profile: _profile!,
            subjects: _subjects,
            apiService: _apiService,
            isEditingProfile: _isEditingProfile,
            onRefresh: _loadData,
            onEditProfile: () => setState(() => _isEditingProfile = true),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Icon(
            Icons.school_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Classroom', style: AppTextStyles.h3),
              Text(
                _isTeacher
                    ? 'Manage your subjects and assignments'
                    : 'Track your subjects and assignments',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (_profile != null)
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
          ),
      ],
    );
  }
}
