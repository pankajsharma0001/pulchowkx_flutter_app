import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/foundation.dart";
import "package:google_sign_in/google_sign_in.dart";
import "package:pulchowkx_app/services/api_service.dart";
import "package:pulchowkx_app/services/notification_service.dart";

class FirebaseServices {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final GoogleSignIn googleSignIn = GoogleSignIn();
  final ApiService _apiService = ApiService();

  Future<bool> signInWithGoogle() async {
    try {
      // Sign in with Google
      final GoogleSignInAccount? googleSignInAccount = await googleSignIn
          .signIn();

      if (googleSignInAccount == null) {
        return false; // User canceled the sign-in
      }

      // Get authentication details
      final GoogleSignInAuthentication googleAuth =
          await googleSignInAccount.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await auth.signInWithCredential(
        credential,
      );

      // Display user info in terminal
      final User? user = userCredential.user;
      if (user != null) {
        debugPrint("========== Login Successful ==========");
        debugPrint("Name: ${user.displayName}");
        debugPrint("Email: ${user.email}");
        debugPrint("UID: ${user.uid}");
        debugPrint("=======================================");

        // Get Firebase ID token for API authentication
        final firebaseIdToken = await user.getIdToken();

        // Sync user to Postgres database
        final fcmToken = await NotificationService.getToken();

        final dbUserId = await _apiService.syncUser(
          authStudentId: user.uid,
          email: user.email ?? '',
          name: user.displayName ?? 'Unknown User',
          firebaseIdToken: firebaseIdToken ?? '',
          image: user.photoURL,
          fcmToken: fcmToken,
        );
        debugPrint("User synced to database. DB ID: $dbUserId");
      }

      return true;
    } catch (e) {
      debugPrint("Error during Google sign-in: $e");
      return false;
    }
  }

  Future<void> googleSignOut() async {
    // Get Firebase ID token before signing out (needed for API authentication)
    final firebaseIdToken = await auth.currentUser?.getIdToken();

    // Clear FCM token from server before signing out
    await _apiService.clearFcmToken(firebaseIdToken);

    // Clear stored user data
    await _apiService.clearStoredUserId();

    // Unsubscribe from notification topics to prevent duplicate notifications
    await NotificationService.unsubscribeFromAllTopics();

    // Sign out from Google and Firebase
    await googleSignIn.signOut();
    await auth.signOut();

    debugPrint("========== Logout Successful ==========");
  }
}
