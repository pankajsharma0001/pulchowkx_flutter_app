import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pulchowkx_app/models/event.dart';
import 'package:pulchowkx_app/pages/main_layout.dart';
import 'package:pulchowkx_app/pages/event_details.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/event_card.dart';
import 'package:pulchowkx_app/widgets/shimmer_loaders.dart';
import 'package:pulchowkx_app/widgets/empty_states.dart';

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
      _enrollmentsFuture = _apiService.getDatabaseUserId().then((dbId) {
        return _apiService.getEnrollments(dbId ?? user.uid);
      });
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
                child: const Icon(
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
                return Column(
                  children: List.generate(
                    2,
                    (index) => const EventCardShimmer(type: EventCardType.list),
                  ),
                );
              }

              if (snapshot.hasError) {
                return const EmptyStateWidget(
                  type: EmptyStateType.generic,
                  title: 'Failed to load enrollments',
                  message: 'Please try again later',
                );
              }

              final enrollments = snapshot.data ?? [];
              final activeEnrollments = enrollments
                  .where((e) => e.status == 'registered')
                  .toList();

              if (activeEnrollments.isEmpty) {
                return EmptyStateWidget(
                  type: EmptyStateType.events,
                  title: 'No enrollments yet',
                  message: 'Browse events and register to see them here',
                  actionLabel: 'Browse Events',
                  onAction: () {
                    final mainLayout = MainLayout.of(context);
                    if (mainLayout != null) {
                      mainLayout.setSelectedIndex(6);
                    }
                  },
                );
              }

              return Column(
                children: activeEnrollments.map((enrollment) {
                  final event = enrollment.event;
                  if (event == null) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: EventCard(
                      event: event,
                      type: EventCardType.list,
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
}
