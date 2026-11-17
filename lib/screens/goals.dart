import 'package:flutter/material.dart';
import '../services/store.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import '../widgets/ui.dart';
import 'goal_detail.dart';
import 'shell.dart';

const areas = ['Health', 'Faith', 'Learn', 'Work', 'Family', 'Money', 'Self'];

/// title, target, unit, area, step, logUnit, perUnit
const goalTemplates = <String, Map<String, dynamic>>{
  'Read books': {'title': 'Read 24 books', 'target': 24, 'unit': 'books', 'area': 'Learn', 'step': 'Read 20 pages', 'logUnit': 'pages', 'perUnit': 300},
  'Lose weight': {'title': 'Lose 8 kg', 'target': 8, 'unit': 'kg', 'area': 'Health', 'step': 'Walk 8,000 steps'},
  'Quran khatam': {'title': 'Quran khatam', 'target': 30, 'unit': 'juz', 'area': 'Faith', 'step': 'Read 2 pages', 'logUnit': 'pages', 'perUnit': 20},
  'Save money': {'title': 'Save 1,00,000 taka', 'target': 100000, 'unit': 'taka', 'area': 'Money', 'step': 'Put aside 300 taka'},
  'Workouts': {'title': 'Work out 150 times', 'target': 150, 'unit': 'workouts', 'area': 'Health', 'step': '30 min workout'},
  'My own': {'title': '', 'target': 10, 'unit': 'times', 'area': 'Self', 'step': 'One small step'},
};

const levels = {'Year': 'year', 'Month': 'month', 'Week': 'week', 'Today': 'day'};

extension GoalMath on Store {
  bool onTrack(Json g) {
    final behind = goalBehind(g);
    final year = goalProgress(g)['year']!;
    return behind <= 0 || year >= 0.9 * (year + behind);
  }

  /// "9 / 24 books" for a level; week and day use the small unit (pages) when there is one.
  String goalPair(Json g, String level) {
    final p = goalProgress(g)[level]!, tg = goalTargets(g)[level]!;
    final per = (g['perUnit'] ?? 0) as num;
    if (per > 1 && (level == 'week' || level == 'day')) {
      return '${(p * per).round()} / ${(tg * per).round()} ${g['logUnit'] ?? ''}';
    }
    return '${fmtAmount(p)} / ${fmtAmount(tg)} ${g['unit'] ?? ''}';
  }
}

String fmtAmount(num v) {
  if (v.abs() >= 1000) return v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.abs() < 1 ? v.toStringAsFixed(2) : v.toStringAsFixed(1);
}

class GoalsTab extends StatefulWidget {
  const GoalsTab({super.key});
  @override
  State<GoalsTab> createState() => _GoalsTabState();
}

class _GoalsTabState extends State<GoalsTab> {
  String level = 'Year';

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final goals = s.todayGoals;
    final k = levels[level]!;
    final onTrack = goals.where(s.onTrack).length;
    final todayDone = goals.where(s.goalDoneToday).length;
    final pct = goals.isEmpty
        ? 0.0
        : goals.fold<double>(0, (a, g) => a + (s.goalProgress(g)[k]! / s.goalTargets(g)[k]!).clamp(0.0, 1.0)) / goals.length;
    final levelName = level == 'Today' ? 'Today' : 'This ${level.toLowerCase()}';

    return TabBody(children: [
      TabTitle('Goals', sub: '${DateTime.now().year} · ${goals.length} goals · $onTrack on track', trailing: HeadPill('Review', onTap: () => push(context, const ReviewPage()))),
      // Year / Month / Week / Today
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(999)),
        child: LayoutBuilder(builder: (context, box) {
          final w = (box.maxWidth - 12) / 4;
          final i = levels.keys.toList().indexOf(level);
          return SizedBox(
            height: 42,
            child: Stack(children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                left: i * (w + 4),
                top: 0,
                bottom: 0,
                width: w,
                child: Container(decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(999))),
              ),
              Row(children: gap([
                for (final l in levels.keys)
                  Expanded(
                    child: Press(
                      onTap: () => setState(() => level = l),
                      haptic: Haptic.select,
                      label: l,
                      selected: l == level,
                      child: Center(
                        child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 200), style: t(13, w: w6, c: l == level ? C.white : C.muted), child: Text(l)),
                      ),
                    ),
                  ),
              ], 4)),
            ]),
          );
        }),
      ),
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: gap([
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(26)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$levelName progress', style: t(13, c: C.darkMuted)),
                const SizedBox(height: 10),
                Ring(value: pct, size: 96, stroke: 11, center: CountText(pct * 100, style: t(21, w: w6, c: C.white), format: (v) => '${v.round()}%')),
                const SizedBox(height: 10),
                Text('All goals together', style: t(12, c: C.lime)),
              ]),
            ),
          ),
          Expanded(
            child: Column(children: [
              Expanded(child: _stat('On track', '$onTrack of ${goals.length}', C.lime)),
              const SizedBox(height: 10),
              Expanded(child: _stat("Today's steps", '$todayDone of ${goals.length}', C.white)),
            ]),
          ),
        ], 10)),
      ),
      Padding(padding: const EdgeInsets.only(left: 4, top: 4), child: Text('My goals', style: t(18, w: w6))),
      if (goals.isEmpty)
        Panel(child: Text('No goals yet. Tap "+ New goal" and pick a template. LifeOS splits it into months, weeks and a small step for today.', style: t(14, c: C.muted, h: 1.45))),
      for (final g in goals) GoalCard(g: g, level: k, levelName: levelName),
      Press(
        onTap: () => addGoalPage(context),
        label: 'New goal',
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: C.border, width: 1.5)),
          child: Text('+ New goal', style: t(15, w: w6)),
        ),
      ),
    ]);
  }

  Widget _stat(String k, String v, Color bg) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(k, style: t(12, w: bg == C.lime ? w6 : FontWeight.w400, c: bg == C.lime ? C.ink : C.muted)),
          const SizedBox(height: 4),
          AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: Text(v, key: ValueKey(v), style: t(22, w: w6))),
        ]),
      );
}

class GoalCard extends StatelessWidget {
  final Json g;
  final String level, levelName;
  const GoalCard({super.key, required this.g, required this.level, required this.levelName});
  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final done = s.goalDoneToday(g);
    final on = s.onTrack(g);
    final p = s.goalProgress(g)[level]! / s.goalTargets(g)[level]!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(26)),
      child: Col([
        Press(
          onTap: () => push(context, GoalDetail(id: g['id'] as String)),
          scale: 0.98,
          label: '${g['title']}',
          child: Col([
            Row(children: [Tag.area('${g['area'] ?? 'Self'}'), const Spacer(), on ? Tag('On track', bg: C.ink, fg: C.lime) : Tag('Behind', bg: C.warnSoft, fg: C.warn)]),
            Text('${g['title']}', style: t(18, w: w6, ls: -0.2)),
            Row(children: [Expanded(child: Text(levelName, style: t(13, c: C.muted))), Text(s.goalPair(g, level), style: t(13, w: w6))]),
            Bar(p, color: level == 'day' ? C.lime2 : C.ink),
          ], space: 10),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Today's step", style: t(11, c: C.muted)),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: t(15, w: w6, c: done ? const Color(0xFF8A8A84) : C.ink, deco: done ? TextDecoration.lineThrough : null),
                  child: Text('${g['step'] ?? 'One small step'}'),
                ),
              ]),
            ),
            TickCircle(
              done: done,
              size: 44,
              label: "today's step",
              onTap: () {
                s.toggleGoalToday(g);
                if (!done) say(context, 'Nice. Year, month, week and today all moved.');
              },
            ),
          ]),
        ),
      ], space: 12),
    );
  }
}

/// New goal: one page, all taps.
Future<void> addGoalPage(BuildContext context) => push(context, const AddGoalPage());

class AddGoalPage extends StatefulWidget {
  const AddGoalPage({super.key});
  @override
  State<AddGoalPage> createState() => _AddGoalPageState();
}

class _AddGoalPageState extends State<AddGoalPage> {
  String tpl = 'Read books';
  late Map<String, dynamic> d = Map.of(goalTemplates[tpl]!);
  late final name = TextEditingController(text: d['title'] as String);
  String why = '';

  num get target => d['target'] as num;
  num get stepSize => target >= 10000 ? 5000 : target >= 1000 ? 100 : target >= 100 ? 10 : 1;

  void pick(String k) {
    setState(() {
      tpl = k;
      d = Map.of(goalTemplates[k]!);
      name.text = d['title'] as String;
    });
  }

  @override
  Widget build(BuildContext context) {
    final unit = '${d['unit']}';
    String r(num v) => fmtAmount(v < 1 ? (v * 100).round() / 100 : (v * 10).round() / 10);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: bgDecoration,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
            children: gap(stagger([
              Row(children: [const BackBtn(icon: Icons.close_rounded, label: 'Close'), const SizedBox(width: 12), Text('New goal', style: t(17, w: w6))]),
              Text('1. Start from', style: t(14, w: w6)),
              Chips(options: goalTemplates.keys.toList(), selected: {tpl}, onTap: pick, off: C.white),
              Text('2. Goal name', style: t(14, w: w6)),
              TextField(
                controller: name,
                style: t(16, w: w5),
                decoration: InputDecoration(
                  hintText: 'Read 24 books',
                  filled: true,
                  fillColor: C.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
                ),
              ),
              Text('3. How many this year?', style: t(14, w: w6)),
              Stepper2(
                value: fmtAmount(target),
                unit: unit,
                size: 28,
                bg: C.white,
                onMinus: () => setState(() => d['target'] = target - stepSize < 1 ? 1 : target - stepSize),
                onPlus: () => setState(() => d['target'] = target + stepSize),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: C.limeSoft, borderRadius: BorderRadius.circular(18)),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: 'LifeOS splits it for you: ', style: t(13, c: C.limeText, h: 1.45)),
                  TextSpan(text: '${r(target / 12)} $unit a month · ${r(target / 52)} a week · a small step every day', style: t(13, w: w6, c: C.limeText, h: 1.45)),
                ])),
              ),
              Text('4. Life area', style: t(14, w: w6)),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in areas)
                  Press(
                    onTap: () => setState(() => d['area'] = a),
                    haptic: Haptic.select,
                    label: a,
                    selected: d['area'] == a,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: areaColors[a]!.$1,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: d['area'] == a ? areaColors[a]!.$2 : areaColors[a]!.$1, width: 1.5),
                      ),
                      child: Center(widthFactor: 1, child: Text(a, style: t(13, w: w6, c: areaColors[a]!.$2))),
                    ),
                  ),
              ]),
              Text.rich(TextSpan(children: [TextSpan(text: '5. Why it matters ', style: t(14, w: w6)), TextSpan(text: '(optional)', style: t(14, c: C.muted))])),
              Chips(options: const ['For my family', 'For my health', 'To grow', 'For Allah'], selected: {why}, off: C.white, onTap: (w) => setState(() => why = why == w ? '' : w)),
              const SizedBox(height: 4),
              PressPill('Create goal', success: true, onTap: () {
                final title = name.text.trim();
                if (title.isEmpty) {
                  say(context, 'Give the goal a name first.', good: false);
                  return;
                }
                store(context, listen: false).add('goals', {
                  ...d,
                  'title': title,
                  'type': 'count',
                  'why': why,
                  'logs': <String, dynamic>{},
                  'steps': <dynamic>[],
                });
                Haptic.celebrate();
                Navigator.pop(context);
                toast(context, "Goal created. Today's step is on the Goals tab.");
              }),
            ]), 12),
          ),
        ),
      ),
    );
  }
}

/// Week review: summary + three chip questions.
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});
  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final a = <String, String>{};

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final goals = s.todayGoals;
    final ws = weekStart;
    final q = [
      ('How did this week go?', 'feel', ['Great', 'Okay', 'Hard']),
      ('What helped most?', 'help', ['Morning time', 'Reminders', 'Small steps', 'Family']),
      ('Focus next week', 'next', [for (final g in goals) '${g['title']}']),
    ];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: bgDecoration,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
            children: gap(stagger([
              Row(children: [
                const BackBtn(),
                const SizedBox(width: 12),
                Expanded(child: Text('Week review', style: t(17, w: w6))),
                Text('${shortDate(ws)} – ${shortDate(ws.add(const Duration(days: 6)))}', style: t(13, c: C.muted)),
              ]),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(24)),
                child: Col([
                  Text('This week', style: t(13, c: C.darkMuted)),
                  if (goals.isEmpty) Text('Add a goal to see your week here.', style: t(14, c: C.white)),
                  for (final g in goals)
                    Builder(builder: (_) {
                      final p = (s.goalProgress(g)['week']! / s.goalTargets(g)['week']!).clamp(0.0, 1.0);
                      return Col([
                        Row(children: [Expanded(child: Text('${g['title']}', style: t(13, c: C.white))), Text('${(p * 100).round()}%', style: t(13, w: w6, c: C.lime))]),
                        Bar(p, height: 6, color: C.lime, track: C.dark3),
                      ], space: 6);
                    }),
                ], space: 10),
              ),
              for (final x in q)
                if (x.$3.isNotEmpty)
                  Panel(
                    title: x.$1,
                    child: Chips(options: x.$3, selected: {a[x.$2] ?? ''}, onTap: (o) => setState(() => a[x.$2] = o)),
                  ),
              PressPill('Save review', success: true, onTap: () {
                s.patchDay({'review': a});
                Navigator.pop(context);
                toast(context, a['next'] == null ? 'Review saved.' : "Review saved. Next week's focus: ${a['next']}.");
              }),
            ]), 14),
          ),
        ),
      ),
    );
  }
}
