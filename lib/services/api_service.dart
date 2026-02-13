import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pulchowkx_app/models/book_listing.dart';
import 'package:pulchowkx_app/models/chatbot_response.dart';
import 'package:pulchowkx_app/models/classroom.dart';
import 'package:pulchowkx_app/models/club.dart';
import 'package:pulchowkx_app/models/event.dart';
import 'package:pulchowkx_app/models/chat.dart';
import 'package:pulchowkx_app/models/notice.dart';
import 'package:pulchowkx_app/models/in_app_notification.dart';
import 'package:pulchowkx_app/models/trust.dart';
import 'package:pulchowkx_app/models/lost_found.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Result class for API operations that provides success status and error messages
class ApiResult<T> {
  final bool success;
  final String? message;
  final T? data;

  ApiResult({required this.success, this.message, this.data});

  factory ApiResult.success({String? message, T? data}) =>
      ApiResult(success: true, message: message, data: data);

  factory ApiResult.failure(String message) =>
      ApiResult(success: false, message: message);

  factory ApiResult.networkError() => ApiResult(
    success: false,
    message: 'No internet connection. Please check your network.',
  );

  factory ApiResult.serverError() => ApiResult(
    success: false,
    message: 'Server error. Please try again later.',
  );

  factory ApiResult.unauthorized() =>
      ApiResult(success: false, message: 'Please sign in to continue.');
}

class ApiService {
  static const String baseUrl = 'https://smart-pulchowk.vercel.app/api/events';
  static const String apiBaseUrl = 'https://smart-pulchowk.vercel.app/api';

  static const String _dbUserIdKey = 'database_user_id';
  static const String _userRoleKey = 'user_role';

  // Secure storage for sensitive data
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // ==================== USER ID MANAGEMENT ====================
  Future<String?> getDatabaseUserId() async {
    try {
      return await _secureStorage.read(key: _dbUserIdKey);
    } catch (e) {
      // Fallback to SharedPreferences for migration
      final prefs = await SharedPreferences.getInstance();
      final legacyId = prefs.getString(_dbUserIdKey);
      if (legacyId != null) {
        // Migrate to secure storage
        await _storeDatabaseUserId(legacyId);
        await prefs.remove(_dbUserIdKey);
      }
      return legacyId;
    }
  }

  /// Get the database user ID, throwing an exception if not available.
  /// This ensures we ALWAYS use the database ID for API calls, never Firebase UID.
  /// Returns the database user ID or null if user needs to re-authenticate.
  Future<String?> requireDatabaseUserId() async {
    final dbUserId = await getDatabaseUserId();
    if (dbUserId != null) return dbUserId;

    // Database ID not found - this shouldn't happen if sync worked properly
    // Log the issue for debugging
    debugPrint(
      'WARNING: Database user ID not found. User may need to re-authenticate.',
    );
    return null;
  }

  /// Store the database user ID securely
  Future<void> _storeDatabaseUserId(String id) async {
    await _secureStorage.write(key: _dbUserIdKey, value: id);
  }

  /// Clear stored user ID on logout
  Future<void> clearStoredUserId() async {
    await _secureStorage.delete(key: _dbUserIdKey);
    await _secureStorage.delete(key: _userRoleKey);
    // Also clear from SharedPreferences (migration cleanup)
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dbUserIdKey);
    await prefs.remove(_userRoleKey);
  }

  /// Clear FCM token from server on logout to prevent duplicate notifications
  /// Requires Firebase ID token for authentication
  Future<void> clearFcmToken(String? firebaseIdToken) async {
    try {
      if (firebaseIdToken == null) {
        debugPrint('Cannot clear FCM token: No Firebase ID token');
        return;
      }

      await http.post(
        Uri.parse('$apiBaseUrl/users/clear-fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $firebaseIdToken',
        },
      );
      debugPrint('FCM token cleared from server');
    } catch (e) {
      debugPrint('Error clearing FCM token: $e');
    }
  }

  /// Update FCM token on server when token refreshes
  /// Requires Firebase ID token for authentication
  Future<void> updateFcmToken(String? firebaseIdToken, String fcmToken) async {
    try {
      if (firebaseIdToken == null) {
        debugPrint('Cannot update FCM token: No Firebase ID token');
        return;
      }

      final response = await http.post(
        Uri.parse('$apiBaseUrl/users/update-fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $firebaseIdToken',
        },
        body: jsonEncode({'fcmToken': fcmToken}),
      );

      if (response.statusCode == 200) {
        debugPrint('FCM token updated on server');
      } else {
        debugPrint('Failed to update FCM token: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }

  /// Get the user's role (student, admin, etc.)
  Future<String> getUserRole() async {
    try {
      final role = await _secureStorage.read(key: _userRoleKey);
      if (role != null) return role;
    } catch (e) {
      debugPrint('Error reading role from secure storage: $e');
    }
    // Fallback to SharedPreferences for migration
    final prefs = await SharedPreferences.getInstance();
    final legacyRole = prefs.getString(_userRoleKey);
    if (legacyRole != null) {
      // Migrate to secure storage
      await _storeUserRole(legacyRole);
      await prefs.remove(_userRoleKey);
      return legacyRole;
    }
    return 'student';
  }

  /// Perform a background role sync with the server.
  /// This updates the local database ID and role without requiring a re-login.
  Future<void> refreshUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final idToken = await user.getIdToken(true); // Force refresh token
      if (idToken == null) return;

      await syncUser(
        authStudentId: user.uid,
        email: user.email ?? '',
        name: user.displayName ?? 'Unknown',
        firebaseIdToken: idToken,
        image: user.photoURL,
      );

      debugPrint('User role refreshed successfully');
    } catch (e) {
      debugPrint('Error refreshing user role: $e');
    }
  }

  /// Get overview statistics for admin dashboard
  Future<Map<String, dynamic>> getAdminOverview({
    bool forceRefresh = false,
  }) async {
    const String cacheKey = 'admin_overview_cache';

    // Try to get from cache first if not forcing refresh
    if (!forceRefresh) {
      final cachedData = await _getFromCache(cacheKey);
      if (cachedData != null) {
        try {
          final json = jsonDecode(cachedData);
          if (json['success'] == true && json['data'] != null) {
            return json['data'];
          }
        } catch (e) {
          debugPrint('Error parsing cached admin overview: $e');
        }
      }
    }

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/admin/overview'),
        headers: await _getAuthHeader(),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          await _saveToCache(cacheKey, response.body);
          return json['data'];
        }
      }
      return {'success': false, 'message': 'Failed to load admin overview'};
    } catch (e) {
      debugPrint('Error getting admin overview: $e');
      // Fallback to cache if network fails, even if forceRefresh was true
      if (forceRefresh) {
        final cachedData = await _getFromCache(cacheKey);
        if (cachedData != null) {
          try {
            final json = jsonDecode(cachedData);
            if (json['success'] == true && json['data'] != null) {
              return json['data'];
            }
          } catch (_) {}
        }
      }
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Check if user is admin
  Future<bool> isAdmin() async {
    final role = await getUserRole();
    return role == 'admin';
  }

  /// Check if user is a guest (non-campus email)
  Future<bool> isGuest() async {
    final role = await getUserRole();
    return role == 'guest';
  }

  /// Get list of users for admin
  Future<Map<String, dynamic>> getAdminUsers({
    String? search,
    String? role,
    int? limit,
    bool forceRefresh = false,
  }) async {
    final String cacheKey =
        'admin_users_cache_${search ?? ""}_${role ?? ""}_${limit ?? ""}';

    if (!forceRefresh) {
      final cachedData = await _getFromCache(cacheKey);
      if (cachedData != null) {
        try {
          final json = jsonDecode(cachedData);
          if (json['success'] == true) {
            return json;
          }
        } catch (e) {
          debugPrint('Error parsing cached admin users: $e');
        }
      }
    }

    try {
      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (role != null && role.isNotEmpty) queryParams['role'] = role;
      if (limit != null) queryParams['limit'] = limit.toString();

      final uri = Uri.parse(
        '$apiBaseUrl/admin/users',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: await _getAuthHeader());

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          await _saveToCache(cacheKey, response.body);
        }
        return json; // Backend returns { success, data: { users, pagination } }
      }
      return {'success': false, 'message': 'Failed to load users'};
    } catch (e) {
      debugPrint('Error getting admin users: $e');
      if (!forceRefresh) {
        final cachedData = await _getFromCache(cacheKey);
        if (cachedData != null) {
          try {
            return jsonDecode(cachedData);
          } catch (_) {}
        }
      }
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Update user role
  Future<bool> updateAdminUserRole(String userId, String newRole) async {
    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/admin/users/$userId/role'),
        headers: await _getAuthHeader(),
        body: jsonEncode({'role': newRole}),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating user role: $e');
      return false;
    }
  }

  /// Toggle seller verification
  Future<bool> toggleSellerVerification(String userId, bool verified) async {
    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/admin/users/$userId/verify-seller'),
        headers: await _getAuthHeader(),
        body: jsonEncode({'verified': verified}),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error toggling seller verification: $e');
      return false;
    }
  }

  /// Get moderation reports
  Future<Map<String, dynamic>> getModerationReports({
    String? status,
    bool forceRefresh = false,
  }) async {
    final String cacheKey = 'moderation_reports_cache_${status ?? "all"}';

    if (!forceRefresh) {
      final cachedData = await _getFromCache(cacheKey);
      if (cachedData != null) {
        try {
          final json = jsonDecode(cachedData);
          if (json['success'] == true) {
            return json;
          }
        } catch (e) {
          debugPrint('Error parsing cached moderation reports: $e');
        }
      }
    }

    try {
      final queryParams = <String, String>{};
      if (status != null) queryParams['status'] = status;

      final uri = Uri.parse(
        '$apiBaseUrl/admin/reports',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: await _getAuthHeader());

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          await _saveToCache(cacheKey, response.body);
        }
        return json;
      }
      return {'success': false, 'message': 'Failed to load reports'};
    } catch (e) {
      debugPrint('Error getting moderation reports: $e');
      if (!forceRefresh) {
        final cachedData = await _getFromCache(cacheKey);
        if (cachedData != null) {
          try {
            return jsonDecode(cachedData);
          } catch (_) {}
        }
      }
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Update moderation report status
  Future<bool> updateModerationReport(
    int reportId,
    String status,
    String? resolutionNotes,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/admin/reports/$reportId'),
        headers: await _getAuthHeader(),
        body: jsonEncode({
          'status': status,
          'resolutionNotes': resolutionNotes,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating moderation report: $e');
      return false;
    }
  }

  /// Store the user role securely
  Future<void> _storeUserRole(String role) async {
    await _secureStorage.write(key: _userRoleKey, value: role);
  }

  Future<String?> syncUser({
    required String authStudentId,
    required String email,
    required String name,
    required String firebaseIdToken,
    String? image,
    String? fcmToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/users/sync-user'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $firebaseIdToken',
        },
        body: jsonEncode({
          'authStudentId': authStudentId,
          'email': email,
          'name': name,
          'image': image,
          'fcmToken': fcmToken,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        final data = json['data'];
        if (data != null && data['success'] == true && data['user'] != null) {
          final databaseUserId = data['user']['id'] as String;
          final userRole = data['user']['role'] as String? ?? 'student';
          await _storeDatabaseUserId(databaseUserId);
          await _storeUserRole(userRole);
          return databaseUserId;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ==================== HEADER HELPERS ====================

  Future<Map<String, String>> _getAuthHeader() async {
    final user = FirebaseAuth.instance.currentUser;
    debugPrint('DEBUG: [Auth Header] Current User: ${user?.email}');
    final token = await user?.getIdToken();
    if (token == null) {
      debugPrint('DEBUG: [Auth Header] WARNING: Token is NULL');
    } else {
      debugPrint(
        'DEBUG: [Auth Header] Token prefix: ${token.substring(0, 10)}...',
      );
    }
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Get standard JSON header
  Map<String, String> _getJsonHeader() {
    return {'Content-Type': 'application/json'};
  }

  // ==================== CACHING & CONNECTIVITY ====================

  Future<bool> _hasInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) return false;

      // On Windows/Web, connectivity_plus might return wifi/mobile even if no real internet.
      // We don't want to over-engineer this with a ping, but we'll prioritize the try-catch in API calls.
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get data from cache
  Future<String?> _getFromCache(String key) async {
    try {
      final box = Hive.box('api_cache');
      return box.get(key) as String?;
    } catch (e) {
      debugPrint('Error reading from Hive cache: $e');
      return null;
    }
  }

  /// Save data to cache
  Future<void> _saveToCache(String key, String json) async {
    try {
      final box = Hive.box('api_cache');
      await box.put(key, json);
    } catch (e) {
      debugPrint('Error writing to Hive cache: $e');
    }
  }

  /// Remove data from cache
  Future<void> _removeFromCache(String key) async {
    try {
      final box = Hive.box('api_cache');
      await box.delete(key);
    } catch (e) {
      debugPrint('Error removing from Hive cache: $e');
    }
  }

  /// Invalidate enrollments cache for a user
  Future<void> invalidateEnrollmentsCache() async {
    final userId = await getDatabaseUserId();
    if (userId != null) {
      await _removeFromCache('enrollments_${userId}_cache');
    }
  }

  /// Invalidate clubs cache to force fresh fetch
  Future<void> invalidateClubsCache() async {
    await _removeFromCache('clubs_cache');
  }

  /// Invalidate specific club cache
  Future<void> invalidateClubCache(int clubId) async {
    await _removeFromCache('club_${clubId}_cache');
    await _removeFromCache('club_profile_${clubId}_cache');
    await _removeFromCache('club_events_${clubId}_cache');
  }

  /// Invalidate all events caches to force fresh fetch
  Future<void> invalidateEventsCache() async {
    await _removeFromCache('all_events_cache');
    await _removeFromCache('upcoming_events_cache');
  }

  /// Invalidate all club and event caches (for pull-to-refresh)
  Future<void> invalidateAllClubEventCaches() async {
    await invalidateClubsCache();
    await invalidateEventsCache();
  }

  /// Invalidate book listings cache to force fresh fetch
  Future<void> invalidateBookListingsCache() async {
    try {
      final box = Hive.box('api_cache');
      final keys = box.keys.where(
        (k) => k.toString().startsWith('book_listings_'),
      );
      for (final key in keys) {
        await box.delete(key);
      }
      debugPrint('Invalidated ${keys.length} book listings cache entries');
    } catch (e) {
      debugPrint('Error invalidating book listings cache: $e');
    }
  }

  // ==================== CLUBS ====================

  /// Get all clubs
  Future<List<Club>> getClubs() async {
    const String cacheKey = 'clubs_cache';
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/clubs'), headers: await _getAuthHeader())
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['data'];

        if (data['success'] == true && data['existingClub'] != null) {
          await _saveToCache(cacheKey, response.body);
          final List<dynamic> clubsJson = data['existingClub'];
          return clubsJson.map((c) => Club.fromJson(c)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching clubs online: $e');
    }

    // Offline or fallback
    final cachedData = await _getFromCache(cacheKey);
    if (cachedData != null) {
      try {
        final json = jsonDecode(cachedData);
        final data = json['data'];
        if (data['success'] == true && data['existingClub'] != null) {
          final List<dynamic> clubsJson = data['existingClub'];
          return clubsJson.map((c) => Club.fromJson(c)).toList();
        }
      } catch (e) {
        debugPrint('Error parsing cached clubs: $e');
      }
    }

    return [];
  }

  /// Get a single club by ID
  Future<Club?> getClub(int clubId) async {
    String cacheKey = 'club_${clubId}_cache';

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/clubs/$clubId'),
            headers: await _getAuthHeader(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['data'];

        if (data['success'] == true && data['clubData'] != null) {
          await _saveToCache(cacheKey, response.body);
          return Club.fromJson(data['clubData']);
        }
      }
    } catch (e) {
      debugPrint('Error fetching club online: $e');
    }

    // Offline or fallback
    final cachedData = await _getFromCache(cacheKey);
    if (cachedData != null) {
      try {
        final json = jsonDecode(cachedData);
        final data = json['data'];
        if (data['success'] == true && data['clubData'] != null) {
          return Club.fromJson(data['clubData']);
        }
      } catch (e) {
        debugPrint('Error parsing cached club: $e');
      }
    }

    return null;
  }

  /// Get club profile
  Future<ClubProfile?> getClubProfile(int clubId) async {
    String cacheKey = 'club_profile_${clubId}_cache';

    try {
      final response = await http
          .get(
            Uri.parse('$apiBaseUrl/clubs/club-profile/$clubId'),
            headers: await _getAuthHeader(),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        await _saveToCache(cacheKey, response.body);
        final json = jsonDecode(response.body);

        // Handle nested response format
        if (json['data'] != null) {
          final data = json['data'];
          if (data['success'] == true && data['profile'] != null) {
            return ClubProfile.fromJson(data['profile']);
          }
        }
        // Handle direct response format
        if (json['success'] == true && json['profile'] != null) {
          return ClubProfile.fromJson(json['profile']);
        }
      }
    } catch (e) {
      debugPrint('Error fetching club profile online: $e');
    }

    // Offline or fallback
    final cachedData = await _getFromCache(cacheKey);
    if (cachedData != null) {
      try {
        final json = jsonDecode(cachedData);
        if (json['data'] != null) {
          final data = json['data'];
          if (data['success'] == true && data['profile'] != null) {
            return ClubProfile.fromJson(data['profile']);
          }
        }
        if (json['success'] == true && json['profile'] != null) {
          return ClubProfile.fromJson(json['profile']);
        }
      } catch (e) {
        debugPrint('Error parsing cached club profile: $e');
      }
    }

    return null;
  }

  // ==================== EVENTS ====================

  /// Get all events
  Future<List<ClubEvent>> getAllEvents() async {
    const String cacheKey = 'all_events_cache';
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/all-events'),
            headers: await _getAuthHeader(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await _saveToCache(cacheKey, response.body);
        final json = jsonDecode(response.body);
        final data = json['data'];

        if (data['success'] == true && data['allEvents'] != null) {
          final List<dynamic> eventsJson = data['allEvents'];
          return eventsJson.map((e) => ClubEvent.fromJson(e)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching events online: $e');
    }

    // Offline or fallback
    final cachedData = await _getFromCache(cacheKey);
    if (cachedData != null) {
      try {
        final json = jsonDecode(cachedData);
        final data = json['data'];
        if (data['success'] == true && data['allEvents'] != null) {
          final List<dynamic> eventsJson = data['allEvents'];
          return eventsJson.map((e) => ClubEvent.fromJson(e)).toList();
        }
      } catch (e) {
        debugPrint('Error parsing cached events: $e');
      }
    }

    return [];
  }

  /// Get upcoming events
  Future<List<ClubEvent>> getUpcomingEvents() async {
    const String cacheKey = 'upcoming_events_cache';
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/get-upcoming-events'),
            headers: await _getAuthHeader(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await _saveToCache(cacheKey, response.body);
        final json = jsonDecode(response.body);
        final data = json['data'];

        if (data['success'] == true && data['upcomingEvents'] != null) {
          final List<dynamic> eventsJson = data['upcomingEvents'];
          return eventsJson.map((e) => ClubEvent.fromJson(e)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching upcoming events online: $e');
    }

    // Offline or fallback
    final cachedData = await _getFromCache(cacheKey);
    if (cachedData != null) {
      try {
        final json = jsonDecode(cachedData);
        final data = json['data'];
        if (data['success'] == true && data['upcomingEvents'] != null) {
          final List<dynamic> eventsJson = data['upcomingEvents'];
          return eventsJson.map((e) => ClubEvent.fromJson(e)).toList();
        }
      } catch (e) {
        debugPrint('Error parsing cached upcoming events: $e');
      }
    }

    return [];
  }

  /// Get events by club ID
  Future<List<ClubEvent>> getClubEvents(int clubId) async {
    String cacheKey = 'club_events_${clubId}_cache';
    bool isOnline = await _hasInternetConnection();

    if (isOnline) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/events/$clubId'),
          headers: await _getAuthHeader(),
        );

        if (response.statusCode == 200) {
          await _saveToCache(cacheKey, response.body);
          final json = jsonDecode(response.body);
          final data = json['data'];

          if (data['success'] == true && data['clubEvents'] != null) {
            final List<dynamic> eventsJson = data['clubEvents'];
            return eventsJson.map((e) => ClubEvent.fromJson(e)).toList();
          }
        }
      } catch (e) {
        debugPrint('Error fetching club events online: $e');
      }
    }

    // Offline or fallback
    final cachedData = await _getFromCache(cacheKey);
    if (cachedData != null) {
      try {
        final json = jsonDecode(cachedData);
        final data = json['data'];
        if (data['success'] == true && data['clubEvents'] != null) {
          final List<dynamic> eventsJson = data['clubEvents'];
          return eventsJson.map((e) => ClubEvent.fromJson(e)).toList();
        }
      } catch (e) {
        debugPrint('Error parsing cached club events: $e');
      }
    }

    return [];
  }

  // ==================== REGISTRATION ====================

  /// Register for an event - returns ApiResult with error message if failed
  Future<ApiResult> registerForEvent(String authStudentId, int eventId) async {
    try {
      final isOnline = await _hasInternetConnection();
      if (!isOnline) {
        return ApiResult.networkError();
      }

      final response = await http.post(
        Uri.parse('$baseUrl/register-event'),
        headers: await _getAuthHeader(),
        body: jsonEncode({'eventId': eventId}),
      );

      final json = jsonDecode(response.body);
      final data = json['data'] ?? json;
      final message = data['message'] as String? ?? 'Unknown error';

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['success'] == true) {
          // Invalidate enrollments cache so fresh data is fetched
          await invalidateEnrollmentsCache();
          return ApiResult.success(message: message);
        }
        return ApiResult.failure(message);
      } else if (response.statusCode == 400) {
        // Already registered, event full, registration closed, etc.
        return ApiResult.failure(message);
      } else if (response.statusCode == 401) {
        return ApiResult.unauthorized();
      } else if (response.statusCode == 404) {
        return ApiResult.failure('Event not found.');
      } else {
        return ApiResult.serverError();
      }
    } catch (e) {
      debugPrint('Error registering for event: $e');
      return ApiResult.failure('Failed to register. Please try again.');
    }
  }

  /// Cancel event registration - returns ApiResult with error message if failed
  Future<ApiResult> cancelRegistration(
    String authStudentId,
    int eventId,
  ) async {
    try {
      final isOnline = await _hasInternetConnection();
      if (!isOnline) {
        return ApiResult.networkError();
      }

      final response = await http.post(
        Uri.parse('$baseUrl/cancel-registration'),
        headers: await _getAuthHeader(),
        body: jsonEncode({'eventId': eventId}),
      );

      final json = jsonDecode(response.body);
      final data = json['data'] ?? json;
      final message = data['message'] as String? ?? 'Unknown error';

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['success'] == true) {
          // Invalidate enrollments cache so fresh data is fetched
          await invalidateEnrollmentsCache();
          return ApiResult.success(message: message);
        }
        return ApiResult.failure(message);
      } else if (response.statusCode == 400) {
        return ApiResult.failure(message);
      } else if (response.statusCode == 401) {
        return ApiResult.unauthorized();
      } else if (response.statusCode == 404) {
        return ApiResult.failure('Registration not found.');
      } else {
        return ApiResult.serverError();
      }
    } catch (e) {
      debugPrint('Error cancelling registration: $e');
      return ApiResult.failure('Failed to cancel. Please try again.');
    }
  }

  /// Get user's enrollments
  Future<List<EventRegistration>> getEnrollments(String authStudentId) async {
    String cacheKey = 'enrollments_${authStudentId}_cache';
    bool isOnline = await _hasInternetConnection();

    if (isOnline) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/enrollment'),
          headers: await _getAuthHeader(),
          body: jsonEncode({'authStudentId': authStudentId}),
        );
        if (response.statusCode == 200) {
          await _saveToCache(cacheKey, response.body);
          final json = jsonDecode(response.body);

          // Handle nested response format
          if (json['data'] != null) {
            final data = json['data'];
            if (data['success'] == true && data['registrations'] != null) {
              final List<dynamic> registrationsJson = data['registrations'];
              return registrationsJson
                  .map((r) => EventRegistration.fromJson(r))
                  .toList();
            }
          }
          // Handle direct response format
          if (json['success'] == true && json['registrations'] != null) {
            final List<dynamic> registrationsJson = json['registrations'];
            return registrationsJson
                .map((r) => EventRegistration.fromJson(r))
                .toList();
          }
        }
      } catch (e) {
        debugPrint('Error fetching enrollments online: $e');
      }
    }

    // Offline or fallback
    final cachedData = await _getFromCache(cacheKey);
    if (cachedData != null) {
      try {
        final json = jsonDecode(cachedData);
        if (json['data'] != null) {
          final data = json['data'];
          if (data['success'] == true && data['registrations'] != null) {
            final List<dynamic> registrationsJson = data['registrations'];
            return registrationsJson
                .map((r) => EventRegistration.fromJson(r))
                .toList();
          }
        }
        if (json['success'] == true && json['registrations'] != null) {
          final List<dynamic> registrationsJson = json['registrations'];
          return registrationsJson
              .map((r) => EventRegistration.fromJson(r))
              .toList();
        }
      } catch (e) {
        return [];
      }
    }

    return [];
  }

  // ==================== CHATBOT ====================

  /// Send a query to the campus navigation chatbot
  Future<ChatBotResponse> chatBot(String query) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/chatbot/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query}),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return ChatBotResponse.fromJson(json);
      }

      return ChatBotResponse(
        success: false,
        errorMessage: 'Server error: ${response.statusCode}',
      );
    } catch (e) {
      return ChatBotResponse(success: false, errorMessage: 'Network error: $e');
    }
  }

  // ==================== ADMIN: EVENT MANAGEMENT ====================

  /// Create a new event for a club
  Future<Map<String, dynamic>> createEvent({
    required String authId,
    required int clubId,
    required String title,
    required String description,
    required String eventType,
    required String venue,
    int? maxParticipants,
    required String registrationDeadline,
    required String eventStartTime,
    required String eventEndTime,
    String? bannerUrl,
    String? externalRegistrationLink,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/create-event'),
        headers: await _getAuthHeader(),
        body: jsonEncode({
          'authId': authId,
          'clubId': clubId,
          'title': title,
          'description': description,
          'eventType': eventType,
          'venue': venue,
          'maxParticipants': maxParticipants,
          'registrationDeadline': registrationDeadline,
          'eventStartTime': eventStartTime,
          'eventEndTime': eventEndTime,
          'bannerUrl': bannerUrl,
          'externalRegistrationLink': externalRegistrationLink,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        final data = json['data'] ?? json;
        return {
          'success': data['success'] == true,
          'event': data['event'],
          'message': data['message'],
        };
      }
      return {
        'success': false,
        'message': 'Server error: ${response.statusCode}',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Cancel an event (club owner/admin only)
  Future<Map<String, dynamic>> cancelEvent(int eventId) async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.put(
        Uri.parse('$baseUrl/$eventId/cancel'),
        headers: await _getAuthHeader(),
      );

      final json = jsonDecode(response.body);
      return {
        'success': json['success'] == true,
        'message': json['message'] ?? 'Event cancelled',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ==================== ADMIN: CLUB MANAGEMENT ====================

  /// Create a new club (admin only)
  Future<Map<String, dynamic>> createClub({
    required String name,
    required String email,
    String? description,
    String? logoUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/create-club'),
        headers: await _getAuthHeader(),
        body: jsonEncode({
          'name': name,
          'email': email,
          'description': description,
          'logoUrl': logoUrl,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        final data = json['data'] ?? json;
        return {
          'success': data['success'] == true,
          'club': data['club'],
          'message': data['message'],
        };
      }
      return {
        'success': false,
        'message': 'Server error: ${response.statusCode}',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Update club information
  Future<Map<String, dynamic>> updateClubInfo(
    int clubId,
    Map<String, dynamic> clubData,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/clubs/$clubId'),
        headers: await _getAuthHeader(),
        body: jsonEncode(clubData),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['data'] ?? json;
        return {'success': data['success'] == true, 'message': data['message']};
      }
      return {
        'success': false,
        'message': 'Server error: ${response.statusCode}',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Update club profile
  Future<Map<String, dynamic>> updateClubProfile(
    int clubId,
    Map<String, dynamic> profileData,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/clubs/club-profile/$clubId'),
        headers: await _getAuthHeader(),
        body: jsonEncode(profileData),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['data'] ?? json;
        return {
          'success': data['success'] == true,
          'profile': data['profile'],
          'message': data['message'],
        };
      }
      return {
        'success': false,
        'message': 'Server error: ${response.statusCode}',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ==================== ADMIN: CLUB ADMIN MANAGEMENT ====================

  /// Get list of admins for a club
  Future<List<Map<String, dynamic>>> getClubAdmins(int clubId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/club/admins/$clubId'),
        headers: await _getAuthHeader(),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['data'] ?? json;
        if (data['success'] == true && data['admins'] != null) {
          return List<Map<String, dynamic>>.from(data['admins']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Add a club admin
  Future<Map<String, dynamic>> addClubAdmin({
    required int clubId,
    required String email,
    required String ownerId,
  }) async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) {
        return {
          'success': false,
          'message': 'Not authenticated. Please sign out and sign in again.',
        };
      }

      final response = await http.post(
        Uri.parse('$baseUrl/club/add-admin'),
        headers: await _getAuthHeader(),
        body: jsonEncode({
          'clubId': clubId,
          'email': email,
          'ownerId': ownerId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        final data = json['data'] ?? json;
        return {'success': data['success'] == true, 'message': data['message']};
      }
      // Parse error message from response if available
      try {
        final errorJson = jsonDecode(response.body);
        final errorData = errorJson['data'] ?? errorJson;
        return {
          'success': false,
          'message':
              errorData['message'] ?? 'Server error: ${response.statusCode}',
        };
      } catch (_) {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Remove a club admin
  Future<Map<String, dynamic>> removeClubAdmin({
    required int clubId,
    required String userId,
    required String ownerId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/club/remove-admin'),
        headers: await _getAuthHeader(),
        body: jsonEncode({
          'clubId': clubId,
          'userId': userId,
          'ownerId': ownerId,
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['data'] ?? json;
        return {'success': data['success'] == true, 'message': data['message']};
      }
      return {
        'success': false,
        'message': 'Server error: ${response.statusCode}',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Check if current user is admin or owner of a club
  Future<bool> isClubAdminOrOwner(int clubId, String? userId) async {
    if (userId == null) return false;

    try {
      // First check if user is club owner
      final club = await getClub(clubId);
      if (club != null && club.authClubId == userId) {
        return true;
      }

      // Check if user is in club admins list
      final admins = await getClubAdmins(clubId);
      return admins.any((admin) => admin['id'] == userId);
    } catch (e) {
      return false;
    }
  }

  // ==================== EVENT EXTRA DETAILS ====================

  /// Get registered students for an event
  Future<List<Map<String, dynamic>>> getRegisteredStudents(int eventId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/registered-student'),
        headers: await _getAuthHeader(),
        body: jsonEncode({'eventId': eventId}),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['data'] ?? json;
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        if (data['registrations'] != null) {
          return List<Map<String, dynamic>>.from(data['registrations']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get export URL for registered students
  Future<String?> getExportRegisteredStudentsUrl(
    int eventId,
    String format,
  ) async {
    final userId = await getDatabaseUserId();
    if (userId == null) return null;
    return '$apiBaseUrl/events/$eventId/export-students?format=$format&token=$userId';
  }

  /// Get export URL for assignment submissions
  Future<String?> getExportAssignmentSubmissionsUrl(
    int assignmentId,
    String format,
  ) async {
    final userId = await getDatabaseUserId();
    if (userId == null) return null;
    return '$apiBaseUrl/classroom/assignments/$assignmentId/export-submissions?format=$format&token=$userId';
  }

  /// Get extra event details
  Future<Map<String, dynamic>?> getExtraEventDetails(int eventId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/clubs/event-details/$eventId'),
        headers: await _getAuthHeader(),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['details'] != null) {
          return Map<String, dynamic>.from(json['details']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Create extra event details
  Future<Map<String, dynamic>> createExtraEventDetails(
    int eventId,
    Map<String, dynamic> detailsData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/clubs/event-details/create-event-details'),
        headers: await _getAuthHeader(),
        body: jsonEncode({'eventId': eventId, ...detailsData}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        return {
          'success': json['success'] == true,
          'details': json['details'],
          'message': json['message'],
        };
      }
      return {
        'success': false,
        'message': 'Server error: ${response.statusCode}',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Update extra event details
  Future<Map<String, dynamic>> updateExtraEventDetails(
    int eventId,
    Map<String, dynamic> detailsData,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/clubs/event-details/update-eventdetail'),
        headers: await _getAuthHeader(),
        body: jsonEncode({'eventId': eventId, ...detailsData}),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return {
          'success': json['success'] == true,
          'details': json['details'],
          'message': json['message'],
        };
      }
      return {
        'success': false,
        'message': 'Server error: ${response.statusCode}',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ==================== IMAGE UPLOADS ====================

  /// Upload an image and return the URL
  Future<Map<String, dynamic>> uploadClubLogo(
    int clubId,
    File imageFile,
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBaseUrl/clubs/$clubId/upload-logo'),
      );

      request.headers.addAll(await _getAuthHeader());

      request.files.add(
        await http.MultipartFile.fromPath(
          'logo',
          imageFile.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'url': data['data']['url'],
          'message': 'Upload successful',
        };
      } else {
        return {
          'success': false,
          'message': 'Upload failed: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Upload error: $e'};
    }
  }

  /// Generic upload for event banners
  Future<Map<String, dynamic>> uploadEventBanner(
    int eventId,
    File imageFile,
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBaseUrl/events/$eventId/upload-banner'),
      );
      request.headers.addAll(await _getAuthHeader());

      request.files.add(
        await http.MultipartFile.fromPath(
          'banner',
          imageFile.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'url': data['data']?['url'] ?? data['url'],
          'message': 'Upload successful',
        };
      } else {
        return {
          'success': false,
          'message': 'Upload failed: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Upload error: $e'};
    }
  }

  // ==================== BOOKS API ====================

  /// Get book listings with filters
  Future<BookListingsResponse?> getBookListings([BookFilters? filters]) async {
    final queryParams =
        filters?.toQueryParams() ?? {'page': '1', 'limit': '12'};
    final cacheKey = 'book_listings_${queryParams.toString()}';
    bool isOnline = await _hasInternetConnection();

    if (isOnline) {
      try {
        final uri = Uri.parse(
          '$apiBaseUrl/books',
        ).replace(queryParameters: queryParams);

        final response = await http.get(uri, headers: await _getAuthHeader());

        if (response.statusCode == 200) {
          await _saveToCache(cacheKey, response.body);
          final json = jsonDecode(response.body);
          if (json['success'] == true && json['data'] != null) {
            return BookListingsResponse.fromJson(
              json['data'] as Map<String, dynamic>,
            );
          }
        }
      } catch (e) {
        debugPrint('Error fetching book listings online: $e');
      }
    }

    // Offline or fallback
    final cachedData = await _getFromCache(cacheKey);
    if (cachedData != null) {
      try {
        final json = jsonDecode(cachedData);
        if (json['success'] == true && json['data'] != null) {
          return BookListingsResponse.fromJson(
            json['data'] as Map<String, dynamic>,
          );
        }
      } catch (e) {
        debugPrint('Error parsing cached book listings: $e');
      }
    }

    return null;
  }

  /// Get a single book listing by ID (cache-first for instant loading)
  Future<BookListing?> getBookListingById(int id) async {
    final String cacheKey = 'book_listing_${id}_cache';

    // 1. Try cache first
    final cachedData = await _getFromCache(cacheKey);
    if (cachedData != null) {
      try {
        final json = jsonDecode(cachedData);
        if (json['success'] == true && json['data'] != null) {
          final book = BookListing.fromJson(
            json['data'] as Map<String, dynamic>,
          );
          // Refresh in background if online
          _refreshBookListingInBackground(id, cacheKey);
          return book;
        }
      } catch (e) {
        debugPrint('Error parsing cached book details: $e');
      }
    }

    // 2. If no cache or error parsing, fetch from network
    return _fetchBookListingFromNetwork(id, cacheKey);
  }

  /// Refreshes book listing details in the background
  Future<void> _refreshBookListingInBackground(int id, String cacheKey) async {
    if (await _hasInternetConnection()) {
      await _fetchBookListingFromNetwork(id, cacheKey);
    }
  }

  /// Fetches book listing from network and saves to cache
  Future<BookListing?> _fetchBookListingFromNetwork(
    int id,
    String cacheKey,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse('$apiBaseUrl/books/listings/$id'),
            headers: await _getAuthHeader(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await _saveToCache(cacheKey, response.body);
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return BookListing.fromJson(json['data'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('Error fetching book details online: $e');
    }
    return null;
  }

  /// Create a new book listing
  Future<Map<String, dynamic>> createBookListing({
    required String title,
    required String author,
    required String condition,
    required String price,
    String? isbn,
    String? edition,
    String? publisher,
    int? publicationYear,
    String? description,
    String? courseCode,
    int? categoryId,
  }) async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$apiBaseUrl/books'),
        headers: await _getAuthHeader(),
        body: jsonEncode({
          'title': title,
          'author': author,
          'condition': condition,
          'price': price,
          if (isbn != null) 'isbn': isbn,
          if (edition != null) 'edition': edition,
          if (publisher != null) 'publisher': publisher,
          if (publicationYear != null) 'publicationYear': publicationYear,
          if (description != null) 'description': description,
          if (courseCode != null) 'courseCode': courseCode,
          if (categoryId != null) 'categoryId': categoryId,
        }),
      );

      final json = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': json['success'] == true,
          'data': json['data'] != null
              ? BookListing.fromJson(json['data'] as Map<String, dynamic>)
              : null,
          'message': json['message'],
        };
      }
      return {
        'success': false,
        'message': json['message'] ?? 'Failed to create listing',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Update an existing book listing
  Future<Map<String, dynamic>> updateBookListing(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.put(
        Uri.parse('$apiBaseUrl/books/listings/$id'),
        headers: await _getAuthHeader(),
        body: jsonEncode(data),
      );

      final json = jsonDecode(response.body);
      return {
        'success': json['success'] == true,
        'data': json['data'] != null
            ? BookListing.fromJson(json['data'] as Map<String, dynamic>)
            : null,
        'message': json['message'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Delete a book listing
  Future<Map<String, dynamic>> deleteBookListing(int id) async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.delete(
        Uri.parse('$apiBaseUrl/books/listings/$id'),
        headers: await _getAuthHeader(),
      );

      final json = jsonDecode(response.body);
      return {'success': json['success'] == true, 'message': json['message']};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Get current user's book listings
  Future<List<BookListing>> getMyBookListings() async {
    final userId = await getDatabaseUserId();
    if (userId == null) return [];

    final String cacheKey = 'my_book_listings_${userId}_cache';
    bool isOnline = await _hasInternetConnection();

    if (isOnline) {
      try {
        final response = await http.get(
          Uri.parse('$apiBaseUrl/books/my-listings'),
          headers: await _getAuthHeader(),
        );

        if (response.statusCode == 200) {
          await _saveToCache(cacheKey, response.body);
          final json = jsonDecode(response.body);
          if (json['success'] == true && json['data'] != null) {
            return (json['data'] as List)
                .map((e) => BookListing.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        }
      } catch (e) {
        debugPrint('Error fetching my listings online: $e');
      }
    }

    // Offline or fallback
    final cachedData = await _getFromCache(cacheKey);
    if (cachedData != null) {
      try {
        final json = jsonDecode(cachedData);
        if (json['success'] == true && json['data'] != null) {
          return (json['data'] as List)
              .map((e) => BookListing.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        debugPrint('Error parsing cached my listings: $e');
      }
    }

    return [];
  }

  /// Mark a book as sold
  Future<Map<String, dynamic>> markBookAsSold(int id) async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.put(
        Uri.parse('$apiBaseUrl/books/listings/$id/mark-sold'),
        headers: await _getAuthHeader(),
      );

      final json = jsonDecode(response.body);
      return {'success': json['success'] == true, 'message': json['message']};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Upload a book image
  Future<Map<String, dynamic>> uploadBookImage(
    int listingId,
    File imageFile,
  ) async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBaseUrl/books/listings/$listingId/images'),
      );
      request.headers.addAll(await _getAuthHeader());
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final json = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': json['success'] == true,
          'data': json['data'] != null
              ? BookImage.fromJson(json['data'] as Map<String, dynamic>)
              : null,
        };
      }
      return {'success': false, 'message': json['message'] ?? 'Upload failed'};
    } catch (e) {
      return {'success': false, 'message': 'Upload error: $e'};
    }
  }

  /// Delete a book image
  Future<Map<String, dynamic>> deleteBookImage(
    int listingId,
    int imageId,
  ) async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.delete(
        Uri.parse('$apiBaseUrl/books/listings/$listingId/images/$imageId'),
        headers: await _getAuthHeader(),
      );

      final json = jsonDecode(response.body);
      return {'success': json['success'] == true, 'message': json['message']};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Get saved books
  Future<List<SavedBook>> getSavedBooks() async {
    final userId = await getDatabaseUserId();
    if (userId == null) return [];

    final String cacheKey = 'saved_books_${userId}_cache';
    bool isOnline = await _hasInternetConnection();

    if (isOnline) {
      try {
        final response = await http.get(
          Uri.parse('$apiBaseUrl/books/saved'),
          headers: await _getAuthHeader(),
        );

        if (response.statusCode == 200) {
          await _saveToCache(cacheKey, response.body);
          final json = jsonDecode(response.body);
          if (json['success'] == true && json['data'] != null) {
            return (json['data'] as List)
                .map((e) => SavedBook.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        }
      } catch (e) {
        debugPrint('Error fetching saved books online: $e');
      }
    }

    // Offline or fallback
    final cachedData = await _getFromCache(cacheKey);
    if (cachedData != null) {
      try {
        final json = jsonDecode(cachedData);
        if (json['success'] == true && json['data'] != null) {
          return (json['data'] as List)
              .map((e) => SavedBook.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        debugPrint('Error parsing cached saved books: $e');
      }
    }

    return [];
  }

  /// Save a book
  Future<Map<String, dynamic>> saveBook(int listingId, {String? notes}) async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$apiBaseUrl/books/listings/$listingId/save'),
        headers: await _getAuthHeader(),
        body: jsonEncode({
          'listingId': listingId,
          if (notes != null) 'notes': notes,
        }),
      );

      final json = jsonDecode(response.body);
      return {'success': json['success'] == true, 'message': json['message']};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Unsave a book
  Future<Map<String, dynamic>> unsaveBook(int listingId) async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.delete(
        Uri.parse('$apiBaseUrl/books/listings/$listingId/save'),
        headers: await _getAuthHeader(),
      );

      final json = jsonDecode(response.body);
      return {'success': json['success'] == true, 'message': json['message']};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Get book categories
  Future<List<BookCategory>> getBookCategories() async {
    const String cacheKey = 'book_categories_cache';
    bool isOnline = await _hasInternetConnection();

    if (isOnline) {
      try {
        final response = await http.get(
          Uri.parse('$apiBaseUrl/books/categories'),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          await _saveToCache(cacheKey, response.body);
          final json = jsonDecode(response.body);
          if (json['success'] == true && json['data'] != null) {
            return (json['data'] as List)
                .map((e) => BookCategory.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        }
      } catch (e) {
        debugPrint('Error fetching book categories online: $e');
      }
    }

    // Offline or fallback
    final cachedData = await _getFromCache(cacheKey);
    if (cachedData != null) {
      try {
        final json = jsonDecode(cachedData);
        if (json['success'] == true && json['data'] != null) {
          return (json['data'] as List)
              .map((e) => BookCategory.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        debugPrint('Error parsing cached book categories: $e');
      }
    }

    return [];
  }

  // ==================== BOOK PURCHASE REQUESTS ====================

  /// Create a purchase request for a book
  Future<Map<String, dynamic>> createPurchaseRequest(
    int listingId,
    String? message,
  ) async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$apiBaseUrl/books/listings/$listingId/request'),
        headers: await _getAuthHeader(),
        body: jsonEncode({'message': message}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return {
        'success': false,
        'message': 'Request failed: ${response.statusCode}',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Get purchase requests for a specific listing (seller's view)
  Future<List<BookPurchaseRequest>> getListingRequests(int listingId) async {
    final userId = await getDatabaseUserId();
    if (userId == null) return [];

    final String cacheKey = 'listing_requests_${listingId}_cache';
    bool isOnline = await _hasInternetConnection();

    if (isOnline) {
      try {
        final response = await http.get(
          Uri.parse('$apiBaseUrl/books/listings/$listingId/requests'),
          headers: await _getAuthHeader(),
        );

        if (response.statusCode == 200) {
          await _saveToCache(cacheKey, response.body);
          final json = jsonDecode(response.body);
          if (json['success'] == true && json['data'] != null) {
            return (json['data'] as List)
                .map(
                  (e) =>
                      BookPurchaseRequest.fromJson(e as Map<String, dynamic>),
                )
                .toList();
          }
        }
      } catch (e) {
        debugPrint('Error fetching listing requests online: $e');
      }
    }

    // Offline or fallback
    final cachedData = await _getFromCache(cacheKey);
    if (cachedData != null) {
      try {
        final json = jsonDecode(cachedData);
        if (json['success'] == true && json['data'] != null) {
          return (json['data'] as List)
              .map(
                (e) => BookPurchaseRequest.fromJson(e as Map<String, dynamic>),
              )
              .toList();
        }
      } catch (e) {
        debugPrint('Error parsing cached listing requests: $e');
      }
    }

    return [];
  }

  /// Get my outgoing purchase requests (buyer's view)
  Future<List<BookPurchaseRequest>> getMyPurchaseRequests() async {
    final userId = await getDatabaseUserId();
    if (userId == null) return [];

    final String cacheKey = 'my_purchase_requests_${userId}_cache';
    bool isOnline = await _hasInternetConnection();

    if (isOnline) {
      try {
        final response = await http.get(
          Uri.parse('$apiBaseUrl/books/my-requests'),
          headers: await _getAuthHeader(),
        );

        if (response.statusCode == 200) {
          await _saveToCache(cacheKey, response.body);
          final json = jsonDecode(response.body);
          if (json['success'] == true && json['data'] != null) {
            return (json['data'] as List)
                .map(
                  (e) =>
                      BookPurchaseRequest.fromJson(e as Map<String, dynamic>),
                )
                .toList();
          }
        }
      } catch (e) {
        debugPrint('Error fetching my requests online: $e');
      }
    }

    // Offline or fallback
    final cachedData = await _getFromCache(cacheKey);
    if (cachedData != null) {
      try {
        final json = jsonDecode(cachedData);
        if (json['success'] == true && json['data'] != null) {
          return (json['data'] as List)
              .map(
                (e) => BookPurchaseRequest.fromJson(e as Map<String, dynamic>),
              )
              .toList();
        }
      } catch (e) {
        debugPrint('Error parsing cached my requests: $e');
      }
    }

    return [];
  }

  /// Respond to a purchase request (Accept/Reject)
  Future<Map<String, dynamic>> respondToPurchaseRequest(
    int requestId,
    bool accept,
  ) async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.put(
        Uri.parse('$apiBaseUrl/books/requests/$requestId/respond'),
        headers: await _getAuthHeader(),
        body: jsonEncode({'accept': accept}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return {
        'success': false,
        'message': 'Response failed: ${response.statusCode}',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Get status of my request for a specific listing
  Future<BookPurchaseRequest?> getPurchaseRequestStatus(int listingId) async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) return null;

      final response = await http.get(
        Uri.parse('$apiBaseUrl/books/listings/$listingId/request-status'),
        headers: await _getAuthHeader(),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return BookPurchaseRequest.fromJson(
            json['data'] as Map<String, dynamic>,
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching request status: $e');
      return null;
    }
  }

  /// Cancel a purchase request (seller/buyer depending on status)
  Future<Map<String, dynamic>> cancelPurchaseRequest(int requestId) async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.delete(
        Uri.parse('$apiBaseUrl/books/requests/$requestId'),
        headers: await _getAuthHeader(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {
        'success': false,
        'message': 'Cancel failed: ${response.statusCode}',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Permanently delete a purchase request from history
  Future<Map<String, dynamic>> deletePurchaseRequest(int requestId) async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.delete(
        Uri.parse('$apiBaseUrl/books/requests/$requestId/delete'),
        headers: await _getAuthHeader(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {
        'success': false,
        'message': 'Delete failed: ${response.statusCode}',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ==================== CLASSROOM API ====================

  /// Get all faculties
  Future<List<Faculty>> getFaculties() async {
    const String cacheKey = 'faculties_cache';
    bool isOnline = await _hasInternetConnection();

    if (isOnline) {
      try {
        final response = await http.get(
          Uri.parse('$apiBaseUrl/classroom/faculties'),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          await _saveToCache(cacheKey, response.body);
          final json = jsonDecode(response.body);
          if (json['success'] == true && json['faculties'] != null) {
            return (json['faculties'] as List)
                .map((e) => Faculty.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        }
      } catch (e) {
        debugPrint('Error fetching faculties online: $e');
      }
    }

    // Offline or fallback
    final cachedData = await _getFromCache(cacheKey);
    if (cachedData != null) {
      try {
        final json = jsonDecode(cachedData);
        if (json['success'] == true && json['faculties'] != null) {
          return (json['faculties'] as List)
              .map((e) => Faculty.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        debugPrint('Error parsing cached faculties: $e');
      }
    }

    return [];
  }

  /// Get subjects by faculty and optional semester
  Future<List<Subject>> getSubjects({
    required int facultyId,
    int? semester,
  }) async {
    final String cacheKey = 'subjects_${facultyId}_${semester ?? 'all'}_cache';
    bool isOnline = await _hasInternetConnection();

    if (isOnline) {
      try {
        final queryParams = <String, String>{'facultyId': facultyId.toString()};
        if (semester != null) queryParams['semester'] = semester.toString();

        final uri = Uri.parse(
          '$apiBaseUrl/classroom/subjects',
        ).replace(queryParameters: queryParams);
        final response = await http.get(
          uri,
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          await _saveToCache(cacheKey, response.body);
          final json = jsonDecode(response.body);
          if (json['success'] == true && json['subjects'] != null) {
            return (json['subjects'] as List)
                .map((e) => Subject.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        }
      } catch (e) {
        debugPrint('Error fetching subjects online: $e');
      }
    }

    // Offline or fallback
    final cachedData = await _getFromCache(cacheKey);
    if (cachedData != null) {
      try {
        final json = jsonDecode(cachedData);
        if (json['success'] == true && json['subjects'] != null) {
          return (json['subjects'] as List)
              .map((e) => Subject.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        debugPrint('Error parsing cached subjects: $e');
      }
    }

    return [];
  }

  /// Get current user's student profile
  Future<StudentProfile?> getStudentProfile() async {
    final userId = await getDatabaseUserId();
    if (userId == null) return null;

    final String cacheKey = 'student_profile_${userId}_cache';
    bool isOnline = await _hasInternetConnection();

    if (isOnline) {
      try {
        final response = await http.get(
          Uri.parse('$apiBaseUrl/classroom/me'),
          headers: await _getAuthHeader(),
        );

        if (response.statusCode == 200) {
          await _saveToCache(cacheKey, response.body);
          final json = jsonDecode(response.body);
          if (json['success'] == true && json['profile'] != null) {
            return StudentProfile.fromJson(
              json['profile'] as Map<String, dynamic>,
            );
          }
        }
      } catch (e) {
        debugPrint('Error fetching student profile online: $e');
      }
    }

    // Offline or fallback
    final cachedData = await _getFromCache(cacheKey);
    if (cachedData != null) {
      try {
        final json = jsonDecode(cachedData);
        if (json['success'] == true && json['profile'] != null) {
          return StudentProfile.fromJson(
            json['profile'] as Map<String, dynamic>,
          );
        }
      } catch (e) {
        debugPrint('Error parsing cached student profile: $e');
      }
    }

    return null;
  }

  /// Create or update student profile
  Future<Map<String, dynamic>> upsertStudentProfile(
    StudentProfileRequest request,
  ) async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$apiBaseUrl/classroom/me'),
        headers: await _getAuthHeader(),
        body: jsonEncode(request.toJson()),
      );

      debugPrint('upsertStudentProfile response: ${response.statusCode}');
      debugPrint('upsertStudentProfile body: ${response.body}');

      if (response.statusCode != 200) {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}',
        };
      }

      final json = jsonDecode(response.body);

      if (json['success'] != true) {
        return {
          'success': false,
          'message': json['message'] ?? 'Failed to update profile',
        };
      }

      return {
        'success': true,
        'profile': json['profile'] != null
            ? StudentProfile.fromJson(json['profile'] as Map<String, dynamic>)
            : null,
        'message': json['message'] ?? 'Profile updated successfully',
      };
    } catch (e) {
      debugPrint('upsertStudentProfile error: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Get current user's subjects with assignments
  Future<List<Subject>> getMySubjects() async {
    final userId = await getDatabaseUserId();
    if (userId == null) return [];

    final String cacheKey = 'my_subjects_${userId}_cache';
    bool isOnline = await _hasInternetConnection();

    if (isOnline) {
      try {
        final response = await http.get(
          Uri.parse('$apiBaseUrl/classroom/me/subjects'),
          headers: await _getAuthHeader(),
        );

        if (response.statusCode == 200) {
          await _saveToCache(cacheKey, response.body);
          final json = jsonDecode(response.body);
          if (json['success'] == true && json['subjects'] != null) {
            return (json['subjects'] as List)
                .map((e) => Subject.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        }
      } catch (e) {
        debugPrint('Error fetching my subjects online: $e');
      }
    }

    // Offline or fallback
    final cachedData = await _getFromCache(cacheKey);
    if (cachedData != null) {
      try {
        final json = jsonDecode(cachedData);
        if (json['success'] == true && json['subjects'] != null) {
          return (json['subjects'] as List)
              .map((e) => Subject.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        debugPrint('Error parsing cached my subjects: $e');
      }
    }

    return [];
  }

  /// Get teacher's assigned subjects
  Future<List<Subject>> getTeacherSubjects() async {
    final userId = await getDatabaseUserId();
    if (userId == null) return [];

    final String cacheKey = 'teacher_subjects_${userId}_cache';
    bool isOnline = await _hasInternetConnection();

    if (isOnline) {
      try {
        final response = await http.get(
          Uri.parse('$apiBaseUrl/classroom/teacher/subjects'),
          headers: await _getAuthHeader(),
        );

        if (response.statusCode == 200) {
          await _saveToCache(cacheKey, response.body);
          final json = jsonDecode(response.body);
          if (json['success'] == true && json['subjects'] != null) {
            return (json['subjects'] as List)
                .map((e) => Subject.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        }
      } catch (e) {
        debugPrint('Error fetching teacher subjects online: $e');
      }
    }

    // Offline or fallback
    final cachedData = await _getFromCache(cacheKey);
    if (cachedData != null) {
      try {
        final json = jsonDecode(cachedData);
        if (json['success'] == true && json['subjects'] != null) {
          return (json['subjects'] as List)
              .map((e) => Subject.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        debugPrint('Error parsing cached teacher subjects: $e');
      }
    }

    return [];
  }

  /// Add a subject for teacher
  Future<Map<String, dynamic>> addTeacherSubject(int subjectId) async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$apiBaseUrl/classroom/teacher/subjects'),
        headers: await _getAuthHeader(),
        body: jsonEncode({'subjectId': subjectId}),
      );

      final json = jsonDecode(response.body);
      return {'success': json['success'] == true, 'message': json['message']};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Create an assignment for a subject
  Future<Map<String, dynamic>> createAssignment(
    CreateAssignmentRequest request,
  ) async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$apiBaseUrl/classroom/assignments'),
        headers: await _getAuthHeader(),
        body: jsonEncode(request.toJson()),
      );

      final json = jsonDecode(response.body);
      return {
        'success': json['success'] == true,
        'assignment': json['assignment'] != null
            ? Assignment.fromJson(json['assignment'] as Map<String, dynamic>)
            : null,
        'message': json['message'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Submit an assignment
  Future<Map<String, dynamic>> submitAssignment(
    int assignmentId,
    File file, {
    String? comment,
  }) async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
          '$apiBaseUrl/classroom/assignments/$assignmentId/submissions',
        ),
      );
      request.headers.addAll(await _getAuthHeader());
      if (comment != null) {
        request.fields['comment'] = comment;
      }
      final extension = file.path.split('.').last.toLowerCase();
      MediaType contentType;
      if (extension == 'pdf') {
        contentType = MediaType('application', 'pdf');
      } else if (extension == 'png') {
        contentType = MediaType('image', 'png');
      } else if (extension == 'webp') {
        contentType = MediaType('image', 'webp');
      } else {
        contentType = MediaType('image', 'jpeg');
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          contentType: contentType,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final json = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': json['success'] == true,
          'submission': json['submission'] != null
              ? AssignmentSubmission.fromJson(
                  json['submission'] as Map<String, dynamic>,
                )
              : null,
          'message': json['message'],
        };
      }
      return {
        'success': false,
        'message': json['message'] ?? 'Submission failed',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Get submissions for an assignment (teacher only)
  Future<List<AssignmentSubmission>> getAssignmentSubmissions(
    int assignmentId,
  ) async {
    final userId = await getDatabaseUserId();
    if (userId == null) return [];

    final String cacheKey = 'assignment_submissions_${assignmentId}_cache';
    bool isOnline = await _hasInternetConnection();

    if (isOnline) {
      try {
        final response = await http.get(
          Uri.parse(
            '$apiBaseUrl/classroom/assignments/$assignmentId/submissions',
          ),
          headers: await _getAuthHeader(),
        );

        if (response.statusCode == 200) {
          await _saveToCache(cacheKey, response.body);
          final json = jsonDecode(response.body);
          if (json['success'] == true && json['submissions'] != null) {
            return (json['submissions'] as List)
                .map(
                  (e) =>
                      AssignmentSubmission.fromJson(e as Map<String, dynamic>),
                )
                .toList();
          }
        }
      } catch (e) {
        debugPrint('Error fetching submissions online: $e');
      }
    }

    // Offline or fallback
    final cachedData = await _getFromCache(cacheKey);
    if (cachedData != null) {
      try {
        final json = jsonDecode(cachedData);
        if (json['success'] == true && json['submissions'] != null) {
          return (json['submissions'] as List)
              .map(
                (e) => AssignmentSubmission.fromJson(e as Map<String, dynamic>),
              )
              .toList();
        }
      } catch (e) {
        debugPrint('Error parsing cached submissions: $e');
      }
    }

    return [];
  }

  /// Check if user is a teacher
  Future<bool> isTeacher() async {
    final role = await getUserRole();
    return role == 'teacher';
  }

  // ==================== CHAT API ====================

  /// Get all conversations for the current user
  Future<List<MarketplaceConversation>> getConversations() async {
    final userId = await getDatabaseUserId();
    if (userId == null) {
      debugPrint('getConversations: No user ID found');
      return [];
    }

    final String cacheKey = 'conversations_${userId}_cache';
    bool isOnline = await _hasInternetConnection();

    if (isOnline) {
      try {
        debugPrint('getConversations: Fetching from API...');
        final response = await http.get(
          Uri.parse('$apiBaseUrl/chat/conversations'),
          headers: await _getAuthHeader(),
        );

        debugPrint('getConversations response: ${response.statusCode}');
        debugPrint('getConversations body: ${response.body}');

        if (response.statusCode == 200) {
          await _saveToCache(cacheKey, response.body);
          final json = jsonDecode(response.body);
          if (json['success'] == true && json['data'] != null) {
            final conversations = (json['data'] as List)
                .map(
                  (c) => MarketplaceConversation.fromJson(
                    c as Map<String, dynamic>,
                  ),
                )
                .toList();
            debugPrint(
              'getConversations: Found ${conversations.length} conversations',
            );
            return conversations;
          } else {
            debugPrint(
              'getConversations: success=${json['success']}, data=${json['data']}',
            );
          }
        }
      } catch (e) {
        debugPrint('Error getting conversations online: $e');
      }
    }

    // Offline or fallback
    final cachedData = await _getFromCache(cacheKey);
    if (cachedData != null) {
      try {
        final json = jsonDecode(cachedData);
        if (json['success'] == true && json['data'] != null) {
          return (json['data'] as List)
              .map(
                (c) =>
                    MarketplaceConversation.fromJson(c as Map<String, dynamic>),
              )
              .toList();
        }
      } catch (e) {
        debugPrint('Error parsing cached conversations: $e');
      }
    }

    return [];
  }

  /// Get messages for a specific conversation
  Future<List<MarketplaceMessage>> getChatMessages(int conversationId) async {
    final userId = await getDatabaseUserId();
    if (userId == null) return [];

    final String cacheKey = 'chat_messages_${conversationId}_cache';
    bool isOnline = await _hasInternetConnection();

    if (isOnline) {
      try {
        final response = await http.get(
          Uri.parse('$apiBaseUrl/chat/conversations/$conversationId/messages'),
          headers: await _getAuthHeader(),
        );

        if (response.statusCode == 200) {
          await _saveToCache(cacheKey, response.body);
          final json = jsonDecode(response.body);
          if (json['success'] == true && json['data'] != null) {
            return (json['data'] as List)
                .map(
                  (m) => MarketplaceMessage.fromJson(m as Map<String, dynamic>),
                )
                .toList();
          }
        }
      } catch (e) {
        debugPrint('Error getting messages online: $e');
      }
    }

    // Offline or fallback
    final cachedData = await _getFromCache(cacheKey);
    if (cachedData != null) {
      try {
        final json = jsonDecode(cachedData);
        if (json['success'] == true && json['data'] != null) {
          return (json['data'] as List)
              .map(
                (m) => MarketplaceMessage.fromJson(m as Map<String, dynamic>),
              )
              .toList();
        }
      } catch (e) {
        debugPrint('Error parsing cached messages: $e');
      }
    }

    return [];
  }

  /// Send a message for a listing
  Future<Map<String, dynamic>> sendMessage(
    int listingId,
    String content, {
    String? buyerId,
  }) async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final Map<String, dynamic> body = {
        'listingId': listingId,
        'content': content,
      };
      if (buyerId != null) {
        body['buyerId'] = buyerId;
      }

      final response = await http.post(
        Uri.parse('$apiBaseUrl/chat/send'),
        headers: await _getAuthHeader(),
        body: jsonEncode(body),
      );

      final json = jsonDecode(response.body);
      return {
        'success': json['success'] == true,
        'data': json['data'] != null
            ? MarketplaceMessage.fromJson(json['data'] as Map<String, dynamic>)
            : null,
        'message': json['message'],
      };
    } catch (e) {
      debugPrint('Error sending message: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Send a message to a specific conversation
  Future<Map<String, dynamic>> sendMessageToConversation(
    int conversationId,
    String content,
  ) async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$apiBaseUrl/chat/conversations/$conversationId/messages'),
        headers: await _getAuthHeader(),
        body: jsonEncode({'content': content}),
      );

      final json = jsonDecode(response.body);
      return {
        'success': json['success'] == true,
        'data': json['data'] != null
            ? MarketplaceMessage.fromJson(json['data'] as Map<String, dynamic>)
            : null,
        'message': json['message'],
      };
    } catch (e) {
      debugPrint('Error sending message to conversation: $e');
      return {'success': false, 'message': ' Error: $e'};
    }
  }

  /// Delete a conversation
  Future<Map<String, dynamic>> deleteConversation(int conversationId) async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.delete(
        Uri.parse('$apiBaseUrl/chat/conversations/$conversationId'),
        headers: await _getAuthHeader(),
      );

      final json = jsonDecode(response.body);
      return {
        'success': json['success'] == true,
        'message': json['message'] ?? 'Conversation deleted',
      };
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ==================== NOTICES API ====================

  /// Create a new notice (notice_manager/admin only)
  Future<Map<String, dynamic>> createNotice(Map<String, dynamic> data) async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$apiBaseUrl/notices'),
        headers: await _getAuthHeader(),
        body: jsonEncode(data),
      );

      final json = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': json['data'],
          'message': json['message'],
        };
      }
      return {
        'success': false,
        'message': json['message'] ?? 'Failed to create notice',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Update an existing notice (notice_manager/admin only)
  Future<Map<String, dynamic>> updateNotice(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.put(
        Uri.parse('$apiBaseUrl/notices/$id'),
        headers: await _getAuthHeader(),
        body: jsonEncode(data),
      );

      final json = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': json['data'],
          'message': json['message'],
        };
      }
      return {
        'success': false,
        'message': json['message'] ?? 'Failed to update notice',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Delete a notice (notice_manager/admin only)
  Future<Map<String, dynamic>> deleteNotice(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/notices/$id'),
        headers: await _getAuthHeader(),
      );

      final json = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': json['message']};
      }
      return {
        'success': false,
        'message': json['message'] ?? 'Failed to delete notice',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Upload notice attachment
  Future<Map<String, dynamic>> uploadNoticeAttachment(File file) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBaseUrl/notices/upload'),
      );
      request.headers.addAll(await _getAuthHeader());
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          contentType: file.path.endsWith('.pdf')
              ? MediaType('application', 'pdf')
              : MediaType('image', 'jpeg'),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final json = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': json['data'], // { url, name }
          'message': json['message'],
        };
      }
      return {
        'success': false,
        'message': json['message'] ?? 'Failed to upload attachment',
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get details of a single notice (cache-first)
  Future<Notice?> getNotice(int id) async {
    final String cacheKey = 'notice_${id}_cache';

    // Try cache first
    final cachedData = await _getFromCache(cacheKey);
    if (cachedData != null) {
      try {
        final json = jsonDecode(cachedData);
        if (json['success'] == true && json['data'] != null) {
          // Background refresh
          _refreshNoticeInBackground(id, cacheKey);
          return Notice.fromJson(json['data'] as Map<String, dynamic>);
        }
      } catch (e) {
        debugPrint('Error parsing cached notice: $e');
      }
    }

    return _fetchNoticeFromNetwork(id, cacheKey);
  }

  /// Refreshes notice details in the background
  Future<void> _refreshNoticeInBackground(int id, String cacheKey) async {
    try {
      await _fetchNoticeFromNetwork(id, cacheKey);
    } catch (e) {
      debugPrint('Background notice refresh failed: $e');
    }
  }

  /// Fetches notice from network and saves to cache
  Future<Notice?> _fetchNoticeFromNetwork(int id, String cacheKey) async {
    bool isOnline = await _hasInternetConnection();
    if (!isOnline) return null;

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/notices/$id'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        await _saveToCache(cacheKey, response.body);
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return Notice.fromJson(json['data'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('Error fetching notice online: $e');
    }
    return null;
  }

  /// Get notices with optional filters (cache-first for instant loading)
  Future<List<Notice>> getNotices({
    NoticeFilters? filters,
    bool forceRefresh = false,
  }) async {
    final String cacheKey =
        'notices_${filters?.section?.value ?? 'all'}_${filters?.category ?? 'all'}_cache';

    // Only skip cache/do background refresh for the first page
    final int offset = filters?.offset ?? 0;

    if (!forceRefresh && offset == 0) {
      // Try cache first for instant display
      final cachedData = await _getFromCache(cacheKey);
      List<Notice> cachedNotices = [];
      if (cachedData != null) {
        try {
          final json = jsonDecode(cachedData);
          if (json['success'] == true && json['data'] != null) {
            cachedNotices = (json['data'] as List)
                .map((e) => Notice.fromJson(e as Map<String, dynamic>))
                .toList();
          } else if (json['data']?['success'] == true &&
              json['data']?['notices'] != null) {
            cachedNotices = (json['data']['notices'] as List)
                .map((e) => Notice.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        } catch (e) {
          debugPrint('Error parsing cached notices: $e');
        }
      }

      // Return cached data immediately if available
      if (cachedNotices.isNotEmpty) {
        // Trigger background refresh without awaiting
        _refreshNoticesInBackground(filters, cacheKey);
        return cachedNotices;
      }
    }

    // No cache or forceRefresh, fetch from network
    return _fetchNoticesFromNetwork(filters, cacheKey);
  }

  /// Refreshes notices in the background and updates the cache.
  Future<void> _refreshNoticesInBackground(
    NoticeFilters? filters,
    String cacheKey,
  ) async {
    try {
      await _fetchNoticesFromNetwork(filters, cacheKey);
    } catch (e) {
      debugPrint('Background notices refresh failed: $e');
    }
  }

  /// Fetches notices from the network and saves to cache.
  Future<List<Notice>> _fetchNoticesFromNetwork(
    NoticeFilters? filters,
    String cacheKey,
  ) async {
    bool isOnline = await _hasInternetConnection();
    if (!isOnline) return [];

    try {
      final queryParams = filters?.toQueryParams() ?? {};
      final uri = Uri.parse(
        '$apiBaseUrl/notices',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        await _saveToCache(cacheKey, response.body);
        final json = jsonDecode(response.body);

        // Handle both response formats
        if (json['success'] == true && json['data'] != null) {
          return (json['data'] as List)
              .map((e) => Notice.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        // Legacy format
        if (json['data']?['success'] == true &&
            json['data']?['notices'] != null) {
          return (json['data']['notices'] as List)
              .map((e) => Notice.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching notices online: $e');
    }
    return [];
  }

  /// Get notice statistics (cache-first for instant loading)
  Future<NoticeStats?> getNoticeStats({bool forceRefresh = false}) async {
    const String cacheKey = 'notice_stats_cache';

    if (!forceRefresh) {
      // Try cache first for instant display
      final cachedData = await _getFromCache(cacheKey);
      NoticeStats? cachedStats;
      if (cachedData != null) {
        try {
          final json = jsonDecode(cachedData);
          if (json['success'] == true && json['data'] != null) {
            cachedStats = NoticeStats.fromJson(
              json['data'] as Map<String, dynamic>,
            );
          } else if (json['data']?['success'] == true &&
              json['data']?['stats'] != null) {
            cachedStats = NoticeStats.fromJson(
              json['data']['stats'] as Map<String, dynamic>,
            );
          }
        } catch (e) {
          debugPrint('Error parsing cached notice stats: $e');
        }
      }

      // Return cached data immediately if available
      if (cachedStats != null) {
        // Trigger background refresh without awaiting
        _refreshNoticeStatsInBackground(cacheKey);
        return cachedStats;
      }
    }

    // No cache or forceRefresh, fetch from network
    return _fetchNoticeStatsFromNetwork(cacheKey);
  }

  /// Refreshes notice stats in the background and updates the cache.
  Future<void> _refreshNoticeStatsInBackground(String cacheKey) async {
    try {
      await _fetchNoticeStatsFromNetwork(cacheKey);
    } catch (e) {
      debugPrint('Background notice stats refresh failed: $e');
    }
  }

  /// Fetches notice stats from the network and saves to cache.
  Future<NoticeStats?> _fetchNoticeStatsFromNetwork(String cacheKey) async {
    bool isOnline = await _hasInternetConnection();
    if (!isOnline) return null;

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/notices/stats'),
        headers: _getJsonHeader(),
      );

      if (response.statusCode == 200) {
        await _saveToCache(cacheKey, response.body);
        final json = jsonDecode(response.body);

        if (json['success'] == true && json['data'] != null) {
          return NoticeStats.fromJson(json['data'] as Map<String, dynamic>);
        }
        // Legacy format
        if (json['data']?['success'] == true &&
            json['data']?['stats'] != null) {
          return NoticeStats.fromJson(
            json['data']['stats'] as Map<String, dynamic>,
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching notice stats online: $e');
    }
    return null;
  }

  // ==================== GLOBAL SEARCH API ====================

  /// Search across all content types (clubs, events, books, notices, places)
  Future<GlobalSearchResult?> searchEverything(
    String query, {
    int limit = 6,
  }) async {
    if (query.trim().length < 2) return null;

    try {
      final uri = Uri.parse('$apiBaseUrl/search').replace(
        queryParameters: {'q': query.trim(), 'limit': limit.toString()},
      );

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return GlobalSearchResult.fromJson(
            json['data'] as Map<String, dynamic>,
          );
        }
      }
    } catch (e) {
      debugPrint('Error performing global search: $e');
    }

    return null;
  }

  // ==================== TRUST SYSTEM API ====================

  /// Get seller reputation and recent ratings (with caching)
  Future<SellerReputation?> getSellerReputation(String sellerId) async {
    final String cacheKey = 'seller_reputation_$sellerId';

    // 1. Try cache first
    final cachedData = await _getFromCache(cacheKey);
    if (cachedData != null) {
      try {
        final json = jsonDecode(cachedData);
        if (json['success'] == true && json['data'] != null) {
          final reputation = SellerReputation.fromJson(
            json['data'] as Map<String, dynamic>,
          );
          // Refresh in background if online
          _refreshSellerReputationInBackground(sellerId, cacheKey);
          return reputation;
        }
      } catch (e) {
        debugPrint('Error parsing cached seller reputation: $e');
      }
    }

    // 2. Fetch from network
    return _fetchSellerReputationFromNetwork(sellerId, cacheKey);
  }

  /// Refreshes seller reputation in the background
  Future<void> _refreshSellerReputationInBackground(
    String sellerId,
    String cacheKey,
  ) async {
    if (await _hasInternetConnection()) {
      await _fetchSellerReputationFromNetwork(sellerId, cacheKey);
    }
  }

  /// Fetches seller reputation from network and saves to cache
  Future<SellerReputation?> _fetchSellerReputationFromNetwork(
    String sellerId,
    String cacheKey,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse('$apiBaseUrl/books/trust/sellers/$sellerId/reputation'),
            headers: await _getAuthHeader(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await _saveToCache(cacheKey, response.body);
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return SellerReputation.fromJson(
            json['data'] as Map<String, dynamic>,
          );
        }
      }
    } catch (e) {
      debugPrint('Error getting seller reputation online: $e');
    }
    return null;
  }

  /// Get books listed by a specific seller
  Future<List<BookListing>> getSellerListings(String sellerId) async {
    try {
      final response = await getBookListings(BookFilters(sellerId: sellerId));
      return response?.listings ?? [];
    } catch (e) {
      debugPrint('Error getting seller listings: $e');
    }
    return [];
  }

  /// Rate a seller for a specific listing
  Future<Map<String, dynamic>> rateSeller({
    required String sellerId,
    required int listingId,
    required int rating,
    String? review,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/books/trust/sellers/$sellerId/rate'),
        headers: await _getAuthHeader(),
        body: jsonEncode({
          'listingId': listingId,
          'rating': rating,
          'review': review,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error rating seller: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Block a user in the marketplace
  Future<Map<String, dynamic>> blockMarketplaceUser(
    String userId, {
    String? reason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/books/trust/users/$userId/block'),
        headers: await _getAuthHeader(),
        body: jsonEncode({'reason': reason}),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          await invalidateBookListingsCache();
        }
        return json;
      }

      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error blocking user: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Unblock a previously blocked user
  Future<Map<String, dynamic>> unblockMarketplaceUser(String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/books/trust/users/$userId/block'),
        headers: await _getAuthHeader(),
      );

      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        await invalidateBookListingsCache();
      }
      return json;
    } catch (e) {
      debugPrint('Error unblocking user: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get list of users blocked by the current user
  Future<List<BlockedUser>> getBlockedMarketplaceUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/books/trust/blocked-users'),
        headers: await _getAuthHeader(),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return (json['data'] as List)
              .map((e) => BlockedUser.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error getting blocked users: $e');
    }
    return [];
  }

  // ==================== LOST & FOUND API ====================

  /// List lost & found items with filters
  /// List lost & found items with filters (cache-first for instant loading)
  Future<List<LostFoundItem>> getLostFoundItems({
    String? itemType,
    String? category,
    String? status,
    String? q,
    String? cursor,
    int limit = 12,
    bool forceRefresh = false,
  }) async {
    final String cacheKey =
        'lost_found_${itemType ?? "all"}_${category ?? "all"}_${status ?? "all"}_${q ?? "none"}_cache';

    // Only use cache for the first page
    if (!forceRefresh && cursor == null) {
      final cachedData = await _getFromCache(cacheKey);
      if (cachedData != null) {
        try {
          final json = jsonDecode(cachedData);
          if (json['success'] == true && json['data']?['items'] != null) {
            final List<LostFoundItem> cachedItems =
                (json['data']['items'] as List)
                    .map(
                      (e) => LostFoundItem.fromJson(e as Map<String, dynamic>),
                    )
                    .toList();

            // Return cached data immediately (even if empty) to ensure "instant-on" feel
            // Background refresh will update it if there are new items
            _refreshLostFoundItemsInBackground(
              itemType: itemType,
              category: category,
              status: status,
              q: q,
              cacheKey: cacheKey,
            );
            return cachedItems;
          }
        } catch (e) {
          debugPrint('Error parsing cached lost & found: $e');
        }
      }
    }

    return _fetchLostFoundItemsFromNetwork(
      itemType: itemType,
      category: category,
      status: status,
      q: q,
      cursor: cursor,
      limit: limit,
      cacheKey: cacheKey,
    );
  }

  /// Refreshes lost & found items in the background
  Future<void> _refreshLostFoundItemsInBackground({
    String? itemType,
    String? category,
    String? status,
    String? q,
    required String cacheKey,
  }) async {
    try {
      await _fetchLostFoundItemsFromNetwork(
        itemType: itemType,
        category: category,
        status: status,
        q: q,
        cacheKey: cacheKey,
      );
    } catch (e) {
      debugPrint('Background lost & found refresh failed: $e');
    }
  }

  /// Fetches lost & found items from network and saves to cache
  Future<List<LostFoundItem>> _fetchLostFoundItemsFromNetwork({
    String? itemType,
    String? category,
    String? status,
    String? q,
    String? cursor,
    int limit = 12,
    required String cacheKey,
  }) async {
    bool isOnline = await _hasInternetConnection();
    if (!isOnline) return [];

    try {
      final queryParams = <String, String>{
        if (itemType != null) 'itemType': itemType,
        if (category != null) 'category': category,
        if (status != null) 'status': status,
        if (q != null) 'q': q,
        if (cursor != null) 'cursor': cursor,
        'limit': limit.toString(),
      };

      final uri = Uri.parse(
        '$apiBaseUrl/lost-found',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: await _getAuthHeader());

      if (response.statusCode == 200) {
        // Only save first page to cache
        if (cursor == null) {
          await _saveToCache(cacheKey, response.body);
        }

        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data']?['items'] != null) {
          return (json['data']['items'] as List)
              .map((e) => LostFoundItem.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching lost & found from network: $e');
    }
    return [];
  }

  /// Get details of a single lost & found item (cache-first)
  Future<LostFoundItem?> getLostFoundItem(
    int id, {
    bool forceRefresh = false,
  }) async {
    final String cacheKey = 'lost_found_item_${id}_cache';

    if (!forceRefresh) {
      final cachedData = await _getFromCache(cacheKey);
      if (cachedData != null) {
        try {
          final json = jsonDecode(cachedData);
          if (json['success'] == true && json['data'] != null) {
            // Background refresh
            _refreshLostFoundItemInBackground(id, cacheKey);
            return LostFoundItem.fromJson(json['data'] as Map<String, dynamic>);
          }
        } catch (e) {
          debugPrint('Error parsing cached lost & found item: $e');
        }
      }
    }

    return _fetchLostFoundItemFromNetwork(id, cacheKey);
  }

  /// Refreshes lost & found item details in the background
  Future<void> _refreshLostFoundItemInBackground(
    int id,
    String cacheKey,
  ) async {
    try {
      await _fetchLostFoundItemFromNetwork(id, cacheKey);
    } catch (e) {
      debugPrint('Background lost & found item refresh failed: $e');
    }
  }

  /// Fetches lost & found item from network and saves to cache
  Future<LostFoundItem?> _fetchLostFoundItemFromNetwork(
    int id,
    String cacheKey,
  ) async {
    bool isOnline = await _hasInternetConnection();
    if (!isOnline) return null;

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/lost-found/$id'),
        headers: await _getAuthHeader(),
      );

      if (response.statusCode == 200) {
        await _saveToCache(cacheKey, response.body);
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return LostFoundItem.fromJson(json['data'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('Error fetching lost & found item online: $e');
    }
    return null;
  }

  /// Create a new lost & found item
  Future<ApiResult<LostFoundItem>> createLostFoundItem(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/lost-found'),
        headers: await _getAuthHeader(),
        body: jsonEncode(data),
      );

      final json = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (json['success'] == true && json['data'] != null) {
          // Invalidate cache
          await invalidateLostFoundCache();
          await invalidateMyLostFoundCache();

          return ApiResult.success(
            data: LostFoundItem.fromJson(json['data'] as Map<String, dynamic>),
          );
        }
      }
      return ApiResult.failure(json['message'] ?? 'Failed to create item');
    } catch (e) {
      debugPrint('Error creating lost & found item: $e');
      return ApiResult.failure(e.toString());
    }
  }

  /// Upload image for a lost & found item
  Future<ApiResult<String>> uploadLostFoundImage(
    int itemId,
    File imageFile,
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBaseUrl/lost-found/$itemId/images'),
      );

      final authHeader = await _getAuthHeader();
      request.headers.addAll(authHeader);

      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final json = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (json['success'] == true && json['data']?['imageUrl'] != null) {
          // Invalidate specific item cache
          await invalidateLostFoundItemCache(itemId);

          return ApiResult.success(data: json['data']['imageUrl'] as String);
        }
      }
      return ApiResult.failure(json['message'] ?? 'Failed to upload image');
    } catch (e) {
      debugPrint('Error uploading lost & found image: $e');
      return ApiResult.failure(e.toString());
    }
  }

  /// Create a claim for a lost & found item
  Future<ApiResult<void>> createLostFoundClaim(
    int itemId,
    String message,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/lost-found/$itemId/claims'),
        headers: await _getAuthHeader(),
        body: jsonEncode({'message': message}),
      );

      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        // Invalidate my claims cache
        await invalidateMyLostFoundCache();
        // Invalidate specific item cache to refresh its state/claims
        await invalidateLostFoundItemCache(itemId);
        return ApiResult.success();
      }
      return ApiResult.failure(json['message'] ?? 'Failed to submit claim');
    } catch (e) {
      debugPrint('Error creating lost & found claim: $e');
      return ApiResult.failure(e.toString());
    }
  }

  /// Get claims for a specific lost & found item (owner only)
  Future<List<LostFoundClaim>> getLostFoundItemClaims(int itemId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/lost-found/$itemId/claims'),
        headers: await _getAuthHeader(),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return (json['data'] as List)
              .map((e) => LostFoundClaim.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching item claims: $e');
    }
    return [];
  }

  /// Respond to a lost & found claim (Accept/Reject)
  Future<ApiResult<void>> respondToLostFoundClaim(
    int itemId,
    int claimId,
    LostFoundClaimStatus status,
  ) async {
    try {
      final statusString = status.name; // accepted, rejected, cancelled
      final response = await http.put(
        Uri.parse('$apiBaseUrl/lost-found/$itemId/claims/$claimId'),
        headers: await _getAuthHeader(),
        body: jsonEncode({'status': statusString}),
      );

      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        // Invalidate cache
        await invalidateLostFoundItemCache(itemId);
        await invalidateMyLostFoundCache();
        return ApiResult.success();
      }
      return ApiResult.failure(json['message'] ?? 'Failed to update claim');
    } catch (e) {
      debugPrint('Error responding to claim: $e');
      return ApiResult.failure(e.toString());
    }
  }

  /// Update the status of a lost & found item (Resolved/Closed)
  Future<ApiResult<void>> updateLostFoundItemStatus(
    int itemId,
    LostFoundStatus status,
  ) async {
    try {
      final statusString = status.name; // resolved, closed, open
      final response = await http.put(
        Uri.parse('$apiBaseUrl/lost-found/$itemId/status'),
        headers: await _getAuthHeader(),
        body: jsonEncode({'status': statusString}),
      );

      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        // Invalidate cache
        await invalidateLostFoundItemCache(itemId);
        await invalidateLostFoundCache();
        await invalidateMyLostFoundCache();
        return ApiResult.success();
      }
      return ApiResult.failure(json['message'] ?? 'Failed to update status');
    } catch (e) {
      debugPrint('Error updating item status: $e');
      return ApiResult.failure(e.toString());
    }
  }

  /// Get user's own lost & found items (cache-first)
  Future<List<LostFoundItem>> getMyLostFoundItems({
    bool forceRefresh = false,
  }) async {
    final userId = await getDatabaseUserId();
    if (userId == null) return [];
    final String cacheKey = 'my_lost_found_items_${userId}_cache';

    if (!forceRefresh) {
      final cachedData = await _getFromCache(cacheKey);
      if (cachedData != null) {
        try {
          final json = jsonDecode(cachedData);
          if (json['success'] == true && json['data'] != null) {
            // Background refresh
            _fetchMyLostFoundItemsFromNetwork(cacheKey);
            return (json['data'] as List)
                .map((e) => LostFoundItem.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        } catch (e) {
          debugPrint('Error parsing cached my lost & found items: $e');
        }
      }
    }

    return _fetchMyLostFoundItemsFromNetwork(cacheKey);
  }

  /// Fetches my lost & found items from network and saves to cache
  Future<List<LostFoundItem>> _fetchMyLostFoundItemsFromNetwork(
    String cacheKey,
  ) async {
    bool isOnline = await _hasInternetConnection();
    if (!isOnline) return [];

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/lost-found/my/items'),
        headers: await _getAuthHeader(),
      );

      if (response.statusCode == 200) {
        await _saveToCache(cacheKey, response.body);
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return (json['data'] as List)
              .map((e) => LostFoundItem.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching my lost & found items online: $e');
    }
    return [];
  }

  /// Get user's own claims (cache-first)
  Future<List<LostFoundClaim>> getMyLostFoundClaims({
    bool forceRefresh = false,
  }) async {
    final userId = await getDatabaseUserId();
    if (userId == null) return [];
    final String cacheKey = 'my_lost_found_claims_${userId}_cache';

    if (!forceRefresh) {
      final cachedData = await _getFromCache(cacheKey);
      if (cachedData != null) {
        try {
          final json = jsonDecode(cachedData);
          if (json['success'] == true && json['data'] != null) {
            // Background refresh
            _fetchMyLostFoundClaimsFromNetwork(cacheKey);
            return (json['data'] as List)
                .map((e) => LostFoundClaim.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        } catch (e) {
          debugPrint('Error parsing cached my lost & found claims: $e');
        }
      }
    }

    return _fetchMyLostFoundClaimsFromNetwork(cacheKey);
  }

  /// Fetches my lost & found claims from network and saves to cache
  Future<List<LostFoundClaim>> _fetchMyLostFoundClaimsFromNetwork(
    String cacheKey,
  ) async {
    bool isOnline = await _hasInternetConnection();
    if (!isOnline) return [];

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/lost-found/my/claims'),
        headers: await _getAuthHeader(),
      );

      if (response.statusCode == 200) {
        await _saveToCache(cacheKey, response.body);
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return (json['data'] as List)
              .map((e) => LostFoundClaim.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching my lost & found claims online: $e');
    }
    return [];
  }

  /// Invalidate general lost & found list cache
  Future<void> invalidateLostFoundCache() async {
    try {
      final box = Hive.box('api_cache');
      final keys = box.keys.where(
        (k) => k.toString().startsWith('lost_found_'),
      );
      for (final key in keys) {
        // Don't invalidate individual items or 'my' lists here
        if (!key.toString().startsWith('lost_found_item_') &&
            !key.toString().startsWith('my_lost_found_')) {
          await box.delete(key);
        }
      }
    } catch (e) {
      debugPrint('Error invalidating lost found cache: $e');
    }
  }

  /// Invalidate my lost & found lists
  Future<void> invalidateMyLostFoundCache() async {
    final userId = await getDatabaseUserId();
    if (userId != null) {
      await _removeFromCache('my_lost_found_items_${userId}_cache');
      await _removeFromCache('my_lost_found_claims_${userId}_cache');
    }
  }

  /// Invalidate specific lost & found item cache
  Future<void> invalidateLostFoundItemCache(int id) async {
    await _removeFromCache('lost_found_item_${id}_cache');
  }

  /// Invalidate ALL lost & found related caches
  Future<void> invalidateAllLostFoundCaches() async {
    await invalidateLostFoundCache();
    await invalidateMyLostFoundCache();
    // Also clear individual items if needed, or just let them expire/refresh
  }

  /// Create a report for a user or listing
  Future<Map<String, dynamic>> createMarketplaceReport({
    required String reportedUserId,
    int? listingId,
    required ReportCategory category,
    required String description,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/books/trust/reports'),
        headers: await _getAuthHeader(),
        body: jsonEncode({
          'reportedUserId': reportedUserId,
          'listingId': listingId,
          'category': category.value,
          'description': description,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('Error creating marketplace report: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get reports created by the current user
  Future<List<MarketplaceReport>> getMyMarketplaceReports() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/books/trust/reports/my'),
        headers: await _getAuthHeader(),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return (json['data'] as List)
              .map((e) => MarketplaceReport.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error getting my reports: $e');
    }
    return [];
  }

  // ==================== IN-APP NOTIFICATIONS API ====================

  /// Get in-app notifications with optional filters
  Future<List<InAppNotification>> getInAppNotifications({
    int limit = 20,
    int offset = 0,
    String? type,
    bool unreadOnly = false,
  }) async {
    try {
      final queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
        if (type != null) 'type': type,
        if (unreadOnly) 'unreadOnly': 'true',
      };

      final uri = Uri.parse(
        '$apiBaseUrl/notifications',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: await _getAuthHeader());

      debugPrint('DEBUG: [API Response Status] ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          final items = (json['data'] as List)
              .map((e) => InAppNotification.fromJson(e as Map<String, dynamic>))
              .toList();
          debugPrint('DEBUG: [Notifications Loaded] ${items.length}');
          return items;
        } else {
          debugPrint(
            'DEBUG: [API Success Flag False or Data Null] success: ${json['success']}, data exists: ${json['data'] != null}',
          );
        }
      } else {
        debugPrint('DEBUG: [API Error Response] ${response.body}');
      }
    } catch (e, stack) {
      debugPrint('Error getting in-app notifications: $e');
      debugPrint('Stack trace: $stack');
    }
    return [];
  }

  /// Get count of unread notifications
  Future<int> getUnreadNotificationCount() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/notifications/unread-count'),
        headers: await _getAuthHeader(),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['count'] != null) {
          return json['count'] as int;
        }
      }
    } catch (e) {
      debugPrint('Error getting unread notification count: $e');
    }
    return 0;
  }

  /// Mark a specific notification as read
  Future<bool> markNotificationAsRead(int notificationId) async {
    try {
      final response = await http.patch(
        Uri.parse('$apiBaseUrl/notifications/$notificationId/read'),
        headers: await _getAuthHeader(),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['success'] == true;
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
    return false;
  }

  /// Mark all notifications as read for current user
  Future<bool> markAllNotificationsAsRead() async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/notifications/mark-all-read'),
        headers: await _getAuthHeader(),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['success'] == true;
      }
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
    return false;
  }

  /// Process and optimize image URL (Cloudinary + Google Drive support)
  static String? processImageUrl(String? url, {int? width}) {
    if (url == null || url.isEmpty) return null;

    // Handle Google Drive links
    if (url.contains('drive.google.com')) {
      // Convert view links to direct download links
      // Format: https://drive.google.com/file/d/FILE_ID/view?usp=sharing
      final regExp = RegExp(r'\/file\/d\/([^\/]+)\/');
      final match = regExp.firstMatch(url);
      if (match != null && match.groupCount >= 1) {
        final fileId = match.group(1);
        return 'https://docs.google.com/uc?export=download&id=$fileId';
      }
    }

    // Handle Cloudinary optimizations
    if (url.contains('cloudinary.com') && url.contains('/upload/')) {
      final transform =
          'f_auto,q_auto${width != null ? ',w_$width,c_limit' : ''}';
      return url.replaceFirst('/upload/', '/upload/$transform/');
    }

    return url;
  }

  /// Optimize Cloudinary URL by adding auto format and quality
  /// @deprecated Use [processImageUrl] instead
  String optimizeCloudinaryUrl(String url, {int? width}) {
    return processImageUrl(url, width: width) ?? url;
  }
}

/// Global search result containing matches from all content types
class GlobalSearchResult {
  final String query;
  final List<Club> clubs;
  final List<ClubEvent> events;
  final List<BookListing> books;
  final List<Notice> notices;
  final List<SearchPlace> places;
  final List<LostFoundItem> lostFound;
  final int total;

  GlobalSearchResult({
    required this.query,
    required this.clubs,
    required this.events,
    required this.books,
    required this.notices,
    required this.places,
    this.lostFound = const [],
    required this.total,
  });

  factory GlobalSearchResult.fromJson(Map<String, dynamic> json) {
    // Parse each category with try-catch to prevent one failure from breaking all
    List<Club> clubs = [];
    if (json['clubs'] is List) {
      for (final item in json['clubs'] as List) {
        try {
          clubs.add(Club.fromJson(item as Map<String, dynamic>));
        } catch (e) {
          debugPrint('Error parsing club in search: $e');
        }
      }
    }

    List<ClubEvent> events = [];
    if (json['events'] is List) {
      for (final item in json['events'] as List) {
        try {
          // Use partial json parser since search returns minimal data
          events.add(ClubEvent.fromPartialJson(item as Map<String, dynamic>));
        } catch (e) {
          debugPrint('Error parsing event in search: $e');
        }
      }
    }

    List<BookListing> books = [];
    if (json['books'] is List) {
      for (final item in json['books'] as List) {
        try {
          // Use partial json parser since search returns minimal data
          books.add(BookListing.fromPartialJson(item as Map<String, dynamic>));
        } catch (e) {
          debugPrint('Error parsing book in search: $e');
        }
      }
    }

    List<Notice> notices = [];
    if (json['notices'] is List) {
      for (final item in json['notices'] as List) {
        try {
          notices.add(Notice.fromJson(item as Map<String, dynamic>));
        } catch (e) {
          debugPrint('Error parsing notice in search: $e');
        }
      }
    }

    List<SearchPlace> places = [];
    if (json['places'] is List) {
      for (final item in json['places'] as List) {
        try {
          places.add(SearchPlace.fromJson(item as Map<String, dynamic>));
        } catch (e) {
          debugPrint('Error parsing place in search: $e');
        }
      }
    }

    List<LostFoundItem> lostFound = [];
    if (json['lostFound'] is List) {
      for (final item in json['lostFound'] as List) {
        try {
          lostFound.add(
            LostFoundItem.fromPartialJson(item as Map<String, dynamic>),
          );
        } catch (e) {
          debugPrint('Error parsing lost_found in search: $e');
        }
      }
    }

    return GlobalSearchResult(
      query: json['query'] as String? ?? '',
      clubs: clubs,
      events: events,
      books: books,
      notices: notices,
      places: places,
      lostFound: lostFound,
      total: json['total'] as int? ?? 0,
    );
  }
}

/// Campus location from search results
class SearchPlace {
  final String id;
  final String name;
  final String description;
  final SearchCoordinates coordinates;
  final String icon;
  final List<SearchService> services;

  SearchPlace({
    required this.id,
    required this.name,
    required this.description,
    required this.coordinates,
    required this.icon,
    required this.services,
  });

  factory SearchPlace.fromJson(Map<String, dynamic> json) {
    return SearchPlace(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      coordinates: SearchCoordinates.fromJson(
        json['coordinates'] as Map<String, dynamic>? ?? {},
      ),
      icon: json['icon'] as String? ?? '',
      services:
          (json['services'] as List?)
              ?.map((e) => SearchService.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Coordinates for a search place
class SearchCoordinates {
  final double lat;
  final double lng;

  SearchCoordinates({required this.lat, required this.lng});

  factory SearchCoordinates.fromJson(Map<String, dynamic> json) {
    return SearchCoordinates(
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Service information for a search place
class SearchService {
  final String name;
  final String purpose;
  final String location;

  SearchService({
    required this.name,
    required this.purpose,
    required this.location,
  });

  factory SearchService.fromJson(Map<String, dynamic> json) {
    return SearchService(
      name: json['name'] as String? ?? '',
      purpose: json['purpose'] as String? ?? '',
      location: json['location'] as String? ?? '',
    );
  }
}
