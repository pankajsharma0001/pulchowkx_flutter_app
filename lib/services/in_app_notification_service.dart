import 'package:flutter/material.dart';
import 'package:pulchowkx_app/services/api_service.dart';

class InAppNotificationService {
  static final InAppNotificationService _instance =
      InAppNotificationService._internal();
  factory InAppNotificationService() => _instance;
  InAppNotificationService._internal();

  final ApiService _apiService = ApiService();
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  Future<void> refreshUnreadCount() async {
    try {
      final count = await _apiService.getUnreadNotificationCount();
      unreadCount.value = count;
    } catch (e) {
      debugPrint('Error refreshing unread count: $e');
    }
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
