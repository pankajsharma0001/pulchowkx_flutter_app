import 'package:flutter/material.dart';

enum NotificationAudience {
  direct,
  all,
  students,
  teachers,
  admins;

  static NotificationAudience fromString(String value) {
    return NotificationAudience.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NotificationAudience.direct,
    );
  }
}

class InAppNotification {
  final int id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final String? recipientId;
  final NotificationAudience audience;
  final DateTime createdAt;
  final bool isRead;
  final DateTime? readAt;

  InAppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    this.recipientId,
    required this.audience,
    required this.createdAt,
    required this.isRead,
    this.readAt,
  });

  factory InAppNotification.fromJson(Map<String, dynamic> json) {
    return InAppNotification(
      id: json['id'] as int,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      data: json['data'] as Map<String, dynamic>?,
      recipientId: json['recipientId'] as String?,
      audience: NotificationAudience.fromString(
        json['audience'] as String? ?? 'direct',
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
      readAt: json['readAt'] != null
          ? DateTime.parse(json['readAt'] as String)
          : null,
    );
  }

  String? get thumbnailUrl => data?['thumbnailUrl'] as String?;
  String? get iconKey => data?['iconKey'] as String?;

  // Specific data IDs
  int? get eventId => _parseId(data?['eventId']);
  int? get noticeId => _parseId(data?['noticeId']);
  int? get listingId => _parseId(data?['listingId'] ?? data?['bookId']);
  String? get chatId => data?['chatId'] as String?;

  static int? _parseId(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    if (val is String) return int.tryParse(val);
    return null;
  }

  IconData getIcon() {
    switch (iconKey) {
      case 'event':
        return Icons.event_rounded;
      case 'book':
        return Icons.menu_book_rounded;
      case 'notice':
        return Icons.notifications_active_rounded;
      case 'classroom':
        return Icons.school_rounded;
      case 'general':
      default:
        return Icons.notifications_rounded;
    }
  }
}
