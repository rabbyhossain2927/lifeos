import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/local.dart';
import '../widgets/ui.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(backgroundColor: C.ink, body: Center(child: LogoMark(size: 96, tile: false)));
}

/// Sign in / sign up with Google (the first sign-in creates the account).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool busy = false;
  String? error;

  Future<void> _go() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await AuthService.signInWithGoogle();
    } catch (e) {
      if (mounted) setState(() => error = AuthService.friendly(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const LogoMark(size: 56),
              const Spacer(),
              Text.rich(TextSpan(children: [
                TextSpan(text: 'Your whole day,\n', style: t(40, w: FontWeight.w400, ls: -1, h: 1.1)),
                TextSpan(text: 'one calm place.', style: t(40, w: w6, ls: -1, h: 1.1)),
              ])),
              const SizedBox(height: 16),
              Text('Goals from year to today, habits, journal, health, focus and deen. Synced to every phone you sign in on.',
                  style: t(15, c: C.muted, h: 1.5)),
              const SizedBox(height: 32),
              if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error!, style: t(13, c: C.warn, h: 1.4))),
              PillButton(busy ? 'Signing in…' : 'Continue with Google', bg: C.ink, fg: C.white, height: 58, icon: Icons.login_rounded, onTap: busy ? null : _go),
              const SizedBox(height: 12),
              Center(child: Text('New here? This also creates your account.', style: t(12, c: C.muted))),
            ]),
          ),
        ),
      ),
    );
  }
}

class SetupNeededScreen extends StatelessWidget {
  const SetupNeededScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Col([
              const LogoMark(size: 56),
              const SizedBox(height: 12),
              Text('Almost ready', style: t(32, w: w6, ls: -0.8)),
              Text('Firebase is not connected yet. Fill in lib/firebase_options.dart and lib/config.dart (setup guide, Part 3), then build again.',
                  style: t(15, c: C.muted, h: 1.5)),
            ], space: 12),
          ),
        ),
      ),
    );
  }
}

/// Asks for the app-lock PIN when one is set (Profile > App lock).
class LockGate extends StatefulWidget {
  final Widget child;
  const LockGate({super.key, required this.child});
  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  bool locked = Local.pin.isNotEmpty;
  DateTime? _away;
  String entered = '';
  bool wrong = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) _away = DateTime.now();
    if (s == AppLifecycleState.resumed && Local.pin.isNotEmpty && _away != null && DateTime.now().difference(_away!).inSeconds > 30) {
      setState(() {
        locked = true;
        entered = '';
      });
    }
  }

  void _key(String k) {
    setState(() {
      wrong = false;
      if (k == '<') {
        if (entered.isNotEmpty) entered = entered.substring(0, entered.length - 1);
      } else if (entered.length < 4) {
        entered += k;
      }
    });
    if (entered.length == 4) {
      if (entered == Local.pin) {
        setState(() => locked = false);
      } else {
        setState(() {
          wrong = true;
          entered = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!locked) return widget.child;
    return Scaffold(
      backgroundColor: C.ink,
      body: SafeArea(
        child: Column(children: [
          const Spacer(),
          const LogoMark(size: 64, tile: false),
          const SizedBox(height: 24),
          Text(wrong ? 'Wrong PIN, try again' : 'Enter your PIN', style: t(18, w: w6, c: wrong ? const Color(0xFFF2A07B) : C.white)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < 4; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 14,
                height: 14,
                decoration: BoxDecoration(shape: BoxShape.circle, color: i < entered.length ? C.lime : C.dark3),
              ),
          ]),
          const Spacer(),
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['', '0', '<'],
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (final k in row)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: k.isEmpty
                        ? const SizedBox(width: 72, height: 72)
                        : Material(
                            color: C.dark2,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => _key(k),
                              child: SizedBox(
                                width: 72,
                                height: 72,
                                child: Center(
                                  child: k == '<'
                                      ? const Icon(Icons.backspace_outlined, color: C.white, semanticLabel: 'Delete')
                                      : Text(k, style: t(26, w: w5, c: C.white)),
                                ),
                              ),
                            ),
                          ),
                  ),
              ]),
            ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}
