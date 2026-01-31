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

        // Sync user to Postgres database
        final fcmToken = await NotificationService.getToken();

        final dbUserId = await _apiService.syncUser(
          authStudentId: user.uid,
          email: user.email ?? '',
          name: user.displayName ?? 'Unknown User',
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
    await googleSignIn.signOut();
    await auth.signOut();
  }
}
