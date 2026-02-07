import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pulchowkx_app/services/haptic_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pulchowkx_app/models/event.dart';
import 'package:pulchowkx_app/services/analytics_service.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/services/favorites_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:pulchowkx_app/widgets/custom_app_bar.dart';
import 'package:pulchowkx_app/widgets/shimmer_loaders.dart';
import 'package:pulchowkx_app/widgets/event_status_badge.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _isCancellingEvent = false;
  ClubEvent? _fullEvent;
  bool _isLoading = true;
  String? _error;

  // Admin features
  bool _isClubOwner = false;
  List<Map<String, dynamic>> _registeredStudents = [];
  bool _loadingStudents = false;
  Map<String, dynamic>? _extraDetails;
  bool _isEditingDetails = false;
  bool _isUploadingBanner = false;

  // Countdown timer
  Timer? _countdownTimer;
  Map<String, int> _countdown = {
    'days': 0,
    'hours': 0,
    'minutes': 0,
    'seconds': 0,
  };
  String? _countdownLabel;
  bool _showCountdown = false;

  @override
  void initState() {
    super.initState();
    _loadFullEventData();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdown();
    });
  }

  void _updateCountdown() {
    if (_fullEvent == null || !mounted) {
      setState(() {
        _showCountdown = false;
        _countdownLabel = null;
      });
      return;
    }

    final event = _fullEvent!;
    if (event.status == 'draft' || event.status == 'cancelled') {
      setState(() {
        _showCountdown = false;
        _countdownLabel = null;
      });
      return;
    }

    final now = DateTime.now();
    final start = event.eventStartTime;
    final end = event.eventEndTime;

    DateTime? target;
    String? label;

    if (now.isBefore(start)) {
      target = start;
      label = 'Starts in';
    } else if (now.isBefore(end) || now.isAtSameMomentAs(end)) {
      target = end;
      label = 'Ends in';
    } else {
      setState(() {
        _showCountdown = false;
        _countdownLabel = null;
      });
      _countdownTimer?.cancel();
      return;
    }

    final diff = target.difference(now);
    final totalSeconds = diff.inSeconds.clamp(0, double.maxFinite.toInt());
    final days = totalSeconds ~/ (24 * 60 * 60);
    final hours = (totalSeconds % (24 * 60 * 60)) ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    setState(() {
      _countdown = {
        'days': days,
        'hours': hours,
        'minutes': minutes,
        'seconds': seconds,
      };
      _countdownLabel = label;
      _showCountdown = true;
    });
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
        _startCountdownTimer();
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

    final userId = await _apiService.requireDatabaseUserId();
    if (userId == null) return;
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
      final userId = await _apiService.requireDatabaseUserId();
      if (userId == null) return;
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
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text('Edit Event Details'),
        titleTextStyle: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        content: SizedBox(
          width: MediaQuery.of(context).size.width,
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
      final userId = await _apiService.requireDatabaseUserId();
      if (userId == null) {
        if (mounted) {
          _showSnackBar('Please sign in again to register.', isError: true);
        }
        return;
      }
      final result = await _apiService.registerForEvent(userId, _fullEvent!.id);

      if (mounted) {
        if (result.success) {
          setState(() => _isRegistered = true);
          AnalyticsService.logRegistration(
            _fullEvent!.id.toString(),
            _fullEvent!.title,
          );
          _showSnackBar('Successfully registered for ${_fullEvent!.title}!');
        } else {
          _showSnackBar(result.message ?? 'Failed to register.', isError: true);
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
        titleTextStyle: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        content: Text(
          'Are you sure you want to cancel your registration for this event?',
          style: Theme.of(context).textTheme.bodyMedium,
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
      final userId = await _apiService.requireDatabaseUserId();
      if (userId == null) {
        if (mounted) {
          _showSnackBar('Please sign in again to cancel.', isError: true);
        }
        return;
      }
      final result = await _apiService.cancelRegistration(
        userId,
        _fullEvent!.id,
      );

      if (mounted) {
        if (result.success) {
          setState(() => _isRegistered = false);
          _showSnackBar('Registration cancelled successfully.');
        } else {
          _showSnackBar(
            result.message ?? 'Failed to cancel registration.',
            isError: true,
          );
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

  Future<void> _handleUpdateBanner() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image == null || _fullEvent == null) return;

    setState(() => _isUploadingBanner = true);

    try {
      final result = await _apiService.uploadEventBanner(
        _fullEvent!.id,
        File(image.path),
      );

      if (mounted) {
        if (result['success'] == true) {
          _showSnackBar('Event banner updated successfully!');
          _loadFullEventData(); // Refresh to show new banner
        } else {
          _showSnackBar(
            result['message'] ?? 'Failed to update banner',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('An error occurred while uploading', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingBanner = false);
      }
    }
  }

  Future<void> _handleExportStudents(String format) async {
    if (_fullEvent == null) return;

    try {
      final url = await _apiService.getExportRegisteredStudentsUrl(
        _fullEvent!.id,
        format,
      );

      if (url != null) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showSnackBar('Could not launch export URL', isError: true);
        }
      }
    } catch (e) {
      _showSnackBar('Failed to generate export URL', isError: true);
    }
  }

  Future<void> _handleCancelEvent() async {
    if (_fullEvent == null) return;

    // Don't allow cancelling already cancelled or completed events
    if (_fullEvent!.status == 'cancelled') {
      _showSnackBar('Event is already cancelled', isError: true);
      return;
    }
    if (_fullEvent!.status == 'completed') {
      _showSnackBar('Cannot cancel a completed event', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                Icons.cancel_rounded,
                color: AppColors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Cancel Event',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel "${_fullEvent!.title}"?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
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
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. All registered participants will be notified.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Event'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Event'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancellingEvent = true);

    try {
      final result = await _apiService.cancelEvent(_fullEvent!.id);

      if (mounted) {
        if (result['success'] == true) {
          _showSnackBar('Event cancelled successfully');
          // Refresh event data to show cancelled status
          _loadFullEventData();
        } else {
          _showSnackBar(
            result['message'] ?? 'Failed to cancel event',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('An error occurred. Please try again.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isCancellingEvent = false);
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
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.light
              ? AppColors.heroGradient
              : AppColors.heroGradientDark,
        ),
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
                          haptics.lightImpact();
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

                // Admin: Edit Banner Button
                if (_isClubOwner)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: ElevatedButton.icon(
                      onPressed: _isUploadingBanner
                          ? null
                          : _handleUpdateBanner,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      icon: _isUploadingBanner
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.camera_alt_rounded, size: 16),
                      label: Text(
                        _isUploadingBanner ? 'Updating...' : 'Edit Cover',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                        title: 'Start Date',
                        value:
                            '${dateFormat.format(event.eventStartTime)} ${timeFormat.format(event.eventStartTime)}',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.event_rounded,
                        title: 'End Date',
                        value:
                            '${dateFormat.format(event.eventEndTime)} ${timeFormat.format(event.eventEndTime)}',
                      ),
                    ),
                  ],
                ),

                // Countdown Timer
                if (_showCountdown) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _countdownLabel?.toUpperCase() ?? '',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _CountdownBox(
                              value: _countdown['days']!,
                              label: 'Days',
                            ),
                            _CountdownBox(
                              value: _countdown['hours']!,
                              label: 'Hours',
                            ),
                            _CountdownBox(
                              value: _countdown['minutes']!,
                              label: 'Min',
                            ),
                            _CountdownBox(
                              value: _countdown['seconds']!,
                              label: 'Sec',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

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
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color,
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
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color:
                            Theme.of(context).dividerTheme.color ??
                            AppColors.border,
                      ),
                    ),
                    child: Text(
                      _extraDetails?['fullDescription']?.isNotEmpty == true
                          ? _extraDetails!['fullDescription']!
                          : (event.description ?? 'No description available'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                  // Cancel Event Button
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          (_isCancellingEvent ||
                              _fullEvent?.status == 'cancelled' ||
                              _fullEvent?.status == 'completed')
                          ? null
                          : _handleCancelEvent,
                      icon: _isCancellingEvent
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.red,
                              ),
                            )
                          : Icon(
                              _fullEvent?.status == 'cancelled'
                                  ? Icons.cancel
                                  : Icons.cancel_outlined,
                              color: _fullEvent?.status == 'cancelled'
                                  ? Colors.grey
                                  : Colors.red,
                            ),
                      label: Text(
                        _isCancellingEvent
                            ? 'Cancelling...'
                            : _fullEvent?.status == 'cancelled'
                            ? 'Event Cancelled'
                            : 'Cancel Event',
                        style: TextStyle(
                          color:
                              (_fullEvent?.status == 'cancelled' ||
                                  _fullEvent?.status == 'completed')
                              ? Colors.grey
                              : Colors.red,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color:
                              (_fullEvent?.status == 'cancelled' ||
                                  _fullEvent?.status == 'completed')
                              ? Colors.grey
                              : Colors.red,
                        ),
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
                          color: Theme.of(context).colorScheme.onSurface,
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
                  if (_registeredStudents.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Text(
                          'Export as:',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _buildExportChip(
                          label: 'CSV',
                          icon: Icons.table_chart_rounded,
                          onTap: () => _handleExportStudents('csv'),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _buildExportChip(
                          label: 'PDF',
                          icon: Icons.picture_as_pdf_rounded,
                          onTap: () => _handleExportStudents('pdf'),
                        ),
                      ],
                    ),
                  ],
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
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color:
                              Theme.of(context).dividerTheme.color ??
                              AppColors.border,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.people_outline_rounded,
                              size: 48,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.6),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'No students registered yet',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color:
                              Theme.of(context).dividerTheme.color ??
                              AppColors.border,
                        ),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _registeredStudents.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: Theme.of(context).dividerTheme.color,
                        ),
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
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
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
          style: AppTextStyles.h4.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: Theme.of(context).dividerTheme.color ?? AppColors.border,
            ),
          ),
          child: Text(
            content,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(ClubEvent event) {
    final user = FirebaseAuth.instance.currentUser;
    // Admins/owners cannot register
    if (_isClubOwner) return const SizedBox.shrink();

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
    // CASE 1: External registration link provided (Exclusive)
    if (event.externalRegistrationLink != null &&
        event.externalRegistrationLink!.isNotEmpty) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () =>
              _handleExternalRegister(event.externalRegistrationLink!),
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('Register Externally (Google Form/Other)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
      );
    }

    // CASE 2: Normal Internal Registration
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

  Future<void> _handleExternalRegister(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        AnalyticsService.logEvent('external_registration_click', {
          'event_id': _fullEvent?.id as Object,
          'url': url,
        });
      } else {
        _showSnackBar('Could not open registration link', isError: true);
      }
    } catch (e) {
      _showSnackBar('Invalid registration link', isError: true);
    }
  }

  Widget _buildExportChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                title,
                style: AppTextStyles.labelSmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.labelMedium.copyWith(
              color: Theme.of(context).textTheme.bodyMedium?.color,
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

class _CountdownBox extends StatelessWidget {
  final int value;
  final String label;

  const _CountdownBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            value.toString().padLeft(2, '0'),
            textAlign: TextAlign.center,
            style: AppTextStyles.h3.copyWith(
              fontWeight: FontWeight.w900,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: AppTextStyles.labelSmall.copyWith(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ],
    );
  }
}
