import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pulchowkx_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulchowkx_app/main.dart' show navigatorKey;
import 'package:pulchowkx_app/pages/marketplace/chat_room.dart';
import 'dart:convert';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);

      // Initialize local notifications for foreground alerts
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle notification tap
          if (response.payload != null) {
            try {
              final data =
                  jsonDecode(response.payload!) as Map<String, dynamic>;
              _handleNotificationClick(data);
            } catch (e) {
              debugPrint('Error parsing notification payload: $e');
            }
          }
        },
      );

      // Create high importance channel for Android
      if (Platform.isAndroid) {
        const channel = AndroidNotificationChannel(
          'high_importance_channel',
          'High Importance Notifications',
          description: 'This channel is used for important campus updates.',
          importance: Importance.max,
        );

        await _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(channel);
      }

      // Auto-subscribe to default topics if enabled in settings
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('notify_events') ?? true) {
        await subscribeToTopic('events');
      }
      if (prefs.getBool('notify_books') ?? true) {
        await subscribeToTopic('books');
      }
      if (prefs.getBool('notify_announcements') ?? true) {
        await subscribeToTopic('announcements');
      }

      // Sync FCM token if user is already logged in
      await syncToken();

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint('Got a message whilst in the foreground!');

        final data = message.data;
        final sellerId = data['sellerId'];

        if (sellerId != null) {
          final apiService = ApiService();
          final currentUserId = await apiService.getDatabaseUserId();
          if (currentUserId != null && currentUserId == sellerId) {
            debugPrint(
              "Suppressing foreground notification for own book listing.",
            );
            return;
          }
        }

        final notification = message.notification;
        // If it's a data-only message with title/body in data
        final title = notification?.title ?? data['title'];
        final body = notification?.body ?? data['body'];

        if (title != null && body != null) {
          _showLocalNotification(
            notification.hashCode,
            title,
            body,
            jsonEncode(message.data),
            androidIcon: message.notification?.android?.smallIcon,
          );
        }
      });

      // Handle message open app
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('A new onMessageOpenedApp event was published!');
        _handleNotificationClick(message.data);
      });

      // Handle terminated state
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('App opened from terminated state via FCM');
        _handleNotificationClick(initialMessage.data);
      }

      final launchDetails = await _localNotifications
          .getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        if (launchDetails.notificationResponse?.payload != null) {
          debugPrint('App opened from terminated state via local notification');
          try {
            final data =
                jsonDecode(launchDetails.notificationResponse!.payload!)
                    as Map<String, dynamic>;
            _handleNotificationClick(data);
          } catch (e) {
            debugPrint('Error parsing launch notification: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Notification service initialization failed: $e');
    }
  }

  static Future<String?> getToken() async {
    final token = await _messaging.getToken();
    debugPrint('FCM Token: $token');
    return token;
  }

  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic $topic: $e');
    }
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('Unsubscribed from topic: $topic');
  }

  /// Unsubscribe from all notification topics (used during logout)
  static Future<void> unsubscribeFromAllTopics() async {
    try {
      await _messaging.unsubscribeFromTopic('events');
      await _messaging.unsubscribeFromTopic('books');
      await _messaging.unsubscribeFromTopic('announcements');
      debugPrint('Unsubscribed from all notification topics');
    } catch (e) {
      debugPrint('Error unsubscribing from topics: $e');
    }
  }

  static Future<void> syncToken() async {
    try {
      final token = await getToken();
      if (token == null) return;

      final apiService = ApiService();
      final dbUserId = await apiService.getDatabaseUserId();

      // We only sync if we have a stored database user ID (logged in)
      if (dbUserId != null) {
        // Set up token refresh listener
        _messaging.onTokenRefresh.listen((newToken) async {
          debugPrint('FCM token refreshed, syncing to server...');
          await _syncTokenToServer(newToken);
        });
      }
    } catch (e) {
      debugPrint('Error setting up token sync: $e');
    }
  }

  /// Sync FCM token to server when it refreshes
  static Future<void> _syncTokenToServer(String fcmToken) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('Cannot sync FCM token: User not logged in');
        return;
      }

      final firebaseIdToken = await user.getIdToken();
      if (firebaseIdToken == null) {
        debugPrint('Cannot sync FCM token: Could not get Firebase ID token');
        return;
      }

      final apiService = ApiService();
      await apiService.updateFcmToken(firebaseIdToken, fcmToken);
    } catch (e) {
      debugPrint('Error syncing FCM token to server: $e');
    }
  }

  static Future<void> subscribeToFaculty(int facultyId) async {
    await subscribeToTopic('faculty_$facultyId');
  }

  static Future<bool> hasPermission() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  static Future<void> _handleNotificationClick(
    Map<String, dynamic> data,
  ) async {
    if (data['type'] == 'chat_message' && data['conversationId'] != null) {
      final conversationId = int.tryParse(data['conversationId'].toString());
      if (conversationId == null) return;

      // Ensure navigator is ready, especially on terminated launch
      int retries = 0;
      while (navigatorKey.currentState == null && retries < 10) {
        debugPrint('Waiting for navigator state... (retry $retries)');
        await Future.delayed(const Duration(milliseconds: 500));
        retries++;
      }

      if (navigatorKey.currentState == null) {
        debugPrint('Navigator state is still null after retries');
        return;
      }

      final apiService = ApiService();
      try {
        final conversations = await apiService.getConversations();
        final conversationIndex = conversations.indexWhere(
          (c) => c.id == conversationId,
        );

        if (conversationIndex != -1) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) =>
                  ChatRoomPage(conversation: conversations[conversationIndex]),
            ),
          );
        } else {
          debugPrint('Conversation $conversationId not found in user list');
        }
      } catch (e) {
        debugPrint('Error navigating to chat: $e');
      }
    }
  }

  static Future<void> _showLocalNotification(
    int id,
    String title,
    String body,
    String? payload, {
    String? androidIcon,
  }) async {
    await _localNotifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription:
              'This channel is used for important campus updates.',
          importance: Importance.max,
          priority: Priority.high,
          icon: androidIcon,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }
}

// Global background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");

  final data = message.data;
  final sellerId = data['sellerId'];

  // If no sellerId, let it proceed (or handle other types)
  // If sellerId is present, check against current user
  if (sellerId != null) {
    final apiService = ApiService();
    // We need to initialize shared prefs or secure storage to get the user ID
    // ApiService getDatabaseUserId uses SecureStorage, which should work in background isolation in most cases?
    // Actually, background isolate might not share the same instance.
    // But SecureStorage is disk-based.

    try {
      // Initialize necessary bindings for background execution
      // WidgetsFlutterBinding.ensureInitialized(); // Should be done by Firebase

      final currentUserId = await apiService.getDatabaseUserId();
      if (currentUserId != null && currentUserId == sellerId) {
        debugPrint("Suppressing notification for own book listing.");
        return;
      }
    } catch (e) {
      debugPrint("Error checking user ID in background: $e");
    }
  }

  // If we shouldn't suppress, we need to show it manually because it's a data-only message now (mostly)
  // Or if it had a notification block, the system showed it already?
  // Our backend change ensures `book` notifications are data-only.
  // So we MUST show it manually here for `books` topic.

  if (data['title'] != null && data['body'] != null) {
    await NotificationService._showLocalNotification(
      message.hashCode,
      data['title'],
      data['body'],
      jsonEncode(data),
    );
  } else if (message.notification != null) {
    // Fallback for standard notifications (e.g. from console)
    // If it has notification block, system handles it in background?
    // Not always reliable. But usually yes.
    // However, if we are here, it means we received it.
  }
}
