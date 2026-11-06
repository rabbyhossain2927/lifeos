import 'package:flutter/material.dart';
import '../services/store.dart';
import '../widgets/form.dart';
import '../widgets/ui.dart';
import 'goal_detail.dart';
import 'shell.dart';

const areas = ['Health', 'Faith', 'Family', 'Learn', 'Work', 'Money', 'Self'];

const goalTemplates = <String, Map<String, dynamic>>{
  'Reading': {'title': 'Read 24 books', 'area': 'Learn', 'target': 24, 'unit': 'books', 'step': 'Read 15 pages'},
  'Fitness': {'title': 'Work out 150 times', 'area': 'Health', 'target': 150, 'unit': 'workouts', 'step': '30 min workout'},
  'Weight': {'title': 'Lose 8 kg', 'area': 'Health', 'target': 8, 'unit': 'kg', 'step': 'Walk 8,000 steps'},
  'Quran khatam': {'title': 'Quran khatam', 'area': 'Faith', 'target': 30, 'unit': 'juz', 'step': 'Read 4 pages'},
  'Saving': {'title': 'Save 1,00,000 taka', 'area': 'Money', 'target': 100000, 'unit': 'taka', 'step': 'Put aside today'},
};

List<Field> goalFields = const [
  Field('title', 'Big goal for this year', hint: 'Read 24 books', required: true),
  Field('area', 'Life area', type: F.choice, options: areas),
  Field('type', 'How you track it', type: F.choice, options: ['Count', 'Yes / no']),
  Field('target', 'Yearly target (number)', type: F.number, hint: '24'),
  Field('unit', 'Unit', hint: 'books, kg, pages…'),
  Field('step', "Today's small step", hint: 'Read 15 pages'),
  Field('daily', 'Amount you log each day (optional)', type: F.number, hint: 'Leave empty to split the year evenly'),
  Field('why', 'My why: the deeper reason', type: F.long, hint: 'Shown to you on hard days'),
];

Map<String, dynamic> _clean(Map<String, dynamic> v) {
  final yesno = v['type'] == 'Yes / no';
  return {
    ...v,
    'type': yesno ? 'yesno' : 'count',
    'target': yesno ? 365 : ((v['target'] as num?) ?? 1),
    'daily': yesno ? 1 : v['daily'],
  };
}

/// Pick a template or start empty, then fill the form.
Future<void> addGoal(BuildContext context) async {
  final s = store(context, listen: false);
  final pick = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: C.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Col([
          Text('New goal', style: t(22, w: w6)),
          Text('Start from a template or your own.', style: t(14, c: C.muted)),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final k in goalTemplates.keys) SmallPill(k, onTap: () => Navigator.pop(c, k)),
            SmallPill('My own goal', bg: C.ink, fg: C.white, onTap: () => Navigator.pop(c, '')),
          ]),
        ]),
      ),
    ),
  );
  if (pick == null || !context.mounted) return;
  final init = pick.isEmpty ? <String, dynamic>{'type': 'Count'} : {...goalTemplates[pick]!, 'type': 'Count'};
  final v = await showForm(context, 'New goal', goalFields, initial: init, save: 'Add goal');
  if (v == null) return;
  s.add('goals', {..._clean(v), 'logs': <String, dynamic>{}});
}

Future<void> editGoal(BuildContext context, Json g) async {
  final s = store(context, listen: false);
  final v = await showForm(context, 'Edit goal', goalFields,
      initial: {...g, 'type': g['type'] == 'yesno' ? 'Yes / no' : 'Count'}, onDelete: () async {
    if (await confirm(context, 'Delete this goal?')) {
      s.remove('goals', g['id'] as String);
      if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    }
  });
  if (v == null) return;
  s.patch('goals', g['id'] as String, _clean(v));
}

class GoalsTab extends StatefulWidget {
  const GoalsTab({super.key});
  @override
  State<GoalsTab> createState() => _GoalsTabState();
}

class _GoalsTabState extends State<GoalsTab> {
  String level = 'Year';
  static const levelKey = {'Year': 'year', 'Month': 'month', 'Week': 'week', 'Day': 'day'};

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final goals = s.todayGoals;
    final usedAreas = goals.map((g) => g['area']).toSet().length;
    final lk = levelKey[level]!;
    return TabBody(children: [
      TabHeader(small: '${DateTime.now().year} · $usedAreas life area${usedAreas == 1 ? '' : 's'}', title: 'Goals'),
      Segmented(options: const ['Year', 'Month', 'Week', 'Day'], selected: level, onPick: (l) => setState(() => level = l)),
      if (goals.isEmpty)
        Box(
          onTap: () => addGoal(context),
          child: Col([
            const H2('Set your first big goal'),
            Text('Pick 3 to 5 big goals for the year. LifeOS splits each into month, week and today, and every tick moves all the bars.',
                style: t(14, c: C.muted, h: 1.45)),
            PillButton('Add a goal', bg: C.ink, fg: C.white, onTap: () => addGoal(context)),
          ]),
        ),
      if (goals.isNotEmpty) _featured(context, s, goals.first),
      if (goals.length > 1) const H2('Other goals'),
      for (final g in goals.skip(1)) _small(context, s, g, lk),
      _dashed('+ New goal', () => addGoal(context)),
    ]);
  }

  Widget _featured(BuildContext context, Store s, Json g) {
    final p = s.goalProgress(g), tg = s.goalTargets(g);
    final unit = (g['unit'] ?? '').toString();
    return Box(
      onTap: () => push(context, GoalDetailScreen(id: g['id'] as String)),
      child: Col([
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Col([
              _tag('${g['area'] ?? 'Self'}'),
              Text('${g['title']}', style: t(20, w: w6, ls: -0.2)),
            ], space: 6),
          ),
          Text('Yearly', style: t(13, c: C.muted)),
        ]),
        Container(
          padding: const EdgeInsets.only(left: 16),
          margin: const EdgeInsets.only(left: 5),
          decoration: const BoxDecoration(border: Border(left: BorderSide(color: C.line, width: 2))),
          child: Col([
            for (final l in const ['year', 'month', 'week', 'day'])
              _level(_levelName(l), '${numText(p[l]!)} / ${numText(tg[l]!)} $unit', p[l]! / tg[l]!, l == 'day'),
          ], space: 14),
        ),
      ], space: 16),
    );
  }

  String _levelName(String l) {
    final now = DateTime.now();
    return switch (l) { 'year' => '${now.year}', 'month' => monthsLong[now.month - 1], 'week' => 'This week', _ => 'Today' };
  }

  Widget _level(String name, String value, double v, bool today) => Col([
        Row(children: [Expanded(child: Text(name, style: t(13, w: w5))), Text(value, style: t(13, c: C.muted))]),
        Bar(v, height: 6, color: today ? C.lime2 : C.ink),
      ], space: 6);

  Widget _small(BuildContext context, Store s, Json g, String lk) {
    final p = s.goalProgress(g), tg = s.goalTargets(g);
    final unit = (g['unit'] ?? '').toString();
    return Box(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      onTap: () => push(context, GoalDetailScreen(id: g['id'] as String)),
      child: Col([
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${g['title']}', style: t(15, w: w5)),
              const SizedBox(height: 2),
              Text('${g['area'] ?? 'Self'} · this week ${numText(p['week']!)} of ${numText(tg['week']!)}', style: t(12, c: C.muted)),
            ]),
          ),
          Text('${numText(p[lk]!)} / ${numText(tg[lk]!)}${unit.isEmpty ? '' : ' $unit'}', style: t(14, w: w6)),
        ]),
        Bar(p[lk]! / tg[lk]!, height: 4),
      ], space: 10),
    );
  }

  Widget _tag(String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(999)),
        child: Text(s, style: t(11, w: w6)),
      );
}

Widget _dashed(String text, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: C.border, width: 1.5)),
        child: Text(text, style: t(14, w: w5)),
      ),
    );

Widget dashedButton(String text, VoidCallback onTap) => _dashed(text, onTap);
