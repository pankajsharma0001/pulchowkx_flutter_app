import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pulchowkx_app/services/haptic_service.dart';
import 'package:pulchowkx_app/models/classroom.dart';
import 'package:pulchowkx_app/widgets/shimmer_loaders.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/custom_app_bar.dart';
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
  List<Subject> _subjects = [];
  bool _isLoading = true;
  bool _isTeacher = false;
  String? _errorMessage;

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

      if (_isTeacher) {
        _subjects = await _apiService.getTeacherSubjects();
      } else {
        _profile = await _apiService.getStudentProfile();
        if (_profile != null) {
          _subjects = await _apiService.getMySubjects();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(currentPage: AppPage.classroom),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.light
              ? AppColors.heroGradient
              : AppColors.heroGradientDark,
        ),
        child: RefreshIndicator(
          onRefresh: () async {
            haptics.mediumImpact();
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
    final user = FirebaseAuth.instance.currentUser;
    final String email = user?.email ?? '';
    final bool isPulchowkEmail = email.endsWith('@pcampus.edu.np');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isPulchowkEmail) _buildProfilePendingWarning(),
        if (_isTeacher)
          TeacherView(
            subjects: _subjects,
            apiService: _apiService,
            onRefresh: _loadData,
          )
        else if (_profile != null)
          StudentView(
            profile: _profile!,
            subjects: _subjects,
            apiService: _apiService,
            onRefresh: _loadData,
          )
        else if (isPulchowkEmail)
          _buildNoProfileMessage(),
      ],
    );
  }

  Widget _buildProfilePendingWarning() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Adaptive colors for the warning card
    final bgColor = isDark ? const Color(0xFF2C2410) : const Color(0xFFFFF9E7);
    final borderColor = isDark
        ? const Color(0xFF4D3D1F)
        : const Color(0xFFFFEFB7);
    final iconBgColor = isDark
        ? const Color(0xFF3D3218)
        : const Color(0xFFFFF1C0);
    final textColor = isDark
        ? const Color(0xFFFFD97D)
        : const Color(0xFF8A5B00);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              Icons.priority_high_rounded,
              color: textColor,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile Pending',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your profile will be created when you sign in with a valid Pulchowk Campus email.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: textColor.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoProfileMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 64, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text('Profile not set up', style: AppTextStyles.h4),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your profile will be automatically configured\nbased on your college email.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(onPressed: _loadData, child: const Text('Refresh')),
          ],
        ),
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
      ],
    );
  }
}
