// Builds every screen with an empty account and fails if any throws.
// Runs in GitHub Actions (Check code), so crashes show up before release.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:lifeos/services/store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lifeos/services/local.dart';
import 'package:lifeos/screens/home.dart';
import 'package:lifeos/screens/goals.dart';
import 'package:lifeos/screens/goal_detail.dart';
import 'package:lifeos/screens/explore.dart';
import 'package:lifeos/screens/account.dart';
import 'package:lifeos/screens/tools.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Local.init();
  });

  final screens = <String, Widget Function()>{
    'Home': () => HomeTab(onTab: (_) {}),
    'Goals': () => const GoalsTab(),
    'Goal detail': () => const GoalDetail(id: 'g1'),
    'New goal': () => const AddGoalPage(),
    'Week review': () => const ReviewPage(),
    'Explore': () => const ExploreTab(),
    'Account': () => const AccountTab(),
    for (final tl in tools) 'Tool ${tl.name}': tl.page,
  };

  for (final e in screens.entries) {
    testWidgets('${e.key} builds', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      final store = Store('test');
      // Like data coming back from the PHP server: empty maps arrive as [].
      store.add('habits', {'name': 'Read', 'logs': cleanDoc({'logs': []})['logs']});
      store.save('goals', cleanDoc({'id': 'g1', 'title': 'Read 24 books', 'target': 24, 'unit': 'books', 'logUnit': 'pages', 'perUnit': 300, 'logs': [], 'steps': [{'t': 'Pick a book', 'min': '5 min', 'done': false}]}));
      store.add('trips', cleanDoc({'place': 'Sylhet', 'from': '2099-01-01', 'to': '2099-01-03', 'packing': [], 'plan': []}));
      store.add('courses', cleanDoc({'name': 'Arabic', 'total': 20, 'done': 3, 'logs': []}));
      store.add('dates', cleanDoc({'title': 'Mom', 'date': '1970-12-01', 'yearly': true}));
      store.add('moments', cleanDoc({'title': 'Trip', 'date': '2025-01-01'}));
      store.add('care', cleanDoc({'name': 'Face wash', 'time': 'pm', 'logs': []}));
      store.add('reminders', cleanDoc({'title': 'Vitamins', 'times': ['09:00'], 'on': true}));
      store.setSetting('license', {'key': 'TEST-KEY-1234'});
      store.setSetting('name', 'Test');
      final errors = <String>[];
      final old = FlutterError.onError;
      FlutterError.onError = (d) => errors.add('${d.exceptionAsString()}\n${d.stack.toString().split('\n').take(8).join('\n')}');
      await tester.pumpWidget(ChangeNotifierProvider<Store>.value(
        value: store,
        child: MaterialApp(home: Scaffold(body: e.value())),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      FlutterError.onError = old;
      // Overflow warnings are layout hints, not crashes.
      final real = errors.where((m) => !m.contains('overflowed')).toList();
      if (errors.isNotEmpty) debugPrint('=== ${e.key}: ${errors.length} error(s)\n${errors.join('\n---\n')}');
      store.dispose();
      await tester.pump(const Duration(seconds: 1));
      expect(real, isEmpty, reason: real.join('\n'));
    });
  }
}

