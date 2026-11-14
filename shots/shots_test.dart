// Renders the main screens to PNG files (shots/out) so the design can be checked
// without a phone. CI: flutter test shots/shots_test.dart --update-goldens
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lifeos/services/local.dart';
import 'package:lifeos/services/store.dart';
import 'package:lifeos/screens/home.dart';
import 'package:lifeos/screens/goals.dart';
import 'package:lifeos/screens/goal_detail.dart';
import 'package:lifeos/screens/explore.dart';
import 'package:lifeos/screens/account.dart';
import 'package:lifeos/screens/tools.dart';
import 'package:lifeos/widgets/ui.dart';

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(Future.value(ByteData.view(File(f).readAsBytesSync().buffer)));
  }
  await l.load();
}

Store seeded() {
  final s = Store('shots');
  final now = DateTime.now();
  String d(int ago) => dayKey(now.subtract(Duration(days: ago)));
  Map<String, dynamic> logs(int days, [int skip = 99]) => {for (var i = 0; i < days; i++) if (i != skip) d(i): true};
  s.setSetting('name', 'Rabby Hossain');
  s.setSetting('seeded', true);
  for (final h in [('Wake before Fajr', logs(12)), ('Read Quran', logs(5)), ('Walk 20 min', logs(8, 0)), ('No phone after 11 PM', logs(3, 0))]) {
    s.add('habits', {'name': h.$1, 'logs': h.$2});
  }
  s.save('goals', {'id': 'g1', 'title': 'Read 24 books', 'area': 'Learn', 'target': 24, 'unit': 'books', 'logUnit': 'pages', 'perUnit': 300, 'step': 'Read 20 pages', 'why': 'I want to think deeper and be someone my family learns from.', 'logs': {d(60): 18.0, d(3): 1.2, d(1): 0.2, d(0): 0.05}, 'steps': [{'t': 'Pick the next 2 books', 'min': '5 min', 'done': true}, {'t': 'Read 20 pages after Isha', 'min': '25 min', 'done': false}]});
  s.save('goals', {'id': 'g2', 'title': 'Lose 8 kg', 'area': 'Health', 'target': 8, 'unit': 'kg', 'step': 'Walk 8,000 steps', 'logs': {d(40): 4.0}, 'steps': []});
  for (var i = 0; i < 7; i++) {
    s.patchDay({'water': [6, 8, 5, 7, 6, 7, 5][i], 'mood': ['Okay', 'Good', 'Low', 'Good', 'Good', 'Great', 'Good'][i], 'sleepH': [6.5, 7, 5.8, 7.4, 6.9, 8, 7.2][i], 'steps': 6420, 'prayed': i == 6 ? ['Fajr', 'Dhuhr'] : ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']}, d(6 - i));
  }
  for (final f in [('Paratha + egg', 'Breakfast', 380), ('Rice, dal, fish', 'Lunch', 620), ('Tea', 'Snack', 40)]) {
    s.add('food', {'day': d(0), 'meal': f.$2, 'name': f.$1, 'size': '1', 'kcal': f.$3});
  }
  s.add('focus', {'day': d(0), 'mins': 25, 'label': 'Work'});
  s.add('dates', {'title': "Mom's birthday", 'date': dayKey(now.add(const Duration(days: 3))), 'kind': 'Birthday', 'yearly': true});
  s.add('trips', {'place': "Cox's Bazar", 'from': dayKey(now.add(const Duration(days: 28))), 'to': dayKey(now.add(const Duration(days: 31))), 'packing': [{'name': 'Passport / NID', 'done': true}, {'name': 'Charger', 'done': false}], 'plan': {'d1': ['Bus from Dhaka · 7 AM', 'Sunset at the beach']}});
  s.add('courses', {'name': 'Arabic basics', 'total': 30, 'done': 12, 'logs': {d(1): 1, d(2): 1}});
  s.add('reminders', {'title': 'Take vitamins', 'times': ['09:00'], 'on': true});
  s.add('reminders', {'title': 'Call Mom', 'times': ['20:00'], 'on': true});
  s.add('care', {'name': 'Cleanser', 'time': 'pm', 'logs': {d(0): true}});
  s.add('care', {'name': 'Moisturizer', 'time': 'pm', 'logs': {}});
  s.add('moments', {'title': 'First trip to Sajek', 'note': 'With Rafi and Tanim', 'date': '${now.year - 1}-${dayKey(now).substring(5)}'});
  s.setSetting('license', {'key': 'LIFE-AB12-CD34-7Q2K'});
  s.setSetting('pins', ['prayer', 'focus', 'journal']);
  return s;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({}); // ignore: invalid_use_of_visible_for_testing_member
    await Local.init();
    await _font('Geist', [for (final w in ['Regular', 'Medium', 'SemiBold', 'Light']) 'assets/fonts/Geist-$w.ttf']);
    final root = Platform.environment['FLUTTER_ROOT'] ?? '';
    await _font('MaterialIcons', ['$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  });

  final screens = <String, Widget Function()>{
    '01-home': () => Container(decoration: const BoxDecoration(gradient: bgGradient), child: HomeTab(onTab: (_) {})),
    '02-goals': () => Container(decoration: const BoxDecoration(gradient: bgGradient), child: const GoalsTab()),
    '03-goal-detail': () => const GoalDetail(id: 'g1'),
    '04-new-goal': () => const AddGoalPage(),
    '05-review': () => const ReviewPage(),
    '06-explore': () => Container(decoration: const BoxDecoration(gradient: bgGradient), child: const ExploreTab()),
    '07-account': () => Container(decoration: const BoxDecoration(gradient: bgGradient), child: const AccountTab()),
    for (var i = 0; i < tools.length; i++) '${(10 + i)}-${tools[i].key}': tools[i].page,
  };

  for (final e in screens.entries) {
    testWidgets(e.key, (tester) async {
      tester.view.physicalSize = const Size(780, 3400);
      tester.view.devicePixelRatio = 2;
      final s = seeded();
      await tester.pumpWidget(ChangeNotifierProvider<Store>.value(
        value: s,
        child: MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData(fontFamily: 'Geist', useMaterial3: true), home: Scaffold(backgroundColor: const Color(0xFFF1EEF4), body: SafeArea(child: e.value()))),
      ));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/${e.key}.png'));
      s.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  }
}
