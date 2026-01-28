import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pulchowkx_app/models/classroom.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/custom_app_bar.dart';

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
              orElse: () => _faculties.isNotEmpty
                  ? _faculties.first
                  : _faculties.first, // Fallback if not found
            );
            _selectedSemester = _profile!.currentSemester;
            _semesterStartDate = _profile!.semesterStartDate;
          }
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
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _errorMessage != null
            ? _buildError()
            : _buildContent(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
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
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: AppSpacing.lg),
          if (_isTeacher)
            _buildTeacherView()
          else if (_profile == null || _isEditingProfile)
            _buildSetupForm()
          else
            _buildStudentView(),
        ],
      ),
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

  Widget _buildSetupForm() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditingProfile
                          ? 'Update Your Profile'
                          : 'Set Up Your Profile',
                      style: AppTextStyles.h4,
                    ),
                    Text(
                      _isEditingProfile
                          ? 'Modify your semester details below'
                          : 'Tell us about your semester to get started',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Faculty Selection
          Text('Faculty *', style: AppTextStyles.labelMedium),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Faculty>(
                value: _selectedFaculty,
                isExpanded: true,
                hint: const Text('Select your faculty'),
                items: _faculties
                    .map((f) => DropdownMenuItem(value: f, child: Text(f.name)))
                    .toList(),
                onChanged: (value) => setState(() {
                  _selectedFaculty = value;
                  _selectedSemester = 1;
                }),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Semester Selection
          if (_selectedFaculty != null) ...[
            Text('Current Semester *', style: AppTextStyles.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: List.generate(_selectedFaculty!.semestersCount, (
                index,
              ) {
                final sem = index + 1;
                final isSelected = _selectedSemester == sem;
                return ChoiceChip(
                  label: Text('Sem $sem'),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedSemester = sem),
                  selectedColor: AppColors.primaryLight,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                );
              }),
            ),

            const SizedBox(height: AppSpacing.md),

            // Start Date
            Text('Semester Start Date', style: AppTextStyles.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            GestureDetector(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _semesterStartDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  setState(() => _semesterStartDate = date);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      DateFormat('MMM dd, yyyy').format(_semesterStartDate),
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: _setupProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: Text(
                      _isEditingProfile ? 'Update Profile' : 'Save Profile',
                    ),
                  ),
                  if (_isEditingProfile) ...[
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: () =>
                          setState(() => _isEditingProfile = false),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStudentWorkspaceHeader(),
        const SizedBox(height: AppSpacing.lg),
        _buildStatsRow(),
        const SizedBox(height: AppSpacing.xl),
        // Profile Card
        _buildProfileCard(),
        const SizedBox(height: AppSpacing.lg),

        // Subjects
        Text('Your Subjects', style: AppTextStyles.h4),
        const SizedBox(height: AppSpacing.md),
        if (_subjects.isEmpty)
          _buildEmptySubjects()
        else
          ..._subjects.map(
            (subject) => _SubjectCard(
              subject: subject,
              apiService: _apiService,
              onRefresh: _loadData,
            ),
          ),
      ],
    );
  }

  Widget _buildProfileCard() {
    final progress = _profile!.semesterProgress;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _profile!.faculty?.name ?? 'Unknown Faculty',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Semester ${_profile!.currentSemester}',
                    style: AppTextStyles.h3.copyWith(color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  '${progress.toInt()}%',
                  style: AppTextStyles.h4.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Edit Profile Button
          GestureDetector(
            onTap: () {
              setState(() => _isEditingProfile = true);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.edit,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'Edit Profile',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('dd MMM yyyy').format(_profile!.semesterStartDate),
                style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
              ),
              if (_profile!.semesterEndDate != null)
                Text(
                  DateFormat('dd MMM yyyy').format(_profile!.semesterEndDate!),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white70,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySubjects() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.book_outlined, size: 48, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No subjects for this semester',
            style: AppTextStyles.bodyMedium,
          ),
          Text(
            'Subjects will appear here once available',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTeacherWorkspaceHeader(),
        const SizedBox(height: AppSpacing.lg),
        _buildTeacherStatsGrid(),
        const SizedBox(height: AppSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Subjects (${_subjects.length})',
              style: AppTextStyles.h4,
            ),
            TextButton.icon(
              onPressed: () => _showAddSubjectDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Subject'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (_subjects.isEmpty)
          _buildEmptySubjects()
        else
          ..._subjects.map(
            (subject) => _TeacherSubjectCard(
              subject: subject,
              apiService: _apiService,
              onRefresh: _loadData,
            ),
          ),
      ],
    );
  }

  Widget _buildTeacherWorkspaceHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Teacher Workspace',
          style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Post classwork, review submissions, and keep every subject on pace.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildTeacherStatsGrid() {
    int subjectsCount = _subjects.length;
    int assignmentsCount = 0;
    int classworkCount = 0;
    int homeworkCount = 0;

    for (var subject in _subjects) {
      if (subject.assignments != null) {
        assignmentsCount += subject.assignments!.length;
        for (var assignment in subject.assignments!) {
          if (assignment.type == AssignmentType.classwork) {
            classworkCount += 1;
          } else if (assignment.type == AssignmentType.homework) {
            homeworkCount += 1;
          }
        }
      }
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard('SUBJECTS', subjectsCount.toString()),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildStatCard('ASSIGNMENTS', assignmentsCount.toString()),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildStatCard('CLASSWORK', classworkCount.toString()),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildStatCard('HOMEWORK', homeworkCount.toString()),
            ),
          ],
        ),
      ],
    );
  }

  void _showAddSubjectDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) =>
          _AddTeacherSubjectDialog(apiService: _apiService, onAdded: _loadData),
    );
  }

  Widget _buildStudentWorkspaceHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Student Workspace',
          style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Track your semester subjects, deadlines, and submissions in one place.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    int subjectsCount = _subjects.length;
    int assignmentsCount = 0;
    int submittedCount = 0;
    int overdueCount = 0;

    for (var subject in _subjects) {
      if (subject.assignments != null) {
        assignmentsCount += subject.assignments!.length;
        for (var assignment in subject.assignments!) {
          if (assignment.submission != null) {
            submittedCount += 1;
          } else if (assignment.isOverdue) {
            overdueCount += 1;
          }
        }
      }
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard('SUBJECTS', subjectsCount.toString()),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildStatCard('ASSIGNMENTS', assignmentsCount.toString()),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildStatCard('SUBMITTED', submittedCount.toString()),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _buildStatCard('OVERDUE', overdueCount.toString())),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 1.2,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _SubjectCard extends StatefulWidget {
  final Subject subject;
  final ApiService apiService;
  final VoidCallback onRefresh;

  const _SubjectCard({
    required this.subject,
    required this.apiService,
    required this.onRefresh,
  });

  @override
  State<_SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends State<_SubjectCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final pendingCount = widget.subject.pendingCount;
    final hasAssignments = widget.subject.assignments?.isNotEmpty == true;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: hasAssignments
                ? () => setState(() => _isExpanded = !_isExpanded)
                : null,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 207, 225, 240),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Center(
                      child: Text(
                        widget.subject.code ?? widget.subject.title[0],
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.subject.title,
                          style: AppTextStyles.labelMedium,
                        ),
                        if (widget.subject.isElective)
                          Text(
                            'Elective',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.accent,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (hasAssignments) ...[
                    if (pendingCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.errorLight,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          '$pendingCount pending',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.error,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textMuted,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_isExpanded && hasAssignments)
            Container(
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppRadius.lg),
                ),
              ),
              child: Column(
                children: widget.subject.assignments!.map((assignment) {
                  return _AssignmentTile(
                    assignment: assignment,
                    apiService: widget.apiService,
                    onRefresh: widget.onRefresh,
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  final Assignment assignment;
  final ApiService apiService;
  final VoidCallback onRefresh;

  const _AssignmentTile({
    required this.assignment,
    required this.apiService,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isSubmitted = assignment.isSubmitted;
    final isOverdue = assignment.isOverdue;
    final isDueSoon = assignment.isDueSoon;

    return ListTile(
      leading: Icon(
        isSubmitted
            ? Icons.check_circle
            : assignment.type == AssignmentType.homework
            ? Icons.home_work_outlined
            : Icons.class_outlined,
        color: isSubmitted
            ? AppColors.success
            : isOverdue
            ? AppColors.error
            : AppColors.primary,
      ),
      title: Text(assignment.title, style: AppTextStyles.labelMedium),
      subtitle: Row(
        children: [
          Text(
            assignment.type.label,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          if (assignment.dueAt != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.access_time,
              size: 12,
              color: isOverdue
                  ? AppColors.error
                  : isDueSoon
                  ? Colors.orange
                  : AppColors.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              DateFormat('MMM dd, yyyy').format(assignment.dueAt!),
              style: AppTextStyles.bodySmall.copyWith(
                color: isOverdue
                    ? AppColors.error
                    : isDueSoon
                    ? Colors.orange
                    : AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
      trailing: TextButton(
        onPressed: () => _showSubmitDialog(context),
        child: Text(isSubmitted ? 'Resubmit' : 'Submit'),
      ),
    );
  }

  void _showSubmitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _SubmitAssignmentDialog(
        assignment: assignment,
        apiService: apiService,
        onSubmitted: onRefresh,
      ),
    );
  }
}

class _SubmitAssignmentDialog extends StatefulWidget {
  final Assignment assignment;
  final ApiService apiService;
  final VoidCallback onSubmitted;

  const _SubmitAssignmentDialog({
    required this.assignment,
    required this.apiService,
    required this.onSubmitted,
  });

  @override
  State<_SubmitAssignmentDialog> createState() =>
      _SubmitAssignmentDialogState();
}

class _SubmitAssignmentDialogState extends State<_SubmitAssignmentDialog> {
  final _commentController = TextEditingController();
  File? _selectedFile;
  String? _fileName;
  bool _isSubmitting = false;

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        final ext =
            file.extension?.toLowerCase() ??
            file.name.split('.').last.toLowerCase();
        final allowed = ['jpg', 'jpeg', 'png', 'pdf'];

        if (!allowed.contains(ext)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Only Image and PDF files are allowed'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedFile = File(file.path!);
          _fileName = file.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a file'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await widget.apiService.submitAssignment(
      widget.assignment.id,
      _selectedFile!,
      comment: _commentController.text.isNotEmpty
          ? _commentController.text
          : null,
    );

    if (mounted) {
      if (result['success'] == true) {
        Navigator.pop(context);
        widget.onSubmitted();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment submitted!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to submit'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Submit: ${widget.assignment.title}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.assignment.description != null) ...[
              Text(
                widget.assignment.description!,
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            GestureDetector(
              onTap: _pickFile,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: _selectedFile != null
                        ? AppColors.primary
                        : AppColors.border,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _selectedFile != null
                          ? Icons.insert_drive_file
                          : Icons.upload_file,
                      color: AppColors.primary,
                      size: 32,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _fileName ?? 'Tap to select file',
                      style: AppTextStyles.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Add a comment (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}

class _TeacherSubjectCard extends StatefulWidget {
  final Subject subject;
  final ApiService apiService;
  final VoidCallback onRefresh;

  const _TeacherSubjectCard({
    required this.subject,
    required this.apiService,
    required this.onRefresh,
  });

  @override
  State<_TeacherSubjectCard> createState() => _TeacherSubjectCardState();
}

class _TeacherSubjectCardState extends State<_TeacherSubjectCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final assignmentCount = widget.subject.assignments?.length ?? 0;
    final hasAssignments = assignmentCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Center(
                    child: Text(
                      widget.subject.code ?? widget.subject.title[0],
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.subject.title,
                        style: AppTextStyles.labelMedium,
                      ),
                      Text(
                        'Semester ${widget.subject.semesterNumber}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        '$assignmentCount assignments',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showCreateAssignmentDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
                if (hasAssignments) ...[
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    icon: Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  ),
                ],
              ],
            ),
          ),
          if (_isExpanded && hasAssignments)
            Container(
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppRadius.lg),
                ),
              ),
              child: Column(
                children: widget.subject.assignments!.map((assignment) {
                  return _TeacherAssignmentTile(
                    assignment: assignment,
                    apiService: widget.apiService,
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  void _showCreateAssignmentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CreateAssignmentDialog(
        subjectId: widget.subject.id,
        apiService: widget.apiService,
        onCreated: widget.onRefresh,
      ),
    );
  }
}

class _TeacherAssignmentTile extends StatelessWidget {
  final Assignment assignment;
  final ApiService apiService;

  const _TeacherAssignmentTile({
    required this.assignment,
    required this.apiService,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        assignment.type == AssignmentType.homework
            ? Icons.home_work_outlined
            : Icons.class_outlined,
        color: AppColors.primary,
      ),
      title: Text(assignment.title, style: AppTextStyles.labelMedium),
      subtitle: Text(
        assignment.dueAt != null
            ? 'Due: ${DateFormat('MMM dd, yyyy').format(assignment.dueAt!)}'
            : 'No due date',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => _AssignmentSubmissionsDialog(
                  assignmentId: assignment.id,
                  assignmentTitle: assignment.title,
                  apiService: apiService,
                ),
              );
            },
            child: const Text('View Submissions'),
          ),
        ],
      ),
    );
  }
}

class _AssignmentSubmissionsDialog extends StatefulWidget {
  final int assignmentId;
  final String assignmentTitle;
  final ApiService apiService;

  const _AssignmentSubmissionsDialog({
    required this.assignmentId,
    required this.assignmentTitle,
    required this.apiService,
  });

  @override
  State<_AssignmentSubmissionsDialog> createState() =>
      _AssignmentSubmissionsDialogState();
}

class _AssignmentSubmissionsDialogState
    extends State<_AssignmentSubmissionsDialog> {
  List<AssignmentSubmission> _submissions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    final submissions = await widget.apiService.getAssignmentSubmissions(
      widget.assignmentId,
    );
    if (mounted) {
      setState(() {
        _submissions = submissions;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Submissions: ${widget.assignmentTitle}'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _submissions.isEmpty
            ? const Center(child: Text('No submissions yet'))
            : ListView.builder(
                itemCount: _submissions.length,
                itemBuilder: (context, index) {
                  final submission = _submissions[index];
                  // Assuming submission has student info
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primaryLight,
                      child: Icon(Icons.person, color: AppColors.primary),
                    ),
                    title: Text(
                      submission.student?.name ?? submission.studentId,
                    ),
                    subtitle: Text(
                      'Submitted: ${DateFormat('MMM dd, yyyy HH:mm').format(submission.submittedAt.toLocal())}',
                    ),
                    onTap: () async {
                      final uri = Uri.parse(submission.fileUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _CreateAssignmentDialog extends StatefulWidget {
  final int subjectId;
  final ApiService apiService;
  final VoidCallback onCreated;

  const _CreateAssignmentDialog({
    required this.subjectId,
    required this.apiService,
    required this.onCreated,
  });

  @override
  State<_CreateAssignmentDialog> createState() =>
      _CreateAssignmentDialogState();
}

class _CreateAssignmentDialogState extends State<_CreateAssignmentDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  AssignmentType _type = AssignmentType.homework;
  DateTime? _dueDate;
  bool _isCreating = false;

  Future<void> _create() async {
    if (_titleController.text.isEmpty) return;

    setState(() => _isCreating = true);

    final result = await widget.apiService.createAssignment(
      CreateAssignmentRequest(
        subjectId: widget.subjectId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        type: _type.value,
        dueAt: _dueDate?.toIso8601String(),
      ),
    );

    if (mounted) {
      if (result['success'] == true) {
        Navigator.pop(context);
        widget.onCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment created!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to create'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Assignment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: AssignmentType.values.map((t) {
                final isSelected = _type == t;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(t.label),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _type = t),
                    selectedColor: AppColors.primaryLight,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),
            GestureDetector(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 7)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  setState(() => _dueDate = date);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      _dueDate != null
                          ? DateFormat('MMM dd, yyyy').format(_dueDate!)
                          : 'Set due date (optional)',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _create,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: _isCreating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

class _AddTeacherSubjectDialog extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onAdded;

  const _AddTeacherSubjectDialog({
    required this.apiService,
    required this.onAdded,
  });

  @override
  State<_AddTeacherSubjectDialog> createState() =>
      _AddTeacherSubjectDialogState();
}

class _AddTeacherSubjectDialogState extends State<_AddTeacherSubjectDialog> {
  List<Faculty> _faculties = [];
  List<Subject> _availableSubjects = [];
  Faculty? _selectedFaculty;
  int _selectedSemester = 1;
  Subject? _selectedSubject;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadFaculties();
  }

  Future<void> _loadFaculties() async {
    final faculties = await widget.apiService.getFaculties();
    if (mounted) {
      setState(() {
        _faculties = faculties;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSubjects() async {
    if (_selectedFaculty == null) return;
    setState(() => _isLoading = true);
    final subjects = await widget.apiService.getSubjects(
      facultyId: _selectedFaculty!.id,
      semester: _selectedSemester,
    );
    if (mounted) {
      setState(() {
        _availableSubjects = subjects;
        _selectedSubject = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _addSubject() async {
    if (_selectedSubject == null) return;

    setState(() => _isSaving = true);

    final result = await widget.apiService.addTeacherSubject(
      _selectedSubject!.id,
    );

    if (mounted) {
      if (result['success'] == true) {
        Navigator.pop(context);
        widget.onAdded();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subject added successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to add subject'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Subject'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoading && _faculties.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                // Faculty
                DropdownButtonFormField<Faculty>(
                  initialValue: _selectedFaculty,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Faculty',
                    border: OutlineInputBorder(),
                  ),
                  items: _faculties
                      .map(
                        (f) => DropdownMenuItem(
                          value: f,
                          child: Text(f.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedFaculty = value;
                      _selectedSemester = 1;
                      _availableSubjects = [];
                      _selectedSubject = null;
                    });
                    _loadSubjects();
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // Semester
                if (_selectedFaculty != null) ...[
                  const Text('Semester'),
                  const SizedBox(height: AppSpacing.sm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(
                        _selectedFaculty!.semestersCount,
                        (index) {
                          final sem = index + 1;
                          return Padding(
                            padding: const EdgeInsets.only(
                              right: AppSpacing.xs,
                            ),
                            child: ChoiceChip(
                              label: Text('Sem $sem'),
                              selected: _selectedSemester == sem,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedSemester = sem);
                                  _loadSubjects();
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Subject
                if (_availableSubjects.isNotEmpty)
                  DropdownButtonFormField<Subject>(
                    initialValue: _selectedSubject,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                    ),
                    items: _availableSubjects
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(
                              s.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedSubject = value),
                    isExpanded: true,
                  )
                else if (_selectedFaculty != null && !_isLoading)
                  const Text(
                    'No subjects found for this semester',
                    style: TextStyle(color: AppColors.textMuted),
                  ),

                if (_isLoading &&
                    _availableSubjects.isEmpty &&
                    _selectedFaculty != null)
                  const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving || _selectedSubject == null ? null : _addSubject,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}
