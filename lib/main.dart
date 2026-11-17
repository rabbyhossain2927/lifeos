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
  // A screen that crashes shows what went wrong (send a screenshot) instead of a grey box.
  ErrorWidget.builder = (d) => Material(
        color: const Color(0xFFF1EEF4),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('This part of the screen hit a problem. Please send a screenshot.\n\n${d.exceptionAsString()}',
                style: const TextStyle(fontFamily: 'Geist', fontSize: 13, color: Color(0xFF5F6368))),
          ),
        ),
      );
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
      brightness: Look.dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bgGradient.colors[1],
      colorScheme: ColorScheme.fromSeed(seedColor: C.ink, primary: C.ink, surface: C.white, brightness: Look.dark ? Brightness.dark : Brightness.light),
      textSelectionTheme: TextSelectionThemeData(cursorColor: C.ink, selectionColor: C.lime, selectionHandleColor: C.ink),
      splashFactory: InkSparkle.splashFactory,
    );

class LifeOS extends StatefulWidget {
  const LifeOS({super.key});
  @override
  State<LifeOS> createState() => _LifeOSState();
}

class _LifeOSState extends State<LifeOS> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Look.apply(WidgetsBinding.instance.platformDispatcher.platformBrightness);
    Look.rev.addListener(_restyle);
  }

  @override
  void dispose() {
    Look.rev.removeListener(_restyle);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Auto theme follows the phone's dark mode.
  @override
  void didChangePlatformBrightness() {
    if (Look.mode == 'Auto') _restyle();
  }

  /// New colours or text size: rebuild every widget on screen (pages stay open).
  void _restyle() {
    Look.apply(WidgetsBinding.instance.platformDispatcher.platformBrightness);
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    if (mounted) {
      setState(() {});
      (context as Element).visitChildren(mark);
    }
  }

  @override
  Widget build(BuildContext context) => _app();

  Widget _app() {
    return ChangeNotifierProvider(
      create: (_) => AuthState(),
      child: Consumer<AuthState>(builder: (context, auth, _) {
        final user = auth.user;
        return MaterialApp(
          title: 'LifeOS',
          debugShowCheckedModeBanner: false,
          navigatorKey: NotifyService.navigatorKey,
          theme: _theme(),
          builder: (context, child) {
            final body = MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(Look.scale)),
              child: child!,
            );
            return user == null ? body : ChangeNotifierProvider<Store>(key: ValueKey(user.uid), create: (_) => _makeStore(user.uid), child: body);
          },
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
