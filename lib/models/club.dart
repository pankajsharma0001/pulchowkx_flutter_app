import 'package:pulchowkx_app/services/api_service.dart';

class Club {
  final int id;
  final String authClubId;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? email;
  final bool isActive;
  final DateTime? createdAt;
  final int? upcomingEvents;
  final int? completedEvents;
  final int? totalParticipants;

  Club({
    required this.id,
    required this.authClubId,
    required this.name,
    this.description,
    this.logoUrl,
    this.email,
    this.isActive = true,
    this.createdAt,
    this.upcomingEvents,
    this.completedEvents,
    this.totalParticipants,
  });

  factory Club.fromJson(Map<String, dynamic> json) {
    return Club(
      id: json['id'] is int
          ? json['id'] as int
          : (json['id'] != null ? int.tryParse(json['id'].toString()) ?? 0 : 0),
      authClubId: json['authClubId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Club',
      description: json['description']?.toString(),
      logoUrl: ApiService.processImageUrl(json['logoUrl']?.toString()),
      email: json['email']?.toString(),
      isActive: json['isActive'] is bool ? json['isActive'] as bool : true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      upcomingEvents: _parseInt(json['upcomingEvents']),
      completedEvents: _parseInt(json['completedEvents']),
      totalParticipants: _parseInt(json['totalParticipants']),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authClubId': authClubId,
      'name': name,
      'description': description,
      'logoUrl': logoUrl,
      'email': email,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
      'upcomingEvents': upcomingEvents,
      'completedEvents': completedEvents,
      'totalParticipants': totalParticipants,
    };
  }
}

class ClubProfile {
  final int id;
  final int clubId;
  final String? aboutClub;
  final String? mission;
  final String? vision;
  final String? achievements;
  final String? benefits;
  final String? contactPhone;
  final String? address;
  final String? websiteUrl;
  final Map<String, String>? socialLinks;
  final int? establishedYear;
  final int totalEventHosted;
  final DateTime? updatedAt;

  ClubProfile({
    required this.id,
    required this.clubId,
    this.aboutClub,
    this.mission,
    this.vision,
    this.achievements,
    this.benefits,
    this.contactPhone,
    this.address,
    this.websiteUrl,
    this.socialLinks,
    this.establishedYear,
    this.totalEventHosted = 0,
    this.updatedAt,
  });

  factory ClubProfile.fromJson(Map<String, dynamic> json) {
    return ClubProfile(
      id: _parseIntRequired(json['id']),
      clubId: _parseIntRequired(json['clubId']),
      aboutClub: json['aboutClub'] as String?,
      mission: json['mission'] as String?,
      vision: json['vision'] as String?,
      achievements: json['achievements'] as String?,
      benefits: json['benefits'] as String?,
      contactPhone: json['contactPhone'] as String?,
      address: json['address'] as String?,
      websiteUrl: json['websiteUrl'] as String?,
      socialLinks: json['socialLinks'] != null
          ? Map<String, String>.from(json['socialLinks'] as Map)
          : null,
      establishedYear: Club._parseInt(json['establishedYear']),
      totalEventHosted: Club._parseInt(json['totalEventHosted']) ?? 0,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  static int _parseIntRequired(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.parse(value);
    throw FormatException('Cannot parse $value as int');
  }
}
