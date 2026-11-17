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
    if (g == null) return ToolPage(title: 'Goal', subtitle: 'This goal was deleted.', icon: Icons.flag_outlined, colors: (C.chip, C.ink), children: const []);
    final yearP = s.goalProgress(g)['year']!, yearT = s.goalTarget(g);
    final ahead = s.goalBehind(g) <= 0;
    final plan = s.planOf(g);
    final todayAmt = plan == 'none' ? s.goalTargets(g)['day']! : s.stepAmount(g, DateTime.now());
    final todayLog = s.loggedOn(g, todayKey);
    final logs = ((g['logs'] as Map?) ?? {}).entries.where((e) => e.value is num && (e.value as num) > 0).toList()..sort((a, b) => '${b.key}'.compareTo('${a.key}'));
    final area = '${g['area'] ?? 'Self'}';
    final ac = areaColors[area] ?? (C.chip, C.ink);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: bgDecoration,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 48),
            children: gap(stagger([
              Row(children: [
                const BackBtn(),
                const Spacer(),
                HeadPill('Edit', onTap: () => addGoalPage(context, id: id)),
                const SizedBox(width: 8),
                Press(
                  onTap: () => _menu(context, s, g),
                  label: 'Goal options',
                  scale: 0.9,
                  child: Container(width: 44, height: 44, decoration: BoxDecoration(color: C.white, shape: BoxShape.circle), child: const Icon(Icons.more_horiz_rounded)),
                ),
              ]),
              // Name and why, big: this is the motivation.
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const RadialGradient(center: Alignment(1, -1), radius: 1.4, colors: [Color(0xFF3A4A12), Color(0xFF1F1F23)], stops: [0, 0.6]),
                ),
                child: Col([
                  Row(children: [
                    Container(width: 40, height: 40, decoration: BoxDecoration(color: C.lime, borderRadius: BorderRadius.circular(14)), child: Icon(goalIcon(g), size: 20, color: C.onLime)),
                    const SizedBox(width: 10),
                    Tag(area, bg: ac.$1, fg: ac.$2),
                    const SizedBox(width: 6),
                    Flexible(child: Tag('${fmtAmount((g['amount'] ?? yearT) as num)} ${g['unit'] ?? ''} · ${periodLabel(g)}', bg: const Color(0xFF34343A), fg: const Color(0xFFE7E7EA))),
                  ]),
                  Text('${g['title']}', style: t(28, w: FontWeight.w700, c: Colors.white, ls: -0.8, h: 1.1)),
                  Press(
                    onTap: () => _editText(context, s, g, 'why', 'Why it matters', 'The deeper reason, for hard days'),
                    scale: 0.99,
                    label: 'Edit why',
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('“', style: t(34, w: FontWeight.w700, c: C.lime, h: 0.9)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${g['why'] ?? ''}'.trim().isEmpty ? 'Tap to write why this matters to you.' : '${g['why']}', style: t(15.5, c: const Color(0xFFE7E7EA), h: 1.5)),
                      ),
                    ]),
                  ),
                  Col([
                    Row(children: [
                      Expanded(child: Text('${DateTime.now().year} progress', style: t(12, c: const Color(0xFFB9B9C0)))),
                      Text('${amountText(g, yearP, unit: false)} of ${amountText(g, yearT)}', style: t(12, w: w6, c: C.lime)),
                    ]),
                    Bar(yearP / (yearT == 0 ? 1 : yearT), color: C.lime, track: const Color(0xFF34343A)),
                  ], space: 6),
                  Press(
                    onTap: () => showSheet(
                        context,
                        'Ahead or behind?',
                        (_, __) => Text(
                            'LifeOS compares what you have done with the plan up to today. "Behind" means you are a little under the plan for this date, not that you failed. Log a bit extra for a few days and you are back on plan.',
                            style: t(14, c: C.muted, h: 1.5))),
                    label: 'What does this mean',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(color: ahead ? const Color(0x26D4F06B) : const Color(0x33B4410C), borderRadius: BorderRadius.circular(999)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(ahead ? Icons.check_rounded : Icons.trending_down_rounded, size: 14, color: ahead ? C.lime : const Color(0xFFF2A07B)),
                        const SizedBox(width: 6),
                        Flexible(child: Text(s.paceText(g), overflow: TextOverflow.ellipsis, style: t(12, w: w6, c: ahead ? C.lime : const Color(0xFFF2A07B)))),
                        const SizedBox(width: 6),
                        const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFFB9B9C0)),
                      ]),
                    ),
                  ),
                ], space: 14),
              ),
              // Today
              HeroCard(
                tone: HeroTone.white,
                label: 'Today',
                big: '${amountText(g, todayLog, small: true, unit: false)} / ${amountText(g, todayAmt, small: true)}',
                sub: todayLog >= todayAmt && todayAmt > 0 ? 'Done for today. Every bar moved.' : 'Log any amount, or tick today\'s step below.',
                btns: [
                  HeroBtn('Custom log', () => logSheet(context, g), primary: true),
                  HeroBtn(todayLog >= todayAmt && todayAmt > 0 ? 'Undo today' : 'Mark done', () {
                    if (todayLog >= todayAmt && todayAmt > 0) {
                      s.setGoalLog(g, todayKey, 0);
                    } else {
                      s.setGoalLog(g, todayKey, todayAmt);
                      Haptic.success();
                    }
                  }),
                ],
              ),
              Panel(
                title: 'Small steps plan',
                child: Chips(
                  options: const ['Every day', 'Weekly', 'Monthly', 'No plan'],
                  selected: {
                    switch (plan) { 'day' => 'Every day', 'week' => 'Weekly', 'month' => 'Monthly', _ => 'No plan' }
                  },
                  onTap: (v) => s.patch('goals', id, {'plan': v == 'Every day' ? 'day' : v == 'Weekly' ? 'week' : v == 'Monthly' ? 'month' : 'none'}),
                ),
              ),
              if (plan != 'none')
                RowsPanel(
                  title: plan == 'month' ? '${monthsLong[DateTime.now().month - 1]} · ${s.planDays(g).length} steps' : 'This week · 7 steps',
                  hint: 'swipe ← to skip a day',
                  rows: [
                    for (final d in s.planDays(g))
                      if (s.stepAmount(g, d) > 0)
                        Row2(
                          swipeId: '${g['id']}-${dayKey(d)}',
                          title: dayLabel(d),
                          sub: amountText(g, s.stepAmount(g, d), small: true) +
                              (s.loggedOn(g, dayKey(d)) > 0 && s.loggedOn(g, dayKey(d)) < s.stepAmount(g, d) ? ' · ${amountText(g, s.loggedOn(g, dayKey(d)), small: true)} done' : ''),
                          done: s.loggedOn(g, dayKey(d)) >= s.stepAmount(g, d),
                          onTick: () {
                            final k = dayKey(d), amt = s.stepAmount(g, d);
                            if (s.loggedOn(g, k) >= amt) {
                              s.setGoalLog(g, k, 0);
                            } else {
                              s.setGoalLog(g, k, amt);
                            }
                          },
                          onDots: () => showMenuSheet(context, dayLabel(d), [
                            MenuItem('Change amount', Icons.edit_outlined, () async {
                              final per = ((g['perUnit'] ?? 1) as num);
                              final v = await askNumber(context, 'Amount for ${dayLabel(d)} (${per > 1 ? g['logUnit'] : g['unit']})', fmtAmount(s.stepAmount(g, d) * per));
                              if (v != null) s.setStepAmount(g, dayKey(d), v / per);
                            }),
                            MenuItem('Log a custom amount', Icons.add_rounded, () => logSheet(context, g, day: d)),
                            MenuItem('Back to the plan amount', Icons.restart_alt_rounded, () => s.setStepAmount(g, dayKey(d), null)),
                            MenuItem('Skip this day', Icons.block_rounded, () => s.setStepAmount(g, dayKey(d), 0), danger: true),
                          ]),
                          onDelete: () => s.setStepAmount(g, dayKey(d), 0),
                          onUndo: () => s.setStepAmount(g, dayKey(d), null),
                        ),
                  ],
                ),
              RowsPanel(
                title: 'Log history',
                hint: 'tap ••• to edit',
                empty: 'Nothing logged yet.',
                rows: [
                  for (final e in logs.take(30))
                    Row2(
                      swipeId: 'log-${g['id']}-${e.key}',
                      title: '+${amountText(g, e.value as num, small: true)}',
                      sub: dayLabel(parseDay('${e.key}')) + ((g['logNotes'] as Map? ?? {})[e.key] == null ? '' : ' · ${(g['logNotes'] as Map)[e.key]}'),
                      onDots: () => showMenuSheet(context, dayLabel(parseDay('${e.key}')), [
                        MenuItem('Edit amount', Icons.edit_outlined, () async {
                          final per = ((g['perUnit'] ?? 1) as num);
                          final v = await askNumber(context, 'Amount (${per > 1 ? g['logUnit'] : g['unit']})', fmtAmount((e.value as num) * per));
                          if (v != null) s.setGoalLog(g, '${e.key}', v / per);
                        }),
                        MenuItem('Delete', Icons.delete_outline_rounded, () => s.setGoalLog(g, '${e.key}', 0), danger: true),
                      ]),
                      onDelete: () => s.setGoalLog(g, '${e.key}', 0),
                      onUndo: () => s.setGoalLog(g, '${e.key}', e.value as num),
                    ),
                ],
              ),
            ]), 12),
          ),
        ),
      ),
    );
  }

  void _editText(BuildContext context, Store s, Json g, String key, String title, String hint) {
    final c = TextEditingController(text: '${g[key] ?? ''}');
    showSheet(context, title, (ctx, _) => Col([
          SoftField(controller: c, hint: hint, lines: 3),
          PressPill('Save', success: true, onTap: () {
            s.patch('goals', g['id'] as String, {key: c.text.trim()});
            Navigator.pop(ctx);
          }),
        ], space: 12));
  }

  void _menu(BuildContext context, Store s, Json g) {
    showMenuSheet(context, '${g['title']}', [
      MenuItem('Edit goal', Icons.edit_outlined, () => addGoalPage(context, id: g['id'] as String)),
      MenuItem('Archive', Icons.archive_outlined, () {
        s.patch('goals', g['id'] as String, {'archived': true});
        Navigator.pop(context);
        toast(context, 'Goal archived.');
      }),
      MenuItem('Delete goal', Icons.delete_outline_rounded, () async {
        if (!await confirm(context, 'Delete this goal?', body: 'All its progress is removed.')) return;
        s.remove('goals', g['id'] as String);
        if (context.mounted) Navigator.pop(context);
      }, danger: true),
    ]);
  }
}

/// Custom log: any amount, in the goal's units (or pages for books), any day.
void logSheet(BuildContext context, Json g, {DateTime? day}) {
  final s = store(context, listen: false);
  final per = ((g['perUnit'] ?? 1) as num).toDouble();
  final units2 = per > 1 ? ['${g['logUnit']}', '${g['unit']}'] : ['${g['unit']}'];
  var u = units2.first;
  final big = ((g['amount'] ?? g['target'] ?? 0) as num) >= 5000;
  var amount = per > 1 ? 20.0 : (big ? 500.0 : 1.0);
  var when = day ?? DateTime.now();
  final note = TextEditingController();
  final yesterday = dayKey(DateTime.now().subtract(const Duration(days: 1)));
  showSheet(context, 'Custom log', (ctx, set) {
    final small = per > 1 && u == units2.first;
    final quick = small
        ? [5.0, 10.0, 20.0, 50.0]
        : big
            ? [100.0, 500.0, 1000.0, 5000.0]
            : '${g['unit']}' == 'kg'
                ? [0.2, 0.5, 1.0, 2.0]
                : [1.0, 2.0, 5.0, 10.0];
    final step = '${g['unit']}' == 'kg' ? 0.1 : big ? 100.0 : 1.0;
    final k = dayKey(when);
    final whenLabel = k == todayKey ? 'Today' : k == yesterday ? 'Yesterday' : dayLabel(when);
    return Col([
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: C.limeSoft, borderRadius: BorderRadius.circular(18)),
        child: Text('${g['title']} · $whenLabel so far ${amountText(g, s.loggedOn(g, k), small: true)}', style: t(13, w: w5, c: C.limeText)),
      ),
      if (units2.length > 1) Chips(options: units2, selected: {u}, onTap: (v) => set(() => u = v)),
      Stepper2(
        value: fmtAmount(amount),
        unit: u,
        size: 30,
        onMinus: () => set(() {
          final n = ((amount - step) * 10).round() / 10;
          if (n > 0) amount = n;
        }),
        onPlus: () => set(() => amount = ((amount + step) * 10).round() / 10),
        onType: (v) => set(() => amount = v.toDouble()),
      ),
      Chips(options: [for (final q in quick) '+${fmtAmount(q)}'], selected: {'+${fmtAmount(amount)}'}, onTap: (v) => set(() => amount = double.parse(v.substring(1).replaceAll(',', '')))),
      Chips(
        options: ['Today', 'Yesterday', if (whenLabel != 'Today' && whenLabel != 'Yesterday') whenLabel, 'Pick date…'],
        selected: {whenLabel},
        onTap: (v) async {
          if (v == 'Today') set(() => when = DateTime.now());
          if (v == 'Yesterday') set(() => when = DateTime.now().subtract(const Duration(days: 1)));
          if (v == 'Pick date…') {
            final d = await showDatePicker(context: ctx, initialDate: when, firstDate: DateTime(DateTime.now().year - 1), lastDate: DateTime.now());
            if (d != null) set(() => when = d);
          }
        },
      ),
      SoftField(controller: note, hint: 'Note (optional)', pill: true),
      PressPill('Save log', success: true, onTap: () {
        final v = small ? amount / per : amount;
        s.logGoal(g, v, dayKey(when));
        if (note.text.trim().isNotEmpty) {
          final notes = Map<String, dynamic>.from(g['logNotes'] as Map? ?? {});
          notes[dayKey(when)] = note.text.trim();
          s.patch('goals', g['id'] as String, {'logNotes': notes});
        }
        Navigator.pop(ctx);
        toast(context, 'Logged +${fmtAmount(amount)} $u. You can edit it in Log history.');
      }),
    ], space: 12);
  });
}
