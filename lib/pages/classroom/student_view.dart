import 'dart:io';
import 'dart:ui';
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

enum ClassroomView { todo, completed, subjects }

class StudentView extends StatefulWidget {
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
  State<StudentView> createState() => _StudentViewState();
}

class _StudentViewState extends State<StudentView> {
  ClassroomView _currentView = ClassroomView.todo;

  List<Map<String, dynamic>> get _todoAssignments {
    final List<Map<String, dynamic>> all = [];
    for (var subject in widget.subjects) {
      if (subject.assignments != null) {
        for (var assignment in subject.assignments!) {
          if (assignment.submission == null) {
            all.add({
              'assignment': assignment,
              'subjectTitle': subject.title,
              'subjectCode': subject.code,
            });
          }
        }
      }
    }
    all.sort((a, b) {
      final aDue = (a['assignment'] as Assignment).dueAt;
      final bDue = (b['assignment'] as Assignment).dueAt;
      if (aDue == null && bDue == null) return 0;
      if (aDue == null) return 1;
      if (bDue == null) return -1;
      return aDue.compareTo(bDue);
    });
    return all;
  }

  List<Map<String, dynamic>> get _completedAssignments {
    final List<Map<String, dynamic>> all = [];
    for (var subject in widget.subjects) {
      if (subject.assignments != null) {
        for (var assignment in subject.assignments!) {
          if (assignment.submission != null) {
            all.add({
              'assignment': assignment,
              'subjectTitle': subject.title,
              'subjectCode': subject.code,
            });
          }
        }
      }
    }
    all.sort((a, b) {
      final aSubAt = (a['assignment'] as Assignment).submission?.submittedAt;
      final bSubAt = (b['assignment'] as Assignment).submission?.submittedAt;
      if (aSubAt == null && bSubAt == null) return 0;
      if (aSubAt == null) return 1;
      if (bSubAt == null) return -1;
      return bSubAt.compareTo(aSubAt);
    });
    return all;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStudentWorkspaceHeader(),
        const SizedBox(height: AppSpacing.lg),
        _buildStatsGrid(),
        const SizedBox(height: AppSpacing.xl),

        // View Toggles
        _buildViewToggles(),
        const SizedBox(height: AppSpacing.lg),

        // Content based on selection
        _buildContent(),
      ],
    );
  }

  Widget _buildViewToggles() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.white.withValues(alpha: 0.8)
              : AppColors.backgroundSecondaryDark.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: Theme.of(context).dividerTheme.color ?? AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildToggleButton(
                  'To Do',
                  ClassroomView.todo,
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.1),
                  _todoAssignments.length,
                ),
                _buildToggleButton(
                  'Completed',
                  ClassroomView.completed,
                  AppColors.success,
                  AppColors.success.withValues(alpha: 0.1),
                  null,
                ),
                _buildToggleButton(
                  'Subjects',
                  ClassroomView.subjects,
                  const Color(0xFF3B82F6), // blue-500
                  const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton(
    String label,
    ClassroomView view,
    Color activeColor,
    Color activeBg,
    int? badgeCount,
  ) {
    final bool isActive = _currentView == view;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        haptics.selectionClick();
        setState(() => _currentView = view);
      },
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: isActive && !isDark
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? activeColor : AppColors.textMuted,
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: activeColor,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  badgeCount.toString(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentView) {
      case ClassroomView.todo:
        return _buildAssignmentList(
          _todoAssignments,
          'No pending assignments',
          'You\'re all caught up!',
        );
      case ClassroomView.completed:
        return _buildAssignmentList(
          _completedAssignments,
          'No completed assignments',
          'Assignments you finish will appear here',
        );
      case ClassroomView.subjects:
        return _buildSubjectsGrid();
    }
  }

  Widget _buildAssignmentList(
    List<Map<String, dynamic>> assignments,
    String emptyTitle,
    String emptyMsg,
  ) {
    if (assignments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(
                Icons.assignment_turned_in_outlined,
                size: 64,
                color: AppColors.textMuted.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(emptyTitle, style: AppTextStyles.labelLarge),
              const SizedBox(height: 8),
              Text(
                emptyMsg,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AnimationLimiter(
      child: Column(
        children: AnimationConfiguration.toStaggeredList(
          duration: const Duration(milliseconds: 375),
          childAnimationBuilder: (widget) => FadeInAnimation(
            child: SlideAnimation(verticalOffset: 20, child: widget),
          ),
          children: assignments.map((data) {
            final assignment = data['assignment'] as Assignment;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AssignmentCard(
                assignment: assignment,
                subjectTitle: data['subjectTitle'],
                subjectCode: data['subjectCode'],
                apiService: widget.apiService,
                onRefresh: widget.onRefresh,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSubjectsGrid() {
    if (widget.subjects.isEmpty) {
      return const EmptyStateWidget(
        type: EmptyStateType.assignments,
        title: 'No Subjects Yet',
        message: 'Enroll in subjects to start tracking your academic progress.',
      );
    }

    return AnimationLimiter(
      child: Column(
        children: AnimationConfiguration.toStaggeredList(
          duration: const Duration(milliseconds: 375),
          childAnimationBuilder: (widget) =>
              ScaleAnimation(child: FadeInAnimation(child: widget)),
          children: widget.subjects
              .map(
                (subject) => SubjectCard(
                  subject: subject,
                  apiService: widget.apiService,
                  onRefresh: widget.onRefresh,
                ),
              )
              .toList(),
        ),
      ),
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
    int assignmentsCount = 0;
    int submittedCount = 0;
    int overdueCount = 0;

    for (var subject in widget.subjects) {
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

    int todoCount = assignmentsCount - submittedCount;
    final progress = widget.profile.semesterProgress / 100;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'To Do',
                value: todoCount.toString(),
                color: const Color(0xFF7C3AED), // violet-600
                icon: Icons.assignment_rounded,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatCard(
                label: 'Overdue',
                value: overdueCount.toString(),
                color: const Color(0xFFEF4444), // rose-500
                icon: Icons.error_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Done',
                value: submittedCount.toString(),
                color: const Color(0xFF10B981), // emerald-500
                icon: Icons.check_circle_rounded,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatCard(
                label: 'Semester',
                value: '${(progress * 100).toInt()}%',
                color: const Color(0xFFF59E0B), // amber-500
                progress: progress,
                icon: Icons.school_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class SubjectCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final pendingCount = subject.pendingCount;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: isDark
          ? AppDecorations.glassDark(borderColor: AppColors.borderDark)
          : AppDecorations.glass(borderColor: AppColors.border),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Center(
                child: Text(
                  subject.code ?? subject.title[0],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
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
                  Text(subject.title, style: AppTextStyles.labelLarge),
                  if (subject.isElective)
                    Text(
                      'Elective Subject',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            if (pendingCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '$pendingCount pending',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AssignmentCard extends StatelessWidget {
  final Assignment assignment;
  final String? subjectTitle;
  final String? subjectCode;
  final ApiService apiService;
  final VoidCallback onRefresh;
  final bool isCompact;

  const AssignmentCard({
    super.key,
    required this.assignment,
    this.subjectTitle,
    this.subjectCode,
    required this.apiService,
    required this.onRefresh,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSubmitted = assignment.isSubmitted;
    final bool isOverdue = assignment.isOverdue;
    final bool isDueSoon = assignment.isDueSoon;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Status colors (Rose, Amber, Blue, Emerald)
    Color statusColor;
    Color statusBg;
    String statusLabel;

    if (isSubmitted) {
      statusColor = const Color(0xFF10B981); // emerald-500
      statusBg = const Color(0xFFECFDF5); // emerald-50
      statusLabel = 'Submitted';
    } else if (isOverdue) {
      statusColor = const Color(0xFFFB7185); // rose-400
      statusBg = const Color(0xFFFFF1F2); // rose-50
      statusLabel = 'Overdue';
    } else if (isDueSoon) {
      statusColor = const Color(0xFFF59E0B); // amber-500
      statusBg = const Color(0xFFFFFBEB); // amber-50
      statusLabel = 'Due Soon';
    } else {
      statusColor = const Color(0xFF3B82F6); // blue-500
      statusBg = const Color(0xFFEFF6FF); // blue-50
      statusLabel = 'Pending';
    }

    if (isDark) {
      statusBg = statusColor.withValues(alpha: 0.15);
    }

    return Container(
      margin: isCompact ? const EdgeInsets.only(top: AppSpacing.sm) : null,
      decoration: isDark
          ? AppDecorations.glassDark(
              borderRadius: AppRadius.md,
              borderColor: AppColors.borderDark,
            )
          : AppDecorations.glass(
              borderRadius: AppRadius.md,
              borderColor: AppColors.border,
            ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isCompact && subjectCode != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            subjectCode!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      Text(
                        assignment.title,
                        style: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!isCompact && subjectTitle != null)
                        Text(
                          subjectTitle!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildStatusChip(statusLabel, statusColor, statusBg),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  assignment.type.label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                if (assignment.dueAt != null) ...[
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: isOverdue
                        ? const Color(0xFFFB7185)
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM dd, yyyy').format(assignment.dueAt!),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isOverdue
                          ? const Color(0xFFFB7185)
                          : AppColors.textMuted,
                      fontWeight: isOverdue ? FontWeight.bold : null,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showSubmitDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSubmitted
                      ? Colors.transparent
                      : AppColors.primary,
                  foregroundColor: isSubmitted
                      ? AppColors.primary
                      : Colors.white,
                  elevation: isSubmitted ? 0 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    side: isSubmitted
                        ? BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          )
                        : BorderSide.none,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: Text(
                  isSubmitted ? 'Resubmit Assignment' : 'Submit Assignment',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
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
