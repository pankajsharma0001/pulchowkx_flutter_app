import 'package:flutter/material.dart';

import 'club.dart';

enum EventStatus { draft, published, ongoing, completed, cancelled }

enum RegistrationStatus { registered, attended, cancelled, waitlisted }

class ClubEvent {
  final int id;
  final int clubId;
  final String title;
  final String? description;
  final String eventType;
  final String status;
  final String? venue;
  final int? maxParticipants;
  final int currentParticipants;
  final DateTime? registrationDeadline;
  final DateTime eventStartTime;
  final DateTime eventEndTime;
  final String? bannerUrl;
  final String? externalRegistrationLink;
  final bool isRegistrationOpen;
  final DateTime createdAt;
  final Club? club;

  ClubEvent({
    required this.id,
    required this.clubId,
    required this.title,
    this.description,
    required this.eventType,
    required this.status,
    this.venue,
    this.maxParticipants,
    this.currentParticipants = 0,
    this.registrationDeadline,
    required this.eventStartTime,
    required this.eventEndTime,
    this.bannerUrl,
    this.externalRegistrationLink,
    this.isRegistrationOpen = true,
    required this.createdAt,
    this.club,
  });

  factory ClubEvent.fromJson(Map<String, dynamic> json) {
    return ClubEvent(
      id: _parseInt(json['id'])!,
      clubId: _parseInt(json['clubId'])!,
      title: json['title'] as String,
      description: json['description'] as String?,
      eventType: json['eventType'] as String,
      status: json['status'] as String,
      venue: json['venue'] as String?,
      maxParticipants: _parseInt(json['maxParticipants']),
      currentParticipants: _parseInt(json['currentParticipants']) ?? 0,
      registrationDeadline: json['registrationDeadline'] != null
          ? DateTime.tryParse(json['registrationDeadline'] as String)
          : null,
      eventStartTime: DateTime.parse(json['eventStartTime'] as String),
      eventEndTime: DateTime.parse(json['eventEndTime'] as String),
      bannerUrl: json['bannerUrl'] as String?,
      externalRegistrationLink: json['externalRegistrationLink'] as String?,
      isRegistrationOpen: json['isRegistrationOpen'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      club: json['club'] != null
          ? Club.fromJson(json['club'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Parse partial event data from enrollment endpoint
  /// The enrollment endpoint returns only: id, title, clubId, eventStartTime, venue, club.name
  factory ClubEvent.fromPartialJson(Map<String, dynamic> json) {
    Club? club;
    if (json['club'] != null) {
      final clubJson = json['club'] as Map<String, dynamic>;
      club = Club(
        id: 0, // Not provided in partial response
        authClubId: '',
        name: clubJson['name']?.toString() ?? 'Unknown Club',
      );
    }

    return ClubEvent(
      id: _parseInt(json['id']) ?? 0,
      clubId: _parseInt(json['clubId']) ?? 0,
      title: json['title']?.toString() ?? 'Untitled Event',
      description: json['description']?.toString(),
      eventType: json['eventType']?.toString() ?? 'event',
      status: json['status']?.toString() ?? 'published',
      venue: json['venue']?.toString(),
      maxParticipants: _parseInt(json['maxParticipants']),
      currentParticipants: _parseInt(json['currentParticipants']) ?? 0,
      registrationDeadline: json['registrationDeadline'] != null
          ? DateTime.tryParse(json['registrationDeadline'].toString())
          : null,
      eventStartTime: json['eventStartTime'] != null
          ? DateTime.parse(json['eventStartTime'].toString())
          : DateTime.now(),
      eventEndTime: json['eventEndTime'] != null
          ? DateTime.parse(json['eventEndTime'].toString())
          : DateTime.now().add(const Duration(hours: 2)),
      bannerUrl: json['bannerUrl']?.toString(),
      externalRegistrationLink: json['externalRegistrationLink']?.toString(),
      isRegistrationOpen: json['isRegistrationOpen'] is bool
          ? json['isRegistrationOpen'] as bool
          : true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      club: club,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  bool get isOngoing {
    final now = DateTime.now();
    return status == 'ongoing' ||
        (eventStartTime.isBefore(now) &&
            eventEndTime.isAfter(now) &&
            status != 'completed' &&
            status != 'cancelled');
  }

  bool get isUpcoming {
    final now = DateTime.now();
    return eventStartTime.isAfter(now) &&
        status != 'completed' &&
        status != 'cancelled' &&
        status != 'ongoing';
  }

  bool get isCompleted {
    final now = DateTime.now();
    return status == 'completed' || eventEndTime.isBefore(now);
  }

  bool get isCancelled {
    return status == 'cancelled';
  }

  bool get canRegister {
    if (!isRegistrationOpen) return false;
    if (registrationDeadline != null &&
        DateTime.now().isAfter(registrationDeadline!)) {
      return false;
    }
    if (maxParticipants != null && currentParticipants >= maxParticipants!) {
      return false;
    }
    return true;
  }
}

class EventRegistration {
  final int id;
  final String userId;
  final int eventId;
  final String status;
  final DateTime registeredAt;
  final DateTime? attendedAt;
  final DateTime? cancelledAt;
  final String? notes;
  final ClubEvent? event;

  EventRegistration({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.status,
    required this.registeredAt,
    this.attendedAt,
    this.cancelledAt,
    this.notes,
    this.event,
  });

  factory EventRegistration.fromJson(Map<String, dynamic> json) {
    ClubEvent? parsedEvent;

    // Parse event if present (may be partial data from enrollment endpoint)
    if (json['event'] != null) {
      try {
        final eventJson = json['event'] as Map<String, dynamic>;
        parsedEvent = ClubEvent.fromPartialJson(eventJson);
      } catch (e) {
        debugPrint('Error parsing event in registration: $e');
      }
    }

    return EventRegistration(
      id: ClubEvent._parseInt(json['id']) ?? 0,
      userId: json['userId']?.toString() ?? '',
      eventId: ClubEvent._parseInt(json['eventId']) ?? 0,
      status: json['status']?.toString() ?? '',
      registeredAt: json['registeredAt'] != null
          ? DateTime.parse(json['registeredAt'].toString())
          : DateTime.now(),
      attendedAt: json['attendedAt'] != null
          ? DateTime.tryParse(json['attendedAt'].toString())
          : null,
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.tryParse(json['cancelledAt'].toString())
          : null,
      notes: json['notes']?.toString(),
      event: parsedEvent,
    );
  }
}
