import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(
    analytics: _analytics,
  );

  static Future<void> logAppOpen() async {
    await _analytics.logAppOpen();
  }

  static Future<void> logPageView(String screenName) async {
    await _analytics.logEvent(
      name: 'screen_view',
      parameters: {
        'firebase_screen': screenName,
        'firebase_screen_class': screenName,
      },
    );
  }

  static Future<void> logEventView(String eventId, String eventTitle) async {
    await _analytics.logSelectContent(contentType: 'event', itemId: eventId);
    await _analytics.logEvent(
      name: 'view_event',
      parameters: {'event_id': eventId, 'event_title': eventTitle},
    );
  }

  static Future<void> logClubView(String clubId, String clubName) async {
    await _analytics.logSelectContent(contentType: 'club', itemId: clubId);
    await _analytics.logEvent(
      name: 'view_club',
      parameters: {'club_id': clubId, 'club_name': clubName},
    );
  }

  static Future<void> logRegistration(String eventId, String eventTitle) async {
    await _analytics.logEvent(
      name: 'event_registration',
      parameters: {'event_id': eventId, 'event_title': eventTitle},
    );
  }

  static Future<void> logLogin(String method) async {
    await _analytics.logLogin(loginMethod: method);
  }

  static Future<void> setUserProperty(String name, String value) async {
    await _analytics.setUserProperty(name: name, value: value);
  }
}
