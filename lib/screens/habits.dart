import 'package:flutter/material.dart';
import '../services/store.dart';
import '../widgets/form.dart';
import '../widgets/ui.dart';
import 'goals.dart' show dashedButton;
import 'shell.dart';
import 'stats.dart';

const habitFields = [
  Field('name', 'Habit', required: true, hint: 'Drink 8 glasses'),
  Field('after', 'Habit stack: do it after… (optional)', hint: 'I brush my teeth'),
  Field('mini', 'Minimum version for hard days (optional)', hint: '5 push-ups'),
  Field('time', 'Gentle reminder (optional)', type: F.time),
];

Future<void> addHabit(BuildContext context, [Json? h]) async {
  final s = store(context, listen: false);
  final v = await showForm(context, h == null ? 'New habit' : 'Edit habit', habitFields,
      initial: h, save: h == null ? 'Add habit' : 'Save', onDelete: h == null
          ? null
          : () async {
              if (await confirm(context, 'Delete this habit and its history?')) s.remove('habits', h['id'] as String);
            });
  if (v == null) return;
  if (h == null) {
    s.add('habits', {...v, 'logs': <String, dynamic>{}});
  } else {
    s.patch('habits', h['id'] as String, v);
  }
  // A habit with a time also gets a daily reminder.
  final time = (v['time'] ?? '').toString();
  final rid = 'habit_${h?['id'] ?? v['name']}';
  if (time.isNotEmpty) {
    s.save('reminders', {'id': rid.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_'), 'title': '${v['name']}', 'note': 'Habit reminder', 'times': [time], 'on': true});
  }
}

class HabitsTab extends StatefulWidget {
  const HabitsTab({super.key});
  @override
  State<HabitsTab> createState() => _HabitsTabState();
}

class _HabitsTabState extends State<HabitsTab> {
  String day = todayKey;

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final habits = s.list('habits');
    final ws = weekStart;
    final now = DateTime.now();
    final weekNo = ((now.difference(DateTime(now.year)).inDays + DateTime(now.year).weekday - 1) / 7).floor() + 1;
    final end = ws.add(const Duration(days: 6));
    return TabBody(children: [
      TabHeader(
        small: 'Week $weekNo · ${ws.day}–${end.day} ${months[end.month - 1]}',
        title: 'Habits',
        trailing: GestureDetector(
          onTap: () => push(context, const StatsScreen()),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${(s.weekScore() * 100).round()}%', style: t(24, w: w6)),
            Text('weekly score', style: t(12, c: C.muted)),
          ]),
        ),
      ),
      Row(children: gap([
        for (var i = 0; i < 7; i++)
          Expanded(child: _dayChip(ws.add(Duration(days: i)))),
      ], 6)),
      if (habits.isEmpty) Box(child: Text('No habits yet. Add one below.', style: t(14, c: C.muted))),
      if (habits.isNotEmpty)
        Box(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Column(children: [
            for (var i = 0; i < habits.length; i++) _habitRow(s, habits[i], ws, i == habits.length - 1),
          ]),
        ),
      dashedButton('+ New habit', () => addHabit(context)),
    ]);
  }

  Widget _dayChip(DateTime d) {
    final k = dayKey(d);
    final on = k == day;
    final future = d.isAfter(DateTime.now());
    return GestureDetector(
      onTap: future ? null : () => setState(() => day = k),
      child: Container(
        height: 56,
        decoration: BoxDecoration(color: on ? C.ink : C.white, borderRadius: BorderRadius.circular(14)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1], style: t(11, w: w5, c: on ? C.white : C.ink)),
          Text('${d.day}', style: t(16, w: w6, c: on ? C.white : (future ? C.muted : C.ink))),
        ]),
      ),
    );
  }

  Widget _habitRow(Store s, Json h, DateTime ws, bool last) {
    final done = s.habitDone(h, day);
    final st = s.streak(h);
    final sub = st > 0 ? '$st day streak' : (s.missedYesterday(h) ? 'Missed yesterday' : 'Start today');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: C.line))),
      child: Col([
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => addHabit(context, h),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${h['name']}', style: t(15, w: w5)),
                const SizedBox(height: 2),
                Text(sub, style: t(12, c: C.muted)),
              ]),
            ),
          ),
          Semantics(
            button: true,
            checked: done,
            label: 'Mark ${h['name']} done',
            child: GestureDetector(
              onTap: () => s.toggleHabit(h, day),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? C.ink : C.white,
                  border: done ? null : Border.all(color: C.border, width: 1.5),
                ),
                child: Icon(Icons.check_rounded, size: 20, color: done ? C.lime : C.darkFaint),
              ),
            ),
          ),
        ]),
        Row(children: gap([
          for (var i = 0; i < 7; i++) Expanded(child: _cell(s, h, ws.add(Duration(days: i)))),
        ], 6)),
      ], space: 10),
    );
  }

  Widget _cell(Store s, Json h, DateTime d) {
    final future = d.isAfter(DateTime.now());
    final done = s.habitDone(h, dayKey(d));
    return Container(
      height: 22,
      decoration: BoxDecoration(
        color: future ? C.white : (done ? C.lime2 : const Color(0xFFE3E3DD)),
        borderRadius: BorderRadius.circular(6),
        border: future ? Border.all(color: const Color(0xFFDAD8D4), width: 1.5) : null,
      ),
    );
  }
}
