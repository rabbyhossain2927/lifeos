// Builds every screen with an empty account and fails if any throws.
// Runs in GitHub Actions (Check code), so crashes show up before release.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:lifeos/services/store.dart';
import 'package:lifeos/screens/today.dart';
import 'package:lifeos/screens/goals.dart';
import 'package:lifeos/screens/habits.dart';
import 'package:lifeos/screens/journal.dart';
import 'package:lifeos/screens/explore.dart';
import 'package:lifeos/screens/health.dart';
import 'package:lifeos/screens/food.dart';
import 'package:lifeos/screens/focus.dart';
import 'package:lifeos/screens/daily.dart';
import 'package:lifeos/screens/deen.dart';
import 'package:lifeos/screens/learn.dart';
import 'package:lifeos/screens/dates.dart';
import 'package:lifeos/screens/travel.dart';
import 'package:lifeos/screens/selfcare.dart';
import 'package:lifeos/screens/rewards.dart';
import 'package:lifeos/screens/stats.dart';
import 'package:lifeos/screens/stuck.dart';
import 'package:lifeos/screens/launch.dart';

void main() {
  final screens = <String, Widget Function()>{
    'Today': () => TodayTab(onTab: (_) {}),
    'Goals': () => const GoalsTab(),
    'Habits': () => const HabitsTab(),
    'Journal': () => const JournalTab(),
    'Explore': () => const ExploreTab(),
    'Health': () => const HealthScreen(),
    'Food': () => const FoodScreen(),
    'Focus': () => const FocusScreen(),
    'Daily': () => const DailyScreen(),
    'Deen': () => const DeenScreen(),
    'Learn': () => const LearnScreen(),
    'Dates': () => const DatesScreen(),
    'Travel': () => const TravelScreen(),
    'Self care': () => const SelfCareScreen(),
    'Rewards': () => const RewardsScreen(),
    'Report': () => const StatsScreen(),
    'Stuck': () => const StuckScreen(),
    'Launch': () => const LaunchScreen(task: 'Task', firstStep: 'Step'),
  };

  for (final e in screens.entries) {
    testWidgets('${e.key} builds', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      final store = Store('test');
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
