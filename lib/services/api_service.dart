import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:pulchowkx_app/models/book_listing.dart';
import 'package:pulchowkx_app/models/chatbot_response.dart';
import 'package:pulchowkx_app/models/classroom.dart';
import 'package:pulchowkx_app/models/club.dart';
import 'package:pulchowkx_app/models/event.dart';
import 'package:pulchowkx_app/models/chat.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ApiService {
  static const String baseUrl = 'https://pulchowk-x.vercel.app/api/events';
  static const String apiBaseUrl = 'https://pulchowk-x.vercel.app/api';

  static const String _dbUserIdKey = 'database_user_id';
  static const String _userRoleKey = 'user_role';

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // ==================== USER ID MANAGEMENT ====================
  Future<String?> getDatabaseUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_dbUserIdKey);
  }

  /// Store the database user ID
  Future<void> _storeDatabaseUserId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dbUserIdKey, id);
  }

  /// Clear stored user ID on logout
  Future<void> clearStoredUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dbUserIdKey);
    await prefs.remove(_userRoleKey);
  }

  /// Get the user's role (student, admin, etc.)
  Future<String> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userRoleKey) ?? 'student';
  }

  /// Check if user is admin
  Future<bool> isAdmin() async {
    final role = await getUserRole();
    return role == 'admin';
  }

  /// Store the user role
  Future<void> _storeUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userRoleKey, role);
  }

  Future<String?> syncUser({
    required String authStudentId,
    required String email,
    required String name,
    String? image,
    String? fcmToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/users/sync-user'),
        headers: {'Content-Type': 'application/json'},
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
          // Store the database user ID and role for future API calls
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

  // ==================== CACHING & CONNECTIVITY ====================

  Future<bool> _hasInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult.first != ConnectivityResult.none;
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

  // ==================== CLUBS ====================

  /// Get all clubs
  Future<List<Club>> getClubs() async {
    const String cacheKey = 'clubs_cache';
    bool isOnline = await _hasInternetConnection();

    if (isOnline) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/clubs'),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          final data = json['data'];

          if (data['success'] == true && data['existingClub'] != null) {
            // Cache specific part or entire body? Caching entire body is safer for structure match
            await _saveToCache(cacheKey, response.body);
            final List<dynamic> clubsJson = data['existingClub'];
            return clubsJson.map((c) => Club.fromJson(c)).toList();
          }
        }
      } catch (e) {
        debugPrint('Error fetching clubs online: $e');
        // Fallback to cache if online request fails
      }
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
    bool isOnline = await _hasInternetConnection();

    if (isOnline) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/clubs/$clubId'),
          headers: {'Content-Type': 'application/json'},
        );

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
    bool isOnline = await _hasInternetConnection();

    if (isOnline) {
      try {
        final response = await http.get(
          Uri.parse('$apiBaseUrl/clubs/club-profile/$clubId'),
          headers: {'Content-Type': 'application/json'},
        );
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
    bool isOnline = await _hasInternetConnection();

    if (isOnline) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/all-events'),
          headers: {'Content-Type': 'application/json'},
        );

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
    bool isOnline = await _hasInternetConnection();

    if (isOnline) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/get-upcoming-events'),
          headers: {'Content-Type': 'application/json'},
        );

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
          headers: {'Content-Type': 'application/json'},
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

  /// Register for an event
  Future<bool> registerForEvent(String authStudentId, int eventId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register-event'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'authStudentId': authStudentId, 'eventId': eventId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        // Handle both nested and direct response formats
        if (json['data'] != null) {
          return json['data']['success'] == true;
        }
        return json['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Cancel event registration
  Future<bool> cancelRegistration(String authStudentId, int eventId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/cancel-registration'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'authStudentId': authStudentId, 'eventId': eventId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        // Handle both nested and direct response formats
        if (json['data'] != null) {
          return json['data']['success'] == true;
        }
        return json['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
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
          headers: {'Content-Type': 'application/json'},
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
      final userId = await getDatabaseUserId();
      final response = await http.post(
        Uri.parse('$baseUrl/create-event'),
        headers: {
          'Content-Type': 'application/json',
          if (userId != null) 'Authorization': 'Bearer $userId',
        },
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

  // ==================== ADMIN: CLUB MANAGEMENT ====================

  /// Create a new club (admin only)
  Future<Map<String, dynamic>> createClub({
    required String name,
    required String email,
    String? description,
    String? logoUrl,
  }) async {
    try {
      final userId = await getDatabaseUserId();
      final response = await http.post(
        Uri.parse('$baseUrl/create-club'),
        headers: {
          'Content-Type': 'application/json',
          if (userId != null) 'Authorization': 'Bearer $userId',
        },
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
      final userId = await getDatabaseUserId();
      final response = await http.put(
        Uri.parse('$baseUrl/clubs/$clubId'),
        headers: {
          'Content-Type': 'application/json',
          if (userId != null) 'Authorization': 'Bearer $userId',
        },
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
      final userId = await getDatabaseUserId();
      final response = await http.put(
        Uri.parse('$apiBaseUrl/clubs/club-profile/$clubId'),
        headers: {
          'Content-Type': 'application/json',
          if (userId != null) 'Authorization': 'Bearer $userId',
        },
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
      final userId = await getDatabaseUserId();
      final response = await http.get(
        Uri.parse('$baseUrl/club/admins/$clubId'),
        headers: {
          'Content-Type': 'application/json',
          if (userId != null) 'Authorization': 'Bearer $userId',
        },
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
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
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
      final authUserId = await getDatabaseUserId();
      final response = await http.post(
        Uri.parse('$baseUrl/club/remove-admin'),
        headers: {
          'Content-Type': 'application/json',
          if (authUserId != null) 'Authorization': 'Bearer $authUserId',
        },
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
      final userId = await getDatabaseUserId();
      final response = await http.post(
        Uri.parse('$baseUrl/registered-student'),
        headers: {
          'Content-Type': 'application/json',
          if (userId != null) 'Authorization': 'Bearer $userId',
        },
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
        headers: {'Content-Type': 'application/json'},
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
      final userId = await getDatabaseUserId();
      final response = await http.post(
        Uri.parse('$apiBaseUrl/clubs/event-details/create-event-details'),
        headers: {
          'Content-Type': 'application/json',
          if (userId != null) 'Authorization': 'Bearer $userId',
        },
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
      final userId = await getDatabaseUserId();
      final response = await http.put(
        Uri.parse('$apiBaseUrl/clubs/event-details/update-eventdetail'),
        headers: {
          'Content-Type': 'application/json',
          if (userId != null) 'Authorization': 'Bearer $userId',
        },
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
      final userId = await getDatabaseUserId();
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBaseUrl/clubs/$clubId/upload-logo'),
      );

      if (userId != null) {
        request.headers['Authorization'] = 'Bearer $userId';
      }

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
      final userId = await getDatabaseUserId();
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBaseUrl/events/$eventId/upload-banner'),
      );

      if (userId != null) {
        request.headers['Authorization'] = 'Bearer $userId';
      }

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
    try {
      final userId = await getDatabaseUserId();
      final queryParams =
          filters?.toQueryParams() ?? {'page': '1', 'limit': '12'};
      final uri = Uri.parse(
        '$apiBaseUrl/books',
      ).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (userId != null) 'Authorization': 'Bearer $userId',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return BookListingsResponse.fromJson(
            json['data'] as Map<String, dynamic>,
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching book listings: $e');
      return null;
    }
  }

  /// Get a single book listing by ID
  Future<BookListing?> getBookListingById(int id) async {
    try {
      final userId = await getDatabaseUserId();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/books/listings/$id'),
        headers: {
          'Content-Type': 'application/json',
          if (userId != null) 'Authorization': 'Bearer $userId',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return BookListing.fromJson(json['data'] as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching book details: $e');
      return null;
    }
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
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
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
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
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
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
      );

      final json = jsonDecode(response.body);
      return {'success': json['success'] == true, 'message': json['message']};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Get current user's book listings
  Future<List<BookListing>> getMyBookListings() async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) return [];

      final response = await http.get(
        Uri.parse('$apiBaseUrl/books/my-listings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return (json['data'] as List)
              .map((e) => BookListing.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching my listings: $e');
      return [];
    }
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
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
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
      request.headers['Authorization'] = 'Bearer $userId';
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
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
      );

      final json = jsonDecode(response.body);
      return {'success': json['success'] == true, 'message': json['message']};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Get saved books
  Future<List<SavedBook>> getSavedBooks() async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) return [];

      final response = await http.get(
        Uri.parse('$apiBaseUrl/books/saved'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return (json['data'] as List)
              .map((e) => SavedBook.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching saved books: $e');
      return [];
    }
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
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
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
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
      );

      final json = jsonDecode(response.body);
      return {'success': json['success'] == true, 'message': json['message']};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Get book categories
  Future<List<BookCategory>> getBookCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/books/categories'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return (json['data'] as List)
              .map((e) => BookCategory.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching book categories: $e');
      return [];
    }
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
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
        body: jsonEncode({'message': message}),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Get purchase requests for a specific listing (seller's view)
  Future<List<BookPurchaseRequest>> getListingRequests(int listingId) async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) return [];

      final response = await http.get(
        Uri.parse('$apiBaseUrl/books/listings/$listingId/requests'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return (json['data'] as List)
              .map(
                (e) => BookPurchaseRequest.fromJson(e as Map<String, dynamic>),
              )
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching listing requests: $e');
      return [];
    }
  }

  /// Get my outgoing purchase requests (buyer's view)
  Future<List<BookPurchaseRequest>> getMyPurchaseRequests() async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) return [];

      final response = await http.get(
        Uri.parse('$apiBaseUrl/books/my-requests'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return (json['data'] as List)
              .map(
                (e) => BookPurchaseRequest.fromJson(e as Map<String, dynamic>),
              )
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching my requests: $e');
      return [];
    }
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
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
        body: jsonEncode({'accept': accept}),
      );

      return jsonDecode(response.body);
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
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
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
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
      );

      return jsonDecode(response.body);
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
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ==================== CLASSROOM API ====================

  /// Get all faculties
  Future<List<Faculty>> getFaculties() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/classroom/faculties'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['faculties'] != null) {
          return (json['faculties'] as List)
              .map((e) => Faculty.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching faculties: $e');
      return [];
    }
  }

  /// Get subjects by faculty and optional semester
  Future<List<Subject>> getSubjects({
    required int facultyId,
    int? semester,
  }) async {
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
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['subjects'] != null) {
          return (json['subjects'] as List)
              .map((e) => Subject.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching subjects: $e');
      return [];
    }
  }

  /// Get current user's student profile
  Future<StudentProfile?> getStudentProfile() async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) return null;

      final response = await http.get(
        Uri.parse('$apiBaseUrl/classroom/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['profile'] != null) {
          return StudentProfile.fromJson(
            json['profile'] as Map<String, dynamic>,
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching student profile: $e');
      return null;
    }
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
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
        body: jsonEncode(request.toJson()),
      );

      final json = jsonDecode(response.body);
      return {
        'success': json['success'] == true,
        'profile': json['profile'] != null
            ? StudentProfile.fromJson(json['profile'] as Map<String, dynamic>)
            : null,
        'message': json['message'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  /// Get current user's subjects with assignments
  Future<List<Subject>> getMySubjects() async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) return [];

      final response = await http.get(
        Uri.parse('$apiBaseUrl/classroom/me/subjects'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['subjects'] != null) {
          return (json['subjects'] as List)
              .map((e) => Subject.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching my subjects: $e');
      return [];
    }
  }

  /// Get teacher's assigned subjects
  Future<List<Subject>> getTeacherSubjects() async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) return [];

      final response = await http.get(
        Uri.parse('$apiBaseUrl/classroom/teacher/subjects'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['subjects'] != null) {
          return (json['subjects'] as List)
              .map((e) => Subject.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching teacher subjects: $e');
      return [];
    }
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
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
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
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
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
      request.headers['Authorization'] = 'Bearer $userId';
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
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) return [];

      final response = await http.get(
        Uri.parse(
          '$apiBaseUrl/classroom/assignments/$assignmentId/submissions',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['submissions'] != null) {
          return (json['submissions'] as List)
              .map(
                (e) => AssignmentSubmission.fromJson(e as Map<String, dynamic>),
              )
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching submissions: $e');
      return [];
    }
  }

  /// Check if user is a teacher
  Future<bool> isTeacher() async {
    final role = await getUserRole();
    return role == 'teacher';
  }

  // ==================== CHAT API ====================

  /// Get all conversations for the current user
  Future<List<MarketplaceConversation>> getConversations() async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) return [];

      final response = await http.get(
        Uri.parse('$apiBaseUrl/chat/conversations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return (json['data'] as List)
              .map(
                (c) =>
                    MarketplaceConversation.fromJson(c as Map<String, dynamic>),
              )
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error getting conversations: $e');
      return [];
    }
  }

  /// Get messages for a specific conversation
  Future<List<MarketplaceMessage>> getChatMessages(int conversationId) async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) return [];

      final response = await http.get(
        Uri.parse('$apiBaseUrl/chat/conversations/$conversationId/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return (json['data'] as List)
              .map(
                (m) => MarketplaceMessage.fromJson(m as Map<String, dynamic>),
              )
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error getting messages: $e');
      return [];
    }
  }

  /// Send a message for a listing
  Future<Map<String, dynamic>> sendMessage(
    int listingId,
    String content,
  ) async {
    try {
      final userId = await getDatabaseUserId();
      if (userId == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$apiBaseUrl/chat/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
        body: jsonEncode({'listingId': listingId, 'content': content}),
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
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userId',
        },
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
}
