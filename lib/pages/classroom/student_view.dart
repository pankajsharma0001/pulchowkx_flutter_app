import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:confetti/confetti.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pulchowkx_app/services/haptic_service.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:pulchowkx_app/models/classroom.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/empty_states.dart';
import 'shared_widgets.dart';

class StudentView extends StatelessWidget {
  final StudentProfile profile;
  final List<Subject> subjects;
  final ApiService apiService;
  final VoidCallback onRefresh;

  const StudentView({
    super.key,
    required this.profile,
    required this.subjects,
    required this.apiService,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStudentWorkspaceHeader(),
        const SizedBox(height: AppSpacing.lg),
        _buildStatsGrid(),
        const SizedBox(height: AppSpacing.xl),
        // Profile Card
        ProfileCard(profile: profile),
        const SizedBox(height: AppSpacing.lg),

        // Subjects
        Text('Your Subjects', style: AppTextStyles.h4),
        const SizedBox(height: AppSpacing.md),
        if (subjects.isEmpty)
          const EmptyStateWidget(
            type: EmptyStateType.assignments,
            title: 'No Subjects Yet',
            message:
                'Enroll in subjects to start tracking your academic progress.',
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
                      (subject) => SubjectCard(
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

  Widget _buildStatsGrid() {
    int subjectsCount = subjects.length;
    int assignmentsCount = 0;
    int submittedCount = 0;
    int overdueCount = 0;

    for (var subject in subjects) {
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
              child: StatCard(
                label: 'SUBJECTS',
                value: subjectsCount.toString(),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatCard(
                label: 'ASSIGNMENTS',
                value: assignmentsCount.toString(),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'SUBMITTED',
                value: submittedCount.toString(),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatCard(label: 'OVERDUE', value: overdueCount.toString()),
            ),
          ],
        ),
      ],
    );
  }
}

class SubjectCard extends StatefulWidget {
  final Subject subject;
  final ApiService apiService;
  final VoidCallback onRefresh;

  const SubjectCard({
    super.key,
    required this.subject,
    required this.apiService,
    required this.onRefresh,
  });

  @override
  State<SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends State<SubjectCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final pendingCount = widget.subject.pendingCount;
    final hasAssignments = widget.subject.assignments?.isNotEmpty == true;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: Theme.of(context).dividerTheme.color ?? AppColors.border,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: hasAssignments
                ? () {
                    haptics.selectionClick();
                    setState(() => _isExpanded = !_isExpanded);
                  }
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
                color: Theme.of(
                  context,
                ).scaffoldBackgroundColor.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppRadius.lg),
                ),
              ),
              child: Column(
                children: widget.subject.assignments!.map((assignment) {
                  return AssignmentTile(
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

class AssignmentTile extends StatelessWidget {
  final Assignment assignment;
  final ApiService apiService;
  final VoidCallback onRefresh;

  const AssignmentTile({
    super.key,
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
      builder: (context) => SubmitAssignmentDialog(
        assignment: assignment,
        apiService: apiService,
        onSubmitted: onRefresh,
      ),
    );
  }
}

class SubmitAssignmentDialog extends StatefulWidget {
  final Assignment assignment;
  final ApiService apiService;
  final VoidCallback onSubmitted;

  const SubmitAssignmentDialog({
    super.key,
    required this.assignment,
    required this.apiService,
    required this.onSubmitted,
  });

  @override
  State<SubmitAssignmentDialog> createState() => _SubmitAssignmentDialogState();
}

class _SubmitAssignmentDialogState extends State<SubmitAssignmentDialog> {
  late ConfettiController _confettiController;
  final _commentController = TextEditingController();
  File? _selectedFile;
  String? _fileName;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
  }

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
        _confettiController.play();
        widget.onSubmitted();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment submitted!'),
            backgroundColor: AppColors.success,
          ),
        );
        // Let the confetti play for a bit before closing
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.pop(context);
        }
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
    _confettiController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AlertDialog(
          title: Text('Submit: ${widget.assignment.title}'),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: SingleChildScrollView(
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
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.backgroundSecondaryDark
                            : AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: _selectedFile != null
                              ? AppColors.primary
                              : (Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.borderDark
                                    : AppColors.border),
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
          ),
          actions: [
            TextButton(
              onPressed: _isSubmitting ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
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
        ),
        Align(
          alignment: Alignment.center,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            particleDrag: 0.05,
            emissionFrequency: 0.05,
            numberOfParticles: 20,
            gravity: 0.05,
            shouldLoop: false,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple,
              AppColors.primary,
            ],
          ),
        ),
      ],
    );
  }
}
