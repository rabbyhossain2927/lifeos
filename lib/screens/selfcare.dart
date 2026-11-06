import 'package:flutter/material.dart';
import '../services/store.dart';
import '../widgets/form.dart';
import '../widgets/ui.dart';

class SelfCareScreen extends StatefulWidget {
  const SelfCareScreen({super.key});
  @override
  State<SelfCareScreen> createState() => _SelfCareScreenState();
}

class _SelfCareScreenState extends State<SelfCareScreen> {
  String tab = DateTime.now().hour < 15 ? 'Morning' : 'Night';

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final key = tab == 'Morning' ? 'am' : 'pm';
    final steps = s.list('care').where((c) => c['time'] == key).toList();
    final visits = s.list('visits')..sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));
    final next = DateTime.tryParse('${s.settings['haircutNext'] ?? ''}');
    final every = ((s.settings['haircutWeeks'] ?? 4) as num).toInt();
    final daysLeft = next?.difference(DateTime.now()).inDays;
    final cycleOn = s.settings['cycleOn'] == true;
    final cycleStart = DateTime.tryParse('${s.settings['cycleStart'] ?? ''}');
    final cycleLen = ((s.settings['cycleLen'] ?? 28) as num).toInt();
    DateTime? cycleNext;
    if (cycleOn && cycleStart != null) {
      cycleNext = cycleStart;
      while (cycleNext!.isBefore(DateTime.now())) {
        cycleNext = cycleNext.add(Duration(days: cycleLen));
      }
    }

    return SubPage(title: 'Self care', children: [
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(999)),
        child: Row(children: [
          for (final o in const ['Morning', 'Night'])
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => tab = o),
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: tab == o ? C.ink : Colors.transparent, borderRadius: BorderRadius.circular(999)),
                  child: Text(o, style: t(14, w: w6, c: tab == o ? C.white : C.muted)),
                ),
              ),
            ),
        ]),
      ),
      Box(
        child: Col([
          CardHead('Skin and hair', action: '+ Step', onAction: () => _edit(context, s, key)),
          if (steps.isEmpty) Text('Add the steps of your $tab routine.', style: t(13, c: C.muted)),
          for (final c in steps)
            Row(children: [
              Tick(done: s.habitDone(c), label: '${c['name']}', size: 22, onTap: () {
                final logs = Map<String, dynamic>.from(c['logs'] as Map? ?? {});
                if (logs[todayKey] == true) {
                  logs.remove(todayKey);
                } else {
                  logs[todayKey] = true;
                }
                s.patch('care', c['id'] as String, {'logs': logs});
              }),
              Expanded(child: GestureDetector(onLongPress: () => _edit(context, s, key, c), child: Text('${c['name']}', style: t(15)))),
              if ((c['note'] ?? '').toString().isNotEmpty) Text('${c['note']}', style: t(12, c: C.muted)),
            ]),
        ], space: 2),
      ),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Box(
            dark: true,
            radius: 24,
            onTap: () async {
              final v = await showForm(context, 'Haircut', const [
                Field('last', 'Last haircut', type: F.date),
                Field('weeks', 'Every how many weeks', type: F.number, hint: '4'),
              ], initial: {'weeks': every});
              if (v == null) return;
              final w = (v['weeks'] as num?)?.toInt() ?? every;
              s.setSetting('haircutWeeks', w);
              final last = DateTime.tryParse('${v['last'] ?? ''}');
              if (last != null) s.setSetting('haircutNext', dayKey(last.add(Duration(days: w * 7))));
            },
            child: Col([
              Text('Next haircut', style: t(13, c: C.darkMuted)),
              Text(daysLeft == null ? 'Set up' : (daysLeft <= 0 ? 'Due now' : '$daysLeft days'), style: t(24, w: w6, c: C.white)),
              Text('Every $every weeks', style: t(12, c: C.lime)),
            ], space: 4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Box(
            radius: 24,
            onTap: () async {
              final v = await showForm(context, 'Cycle tracker', const [
                Field('on', 'Turn on', type: F.toggle, hint: 'Track a cycle'),
                Field('start', 'Last start date', type: F.date),
                Field('len', 'Cycle length (days)', type: F.number, hint: '28'),
              ], initial: {'on': cycleOn, 'start': s.settings['cycleStart'], 'len': cycleLen});
              if (v == null) return;
              s.setSetting('cycleOn', v['on'] == true);
              if (v['start'] != null) s.setSetting('cycleStart', v['start']);
              if (v['len'] is num) s.setSetting('cycleLen', v['len']);
            },
            child: Col([
              Text('Cycle tracker', style: t(13, c: C.muted)),
              Text(!cycleOn ? 'Off' : (cycleNext == null ? 'Set start' : shortDate(cycleNext)), style: t(18, w: w6)),
              Text(cycleOn ? 'Next expected' : 'Turn on if needed', style: t(12, c: C.muted)),
            ], space: 4),
          ),
        ),
      ]),
      ListCard(
        title: 'Doctor visits',
        action: '+ Add note',
        onAction: () => _visit(context, s),
        rows: [
          for (final v in visits)
            ListRow(title: '${v['title']}', sub: [if (DateTime.tryParse('${v['date']}') != null) shortDate(DateTime.parse('${v['date']}')), '${v['note'] ?? ''}'].where((x) => x.isNotEmpty).join(' · '), onTap: () => _visit(context, s, v)),
        ],
        empty: 'Keep short notes after each doctor visit.',
      ),
    ]);
  }

  static Future<void> _edit(BuildContext context, Store s, String time, [Json? c]) async {
    final v = await showForm(context, c == null ? 'New step' : 'Edit step', const [
      Field('name', 'Step', required: true, hint: 'Sunscreen'),
      Field('note', 'Note', hint: 'SPF 50, Fri only…'),
    ], initial: c, onDelete: c == null ? null : () => s.remove('care', c['id'] as String));
    if (v == null) return;
    if (c == null) {
      s.add('care', {...v, 'time': time, 'logs': <String, dynamic>{}});
    } else {
      s.patch('care', c['id'] as String, v);
    }
  }

  static Future<void> _visit(BuildContext context, Store s, [Json? x]) async {
    final v = await showForm(context, x == null ? 'Doctor visit' : 'Edit visit', const [
      Field('title', 'Doctor or clinic', required: true, hint: 'Dentist'),
      Field('date', 'Date', type: F.date),
      Field('note', 'Notes', type: F.long, hint: 'What they said, next check'),
    ], initial: x ?? {'date': todayKey}, onDelete: x == null ? null : () => s.remove('visits', x['id'] as String));
    if (v == null) return;
    if (x == null) {
      s.add('visits', v);
    } else {
      s.patch('visits', x['id'] as String, v);
    }
  }
}
