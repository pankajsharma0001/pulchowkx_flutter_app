import 'package:flutter/material.dart';
import 'package:pulchowkx_app/services/api_service.dart';

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
      id: _parseId(json['id']) ?? 0,
      type: json['type'] as String? ?? 'general',
      title: json['title'] as String? ?? 'Notification',
      body: json['body'] as String? ?? '',
      data: json['data'] as Map<String, dynamic>?,
      recipientId: json['recipientId']?.toString(),
      audience: NotificationAudience.fromString(
        json['audience'] as String? ?? 'direct',
      ),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      isRead: json['isRead'] == true || json['isRead'] == 1,
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'].toString())
          : null,
    );
  }

  String? get thumbnailUrl {
    final url =
        (data?['thumbnailUrl'] ??
                data?['imageUrl'] ??
                data?['image_url'] ??
                data?['bannerUrl'] ??
                data?['attachmentUrl'])
            as String?;
    return ApiService.processImageUrl(url);
  }

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
    if (type.contains('lost_found') || type.contains('item')) {
      return Icons.find_in_page_rounded;
    }

    switch (iconKey) {
      case 'event':
        return Icons.event_rounded;
      case 'book':
      case 'purchase_request':
        return Icons.menu_book_rounded;
      case 'notice':
        return Icons.notifications_active_rounded;
      case 'classroom':
        return Icons.school_rounded;
      case 'general':
      default:
        if (type.contains('event')) return Icons.event_rounded;
        if (type.contains('book') || type.contains('purchase')) {
          return Icons.menu_book_rounded;
        }
        if (type.contains('notice')) return Icons.notifications_active_rounded;
        return Icons.notifications_rounded;
    }
  }
}
