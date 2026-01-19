import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pulchowkx_app/models/event.dart';
import 'package:pulchowkx_app/pages/event_details.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';

class MyEnrollments extends StatefulWidget {
  const MyEnrollments({super.key});

  @override
  State<MyEnrollments> createState() => _MyEnrollmentsState();
}

class _MyEnrollmentsState extends State<MyEnrollments> {
  final ApiService _apiService = ApiService();
  late Future<List<EventRegistration>> _enrollmentsFuture;

  @override
  void initState() {
    super.initState();
    _loadEnrollments();
  }

  void _loadEnrollments() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _enrollmentsFuture = _apiService.getEnrollments(user.uid);
    } else {
      _enrollmentsFuture = Future.value([]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.infoLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.event_available_rounded,
                  size: 20,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('My Event Enrollments', style: AppTextStyles.h4),
              const Spacer(),
              IconButton(
                onPressed: () {
                  setState(() => _loadEnrollments());
                },
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Dynamic Event List
          FutureBuilder<List<EventRegistration>>(
            future: _enrollmentsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              if (snapshot.hasError) {
                return _buildEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Failed to load enrollments',
                  subtitle: 'Please try again later',
                  color: AppColors.error,
                );
              }

              final enrollments = snapshot.data ?? [];
              final activeEnrollments = enrollments
                  .where((e) => e.status == 'registered')
                  .toList();

              if (activeEnrollments.isEmpty) {
                return _buildEmptyState(
                  icon: Icons.event_busy_rounded,
                  title: 'No enrollments yet',
                  subtitle: 'Browse events and register to see them here',
                  color: AppColors.textMuted,
                );
              }

              return Column(
                children: activeEnrollments.map((enrollment) {
                  final event = enrollment.event;
                  if (event == null) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _EventCard(
                      enrollment: enrollment,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                EventDetailsPage(eventId: event.id),
                          ),
                        ).then((_) {
                          // Refresh enrollments when coming back
                          setState(() => _loadEnrollments());
                        });
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 40, color: color.withValues(alpha: 0.5)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatefulWidget {
  final EventRegistration enrollment;
  final VoidCallback onTap;

  const _EventCard({required this.enrollment, required this.onTap});

  @override
  State<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<_EventCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final event = widget.enrollment.event!;
    final dateFormat = DateFormat('EEE, MMM d');

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _isHovered ? AppColors.accentLight : AppColors.background,
          border: Border.all(
            color: _isHovered
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow: AppShadows.colored(AppColors.primary),
                    ),
                    child: const Icon(
                      Icons.calendar_today_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.title, style: AppTextStyles.labelLarge),
                        const SizedBox(height: 2),
                        if (event.club != null)
                          Text(
                            event.club!.name.toUpperCase(),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: 4,
                          children: [
                            _InfoChip(
                              icon: Icons.calendar_month_rounded,
                              label: dateFormat.format(event.eventStartTime),
                            ),
                            _InfoChip(
                              icon: Icons.location_on_rounded,
                              label: event.venue ?? 'TBA',
                            ),
                            _buildStatusBadge(event),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ClubEvent event) {
    Color bgColor;
    Color textColor;
    String text;
    IconData icon;

    if (event.isOngoing) {
      bgColor = AppColors.success.withValues(alpha: 0.15);
      textColor = AppColors.success;
      text = 'LIVE';
      icon = Icons.circle;
    } else if (event.isUpcoming) {
      bgColor = AppColors.info.withValues(alpha: 0.15);
      textColor = AppColors.info;
      text = 'UPCOMING';
      icon = Icons.schedule_rounded;
    } else {
      bgColor = AppColors.textMuted.withValues(alpha: 0.15);
      textColor = AppColors.textMuted;
      text = 'COMPLETED';
      icon = Icons.check_circle_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTextStyles.labelSmall.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.bodySmall),
      ],
    );
  }
}
