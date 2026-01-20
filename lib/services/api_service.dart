import 'dart:convert';
import 'package:http/http.dart' as http;
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
  }

  // ==================== USER SYNC ====================

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
          // Store the database user ID for future API calls
          await _storeDatabaseUserId(databaseUserId);
          return databaseUserId;
        }
      }
      return null;
    } catch (e) {
      print('Error syncing user: $e');
      return null;
    }
  }

  // ==================== CACHING & CONNECTIVITY ====================

  /// Check for internet connectivity
  /// Check for internet connectivity
  Future<bool> _hasInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      print('Connectivity check: $connectivityResult');
      return connectivityResult.first != ConnectivityResult.none;
    } catch (e) {
      print('Error checking connectivity: $e');
      // If plugin is missing (hot restart issue) or other error,
      // return false to safely fallback to cache or handle appropriately.
      // Alternatively return true to attempt request anyway?
      // Let's return false to avoid crashing on network calls if the environment is unstable,
      // but usually MissingPluginException means we should just rebuild.
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

      print('Register response status: ${response.statusCode}');
      print('Register response body: ${response.body}');

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
      print('Error registering for event: $e');
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

      print('Cancel response status: ${response.statusCode}');
      print('Cancel response body: ${response.body}');

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
      print('Error cancelling registration: $e');
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
        print('Error parsing cached enrollments: $e');
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
      print('Error calling chatbot: $e');
      return ChatBotResponse(success: false, errorMessage: 'Network error: $e');
    }
  }
}
