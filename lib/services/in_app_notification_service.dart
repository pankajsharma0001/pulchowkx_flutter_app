import 'package:flutter/material.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/models/in_app_notification.dart';

class InAppNotificationService {
  static final InAppNotificationService _instance =
      InAppNotificationService._internal();
  factory InAppNotificationService() => _instance;
  InAppNotificationService._internal();

  final ApiService _apiService = ApiService();
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  // Session-based state
  List<InAppNotification> notifications = [];
  int offset = 0;
  bool hasMore = true;
  bool isInitialized = false;
  bool needsRefresh = false;

  Future<void> refreshUnreadCount() async {
    try {
      final count = await _apiService.getUnreadNotificationCount();
      // If unread count increased, we definitely have new items
      if (count > unreadCount.value) {
        needsRefresh = true;
      }
      unreadCount.value = count;
    } catch (e) {
      debugPrint('Error refreshing unread count: $e');
    }
  }

  void updateState({
    required List<InAppNotification> newNotifications,
    required int newOffset,
    required bool newHasMore,
    bool clearExisting = false,
  }) {
    if (clearExisting) {
      notifications = newNotifications;
    } else {
      notifications.addAll(newNotifications);
    }
    offset = newOffset;
    hasMore = newHasMore;
    isInitialized = true;
    needsRefresh = false;
  }

  void clearState() {
    notifications = [];
    offset = 0;
    hasMore = true;
    isInitialized = false;
  }

  void markAsRead(int id) {
    final index = notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !notifications[index].isRead) {
      final n = notifications[index];
      notifications[index] = InAppNotification(
        id: n.id,
        type: n.type,
        title: n.title,
        body: n.body,
        data: n.data,
        recipientId: n.recipientId,
        audience: n.audience,
        createdAt: n.createdAt,
        isRead: true,
        readAt: DateTime.now(),
      );
      decrementCount();
    }
  }

  void markAllReadLocal() {
    notifications = notifications.map((n) {
      if (!n.isRead) {
        return InAppNotification(
          id: n.id,
          type: n.type,
          title: n.title,
          body: n.body,
          data: n.data,
          recipientId: n.recipientId,
          audience: n.audience,
          createdAt: n.createdAt,
          isRead: true,
          readAt: DateTime.now(),
        );
      }
      return n;
    }).toList();
    markAllRead();
  }

  void incrementCount() {
    unreadCount.value++;
  }

  void decrementCount() {
    if (unreadCount.value > 0) {
      unreadCount.value--;
    }
  }

  void markAllRead() {
    unreadCount.value = 0;
  }
}

// Global instance for easy access
final inAppNotifications = InAppNotificationService();
