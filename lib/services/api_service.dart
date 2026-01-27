import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:pulchowkx_app/models/chatbot_response.dart';
import 'package:pulchowkx_app/models/club.dart';
import 'package:pulchowkx_app/models/event.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ApiService {
  // Change this to your backend URL
  // For local development: 'http://10.0.2.2:3000' (Android emulator)
  // For local development: 'http://localhost:3000' (iOS simulator/web)
  // For production: your deployed backend URL
  // static const String baseUrl = 'http://10.0.2.2:3000/api/event';
  // static const String apiBaseUrl = 'http://10.0.2.2:3000/api';
  static const String baseUrl = 'https://pulchowk-x.vercel.app/api/events';
  static const String apiBaseUrl = 'https://pulchowk-x.vercel.app/api';

  static const String _dbUserIdKey = 'database_user_id';
  static const String _userRoleKey = 'user_role';

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // ==================== USER ID MANAGEMENT ====================

  /// Get the database user ID (linked account ID)
  /// Falls back to Firebase UID if not set
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

  /// Sync Firebase user to Postgres database
  /// Call this after successful Firebase sign-in
  /// Returns the database user ID (may differ from Firebase UID if account was linked)
  Future<String?> syncUser({
    required String authStudentId,
    required String email,
    required String name,
    String? image,
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
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  /// Save data to cache
  Future<void> _saveToCache(String key, String json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, json);
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
        print('Error fetching clubs online: $e');
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
        print('Error parsing cached clubs: $e');
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
        print('Error fetching club online: $e');
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
        print('Error parsing cached club: $e');
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
        print('Error fetching club profile online: $e');
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
        print('Error parsing cached club profile: $e');
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
        print('Error fetching events online: $e');
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
        print('Error parsing cached events: $e');
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
        print('Error fetching upcoming events online: $e');
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
        print('Error parsing cached upcoming events: $e');
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
        print('Error fetching club events online: $e');
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
        print('Error parsing cached club events: $e');
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
        print('Error fetching enrollments online: $e');
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
  Future<Map<String, dynamic>> uploadEventBanner(File imageFile) async {
    try {
      final userId = await getDatabaseUserId();
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBaseUrl/events/upload-banner'),
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
}
