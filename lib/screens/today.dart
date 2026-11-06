import 'package:flutter/material.dart';
import '../services/prayer.dart';
import '../services/store.dart';
import '../widgets/ui.dart';
import 'goal_detail.dart';
import 'goals.dart';
import 'profile.dart';
import 'shell.dart';
import 'stuck.dart';

class TodayTab extends StatefulWidget {
  final ValueChanged<int> onTab;
  const TodayTab({super.key, required this.onTab});
  @override
  State<TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<TodayTab> {
  String chip = 'Goals';

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final name = (s.settings['name'] ?? '').toString();
    final goals = s.todayGoals;
    final habits = s.list('habits');
    final total = s.todayTotal, done = s.todayDone;
    final d = s.day();
    final loc = s.settings['city'] is List ? (s.settings['city'] as List).cast<num>() : const [23.8103, 90.4125];
    final next = PrayerTimes.next(loc[0].toDouble(), loc[1].toDouble());
    final dueSoon = s.list('dates').where((x) {
      final dt = DateTime.tryParse('${x['date'] ?? ''}');
      if (dt == null) return false;
      final now = DateTime.now();
      var n = DateTime(now.year, dt.month, dt.day);
      if (n.isBefore(DateTime(now.year, now.month, now.day))) n = DateTime(now.year + 1, dt.month, dt.day);
      return n.difference(now).inDays <= 7;
    }).toList();

    return TabBody(children: [
      Row(children: [
        GestureDetector(
          onTap: () => push(context, const ProfileScreen()),
          child: Semantics(
            button: true,
            label: 'Profile',
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: C.white, shape: BoxShape.circle),
              child: Text(name.isEmpty ? 'L' : name[0].toUpperCase(), style: t(16, w: w6)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_greeting, style: t(15, w: w6)),
            Text(niceDate(DateTime.now()), style: t(13, c: C.muted)),
          ]),
        ),
        RoundBtn(icon: Icons.notifications_none_rounded, label: 'Next prayer', onTap: () => toast(context, 'Next: ${next.key} at ${hmA(next.value)}')),
      ]),
      Text.rich(TextSpan(children: [
        TextSpan(text: "Let's make today\n", style: t(32, ls: -0.6, h: 1.15)),
        TextSpan(text: 'count', style: t(32, w: w6, ls: -0.6, h: 1.15)),
      ])),
      // Progress card
      Box(
        dark: true,
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Today's progress", style: t(14, w: w5, c: C.white)),
              const SizedBox(height: 12),
              Ring(
                value: total == 0 ? 0 : done / total,
                center: Text('${total == 0 ? 0 : (done * 100 / total).round()}%', style: t(22, w: w6, c: C.white)),
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.only(left: 20),
            decoration: const BoxDecoration(border: Border(left: BorderSide(color: C.dark3))),
            child: Col([
              _stat('$total', "Today's items"),
              _stat('$done', 'Done'),
              _stat('${s.dayStreak}', 'Day streak'),
            ], space: 14),
          ),
        ]),
      ),
      // Check-in: mood + energy
      Box(
        child: Col([
          Row(children: [
            const Expanded(child: H2('How are you?')),
            SmallPill("I'm stuck", bg: C.ink, fg: C.white, onTap: () => push(context, const StuckScreen())),
          ]),
          ChoiceRow(options: moods, selected: d['mood'] as String?, onPick: (m) => s.patchDay({'mood': m})),
          ChoiceRow(
            options: const ['Low energy', 'Medium energy', 'High energy'],
            selected: d['energy'] == null ? null : '${d['energy']} energy',
            dark: true,
            onPick: (e) => s.patchDay({'energy': e.split(' ').first}),
          ),
          if (d['energy'] == 'Low') Text('Low energy day: do the easy goals first. Small wins count.', style: t(13, c: C.muted, h: 1.4)),
        ], space: 10),
      ),
      Row(children: [
        const Expanded(child: H2('Today', size: 18)),
        GestureDetector(onTap: () => widget.onTab(chip == 'Habits' ? 2 : 1), child: Padding(padding: const EdgeInsets.all(8), child: Text('View all', style: t(13, w: w5)))),
      ]),
      Row(children: [
        _chip('Goals', goals.length),
        const SizedBox(width: 8),
        _chip('Habits', habits.length),
        const SizedBox(width: 8),
        _chip('Due', dueSoon.length),
      ]),
      if (chip == 'Goals') ...[
        if (goals.isEmpty) _empty('No goals yet. Tap + to add your first big goal.', () => addGoal(context)),
        for (final g in goals)
          _row(
            title: goalStepLabel(s, g),
            sub: '${g['title']}',
            done: s.goalDoneToday(g),
            onTick: () => s.toggleGoalToday(g),
            onTap: () => push(context, GoalDetailScreen(id: g['id'] as String)),
          ),
      ],
      if (chip == 'Habits') ...[
        if (habits.isEmpty) _empty('No habits yet.', null),
        for (final h in habits)
          _row(title: '${h['name']}', sub: '${s.streak(h)} day streak', done: s.habitDone(h), onTick: () => s.toggleHabit(h)),
      ],
      if (chip == 'Due') ...[
        if (dueSoon.isEmpty) _empty('Nothing due in the next 7 days.', null),
        for (final x in dueSoon) _row(title: '${x['title']}', sub: '${x['kind'] ?? 'Date'} · ${shortDate(DateTime.parse('${x['date']}'))}', done: false, onTick: null),
      ],
    ]);
  }

  Widget _stat(String n, String label) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(n, style: t(18, w: w6, c: C.white)), Text(label, style: t(12, c: C.darkMuted))]);

  Widget _chip(String name, int count) {
    final on = chip == name;
    return GestureDetector(
      onTap: () => setState(() => chip = name),
      child: Container(
        height: 44,
        padding: const EdgeInsets.only(left: 6, right: 16),
        decoration: BoxDecoration(
          color: on ? C.lime : C.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? C.ink : C.white, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: on ? C.white : C.chip),
            child: Text('$count', style: t(14, w: w6)),
          ),
          const SizedBox(width: 8),
          Text(name, style: t(14, w: w5)),
        ]),
      ),
    );
  }

  Widget _row({required String title, required String sub, required bool done, VoidCallback? onTick, VoidCallback? onTap}) {
    return Box(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
      onTap: onTap,
      child: Row(children: [
        if (onTick != null) Tick(done: done, onTap: onTick, label: 'Mark $title done') else const SizedBox(width: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              doneText(title, done),
              const SizedBox(height: 2),
              Text(sub, style: t(12, c: C.muted)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _empty(String text, VoidCallback? onTap) => Box(
        radius: 24,
        onTap: onTap,
        child: Text(text, style: t(14, c: C.muted)),
      );
}

const moods = ['Low', 'Meh', 'Okay', 'Good', 'Great'];

/// "Read 15 pages" from a goal: today's small step.
String goalStepLabel(Store s, Json g) {
  final step = (g['step'] ?? '').toString();
  if (step.isNotEmpty) return step;
  final day = s.goalTargets(g)['day']!;
  final unit = (g['unit'] ?? '').toString();
  if (g['type'] == 'yesno') return '${g['title']}';
  return '${numText(day)}${unit.isEmpty ? '' : ' $unit'} today';
}

