import 'package:flutter/material.dart';
import 'package:pulchowkx_app/models/event.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';

class EventStatusBadge extends StatelessWidget {
  final ClubEvent event;
  final bool isCompact;

  const EventStatusBadge({
    super.key,
    required this.event,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String text;
    IconData? icon;

    if (event.isCancelled) {
      bgColor = AppColors.error;
      textColor = Colors.white;
      text = 'CANCELLED';
      icon = Icons.cancel_rounded;
    } else if (event.isOngoing) {
      bgColor = AppColors.success;
      textColor = Colors.white;
      text = 'LIVE';
      icon = Icons.circle;
    } else if (event.isUpcoming) {
      bgColor = AppColors.primary.withValues(alpha: 0.9);
      textColor = Colors.white;
      text = event.eventType.toUpperCase();
    } else {
      bgColor = AppColors.textSecondary.withValues(alpha: 0.8);
      textColor = Colors.white;
      text = 'COMPLETED';
    }

    if (isCompact) {
      if (event.isCancelled) {
        bgColor = AppColors.error.withValues(alpha: 0.15);
        textColor = AppColors.error;
        icon = Icons.cancel_rounded;
      } else if (event.isOngoing) {
        bgColor = AppColors.success.withValues(alpha: 0.15);
        textColor = AppColors.success;
      } else if (event.isUpcoming) {
        bgColor = AppColors.info.withValues(alpha: 0.15);
        textColor = AppColors.info;
        icon = Icons.schedule_rounded;
      } else {
        bgColor = AppColors.textMuted.withValues(alpha: 0.15);
        textColor = AppColors.textMuted;
        icon = Icons.check_circle_rounded;
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 10,
        vertical: isCompact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: isCompact ? 12 : 8, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: AppTextStyles.labelSmall.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: isCompact ? null : 10,
            ),
          ),
        ],
      ),
    );
  }
}
