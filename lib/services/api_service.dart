import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pulchowkx_app/models/club.dart';
import 'package:pulchowkx_app/models/event.dart';

class ApiService {
  // Change this to your backend URL
  // For local development: 'http://10.0.2.2:3000' (Android emulator)
  // For local development: 'http://localhost:3000' (iOS simulator/web)
  // For production: your deployed backend URL
  // static const String baseUrl = 'http://10.0.2.2:3000/api/event';
  // static const String apiBaseUrl = 'http://10.0.2.2:3000/api';
  static const String baseUrl = 'https://pulchowk-x.vercel.app/api/event';
  static const String apiBaseUrl = 'https://pulchowk-x.vercel.app/api';

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // ==================== USER SYNC ====================

  /// Sync Firebase user to Postgres database
  /// Call this after successful Firebase sign-in
  Future<bool> syncUser({
    required String authStudentId,
    required String email,
    required String name,
    String? image,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/sync-user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'authStudentId': authStudentId,
          'email': email,
          'name': name,
          'image': image,
        }),
      );

      print('Sync user response status: ${response.statusCode}');
      print('Sync user response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        if (json['data'] != null) {
          return json['data']['success'] == true;
        }
        return json['success'] == true;
      }
      return false;
    } catch (e) {
      print('Error syncing user: $e');
      return false;
    }
  }

  // ==================== CLUBS ====================

  /// Get all clubs
  Future<List<Club>> getClubs() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/clubs'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['data'];

        if (data['success'] == true && data['existingClub'] != null) {
          final List<dynamic> clubsJson = data['existingClub'];
          return clubsJson.map((c) => Club.fromJson(c)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching clubs: $e');
      return [];
    }
  }

  /// Get a single club by ID
  Future<Club?> getClub(int clubId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/clubs/$clubId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['data'];

        if (data['success'] == true && data['clubData'] != null) {
          return Club.fromJson(data['clubData']);
        }
      }
      return null;
    } catch (e) {
      print('Error fetching club: $e');
      return null;
    }
  }

  /// Get club profile
  Future<ClubProfile?> getClubProfile(int clubId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/club-profile/$clubId'),
        headers: {'Content-Type': 'application/json'},
      );

      print('Club profile response status: ${response.statusCode}');
      print('Club profile response body: ${response.body}');

      if (response.statusCode == 200) {
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
      return null;
    } catch (e) {
      print('Error fetching club profile: $e');
      return null;
    }
  }

  // ==================== EVENTS ====================

  /// Get all events
  Future<List<ClubEvent>> getAllEvents() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/all-events'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['data'];

        if (data['success'] == true && data['allEvents'] != null) {
          final List<dynamic> eventsJson = data['allEvents'];
          return eventsJson.map((e) => ClubEvent.fromJson(e)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching events: $e');
      return [];
    }
  }

  /// Get upcoming events
  Future<List<ClubEvent>> getUpcomingEvents() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/get-upcoming-events'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['data'];

        if (data['success'] == true && data['upcomingEvents'] != null) {
          final List<dynamic> eventsJson = data['upcomingEvents'];
          return eventsJson.map((e) => ClubEvent.fromJson(e)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching upcoming events: $e');
      return [];
    }
  }

  /// Get events by club ID
  Future<List<ClubEvent>> getClubEvents(int clubId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/events/$clubId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['data'];

        if (data['success'] == true && data['clubEvents'] != null) {
          final List<dynamic> eventsJson = data['clubEvents'];
          return eventsJson.map((e) => ClubEvent.fromJson(e)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching club events: $e');
      return [];
    }
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
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/enrollment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'authStudentId': authStudentId}),
      );

      print('Enrollments response status: ${response.statusCode}');
      print('Enrollments response body: ${response.body}');

      if (response.statusCode == 200) {
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
      return [];
    } catch (e) {
      print('Error fetching enrollments: $e');
      return [];
    }
  }
}
