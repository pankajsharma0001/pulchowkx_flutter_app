import 'package:flutter/material.dart';
import 'package:pulchowkx_app/services/haptic_service.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pulchowkx_app/models/classroom.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/empty_states.dart';
import 'package:pulchowkx_app/widgets/shimmer_loaders.dart';
import 'shared_widgets.dart';

class TeacherView extends StatelessWidget {
  final List<Subject> subjects;
  final ApiService apiService;
  final VoidCallback onRefresh;

  const TeacherView({
    super.key,
    required this.subjects,
    required this.apiService,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
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
            Text('Your Subjects (${subjects.length})', style: AppTextStyles.h4),
            TextButton.icon(
              onPressed: () => _showAddSubjectDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Subject'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (subjects.isEmpty)
          const EmptyStateWidget(
            type: EmptyStateType.assignments,
            title: 'No Subjects Assigned',
            message:
                'Add subjects to your workspace to start managing assignments.',
          )
        else
          AnimationLimiter(
            child: Column(
              children: AnimationConfiguration.toStaggeredList(
                duration: const Duration(milliseconds: 375),
                childAnimationBuilder: (widget) =>
                    ScaleAnimation(child: FadeInAnimation(child: widget)),
                children: subjects
                    .map(
                      (subject) => TeacherSubjectCard(
                        subject: subject,
                        apiService: apiService,
                        onRefresh: onRefresh,
                      ),
                    )
                    .toList(),
              ),
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
          style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          'Manage your curriculum, track student progress, and organize assignments effortlessly.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildTeacherStatsGrid() {
    int assignmentsCount = 0;
    int classworkCount = 0;
    int homeworkCount = 0;

    for (var subject in subjects) {
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
              child: StatCard(
                label: 'Subjects',
                value: subjects.length.toString(),
                color: const Color(0xFF0891B2), // cyan-600
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatCard(
                label: 'Active Tasks',
                value: assignmentsCount.toString(),
                color: const Color(0xFF6366F1), // indigo-500
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Classwork',
                value: classworkCount.toString(),
                color: const Color(0xFF7C3AED), // purple-600
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatCard(
                label: 'Homework',
                value: homeworkCount.toString(),
                color: const Color(0xFF10B981), // emerald-500
              ),
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
          AddTeacherSubjectDialog(apiService: apiService, onAdded: onRefresh),
    );
  }
}

class TeacherSubjectCard extends StatelessWidget {
  final Subject subject;
  final ApiService apiService;
  final VoidCallback onRefresh;

  const TeacherSubjectCard({
    super.key,
    required this.subject,
    required this.apiService,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final assignmentCount = subject.assignments?.length ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: Theme.of(context).dividerTheme.color ?? AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.05 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Center(
                child: Text(
                  subject.code ?? subject.title[0],
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
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
                    subject.title,
                    style: AppTextStyles.h4.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'Semester ${subject.semesterNumber}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('•', style: TextStyle(color: AppColors.textMuted)),
                      const SizedBox(width: 8),
                      Text(
                        '$assignmentCount assignments',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filledTonal(
              onPressed: () => _showCreateAssignmentDialog(context),
              icon: const Icon(Icons.add_rounded),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                foregroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateAssignmentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CreateAssignmentDialog(
        subjectId: subject.id,
        apiService: apiService,
        onCreated: onRefresh,
      ),
    );
  }
}

class TeacherAssignmentTile extends StatelessWidget {
  final Assignment assignment;
  final ApiService apiService;

  const TeacherAssignmentTile({
    super.key,
    required this.assignment,
    required this.apiService,
  });

  @override
  Widget build(BuildContext context) {
    final bool isHomework = assignment.type == AssignmentType.homework;
    final Color typeColor = isHomework
        ? const Color(0xFF7C3AED)
        : AppColors.primary;
    final Color typeBg = typeColor.withValues(alpha: 0.1);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 4,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: typeBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: typeColor.withValues(alpha: 0.2)),
                ),
                child: Text(
                  isHomework ? 'HOMEWORK' : 'CLASSWORK',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: typeColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (assignment.dueAt != null) ...[
                const SizedBox(width: 8),
                Text(
                  'Due ${DateFormat('MMM dd').format(assignment.dueAt!)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            assignment.title,
            style: AppTextStyles.labelMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      trailing: TextButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AssignmentSubmissionsDialog(
              assignmentId: assignment.id,
              assignmentTitle: assignment.title,
              apiService: apiService,
            ),
          );
        },
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        child: const Text('View Submissions'),
      ),
    );
  }
}

class AssignmentSubmissionsDialog extends StatefulWidget {
  final int assignmentId;
  final String assignmentTitle;
  final ApiService apiService;

  const AssignmentSubmissionsDialog({
    super.key,
    required this.assignmentId,
    required this.assignmentTitle,
    required this.apiService,
  });

  @override
  State<AssignmentSubmissionsDialog> createState() =>
      _AssignmentSubmissionsDialogState();
}

class _AssignmentSubmissionsDialogState
    extends State<AssignmentSubmissionsDialog> {
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

  Future<void> _handleExportSubmissions(String format) async {
    try {
      final url = await widget.apiService.getExportAssignmentSubmissionsUrl(
        widget.assignmentId,
        format,
      );

      if (url != null) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showSnackBar('Could not launch export URL', isError: true);
        }
      }
    } catch (e) {
      _showSnackBar('Failed to generate export URL', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.assignmentTitle,
                  style: AppTextStyles.h4.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!_isLoading && _submissions.isNotEmpty)
            Row(
              children: [
                Text(
                  '${_submissions.length} Submissions',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                _buildExportChip(
                  label: 'CSV',
                  icon: Icons.table_chart_rounded,
                  onTap: () => _handleExportSubmissions('csv'),
                ),
                const SizedBox(width: AppSpacing.xs),
                _buildExportChip(
                  label: 'PDF',
                  icon: Icons.picture_as_pdf_rounded,
                  onTap: () => _handleExportSubmissions('pdf'),
                ),
              ],
            ),
        ],
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: BoxShimmer(height: double.infinity),
              )
            : _submissions.isEmpty
            ? const EmptyStateWidget(
                type: EmptyStateType.submissions,
                message: 'No submissions received yet for this assignment.',
              )
            : ListView.builder(
                itemCount: _submissions.length,
                itemBuilder: (context, index) {
                  final submission = _submissions[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryLight,
                      backgroundImage: submission.student?.image != null
                          ? CachedNetworkImageProvider(
                              submission.student!.image!,
                            )
                          : null,
                      child: submission.student?.image == null
                          ? const Icon(Icons.person, color: AppColors.primary)
                          : null,
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

  Widget _buildExportChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        haptics.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CreateAssignmentDialog extends StatefulWidget {
  final int subjectId;
  final ApiService apiService;
  final VoidCallback onCreated;

  const CreateAssignmentDialog({
    super.key,
    required this.subjectId,
    required this.apiService,
    required this.onCreated,
  });

  @override
  State<CreateAssignmentDialog> createState() => _CreateAssignmentDialogState();
}

class _CreateAssignmentDialogState extends State<CreateAssignmentDialog> {
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
      title: Text(
        'Create Assignment',
        style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w900),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title *',
                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                hintText: 'Enter assignment title',
                filled: true,
                fillColor: Theme.of(
                  context,
                ).scaffoldBackgroundColor.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(AppSpacing.md),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                hintText: 'Add instructions (optional)',
                filled: true,
                fillColor: Theme.of(
                  context,
                ).scaffoldBackgroundColor.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(AppSpacing.md),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Assignment Type',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: AssignmentType.values.map((t) {
                final isSelected = _type == t;
                final color = t == AssignmentType.homework
                    ? const Color(0xFF7C3AED)
                    : AppColors.primary;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(t.label),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _type = t),
                    selectedColor: color.withValues(alpha: 0.1),
                    checkmarkColor: color,
                    labelStyle: TextStyle(
                      color: isSelected ? color : AppColors.textMuted,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      side: BorderSide(
                        color: isSelected
                            ? color.withValues(alpha: 0.3)
                            : AppColors.border,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Due Date',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
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
                  color: Theme.of(
                    context,
                  ).scaffoldBackgroundColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      _dueDate != null
                          ? DateFormat('MMM dd, yyyy').format(_dueDate!)
                          : 'Set due date (optional)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _dueDate != null
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: AppColors.textMuted,
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

class AddTeacherSubjectDialog extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onAdded;

  const AddTeacherSubjectDialog({
    super.key,
    required this.apiService,
    required this.onAdded,
  });

  @override
  State<AddTeacherSubjectDialog> createState() =>
      _AddTeacherSubjectDialogState();
}

class _AddTeacherSubjectDialogState extends State<AddTeacherSubjectDialog> {
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
      title: Text(
        'Add Subject',
        style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w900),
      ),
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
                DropdownButtonFormField<Faculty>(
                  initialValue: _selectedFaculty,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Faculty',
                    labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).scaffoldBackgroundColor.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
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
                const SizedBox(height: AppSpacing.lg),
                if (_selectedFaculty != null) ...[
                  const Text(
                    'Semester',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(
                        _selectedFaculty!.semestersCount,
                        (index) {
                          final sem = index + 1;
                          final isSelected = _selectedSemester == sem;
                          return Padding(
                            padding: const EdgeInsets.only(
                              right: AppSpacing.xs,
                            ),
                            child: ChoiceChip(
                              label: Text('Sem $sem'),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedSemester = sem);
                                  _loadSubjects();
                                }
                              },
                              selectedColor: AppColors.primary.withValues(
                                alpha: 0.1,
                              ),
                              checkmarkColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                fontSize: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.primary.withValues(alpha: 0.3)
                                      : AppColors.border,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (_availableSubjects.isNotEmpty)
                  DropdownButtonFormField<Subject>(
                    initialValue: _selectedSubject,
                    decoration: InputDecoration(
                      labelText: 'Subject',
                      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                      filled: true,
                      fillColor: Theme.of(
                        context,
                      ).scaffoldBackgroundColor.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide.none,
                      ),
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
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
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
