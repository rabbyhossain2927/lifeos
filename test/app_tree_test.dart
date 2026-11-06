// Same widget tree as main.dart: the Store provider is added by
// MaterialApp.builder only after sign-in. Checks the tabs still find it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:lifeos/services/store.dart';
import 'package:lifeos/screens/goals.dart';

final navKey = GlobalKey<NavigatorState>();

class FakeApp extends StatelessWidget {
  final String? uid;
  const FakeApp(this.uid, {super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navKey,
      builder: (context, child) => uid == null ? child! : ChangeNotifierProvider<Store>(key: ValueKey(uid), create: (_) => Store(uid!), child: child!),
      home: uid == null ? const Text('splash') : const Scaffold(body: GoalsTab()),
    );
  }
}

void main() {
  testWidgets('tabs find the Store after signing in', (tester) async {
    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.exceptionAsString());
    await tester.pumpWidget(const FakeApp(null));
    await tester.pumpWidget(const FakeApp('u1'));
    await tester.pump(const Duration(milliseconds: 100));
    FlutterError.onError = old;
    final real = errors.where((m) => !m.contains('overflowed')).toList();
    debugPrint('=== app tree: ${real.join('\n')}');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(real, isEmpty, reason: real.join('\n'));
  });
}
