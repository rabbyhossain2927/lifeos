import 'package:firebase_core/firebase_core.dart';

/// Fill these from Firebase console > Project settings > General > Your apps > LifeOS (Android).
/// See docs/SETUP-GUIDE.md, Part 1. Until they are filled, the app shows a
/// "setup needed" page instead of crashing.
class DefaultFirebaseOptions {
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'PASTE-WEB-API-KEY', // "Web API Key"
    appId: 'PASTE-APP-ID', // looks like 1:1234567890:android:abc123...
    messagingSenderId: 'PASTE-PROJECT-NUMBER', // "Project number"
    projectId: 'PASTE-PROJECT-ID', // "Project ID"
  );

  static bool get configured => !android.apiKey.startsWith('PASTE');
}
