import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:pulchowkx_app/models/event.dart';
import 'package:pulchowkx_app/services/analytics_service.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/services/favorites_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/custom_app_bar.dart';
import 'package:pulchowkx_app/widgets/shimmer_loaders.dart';
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

  // Admin features
  bool _isClubOwner = false;
  List<Map<String, dynamic>> _registeredStudents = [];
  bool _loadingStudents = false;
  Map<String, dynamic>? _extraDetails;
  bool _isEditingDetails = false;

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
        AnalyticsService.logEventView(fullEvent.id.toString(), fullEvent.title);
        _checkRegistrationStatus();
        _checkAdminStatus();
        _loadExtraDetails();
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

  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _fullEvent == null) return;

    try {
      final userId = await _apiService.getDatabaseUserId() ?? user.uid;
      final clubId = _fullEvent!.clubId;
      final isAdmin = await _apiService.isClubAdminOrOwner(clubId, userId);
      if (mounted) {
        setState(() => _isClubOwner = isAdmin);
        if (isAdmin) {
          _loadRegisteredStudents();
        }
      }
    } catch (e) {
      debugPrint('Error checking admin status: $e');
    }
  }

  Future<void> _loadExtraDetails() async {
    if (_fullEvent == null) return;

    try {
      final details = await _apiService.getExtraEventDetails(_fullEvent!.id);
      if (mounted && details != null) {
        setState(() => _extraDetails = details);
      }
    } catch (e) {
      debugPrint('Error loading extra details: $e');
    }
  }

  Future<void> _loadRegisteredStudents() async {
    if (_fullEvent == null) return;

    setState(() => _loadingStudents = true);
    try {
      final students = await _apiService.getRegisteredStudents(_fullEvent!.id);
      if (mounted) {
        setState(() {
          _registeredStudents = students;
          _loadingStudents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingStudents = false);
      }
    }
  }

  Future<void> _showEditDetailsDialog() async {
    final fullDescController = TextEditingController(
      text: _extraDetails?['fullDescription'] ?? _fullEvent?.description ?? '',
    );
    final objectivesController = TextEditingController(
      text: _extraDetails?['objectives'] ?? '',
    );
    final targetAudienceController = TextEditingController(
      text: _extraDetails?['targetAudience'] ?? '',
    );
    final prerequisitesController = TextEditingController(
      text: _extraDetails?['prerequisites'] ?? '',
    );
    final rulesController = TextEditingController(
      text: _extraDetails?['rules'] ?? '',
    );
    final judgingCriteriaController = TextEditingController(
      text: _extraDetails?['judgingCriteria'] ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text('Edit Event Details'),
        titleTextStyle: AppTextStyles.h4,
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: fullDescController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Full Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: objectivesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Objectives',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: targetAudienceController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Target Audience',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: prerequisitesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Prerequisites',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: rulesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Rules',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: judgingCriteriaController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Judging Criteria',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      setState(() => _isEditingDetails = true);
      try {
        final detailsData = {
          'fullDescription': fullDescController.text,
          'objectives': objectivesController.text,
          'targetAudience': targetAudienceController.text,
          'prerequisites': prerequisitesController.text,
          'rules': rulesController.text,
          'judgingCriteria': judgingCriteriaController.text,
        };

        Map<String, dynamic> response;
        if (_extraDetails != null) {
          response = await _apiService.updateExtraEventDetails(
            _fullEvent!.id,
            detailsData,
          );
        } else {
          response = await _apiService.createExtraEventDetails(
            _fullEvent!.id,
            detailsData,
          );
        }

        if (response['success'] == true) {
          _showSnackBar('Event details updated successfully!');
          // Update local state immediately
          setState(() {
            _extraDetails = {...?_extraDetails, ...detailsData};
          });
          // Also refresh from server to ensure sync
          _loadExtraDetails();
        } else {
          _showSnackBar(
            response['message'] ?? 'Failed to update details',
            isError: true,
          );
        }
      } catch (e) {
        _showSnackBar('An error occurred', isError: true);
      } finally {
        if (mounted) {
          setState(() => _isEditingDetails = false);
        }
      }
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
          AnalyticsService.logRegistration(
            _fullEvent!.id.toString(),
            _fullEvent!.title,
          );
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
      return const DetailsPageShimmer();
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
                  Hero(
                    tag: 'event_banner_${event.id}',
                    child: CachedNetworkImage(
                      imageUrl: event.bannerUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => _buildBannerPlaceholder(),
                      errorWidget: (_, _, _) => _buildBannerPlaceholder(),
                    ),
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

                // Favorite Button
                Positioned(
                  top: 16,
                  right: 16,
                  child: ListenableBuilder(
                    listenable: favoritesService,
                    builder: (context, _) {
                      final isFavorite = favoritesService.isEventFavorite(
                        event.id.toString(),
                      );
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          favoritesService.toggleEventFavorite(
                            event.id.toString(),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isFavorite
                                ? AppColors.error
                                : Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_outline_rounded,
                              key: ValueKey(isFavorite),
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
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

                // Description - Use extra details if available, fallback to event description
                if (event.description != null || _extraDetails != null) ...[
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
                      _extraDetails?['fullDescription']?.isNotEmpty == true
                          ? _extraDetails!['fullDescription']!
                          : (event.description ?? 'No description available'),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],

                // Extra Details Sections
                if (_extraDetails != null) ...[
                  _buildDetailSection(
                    'Objectives',
                    _extraDetails!['objectives'],
                  ),
                  _buildDetailSection(
                    'Target Audience',
                    _extraDetails!['targetAudience'],
                  ),
                  _buildDetailSection(
                    'Prerequisites',
                    _extraDetails!['prerequisites'],
                  ),
                  _buildDetailSection('Rules', _extraDetails!['rules']),
                  _buildDetailSection(
                    'Judging Criteria',
                    _extraDetails!['judgingCriteria'],
                  ),
                ],

                // Admin Section: Edit Event Details Button
                if (_isClubOwner) ...[
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isEditingDetails
                          ? null
                          : _showEditDetailsDialog,
                      icon: _isEditingDetails
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.edit_rounded),
                      label: Text(
                        _isEditingDetails ? 'Saving...' : 'Edit Event Details',
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ),
                ],

                // Admin Section: Registered Students
                if (_isClubOwner) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Registered Students',
                        style: AppTextStyles.h4.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          '${_registeredStudents.length}',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_loadingStudents)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_registeredStudents.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.people_outline_rounded,
                              size: 48,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'No students registered yet',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _registeredStudents.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (context, index) {
                          final student = _registeredStudents[index];
                          final user = student['student'] ?? student;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.1,
                              ),
                              child: Text(
                                (user['name'] ?? 'U')[0].toUpperCase(),
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            title: Text(
                              user['name'] ?? 'Unknown',
                              style: AppTextStyles.labelLarge,
                            ),
                            subtitle: Text(
                              user['email'] ?? '',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            trailing: Builder(
                              builder: (context) {
                                final status =
                                    student['status'] ?? 'registered';
                                final isCancelled =
                                    status.toLowerCase() == 'cancelled';
                                final statusColor = isCancelled
                                    ? AppColors.error
                                    : AppColors.success;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.sm,
                                    ),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: statusColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
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

  Widget _buildDetailSection(String title, String? content) {
    if (content == null || content.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xl),
        Text(
          title,
          style: AppTextStyles.h4.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            content,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ),
      ],
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
