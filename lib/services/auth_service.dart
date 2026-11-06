import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config.dart';

/// Google sign-in. The first sign-in creates the account (sign up);
/// later sign-ins on any phone open the same account and its data.
class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final google = GoogleSignIn(serverClientId: Config.googleWebClientId, scopes: const ['email']);

  static User? get user => _auth.currentUser;

  static Future<void> signInWithGoogle() async {
    final acc = await google.signIn();
    if (acc == null) throw 'Sign-in cancelled';
    final a = await acc.authentication;
    await _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: a.idToken, accessToken: a.accessToken));
  }

  static Future<void> signOut() async {
    try {
      await google.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  /// Short, friendly sentences for sign-in problems.
  static String friendly(Object e) {
    final s = e.toString();
    if (s.contains('ApiException: 10') || s.contains('DEVELOPER_ERROR')) {
      return 'Google sign-in is not set up yet: the SHA-1 in Firebase does not match the app. See the setup guide, Part 1.';
    }
    if (s.contains('network') || s.contains('ApiException: 7')) return 'No internet. Try again when you are online.';
    if (e is FirebaseAuthException) return e.message ?? 'Sign-in failed.';
    return s;
  }
}
