import 'package:flutter/material.dart';
import '../services/store.dart';
import '../widgets/form.dart';
import '../widgets/ui.dart';
import 'goals.dart';
import 'launch.dart';

class GoalDetailScreen extends StatelessWidget {
  final String id;
  const GoalDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final g = s.get('goals', id);
    if (g == null) return const SubPage(title: 'Goal', children: [Text('This goal was deleted.')]);
    final p = s.goalProgress(g), tg = s.goalTargets(g);
    final unit = (g['unit'] ?? '').toString();
    final steps = ((g['steps'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final behind = s.goalBehind(g);
    final now = DateTime.now();
    final why = (g['why'] ?? '').toString();

    void saveSteps(List<Map<String, dynamic>> list) => s.patch('goals', id, {'steps': list});

    return SubPage(
      title: '',
      trailing: RoundBtn(icon: Icons.more_horiz_rounded, label: 'Edit goal', onTap: () => editGoal(context, g)),
      children: [
        Col([
          Wrap(spacing: 6, children: [
            _tag('${g['area'] ?? 'Self'}'),
            _tag(g['type'] == 'yesno' ? 'Yes / no' : 'Counted in ${unit.isEmpty ? 'steps' : unit}'),
          ]),
          Text('${g['title']}', style: t(32, w: w6, ls: -0.6, h: 1.15)),
        ], space: 8),
        Box(
          dark: true,
          padding: const EdgeInsets.all(18),
          onTap: () => editGoal(context, g),
          child: Col([
            const H2('My why', color: C.white),
            Text(why.isEmpty ? 'Tap to write why this goal matters to you. LifeOS shows it on hard days.' : why,
                style: t(16, c: why.isEmpty ? C.darkMuted : C.white, h: 1.45)),
          ], space: 6),
        ),
        Box(
          child: Col([
            for (final l in const ['year', 'month', 'week', 'day'])
              Col([
                Row(children: [
                  Expanded(child: Text(switch (l) { 'year' => '${now.year}', 'month' => monthsLong[now.month - 1], 'week' => 'This week', _ => 'Today' }, style: t(13, w: w5))),
                  Text('${numText(p[l]!)} / ${numText(tg[l]!)} $unit', style: t(13, c: C.muted)),
                ]),
                Bar(p[l]! / tg[l]!, color: l == 'day' ? C.lime2 : C.ink),
              ], space: 6),
            Row(children: [
              Expanded(child: PillButton(s.goalDoneToday(g) ? 'Done today' : 'Tick today', height: 44, bg: s.goalDoneToday(g) ? C.chip : C.lime, onTap: () => s.toggleGoalToday(g))),
              if (g['type'] != 'yesno') ...[
                const SizedBox(width: 8),
                PillButton('Log amount', height: 44, expand: false, bg: C.ink, fg: C.white, onTap: () async {
                  final v = await showForm(context, 'Log progress', [Field('n', 'How much today? ($unit)', type: F.number, required: true)], save: 'Log');
                  final n = v?['n'];
                  if (n is num) s.logGoal(g, n);
                }),
              ],
            ]),
          ], space: 12),
        ),
        if (behind >= tg['day']!)
          Box(
            color: C.limeSoft,
            radius: 24,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Col([
              Text('Catch up, no stress', style: t(14, w: w6)),
              Text(
                  '${numText((behind / tg['day']!).ceil())} day${(behind / tg['day']!).ceil() == 1 ? '' : 's'} behind. Add ${numText((behind / 3 * 10).ceil() / 10)} $unit a day for 3 days and you are back on track.',
                  style: t(13, c: C.limeText, h: 1.45)),
            ], space: 4),
          ),
        Box(
          child: Col([
            CardHead('Small steps', action: '+ Add step', onAction: () async {
              final v = await showForm(context, 'New step', const [
                Field('t', 'Step', required: true, hint: 'Put the book by the bed'),
                Field('min', 'Minutes it takes', type: F.number, hint: '5'),
              ]);
              if (v == null) return;
              saveSteps([...steps, {'t': v['t'], 'min': v['min'], 'done': false}]);
            }),
            if (steps.isEmpty) Text('Break the goal into tiny steps you can finish in minutes.', style: t(13, c: C.muted, h: 1.4)),
            for (var i = 0; i < steps.length; i++)
              Row(children: [
                Tick(
                  done: steps[i]['done'] == true,
                  size: 20,
                  label: '${steps[i]['t']}',
                  onTap: () {
                    final l = [...steps];
                    l[i] = {...l[i], 'done': l[i]['done'] != true};
                    saveSteps(l);
                  },
                ),
                Expanded(child: GestureDetector(onLongPress: () => saveSteps([...steps]..removeAt(i)), child: doneText('${steps[i]['t']}', steps[i]['done'] == true, size: 14))),
                if (steps[i]['min'] != null) Text('${numText(steps[i]['min'] as num)} min', style: t(12, c: C.muted)),
              ]),
          ], space: 4),
        ),
        Col([
          const H2('Vision board'),
          Row(children: [
            for (final c in const [Color(0xFFE4DDF1), Color(0xFFF2E1E8), Color(0xFFE8F4BC)])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(18)),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(8),
                      child: Text(why.isEmpty ? '${g['title']}' : why, maxLines: 4, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: t(11, c: C.muted)),
                    ),
                  ),
                ),
              ),
          ]),
        ], space: 10),
        PillButton('2-minute start: ${(g['step'] ?? 'first tiny step')}'.trim(), bg: C.ink, fg: C.white, height: 56,
            onTap: () => push(context, LaunchScreen(task: '${g['title']}', firstStep: (g['step'] ?? 'Do the first tiny step').toString()))),
      ],
    );
  }

  Widget _tag(String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(999)),
        child: Text(s, style: t(11, w: w6)),
      );
}
