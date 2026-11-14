import 'package:flutter/material.dart';
import '../services/license_service.dart';
import '../services/life.dart';
import '../services/store.dart';
import '../widgets/kit.dart';
import '../widgets/ui.dart';
import 'account.dart';
import 'tools_daily.dart';
import 'tools_grow.dart';
import 'tools_life.dart';

/// One Explore tool.
class Tool {
  final String key, name, group, subtitle;
  final IconData icon;
  final String Function(Store s) status;
  final Widget Function() page;
  final String? pro; // License.proFeatures key
  const Tool(this.key, this.name, this.group, this.subtitle, this.icon, this.status, this.page, {this.pro});
  (Color, Color) get colors => groupColors[group]!;
}

const groupColors = {
  'Daily': (C.lime, C.ink),
  'Grow': (Color(0xFFEFEDFF), Color(0xFF4A3FB0)),
  'Life': (Color(0xFFFBEBEB), Color(0xFFA33A3A)),
};

String _plural(int n, String w) => '$n $w${n == 1 ? '' : 's'}';

/// Next yearly (or one-time) occurrence of a date, with days left.
List<(Json, DateTime, int)> upcomingDates(Store s) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final out = <(Json, DateTime, int)>[];
  for (final d in s.list('dates')) {
    final date = DateTime.tryParse('${d['date'] ?? ''}');
    if (date == null) continue;
    var next = DateTime(d['yearly'] == false ? date.year : today.year, date.month, date.day);
    if (next.isBefore(today) && d['yearly'] != false) next = DateTime(today.year + 1, date.month, date.day);
    if (next.isBefore(today)) continue;
    out.add((d, next, next.difference(today).inDays));
  }
  out.sort((a, b) => a.$3.compareTo(b.$3));
  return out;
}

Json? nextTrip(Store s) {
  final t = todayKey;
  final l = s.list('trips').where((x) => '${x['to'] ?? x['from'] ?? ''}'.compareTo(t) >= 0).toList()
    ..sort((a, b) => '${a['from']}'.compareTo('${b['from']}'));
  return l.isEmpty ? null : l.first;
}

int journalStreak(Store s) {
  var d = DateTime.now();
  bool wrote(DateTime x) => '${s.day(dayKey(x))['text'] ?? ''}'.trim().isNotEmpty;
  if (!wrote(d)) d = d.subtract(const Duration(days: 1));
  var n = 0;
  while (wrote(d) && n < 3650) {
    n++;
    d = d.subtract(const Duration(days: 1));
  }
  return n;
}

String inDays(int n) => n == 0 ? 'today' : n == 1 ? 'tomorrow' : 'in $n days';

final tools = <Tool>[
  Tool('prayer', 'Prayer', 'Daily', 'Five prayers, on time', Icons.mosque_outlined, (s) {
    final n = s.nextPrayer;
    return 'Next: ${n.key} ${hmA(n.value)}';
  }, () => const PrayerPage()),
  Tool('habits', 'Habits', 'Daily', 'Small things, every day', Icons.check_rounded, (s) => '${s.habitsDoneToday} of ${s.list('habits').length} done', () => const HabitsPage()),
  Tool('water', 'Water', 'Daily', 'Sip through the day', Icons.water_drop_outlined, (s) => '${s.waterOn()} of ${s.waterGoal} glasses', () => const WaterPage()),
  Tool('food', 'Food', 'Daily', 'Tap what you ate', Icons.restaurant_outlined, (s) => '${s.kcalOn(todayKey)} kcal today', () => const FoodPage()),
  Tool('sleep', 'Sleep', 'Daily', 'Rest well, wake for Fajr', Icons.bedtime_outlined, (s) {
    final h = s.sleepOn(todayKey);
    return h > 0 ? '${h.floor()}h ${((h % 1) * 60).round()}m last night' : 'Tap to log';
  }, () => const SleepPage()),
  Tool('mood', 'Mood', 'Daily', 'How is your heart today?', Icons.sentiment_satisfied_outlined, (s) => s.moodToday ?? 'How are you?', () => const MoodPage()),
  Tool('health', 'Health', 'Daily', 'Steps, weight, workouts', Icons.monitor_heart_outlined, (s) => '${s.stepsOn()} steps', () => const HealthPage()),
  Tool('reminders', 'Reminders', 'Daily', 'Never forget the small stuff', Icons.notifications_none_rounded, (s) => '${s.list('reminders').where((r) => r['on'] != false).length} on', () => const RemindersPage()),
  Tool('journal', 'Journal', 'Grow', 'Three lines a day', Icons.menu_book_outlined, (s) {
    final n = journalStreak(s);
    return n == 0 ? 'Write 3 lines' : '$n day streak';
  }, () => const JournalPage()),
  Tool('focus', 'Focus', 'Grow', 'One thing at a time', Icons.timer_outlined, (s) => '${s.focusOn(todayKey)} min today', () => const FocusPage()),
  Tool('learn', 'Learn', 'Grow', 'A little every day', Icons.school_outlined, (s) {
    final n = s.list('courses').length + s.list('books').where((b) => b['done'] != true).length;
    return n == 0 ? 'Start something' : _plural(n, 'thing') + ' going';
  }, () => const LearnPage()),
  Tool('rewards', 'Rewards', 'Grow', 'You earned these', Icons.emoji_events_outlined, (s) => '${s.points} points', () => const RewardsPage(), pro: 'rewards'),
  Tool('dates', 'Dates', 'Life', 'Birthdays and big days', Icons.event_outlined, (s) {
    final u = upcomingDates(s);
    return u.isEmpty ? 'Add a birthday' : '${u.first.$1['title']} ${inDays(u.first.$3)}';
  }, () => const DatesPage()),
  Tool('travel', 'Travel', 'Life', 'Trips, plans, packing', Icons.flight_takeoff_rounded, (s) {
    final tr = nextTrip(s);
    final d = DateTime.tryParse('${tr?['from'] ?? ''}');
    return tr == null ? 'Plan a trip' : '${tr['place']}${d == null ? '' : ' · ${shortDate(d)}'}';
  }, () => const TravelPage(), pro: 'travel'),
  Tool('selfcare', 'Self care', 'Life', 'Look after you', Icons.favorite_border_rounded, (s) {
    final pm = DateTime.now().hour >= 15;
    final l = s.list('care').where((c) => c['time'] == (pm ? 'pm' : 'am')).toList();
    return '${l.where((c) => (c['logs'] as Map? ?? {})[todayKey] == true).length} of ${l.length} ${pm ? 'tonight' : 'this morning'}';
  }, () => const SelfCarePage()),
  Tool('memory', 'Memory', 'Life', 'Keep the good days', Icons.auto_awesome_outlined, (s) => _plural(s.list('moments').length, 'memory').replaceAll('memorys', 'memories'), () => const MemoryPage(), pro: 'memory'),
];

Tool toolOf(String key) => tools.firstWhere((x) => x.key == key);

/// Opens a tool page (or the Pro screen for locked ones).
void openTool(BuildContext context, String key) {
  final tool = toolOf(key);
  final s = store(context, listen: false);
  if (tool.pro != null && !License.unlocked(s, tool.pro!)) {
    push(context, ProLocked(tool: tool));
    return;
  }
  push(context, tool.page());
}

class ProLocked extends StatelessWidget {
  final Tool tool;
  const ProLocked({super.key, required this.tool});
  @override
  Widget build(BuildContext context) {
    final s = store(context);
    if (License.unlocked(s, tool.pro!)) return tool.page();
    return ToolPage(title: tool.name, subtitle: tool.subtitle, icon: tool.icon, colors: tool.colors, children: [
      HeroCard(label: 'LifeOS Pro', big: '${tool.name} is a Pro tool', sub: '${License.proFeatures[tool.pro]}. One key unlocks every Pro tool on your phones.'),
      Panel(
        title: 'Pro unlocks',
        child: Col([for (final f in License.proFeatures.values) Row(children: [const Icon(Icons.check_rounded, size: 18), const SizedBox(width: 8), Expanded(child: Text(f, style: t(14)))])], space: 8),
      ),
      PressPill('Unlock with a key', onTap: () => licenseSheet(context)),
    ]);
  }
}

/// Shared tool page frame.
class ToolFrame extends StatelessWidget {
  final String keyName;
  final List<Widget> children;
  final Widget? trailing;
  const ToolFrame(this.keyName, {super.key, required this.children, this.trailing});
  @override
  Widget build(BuildContext context) {
    final tool = toolOf(keyName);
    return ToolPage(title: tool.name, subtitle: tool.subtitle, icon: tool.icon, colors: tool.colors, trailing: trailing, children: children);
  }
}
