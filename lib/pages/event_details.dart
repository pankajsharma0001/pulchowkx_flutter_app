import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:pulchowkx_app/models/event.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/custom_app_bar.dart';

import 'package:pulchowkx_app/widgets/event_status_badge.dart';

class EventDetailsPage extends StatefulWidget {
  /// The event to display. Can be partial data (from enrollments) or full data.
  final ClubEvent? event;

  /// Event ID - used to fetch full event data if event is null or partial.
  final int? eventId;

  const EventDetailsPage({super.key, this.event, this.eventId})
    : assert(
        event != null || eventId != null,
        'Either event or eventId must be provided',
      );

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  final ApiService _apiService = ApiService();
  bool _isRegistering = false;
  bool _isRegistered = false;
  bool _isCancelling = false;
  ClubEvent? _fullEvent;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFullEventData();
  }

  /// Fetch the complete event data from API
  Future<void> _loadFullEventData() async {
    final eventId = widget.eventId ?? widget.event?.id;
    if (eventId == null) {
      setState(() {
        _error = 'No event ID provided';
        _isLoading = false;
      });
      return;
    }

    try {
      // Fetch all events and find the one we need
      final allEvents = await _apiService.getAllEvents();
      final fullEvent = allEvents.firstWhere(
        (e) => e.id == eventId,
        orElse: () => widget.event!,
      );

      if (mounted) {
        setState(() {
          _fullEvent = fullEvent;
          _isLoading = false;
        });
        _checkRegistrationStatus();
      }
    } catch (e) {
      if (mounted) {
        // Fall back to widget.event if available
        setState(() {
          _fullEvent = widget.event;
          _isLoading = false;
          if (widget.event == null) {
            _error = 'Failed to load event details';
          }
        });
        if (widget.event != null) {
          _checkRegistrationStatus();
        }
      }
    }
  }

  Future<void> _checkRegistrationStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _fullEvent == null) return;

    final userId = await _apiService.getDatabaseUserId() ?? user.uid;
    final enrollments = await _apiService.getEnrollments(userId);
    if (mounted) {
      setState(() {
        _isRegistered = enrollments.any(
          (e) => e.eventId == _fullEvent!.id && e.status == 'registered',
        );
      });
    }
  }

  Future<void> _handleRegister() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Please sign in to register for events', isError: true);
      return;
    }

    setState(() => _isRegistering = true);

    try {
      final userId = await _apiService.getDatabaseUserId() ?? user.uid;
      final success = await _apiService.registerForEvent(
        userId,
        _fullEvent!.id,
      );

      if (mounted) {
        if (success) {
          setState(() => _isRegistered = true);
          _showSnackBar('Successfully registered for ${_fullEvent!.title}!');
        } else {
          _showSnackBar('Failed to register. Please try again.', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('An error occurred. Please try again.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isRegistering = false);
      }
    }
  }

  Future<void> _handleCancelRegistration() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text('Cancel Registration'),
        titleTextStyle: AppTextStyles.h4,
        content: const Text(
          'Are you sure you want to cancel your registration for this event?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Registration'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Registration'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);

    try {
      final userId = await _apiService.getDatabaseUserId() ?? user.uid;
      final success = await _apiService.cancelRegistration(
        userId,
        _fullEvent!.id,
      );

      if (mounted) {
        if (success) {
          setState(() => _isRegistered = false);
          _showSnackBar('Registration cancelled successfully.');
        } else {
          _showSnackBar('Failed to cancel registration.', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('An error occurred. Please try again.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isCancelling = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    // Show loading state
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: AppSpacing.md),
            Text('Loading event details...', style: AppTextStyles.bodyMedium),
          ],
        ),
      );
    }

    // Show error state
    if (_error != null || _fullEvent == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(_error ?? 'Failed to load event', style: AppTextStyles.h4),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final event = _fullEvent!;
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (event.bannerUrl != null)
                  CachedNetworkImage(
                    imageUrl: event.bannerUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => _buildBannerPlaceholder(),
                    errorWidget: (_, _, _) => _buildBannerPlaceholder(),
                  )
                else
                  _buildBannerPlaceholder(),
                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
                // Status badge
                Positioned(
                  top: 16,
                  left: 16,
                  child: EventStatusBadge(event: event),
                ),

                // Title at bottom
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (event.club != null)
                        Row(
                          children: [
                            if (event.club!.logoUrl != null)
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(7),
                                  child: CachedNetworkImage(
                                    imageUrl: event.club!.logoUrl!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 10),
                            Text(
                              event.club!.name,
                              style: AppTextStyles.labelMedium.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      Text(
                        event.title,
                        style: AppTextStyles.h2.copyWith(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Info Cards
                Row(
                  children: [
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.calendar_today_rounded,
                        title: 'Date',
                        value: dateFormat.format(event.eventStartTime),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.access_time_rounded,
                        title: 'Time',
                        value:
                            '${timeFormat.format(event.eventStartTime)} - ${timeFormat.format(event.eventEndTime)}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.location_on_rounded,
                        title: 'Venue',
                        value: event.venue ?? 'TBA',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.people_rounded,
                        title: 'Participants',
                        value: event.maxParticipants != null
                            ? '${event.currentParticipants}/${event.maxParticipants}'
                            : '${event.currentParticipants} registered',
                      ),
                    ),
                  ],
                ),

                // Registration deadline
                if (event.registrationDeadline != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.timer_rounded,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Registration Deadline',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.warning,
                                ),
                              ),
                              Text(
                                '${dateFormat.format(event.registrationDeadline!)} at ${timeFormat.format(event.registrationDeadline!)}',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Description
                if (event.description != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'About This Event',
                    style: AppTextStyles.h4.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      event.description!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],

                // Register Button
                const SizedBox(height: AppSpacing.xl),
                _buildActionButton(event),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerPlaceholder() {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: const Center(
        child: Icon(Icons.event_rounded, color: Colors.white, size: 64),
      ),
    );
  }

  Widget _buildActionButton(ClubEvent event) {
    final user = FirebaseAuth.instance.currentUser;

    // Not logged in
    if (user == null) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            _showSnackBar(
              'Please sign in to register for events',
              isError: true,
            );
          },
          icon: const Icon(Icons.login_rounded),
          label: const Text('Sign In to Register'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
      );
    }

    // Already registered
    if (_isRegistered) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'You\'re registered!',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isCancelling ? null : _handleCancelRegistration,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isCancelling
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.error,
                      ),
                    )
                  : Text(
                      'Cancel Registration',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.error,
                      ),
                    ),
            ),
          ),
        ],
      );
    }

    // Event completed
    if (event.isCompleted) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          child: const Text('Event Completed'),
        ),
      );
    }

    // Can't register (full or deadline passed)
    if (!event.canRegister) {
      String reason = 'Registration Closed';
      if (event.maxParticipants != null &&
          event.currentParticipants >= event.maxParticipants!) {
        reason = 'Event is Full';
      } else if (event.registrationDeadline != null &&
          DateTime.now().isAfter(event.registrationDeadline!)) {
        reason = 'Deadline Passed';
      }

      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          child: Text(reason),
        ),
      );
    }

    // Can register
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isRegistering ? null : _handleRegister,
        icon: _isRegistering
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.how_to_reg_rounded),
        label: Text(_isRegistering ? 'Registering...' : 'Register Now'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                title,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
