import 'package:flutter/material.dart';
import '../services/store.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import '../widgets/ui.dart';
import 'goals.dart';

class GoalDetail extends StatelessWidget {
  final String id;
  const GoalDetail({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final g = s.get('goals', id);
    if (g == null) return const ToolPage(title: 'Goal', subtitle: 'This goal was deleted.', icon: Icons.flag_outlined, colors: (C.chip, C.ink), children: []);
    final done = s.goalDoneToday(g);
    final on = s.onTrack(g);
    final behind = s.goalBehind(g);
    final steps = ((g['steps'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final yesno = g['type'] == 'yesno';
    void saveSteps(List<Map<String, dynamic>> l) => s.patch('goals', id, {'steps': l});

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 48),
            children: gap(stagger([
              Row(children: [
                const BackBtn(),
                const SizedBox(width: 10),
                Tag.area('${g['area'] ?? 'Self'}'),
                const SizedBox(width: 6),
                on ? const Tag('On track', bg: C.ink, fg: C.lime) : const Tag('Behind', bg: C.warnSoft, fg: C.warn),
                const Spacer(),
                Press(
                  onTap: () => _menu(context, s, g),
                  label: 'Goal options',
                  scale: 0.9,
                  child: Container(width: 46, height: 46, decoration: const BoxDecoration(color: C.white, shape: BoxShape.circle), child: const Icon(Icons.more_horiz_rounded)),
                ),
              ]),
              Text('${g['title']}', style: t(28, w: w6, ls: -0.6, h: 1.15)),
              Press(
                onTap: () => _edit(context, s, g, 'why', 'My why', 'The deeper reason, shown on hard days'),
                scale: 0.98,
                label: 'Edit my why',
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(24)),
                  child: Col([
                    Text('My why', style: t(12, w: w6, c: C.lime)),
                    Text('${g['why'] ?? ''}'.trim().isEmpty ? 'Tap to write why this matters.' : '${g['why']}', style: t(15, c: C.white, h: 1.45)),
                  ], space: 6),
                ),
              ),
              Panel(
                child: Col([
                  for (final l in [('${DateTime.now().year}', 'year'), (monthsLong[DateTime.now().month - 1], 'month'), ('This week', 'week'), ('Today', 'day')])
                    Col([
                      Row(children: [Expanded(child: Text(l.$1, style: t(13, w: w5))), Text(s.goalPair(g, l.$2), style: t(13, c: C.muted))]),
                      Bar(s.goalProgress(g)[l.$2]! / s.goalTargets(g)[l.$2]!, color: l.$2 == 'day' ? C.lime2 : C.ink),
                    ], space: 6),
                  Text('One log moves all four bars.', style: t(12, c: C.muted)),
                ], space: 12),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: C.lime, borderRadius: BorderRadius.circular(24)),
                child: Col([
                  Text("Today's step", style: t(12, w: w6)),
                  Press(
                    onTap: () => _edit(context, s, g, 'step', "Today's step", 'Read 20 pages'),
                    scale: 0.98,
                    label: "Edit today's step",
                    child: Text('${g['step'] ?? 'One small step'}', style: t(20, w: w6)),
                  ),
                  Row(children: gap([
                    Expanded(
                      child: PressPill(
                        done ? 'Done today ✓' : 'Mark done',
                        bg: done ? C.white : C.ink,
                        fg: done ? C.ink : C.white,
                        height: 48,
                        success: !done,
                        onTap: () {
                          s.toggleGoalToday(g);
                          if (!done) toast(context, 'Nice. All four bars moved.');
                        },
                      ),
                    ),
                    if (!yesno) Expanded(child: PressPill('Log more', bg: C.white, fg: C.ink, height: 48, onTap: () => logSheet(context, g))),
                  ], 8)),
                ], space: 12),
              ),
              if (!on && behind > 0)
                Panel(
                  child: Col([
                    Text('Catch up, no stress', style: t(14, w: w6)),
                    Text('${fmtAmount(behind)} ${g['unit'] ?? ''} behind the yearly pace. Add a little each day for a week and you are back on track.', style: t(13, c: C.muted, h: 1.45)),
                  ], space: 4),
                ),
              RowsPanel(
                title: 'Small steps',
                hint: '+ Add',
                empty: 'Break the goal into tiny steps you can finish in minutes.',
                rows: [
                  for (var i = 0; i < steps.length; i++)
                    Row2(
                      title: '${steps[i]['t']}',
                      right: '${steps[i]['min'] ?? ''}',
                      done: steps[i]['done'] == true,
                      onTick: () => saveSteps([for (var j = 0; j < steps.length; j++) j == i ? {...steps[j], 'done': steps[j]['done'] != true} : steps[j]]),
                      onLongPress: () async {
                        if (await confirm(context, 'Delete this step?')) saveSteps([...steps]..removeAt(i));
                      },
                    ),
                ],
              ),
              PressPill('+ Add a small step', bg: C.white, fg: C.ink, height: 50, onTap: () => _addStep(context, steps, saveSteps)),
            ]), 14),
          ),
        ),
      ),
    );
  }

  void _addStep(BuildContext context, List<Map<String, dynamic>> steps, void Function(List<Map<String, dynamic>>) save) {
    final c = TextEditingController();
    var mins = '10 min';
    showSheet(context, 'Add a small step', (ctx, set) => Col([
          SoftField(controller: c, hint: 'Put the book by the bed', pill: true),
          Chips(options: const ['1 min', '5 min', '10 min', '20 min', '30 min'], selected: {mins}, onTap: (m) => set(() => mins = m)),
          PressPill('Add step', success: true, onTap: () {
            if (c.text.trim().isEmpty) return;
            save([...steps, {'t': c.text.trim(), 'min': mins, 'done': false}]);
            Navigator.pop(ctx);
          }),
        ], space: 12));
  }

  void _edit(BuildContext context, Store s, Json g, String key, String title, String hint) {
    final c = TextEditingController(text: '${g[key] ?? ''}');
    showSheet(context, title, (ctx, _) => Col([
          SoftField(controller: c, hint: hint, lines: key == 'why' ? 3 : 1, pill: key != 'why'),
          PressPill('Save', success: true, onTap: () {
            s.patch('goals', g['id'] as String, {key: c.text.trim()});
            Navigator.pop(ctx);
          }),
        ], space: 12));
  }

  void _menu(BuildContext context, Store s, Json g) {
    showSheet(context, 'Goal options', (ctx, _) => Col([
          PressPill('Rename', bg: C.chip, fg: C.ink, height: 52, onTap: () {
            Navigator.pop(ctx);
            _edit(context, s, g, 'title', 'Goal name', 'Read 24 books');
          }),
          PressPill('Archive', bg: C.chip, fg: C.ink, height: 52, onTap: () {
            s.patch('goals', g['id'] as String, {'archived': true});
            Navigator.pop(ctx);
            Navigator.pop(context);
            toast(context, 'Goal archived.');
          }),
          PressPill('Delete goal', bg: C.warnSoft, fg: C.warn, height: 52, onTap: () async {
            if (!await confirm(ctx, 'Delete this goal?', body: 'All its progress is removed.')) return;
            s.remove('goals', g['id'] as String);
            Haptic.warn();
            if (ctx.mounted) Navigator.pop(ctx);
            if (context.mounted) Navigator.pop(context);
          }),
        ], space: 10));
  }
}

/// Log progress: − amount + and quick chips. Saves in goal units.
void logSheet(BuildContext context, Json g) {
  final s = store(context, listen: false);
  final per = ((g['perUnit'] ?? 1) as num).toDouble();
  final small = per > 1 ? '${g['logUnit'] ?? ''}' : '${g['unit'] ?? ''}';
  final kg = '${g['unit']}' == 'kg';
  final money = ((g['target'] ?? 0) as num) >= 10000;
  final quick = kg ? [0.2, 0.5, 1.0, 2.0] : money ? [100.0, 500.0, 1000.0, 5000.0] : per > 1 ? [5.0, 10.0, 15.0, 30.0] : [1.0, 2.0, 5.0, 10.0];
  final step = kg ? 0.1 : money ? 100.0 : 1.0;
  var amount = quick[per > 1 ? 2 : 0];
  final today = s.goalProgress(g)['day']! * per;
  showSheet(context, 'Log progress', (ctx, set) => Col([
        Text('${g['title']} · today so far ${fmtAmount(per > 1 ? today.round() : today)} $small', style: t(13, c: C.muted)),
        Stepper2(
          value: '+${fmtAmount(amount)}',
          unit: small,
          size: 36,
          onMinus: () => set(() => amount = ((amount - step) * 10).round() / 10 < step ? step : ((amount - step) * 10).round() / 10),
          onPlus: () => set(() => amount = ((amount + step) * 10).round() / 10),
        ),
        Row(children: gap([
          for (final q in quick)
            Expanded(
              child: Press(
                onTap: () => set(() => amount = q),
                haptic: Haptic.select,
                label: '+${fmtAmount(q)}',
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: amount == q ? C.lime : C.chip,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: amount == q ? C.ink : C.chip, width: 1.5),
                  ),
                  child: Text('+${fmtAmount(q)}', style: t(15, w: w6)),
                ),
              ),
            ),
        ], 8)),
        PressPill('Save', success: true, onTap: () {
          s.logGoal(g, amount / per);
          Navigator.pop(ctx);
          toast(context, 'Logged +${fmtAmount(amount)} $small. All bars moved.');
        }),
      ], space: 14));
}
