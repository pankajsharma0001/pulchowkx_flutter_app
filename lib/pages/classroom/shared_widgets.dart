import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pulchowkx_app/models/classroom.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
  final double? progress;
  final bool animate;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
    this.progress,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final themeColor = color ?? AppColors.primary;
    final borderColor = isDark
        ? themeColor.withValues(alpha: 0.2)
        : themeColor.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: isDark ? 0.05 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: themeColor),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 1,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: AppTextStyles.h2.copyWith(
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.textPrimary,
              height: 1,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: themeColor.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ProfileCard extends StatelessWidget {
  final StudentProfile profile;

  const ProfileCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final progress = profile.semesterProgress;

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
                    profile.faculty?.name ?? 'Unknown Faculty',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Semester ${profile.currentSemester}',
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
                DateFormat('dd MMM yyyy').format(profile.semesterStartDate),
                style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
              ),
              if (profile.semesterEndDate != null)
                Text(
                  DateFormat('dd MMM yyyy').format(profile.semesterEndDate!),
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
}

class SetupForm extends StatelessWidget {
  final List<Faculty> faculties;
  final Faculty? selectedFaculty;
  final int selectedSemester;
  final DateTime semesterStartDate;
  final bool isEditingProfile;
  final Function(Faculty?) onFacultyChanged;
  final Function(int) onSemesterChanged;
  final Function(DateTime) onStartDateChanged;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  const SetupForm({
    super.key,
    required this.faculties,
    required this.selectedFaculty,
    required this.selectedSemester,
    required this.semesterStartDate,
    required this.isEditingProfile,
    required this.onFacultyChanged,
    required this.onSemesterChanged,
    required this.onStartDateChanged,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: Theme.of(context).dividerTheme.color ?? AppColors.border,
        ),
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
                      isEditingProfile
                          ? 'Update Your Profile'
                          : 'Set Up Your Profile',
                      style: AppTextStyles.h4,
                    ),
                    Text(
                      isEditingProfile
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
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: Theme.of(context).dividerTheme.color ?? AppColors.border,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Faculty>(
                value: selectedFaculty,
                isExpanded: true,
                hint: const Text('Select your faculty'),
                items: faculties
                    .map((f) => DropdownMenuItem(value: f, child: Text(f.name)))
                    .toList(),
                dropdownColor: Theme.of(context).cardTheme.color,
                onChanged: onFacultyChanged,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Semester Selection
          if (selectedFaculty != null) ...[
            Text('Current Semester *', style: AppTextStyles.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: List.generate(selectedFaculty!.semestersCount, (index) {
                final sem = index + 1;
                final isSelected = selectedSemester == sem;
                return ChoiceChip(
                  label: Text('Sem $sem'),
                  selected: isSelected,
                  onSelected: (_) => onSemesterChanged(sem),
                  selectedColor: AppColors.primaryLight,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : Theme.of(context).textTheme.bodyMedium?.color,
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
                  initialDate: semesterStartDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  onStartDateChanged(date);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color:
                        Theme.of(context).dividerTheme.color ??
                        AppColors.border,
                  ),
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
                      DateFormat('MMM dd, yyyy').format(semesterStartDate),
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
                    onPressed: onSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: Text(
                      isEditingProfile ? 'Update Profile' : 'Save Profile',
                    ),
                  ),
                  if (isEditingProfile) ...[
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: onCancel,
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
}

class EmptySubjects extends StatelessWidget {
  const EmptySubjects({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: Theme.of(context).dividerTheme.color ?? AppColors.border,
        ),
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
}
