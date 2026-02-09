import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pulchowkx_app/models/event.dart';
import 'package:pulchowkx_app/pages/event_details.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/event_status_badge.dart';
import 'package:pulchowkx_app/widgets/shimmer_loaders.dart';
import 'package:pulchowkx_app/services/api_service.dart';

enum EventCardType { grid, list }

class EventCard extends StatefulWidget {
  final ClubEvent event;
  final EventCardType type;
  final VoidCallback? onTap;

  const EventCard({
    super.key,
    required this.event,
    this.type = EventCardType.grid,
    this.onTap,
  });

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.type == EventCardType.grid) {
      return _buildGridCard(context);
    } else {
      return _buildListCard(context);
    }
  }

  Widget _buildGridCard(BuildContext context) {
    final dateFormat = DateFormat('MMM d');
    final timeFormat = DateFormat('h:mm a');
    final isCompleted = widget.event.isCompleted;
    final isOngoing = widget.event.isOngoing;

    return Opacity(
      opacity: isCompleted ? 0.7 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap ?? () => _navigateToDetails(context),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: isOngoing
                    ? AppColors.success.withValues(alpha: 0.5)
                    : Theme.of(context).dividerTheme.color ?? AppColors.border,
                width: isOngoing ? 2 : 1,
              ),
              boxShadow: Theme.of(context).brightness == Brightness.light
                  ? AppShadows.sm
                  : null, // Deeper look in dark mode without shadows
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Banner
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.xl),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (widget.event.bannerUrl != null)
                          CachedNetworkImage(
                            imageUrl: ApiService().optimizeCloudinaryUrl(
                              widget.event.bannerUrl!,
                              width: 600,
                            ),
                            fit: BoxFit.cover,
                            memCacheWidth: 600,
                            placeholder: (_, _) => _buildPlaceholder(),
                            errorWidget: (_, _, _) => _buildPlaceholder(),
                          )
                        else
                          _buildPlaceholder(),
                        // Gradient overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                        ),
                        // Status badge
                        Positioned(
                          top: 8,
                          left: 8,
                          child: EventStatusBadge(
                            event: widget.event,
                            isCompact: true,
                          ),
                        ),
                        // Date badge
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              boxShadow:
                                  Theme.of(context).brightness ==
                                      Brightness.light
                                  ? AppShadows.sm
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  dateFormat
                                      .format(widget.event.eventStartTime)
                                      .split(' ')[0],
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 9,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  widget.event.eventStartTime.day.toString(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: AppColors.primary,
                                        fontSize: 12,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Club name at bottom of image
                        if (widget.event.club != null)
                          Positioned(
                            bottom: 8,
                            left: 12,
                            right: 12,
                            child: Row(
                              children: [
                                if (widget.event.club!.logoUrl != null)
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(5),
                                      child: CachedNetworkImage(
                                        imageUrl: ApiService()
                                            .optimizeCloudinaryUrl(
                                              widget.event.club!.logoUrl!,
                                              width: 100,
                                            ),
                                        fit: BoxFit.cover,
                                        memCacheWidth: 100,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.event.club!.name,
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Info section
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.event.title,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 11,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              timeFormat.format(widget.event.eventStartTime),
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(fontSize: 10),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        if (widget.event.venue != null)
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 11,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  widget.event.venue!,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        // Participants
                        Row(
                          children: [
                            const Icon(
                              Icons.people_rounded,
                              size: 11,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                '${widget.event.currentParticipants}${widget.event.maxParticipants != null ? '/${widget.event.maxParticipants}' : ''} registered',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 10,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListCard(BuildContext context) {
    final dateFormat = DateFormat('EEE, MMM d');

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _isHovered
              ? (Theme.of(context).brightness == Brightness.dark
                    ? AppColors.backgroundSecondaryDark
                    : AppColors.accentLight)
              : Theme.of(context).cardTheme.color,
          border: Border.all(
            color: _isHovered
                ? AppColors.primary.withValues(alpha: 0.3)
                : Theme.of(context).dividerTheme.color ?? AppColors.border,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap ?? () => _navigateToDetails(context),
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
                        Text(
                          widget.event.title,
                          style: AppTextStyles.labelLarge,
                        ),
                        const SizedBox(height: 2),
                        if (widget.event.club != null)
                          Text(
                            widget.event.club!.name.toUpperCase(),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: 4,
                          children: [
                            _InfoChip(
                              icon: Icons.calendar_month_rounded,
                              label: dateFormat.format(
                                widget.event.eventStartTime,
                              ),
                            ),
                            _InfoChip(
                              icon: Icons.location_on_rounded,
                              label: widget.event.venue ?? 'TBA',
                            ),
                            EventStatusBadge(
                              event: widget.event,
                              isCompact: true,
                            ),
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

  void _navigateToDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailsPage(event: widget.event),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return const BoxShimmer(height: double.infinity, borderRadius: 0);
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
