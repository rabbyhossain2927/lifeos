import 'package:flutter/material.dart';
import '../services/store.dart';
import '../widgets/form.dart';
import '../widgets/ui.dart';

const reminderFields = [
  Field('title', 'Reminder', required: true, hint: 'Medicine'),
  Field('note', 'Details', hint: 'Vitamin D · 1 tablet'),
  Field('times', 'Times (24-hour, comma separated)', type: F.times, required: true, hint: '09:00, 21:00'),
  Field('weekdays', 'Weekdays only', type: F.toggle, hint: 'Only Monday to Friday'),
];

Future<void> editReminder(BuildContext context, [Json? r]) async {
  final s = store(context, listen: false);
  final v = await showForm(context, r == null ? 'New reminder' : 'Edit reminder', reminderFields,
      initial: r, onDelete: r == null ? null : () => s.remove('reminders', r['id'] as String));
  if (v == null) return;
  if (r == null) {
    s.add('reminders', {...v, 'on': true});
  } else {
    s.patch('reminders', r['id'] as String, v);
  }
}

const morningDefault = ['Glass of water', 'Fajr prayer', '5-minute stretch', 'Pick one important task'];

class DailyScreen extends StatelessWidget {
  const DailyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final routine = ((s.settings['morning'] as List?) ?? morningDefault).map((e) => '$e').toList();
    final doneList = ((s.day()['morning'] as List?) ?? const []).map((e) => '$e').toSet();
    final habits = s.list('habits');
    final missed = habits.where((h) => s.missedYesterday(h) && !s.habitDone(h)).firstOrNull;
    final stack = habits.where((h) => (h['after'] ?? '').toString().isNotEmpty).toList();
    final reminders = s.list('reminders');

    return SubPage(title: 'Daily', children: [
      Box(
        dark: true,
        padding: const EdgeInsets.all(18),
        child: Col([
          Row(children: [
            const Expanded(child: H2('Morning launch', color: C.white)),
            Text('10 min · ${doneList.length} of ${routine.length}', style: t(12, c: C.darkMuted)),
          ]),
          for (final r in routine)
            Row(children: [
              Tick(
                done: doneList.contains(r),
                darkBg: true,
                size: 22,
                label: r,
                onTap: () {
                  final l = {...doneList};
                  l.contains(r) ? l.remove(r) : l.add(r);
                  s.patchDay({'morning': l.toList()});
                },
              ),
              Expanded(child: doneText(r, doneList.contains(r), dark: true)),
            ]),
          PillButton('Edit routine', height: 46, onTap: () async {
            final v = await showForm(context, 'Morning routine', const [Field('l', 'Steps, one per line', type: F.long)], initial: {'l': routine.join('\n')});
            if (v == null) return;
            s.setSetting('morning', '${v['l']}'.split('\n').map((x) => x.trim()).where((x) => x.isNotEmpty).toList());
          }),
        ], space: 4),
      ),
      if (missed != null)
        Box(
          color: C.limeSoft,
          radius: 24,
          child: Col([
            Text('Never miss twice', style: t(14, w: w6)),
            Text('You skipped ${missed['name']} yesterday. Do the ${(missed['mini'] ?? '').toString().isEmpty ? '5-minute' : '"${missed['mini']}"'} version today?',
                style: t(13, c: C.limeText, h: 1.45)),
            PillButton('Done the small version', bg: C.ink, fg: C.white, height: 40, expand: false, onTap: () => s.toggleHabit(missed)),
          ], space: 8),
        ),
      ListCard(
        title: 'Reminders',
        action: '+ New',
        onAction: () => editReminder(context),
        rows: [
          for (final r in reminders)
            ListRow(
              title: '${r['title']}',
              sub: [if ((r['note'] ?? '').toString().isNotEmpty) '${r['note']}', ((r['times'] as List?) ?? const []).join(', '), if (r['weekdays'] == true) 'weekdays'].join(' · '),
              onTap: () => editReminder(context, r),
              trailing: Toggle(on: r['on'] != false, label: '${r['title']}', onChanged: (v) => s.patch('reminders', r['id'] as String, {'on': v})),
            ),
        ],
        empty: 'Add water, meals, medicine, work start or phone-time reminders.',
      ),
      Box(
        radius: 24,
        child: Col([
          const H2('Habit stack'),
          if (stack.isEmpty) Text('Tie a new habit to one you already do. Edit a habit and fill "do it after".', style: t(13, c: C.muted, h: 1.4)),
          for (final h in stack) Text('After ${h['after']} → ${h['name']}', style: t(15, h: 1.45)),
          Text('Tip: lay out your gym clothes tonight.', style: t(13, c: C.muted)),
        ], space: 6),
      ),
    ]);
  }
}
