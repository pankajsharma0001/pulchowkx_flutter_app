import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService extends ChangeNotifier {
  static const String _clubsKey = 'favorite_clubs';
  static const String _eventsKey = 'favorite_events';

  Set<String> _favoriteClubIds = {};
  Set<String> _favoriteEventIds = {};
  bool _isLoaded = false;

  Set<String> get favoriteClubIds => _favoriteClubIds;
  Set<String> get favoriteEventIds => _favoriteEventIds;
  bool get isLoaded => _isLoaded;

  FavoritesService() {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final clubsJson = prefs.getString(_clubsKey);
      if (clubsJson != null) {
        final List<dynamic> clubsList = jsonDecode(clubsJson);
        _favoriteClubIds = clubsList.cast<String>().toSet();
      }

      final eventsJson = prefs.getString(_eventsKey);
      if (eventsJson != null) {
        final List<dynamic> eventsList = jsonDecode(eventsJson);
        _favoriteEventIds = eventsList.cast<String>().toSet();
      }

      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading favorites: $e');
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_clubsKey, jsonEncode(_favoriteClubIds.toList()));
      await prefs.setString(_eventsKey, jsonEncode(_favoriteEventIds.toList()));
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }

  // Club favorites
  bool isClubFavorite(String clubId) => _favoriteClubIds.contains(clubId);

  Future<void> toggleClubFavorite(String clubId) async {
    if (_favoriteClubIds.contains(clubId)) {
      _favoriteClubIds.remove(clubId);
    } else {
      _favoriteClubIds.add(clubId);
    }
    notifyListeners();
    await _saveFavorites();
  }

  Future<void> addClubToFavorites(String clubId) async {
    if (!_favoriteClubIds.contains(clubId)) {
      _favoriteClubIds.add(clubId);
      notifyListeners();
      await _saveFavorites();
    }
  }

  Future<void> removeClubFromFavorites(String clubId) async {
    if (_favoriteClubIds.contains(clubId)) {
      _favoriteClubIds.remove(clubId);
      notifyListeners();
      await _saveFavorites();
    }
  }

  // Event favorites
  bool isEventFavorite(String eventId) => _favoriteEventIds.contains(eventId);

  Future<void> toggleEventFavorite(String eventId) async {
    if (_favoriteEventIds.contains(eventId)) {
      _favoriteEventIds.remove(eventId);
    } else {
      _favoriteEventIds.add(eventId);
    }
    notifyListeners();
    await _saveFavorites();
  }

  Future<void> addEventToFavorites(String eventId) async {
    if (!_favoriteEventIds.contains(eventId)) {
      _favoriteEventIds.add(eventId);
      notifyListeners();
      await _saveFavorites();
    }
  }

  Future<void> removeEventFromFavorites(String eventId) async {
    if (_favoriteEventIds.contains(eventId)) {
      _favoriteEventIds.remove(eventId);
      notifyListeners();
      await _saveFavorites();
    }
  }

  // Clear all favorites
  Future<void> clearAllFavorites() async {
    _favoriteClubIds.clear();
    _favoriteEventIds.clear();
    notifyListeners();
    await _saveFavorites();
  }

  // Get counts
  int get favoriteClubsCount => _favoriteClubIds.length;
  int get favoriteEventsCount => _favoriteEventIds.length;
}

// Global instance for easy access
final favoritesService = FavoritesService();
