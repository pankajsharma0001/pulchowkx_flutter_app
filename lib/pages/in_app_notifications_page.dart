import 'package:flutter/material.dart';
import 'package:pulchowkx_app/models/in_app_notification.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:pulchowkx_app/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:pulchowkx_app/services/haptic_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pulchowkx_app/pages/event_details.dart';
import 'package:pulchowkx_app/pages/marketplace/chat_room.dart';
import 'package:pulchowkx_app/pages/notices.dart';
import 'package:pulchowkx_app/pages/book_details.dart';
import 'package:pulchowkx_app/pages/main_layout.dart';
import 'package:pulchowkx_app/services/in_app_notification_service.dart';
import 'package:pulchowkx_app/pages/notice_details_page.dart';
import 'package:pulchowkx_app/pages/lost_found/lost_found_details_page.dart';

class InAppNotificationsPage extends StatefulWidget {
  const InAppNotificationsPage({super.key});

  @override
  State<InAppNotificationsPage> createState() => _InAppNotificationsPageState();
}

class _InAppNotificationsPageState extends State<InAppNotificationsPage> {
  final ApiService _apiService = ApiService();
  List<InAppNotification> _notifications = [];
  bool _isLoading = true;
  String? _error;
  ValueNotifier<int>? _tabIndexNotifier;

  @override
  void initState() {
    super.initState();
    _loadNotifications();

    // Listen for tab changes to auto-pop this page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final mainLayout = MainLayout.of(context);
      if (mainLayout != null) {
        _tabIndexNotifier = mainLayout.tabIndexNotifier;
        _tabIndexNotifier?.addListener(_handleTabChange);
      }
    });
  }

  void _handleTabChange() {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _tabIndexNotifier?.removeListener(_handleTabChange);
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('Loading in-app notifications...');
      final notifications = await _apiService.getInAppNotifications();
      debugPrint('Loaded ${notifications.length} notifications');

      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load notifications: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(InAppNotification notification) async {
    if (notification.isRead) return;

    final success = await _apiService.markNotificationAsRead(notification.id);
    if (success) {
      inAppNotifications.refreshUnreadCount();
      setState(() {
        _notifications = _notifications.map((n) {
          if (n.id == notification.id) {
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
      });
    }
  }

  Future<void> _markAllAsRead() async {
    haptics.mediumImpact();
    final success = await _apiService.markAllNotificationsAsRead();
    if (success) {
      inAppNotifications.refreshUnreadCount();
      setState(() {
        _notifications = _notifications.map((n) {
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
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_notifications.any((n) => !n.isRead))
            IconButton(
              icon: const Icon(Icons.done_all_rounded),
              tooltip: 'Mark all as read',
              onPressed: _markAllAsRead,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: _buildBody(isDark),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading && _notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: isDark ? AppColors.error : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadNotifications,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.notifications_none_rounded,
                  size: 64,
                  color: isDark
                      ? AppColors.textMutedDark.withValues(alpha: 0.5)
                      : AppColors.textMuted.withValues(alpha: 0.5),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Transform.rotate(
                    angle: 0.2,
                    child: Text(
                      'Zzz',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('No notifications yet', style: AppTextStyles.h3),
            const SizedBox(height: 8),
            Text(
              'We will notify you about important updates',
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        return _NotificationCard(
          notification: _notifications[index],
          onTap: () async {
            final notification = _notifications[index];
            _markAsRead(notification);
            _handleNotificationTap(notification);
          },
        );
      },
    );
  }

  void _handleNotificationTap(InAppNotification notification) async {
    final navigator = Navigator.of(context);

    // Navigate based on type and ID
    if (notification.type.contains('event') && notification.eventId != null) {
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (context) =>
              EventDetailsPage(eventId: notification.eventId!),
        ),
      );
    } else if (notification.type.contains('notice')) {
      final noticeIdStr = notification.data?['noticeId'];
      if (noticeIdStr != null) {
        final noticeId = int.tryParse(noticeIdStr.toString());
        if (noticeId != null) {
          navigator.pushReplacement(
            MaterialPageRoute(
              builder: (context) => NoticeDetailsPage(noticeId: noticeId),
            ),
          );
          return;
        }
      }

      // Fallback to Notices tab
      final mainLayout = MainLayout.of(context);
      if (mainLayout != null) {
        navigator.pop();
        mainLayout.setSelectedIndex(8);
      } else {
        navigator.pushReplacement(
          MaterialPageRoute(builder: (context) => const NoticesPage()),
        );
      }
    } else if ((notification.type.contains('book') ||
            notification.type.contains('purchase_request')) &&
        notification.listingId != null) {
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (context) =>
              BookDetailsPage(bookId: notification.listingId!),
        ),
      );
    } else if (notification.type.contains('lost_found')) {
      final itemIdStr = notification.data?['itemId'];
      if (itemIdStr != null) {
        final itemId = int.tryParse(itemIdStr.toString());
        if (itemId != null) {
          navigator.pushReplacement(
            MaterialPageRoute(
              builder: (context) => LostFoundDetailsPage(itemId: itemId),
            ),
          );
        }
      }
    } else if (notification.type == 'chat_message' &&
        notification.chatId != null) {
      final conversationId = int.tryParse(notification.chatId!);
      if (conversationId != null) {
        try {
          final conversations = await _apiService.getConversations();
          final conversation = conversations.firstWhere(
            (c) => c.id == conversationId,
          );
          navigator.pushReplacement(
            MaterialPageRoute(
              builder: (context) => ChatRoomPage(conversation: conversation),
            ),
          );
        } catch (e) {
          debugPrint('Error navigating to chat: $e');
        }
      }
    }
  }
}

class _NotificationCard extends StatelessWidget {
  final InAppNotification notification;
  final VoidCallback onTap;

  const _NotificationCard({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeStr = DateFormat('MMM d, h:mm a').format(notification.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.border,
          width: 0.5,
        ),
      ),
      color: notification.isRead
          ? (isDark ? AppColors.backgroundSecondaryDark : Colors.grey[50])
          : (isDark ? AppColors.surfaceDark : Colors.white),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIcon(isDark),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: AppTextStyles.h4.copyWith(
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timeStr,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: isDark
                            ? AppColors.textMutedDark
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (notification.thumbnailUrl != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: notification.thumbnailUrl!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        width: 50,
                        height: 50,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: notification.isRead
            ? (isDark ? Colors.grey[800] : Colors.grey[200])
            : AppColors.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        notification.getIcon(),
        size: 20,
        color: notification.isRead
            ? (isDark ? Colors.grey[400] : Colors.grey[600])
            : AppColors.primary,
      ),
    );
  }
}
