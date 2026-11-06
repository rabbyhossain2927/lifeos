import 'package:flutter/material.dart';
import '../services/store.dart';
import '../widgets/ui.dart';
import 'goals.dart' show areas;

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final ws = weekStart;
    final now = DateTime.now();
    final end = ws.add(const Duration(days: 6));
    final score = s.weekScore(), last = s.weekScore(1);
    final diff = ((score - last) * 100).round();
    final days = [for (var i = 0; i < 7; i++) ws.add(Duration(days: i)).isAfter(now) ? -1.0 : s.dayScore(dayKey(ws.add(Duration(days: i))))];
    final habits = s.list('habits')..sort((a, b) => s.streak(b).compareTo(s.streak(a)));
    // Life balance: share of each area's goals done this week.
    final goals = s.list('goals');
    final balance = <String, double>{};
    for (final a in areas) {
      final gs = goals.where((g) => g['area'] == a).toList();
      if (gs.isEmpty) continue;
      balance[a] = gs.map((g) => (s.goalProgress(g)['week']! / s.goalTargets(g)['week']!).clamp(0.0, 1.0).toDouble()).reduce((x, y) => x + y) / gs.length;
    }
    final pattern = _pattern(s);
    final busy = _burnout(s);

    return SubPage(
      title: 'Weekly report',
      trailing: Text('${ws.day}–${end.day} ${months[end.month - 1]}', textAlign: TextAlign.right, style: t(12, c: C.muted), maxLines: 1, softWrap: false, overflow: TextOverflow.visible),
      children: [
        Box(
          dark: true,
          padding: const EdgeInsets.all(20),
          child: Col([
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Weekly score', style: t(13, c: C.darkMuted)),
                  Text('${(score * 100).round()}%', style: t(44, w: w6, c: C.white, ls: -1.2)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(diff == 0 ? 'Same as last week' : '${diff > 0 ? 'Up' : 'Down'} ${diff.abs()}% from last week', style: t(13, w: w6, c: C.lime)),
              ),
            ]),
            Bars(values: days, labels: weekLetters),
          ], space: 14),
        ),
        Box(
          child: Col([
            const H2('Life balance'),
            if (balance.isEmpty) Text('Give your goals a life area to see your balance.', style: t(13, c: C.muted)),
            for (final e in balance.entries)
              Row(children: [
                SizedBox(width: 64, child: Text(e.key, style: t(13, w: w5))),
                const SizedBox(width: 10),
                Expanded(child: Bar(e.value)),
                SizedBox(width: 44, child: Text('${(e.value * 100).round()}%', textAlign: TextAlign.right, style: t(13, c: C.muted))),
              ]),
          ]),
        ),
        Box(
          child: Col([
            const H2('Top streaks'),
            if (habits.isEmpty) Text('Tick habits to build streaks.', style: t(13, c: C.muted)),
            for (final h in habits.take(3))
              Row(children: [
                Expanded(child: Text('${h['name']}', style: t(15))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: C.lime, borderRadius: BorderRadius.circular(999)),
                  child: Text('${s.streak(h)} days', style: t(13, w: w6)),
                ),
              ]),
          ], space: 10),
        ),
        if (pattern != null)
          Box(
            child: Col([
              const H2('Pattern found'),
              Text(pattern, style: t(15, h: 1.45)),
            ], space: 10),
          ),
        if (busy != null)
          Box(
            child: Col([
              const H2('Burnout guard', color: C.warn),
              Text(busy, style: t(15, h: 1.45)),
            ], space: 6),
          ),
        PillButton('Start Sunday reset', height: 56, onTap: () => push(context, const ResetScreen())),
      ],
    );
  }

  /// The weekday you finish the least, if it clearly stands out.
  static String? _pattern(Store s) {
    final sums = List<double>.filled(7, 0), counts = List<int>.filled(7, 0);
    final now = DateTime.now();
    for (var i = 1; i <= 56; i++) {
      final d = now.subtract(Duration(days: i));
      sums[d.weekday - 1] += s.dayScore(dayKey(d));
      counts[d.weekday - 1]++;
    }
    final avg = [for (var i = 0; i < 7; i++) counts[i] == 0 ? 0.0 : sums[i] / counts[i]];
    final overall = avg.reduce((a, b) => a + b) / 7;
    if (overall < 0.05) return null;
    var worst = 0;
    for (var i = 1; i < 7; i++) {
      if (avg[i] < avg[worst]) worst = i;
    }
    if (avg[worst] > overall * 0.75) return null;
    var best = 0;
    for (var i = 1; i < 7; i++) {
      if (avg[i] > avg[best]) best = i;
    }
    return 'You finish the least on ${weekdaysLong[worst]}s. Plan lighter goals then, and move hard tasks to ${weekdaysLong[best]}.';
  }

  static String? _burnout(Store s) {
    final now = DateTime.now();
    var busy = 0;
    for (var i = 0; i < 7; i++) {
      final d = s.day(dayKey(now.subtract(Duration(days: i))));
      if (d['energy'] == 'Low' || (d['sleepH'] is num && (d['sleepH'] as num) < 6)) busy++;
    }
    if (busy < 3) return null;
    return '$busy tired days this week. Make tomorrow a light day: only the easy goals, and sleep early.';
  }
}

/// Sunday reset: what worked, what didn't, one focus for next week.
class ResetScreen extends StatefulWidget {
  const ResetScreen({super.key});
  @override
  State<ResetScreen> createState() => _ResetScreenState();
}

class _ResetScreenState extends State<ResetScreen> {
  final worked = TextEditingController(), didnt = TextEditingController(), focus = TextEditingController();

  @override
  void dispose() {
    worked.dispose();
    didnt.dispose();
    focus.dispose();
    super.dispose();
  }

  Widget _q(String label, TextEditingController c) => Box(
        child: Col([
          H2(label),
          TextField(
            controller: c,
            minLines: 2,
            maxLines: 5,
            style: t(15, h: 1.45),
            decoration: InputDecoration(filled: true, fillColor: C.chip, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
          ),
        ], space: 10),
      );

  @override
  Widget build(BuildContext context) {
    final s = store(context, listen: false);
    return SubPage(title: 'Sunday reset', children: [
      Text('Five quiet minutes to close the week.', style: t(15, c: C.muted)),
      _q('What worked this week?', worked),
      _q("What didn't?", didnt),
      _q('One focus for next week', focus),
      PillButton('Save reset', bg: C.ink, fg: C.white, onTap: () {
        s.patchDay({'reset': {'worked': worked.text, 'didnt': didnt.text, 'focus': focus.text}});
        if (focus.text.trim().isNotEmpty) s.setSetting('weekFocus', focus.text.trim());
        Navigator.pop(context);
        toast(context, 'Week closed. Have a good one!');
      }),
    ]);
  }
}
