import 'package:flutter/material.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';

enum EmptyStateType { books, clubs, events, submissions, assignments, generic }

class EmptyStateWidget extends StatelessWidget {
  final EmptyStateType type;
  final String? title;
  final String? message;
  final VoidCallback? onAction;
  final String? actionLabel;

  const EmptyStateWidget({
    super.key,
    required this.type,
    this.title,
    this.message,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIllustration(),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title ?? _getDefaultTitle(),
              style: AppTextStyles.h4,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message ?? _getDefaultMessage(),
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel ?? 'Get Started'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIllustration() {
    IconData icon;
    Color color;

    switch (type) {
      case EmptyStateType.books:
        icon = Icons.menu_book_rounded;
        color = Colors.teal;
        break;
      case EmptyStateType.clubs:
        icon = Icons.groups_rounded;
        color = AppColors.accent;
        break;
      case EmptyStateType.events:
        icon = Icons.event_rounded;
        color = AppColors.primary;
        break;
      case EmptyStateType.submissions:
        icon = Icons.assignment_turned_in_rounded;
        color = AppColors.success;
        break;
      case EmptyStateType.assignments:
        icon = Icons.assignment_rounded;
        color = Colors.orange;
        break;
      case EmptyStateType.generic:
        icon = Icons.inbox_rounded;
        color = AppColors.textMuted;
    }

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 64, color: color),
    );
  }

  String _getDefaultTitle() {
    switch (type) {
      case EmptyStateType.books:
        return 'No books found';
      case EmptyStateType.clubs:
        return 'No clubs yet';
      case EmptyStateType.events:
        return 'No upcoming events';
      case EmptyStateType.submissions:
        return 'No submissions yet';
      case EmptyStateType.assignments:
        return 'All caught up!';
      default:
        return 'Nothing here';
    }
  }

  String _getDefaultMessage() {
    switch (type) {
      case EmptyStateType.books:
        return 'Be the first to list a book for sale in your campus community.';
      case EmptyStateType.clubs:
        return 'Explore other faculties or check back later for new clubs.';
      case EmptyStateType.events:
        return 'Stay tuned for exciting campus events coming your way soon.';
      case EmptyStateType.submissions:
        return 'Waiting for students to submit their brilliance.';
      case EmptyStateType.assignments:
        return 'You have no pending assignments. Time to relax or explore!';
      default:
        return 'This section seems empty for now.';
    }
  }
}
