import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/shell.dart';
import 'screens/start.dart';
import 'screens/update_screen.dart';
import 'services/local.dart';
import 'services/notify_service.dart';
import 'services/store.dart';
import 'widgets/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));
  await Local.init();
  try {
    await NotifyService.init();
  } catch (_) {}
  NotifyService.onOpenUpdate = () => NotifyService.navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const UpdateScreen()));
  var firebaseOk = false;
  if (DefaultFirebaseOptions.configured) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
      firebaseOk = true;
    } catch (_) {}
  }
  runApp(firebaseOk ? const LifeOS() : const SetupNeededApp());
}

/// Who is signed in.
class AuthState extends ChangeNotifier {
  User? user;
  bool ready = false;
  AuthState() {
    FirebaseAuth.instance.userChanges().listen((u) {
      user = u;
      ready = true;
      notifyListeners();
    });
  }
}

ThemeData _theme() => ThemeData(
      useMaterial3: true,
      fontFamily: 'Geist',
      scaffoldBackgroundColor: const Color(0xFFF1EEF4),
      colorScheme: ColorScheme.fromSeed(seedColor: C.ink, primary: C.ink, surface: C.white),
      textSelectionTheme: const TextSelectionThemeData(cursorColor: C.ink, selectionColor: C.lime, selectionHandleColor: C.ink),
      splashFactory: InkSparkle.splashFactory,
    );

class LifeOS extends StatelessWidget {
  const LifeOS({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthState(),
      child: Consumer<AuthState>(builder: (context, auth, _) {
        final user = auth.user;
        return MaterialApp(
          title: 'LifeOS',
          debugShowCheckedModeBanner: false,
          navigatorKey: NotifyService.navigatorKey,
          theme: _theme(),
          builder: (context, child) => user == null
              ? child!
              : ChangeNotifierProvider<Store>(key: ValueKey(user.uid), create: (_) => _makeStore(user.uid), child: child!),
          home: !auth.ready
              ? const SplashScreen()
              : user == null
                  ? const WelcomeScreen()
                  : LockGate(key: ValueKey(user.uid), child: const Shell()),
        );
      }),
    );
  }
}

Timer? _reschedule;

Store _makeStore(String uid) {
  final s = Store(uid);
  // Reminders follow the data: rebuild them shortly after any change.
  s.onChanged = () {
    _reschedule?.cancel();
    _reschedule = Timer(const Duration(seconds: 3), () => NotifyService.rescheduleAll(s));
  };
  s.onChanged!();
  return s;
}

/// Shown when Firebase values are not filled in yet (docs/SETUP-GUIDE.md, Part 3).
class SetupNeededApp extends StatelessWidget {
  const SetupNeededApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(debugShowCheckedModeBanner: false, theme: _theme(), home: const SetupNeededScreen());
}
