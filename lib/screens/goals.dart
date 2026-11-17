import 'package:flutter/material.dart';
import '../services/store.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import '../widgets/ui.dart';
import 'goal_detail.dart';
import 'shell.dart';

const areas = ['Health', 'Faith', 'Learn', 'Work', 'Family', 'Money', 'Self'];

/// How many times a year each period happens.
const periods = {'Daily': 365, 'Weekly': 52, 'Half monthly': 24, 'Monthly': 12, 'Quarterly': 4, 'Half yearly': 2, 'Yearly': 1};

const goalIcons = <String, IconData>{
  'book': Icons.menu_book_rounded,
  'weight': Icons.monitor_weight_outlined,
  'quran': Icons.auto_stories_outlined,
  'money': Icons.savings_outlined,
  'steps': Icons.directions_walk_rounded,
  'workout': Icons.fitness_center_rounded,
  'learn': Icons.school_outlined,
  'sleep': Icons.bedtime_outlined,
  'water': Icons.water_drop_outlined,
  'income': Icons.attach_money_rounded,
  'family': Icons.family_restroom_rounded,
  'star': Icons.star_outline_rounded,
  'heart': Icons.favorite_border_rounded,
  'leaf': Icons.eco_outlined,
  'plane': Icons.flight_takeoff_rounded,
  'camera': Icons.photo_camera_outlined,
  'bolt': Icons.bolt_rounded,
  'fire': Icons.local_fire_department_outlined,
  'home': Icons.home_outlined,
  'music': Icons.music_note_outlined,
  'brush': Icons.brush_outlined,
  'code': Icons.code_rounded,
  'pets': Icons.pets_outlined,
  'flag': Icons.flag_outlined,
};

const customIcons = ['star', 'heart', 'leaf', 'plane', 'camera', 'bolt', 'fire', 'home', 'music', 'brush', 'code', 'pets'];

/// name: icon, unit, period, amount, area, (logUnit, perUnit)
const goalTemplates = <String, Map<String, dynamic>>{
  'Read books': {'icon': 'book', 'unit': 'books', 'period': 'Yearly', 'amount': 24, 'area': 'Learn', 'logUnit': 'pages', 'perUnit': 300},
  'Lose weight': {'icon': 'weight', 'unit': 'kg', 'period': 'Yearly', 'amount': 8, 'area': 'Health'},
  'Quran': {'icon': 'quran', 'unit': 'pages', 'period': 'Yearly', 'amount': 604, 'area': 'Faith'},
  'Save money': {'icon': 'money', 'unit': 'tk', 'period': 'Yearly', 'amount': 100000, 'area': 'Money'},
  'Walk': {'icon': 'steps', 'unit': 'steps', 'period': 'Daily', 'amount': 8000, 'area': 'Health'},
  'Workout': {'icon': 'workout', 'unit': 'workouts', 'period': 'Weekly', 'amount': 3, 'area': 'Health'},
  'Learn a skill': {'icon': 'learn', 'unit': 'lessons', 'period': 'Quarterly', 'amount': 40, 'area': 'Learn'},
  'Sleep early': {'icon': 'sleep', 'unit': 'nights', 'period': 'Monthly', 'amount': 20, 'area': 'Health'},
  'Drink water': {'icon': 'water', 'unit': 'glasses', 'period': 'Daily', 'amount': 8, 'area': 'Health'},
  'Side income': {'icon': 'income', 'unit': r'$', 'period': 'Monthly', 'amount': 500, 'area': 'Money'},
  'Family time': {'icon': 'family', 'unit': 'hours', 'period': 'Weekly', 'amount': 10, 'area': 'Family'},
  'Custom': {'icon': 'star', 'unit': 'times', 'period': 'Yearly', 'amount': 10, 'area': 'Self'},
};

const units = ['books', 'pages', 'kg', 'tk', r'$', 'steps', 'lessons', 'hours', 'times'];

const levels = {'Year': 'year', 'Month': 'month', 'Week': 'week', 'Today': 'day'};

IconData goalIcon(Json g) => goalIcons['${g['icon']}'] ?? Icons.flag_outlined;

/// Times a year for a goal's period (Custom = every N days).
double perYear(Json g) {
  final p = '${g['period'] ?? 'Yearly'}';
  if (p == 'Custom') return 365 / (((g['customDays'] ?? 30) as num).clamp(1, 3650));
  return (periods[p] ?? 1).toDouble();
}

String periodLabel(Json g) {
  final p = '${g['period'] ?? 'Yearly'}';
  return p == 'Custom' ? 'every ${g['customDays'] ?? 30} days' : p.toLowerCase();
}

extension GoalMath on Store {
  bool onTrack(Json g) => goalBehind(g) <= goalTarget(g) * 0.01;

  /// "9 / 24 books" for a level; week and day use the small unit (pages) when there is one.
  String goalPair(Json g, String level) {
    final p = goalProgress(g)[level]!, tg = goalTargets(g)[level]!;
    return '${amountText(g, p, small: level == 'week' || level == 'day', unit: false)} / ${amountText(g, tg, small: level == 'week' || level == 'day')}';
  }

  /// Ahead/behind in plain words.
  String paceText(Json g) {
    final b = goalBehind(g);
    if (b.abs() < goalTarget(g) * 0.01) return 'Right on plan';
    return b > 0 ? '${amountText(g, b, small: b < 1)} behind plan' : '${amountText(g, -b, small: -b < 1)} ahead of plan';
  }

  // ---- day-by-day small steps
  String planOf(Json g) => '${g['plan'] ?? 'none'}'; // day, week, month, none

  List<DateTime> planDays(Json g) {
    final now = DateTime.now();
    if (planOf(g) == 'month') {
      final last = DateTime(now.year, now.month + 1, 0).day;
      return [for (var d = 1; d <= last; d++) DateTime(now.year, now.month, d)];
    }
    final ws = weekStart;
    return [for (var i = 0; i < 7; i++) ws.add(Duration(days: i))];
  }

  /// Planned amount for one day (in goal units). 0 = skipped.
  num stepAmount(Json g, DateTime d) {
    final over = (g['planAmounts'] as Map? ?? {})[dayKey(d)];
    if (over is num) return over;
    final tg = goalTargets(g);
    return switch (planOf(g)) { 'week' => tg['week']! / 7, 'month' => tg['month']! / planDays(g).length, _ => tg['day']! };
  }

  num loggedOn(Json g, String k) => ((g['logs'] as Map? ?? {})[k] ?? 0) as num;

  void setGoalLog(Json g, String k, num v) {
    final logs = Map<String, dynamic>.from(g['logs'] as Map? ?? {});
    v <= 0 ? logs.remove(k) : logs[k] = v;
    patch('goals', g['id'] as String, {'logs': logs});
  }

  void setStepAmount(Json g, String k, num? v) {
    final m = Map<String, dynamic>.from(g['planAmounts'] as Map? ?? {});
    v == null ? m.remove(k) : m[k] = v;
    patch('goals', g['id'] as String, {'planAmounts': m});
  }
}

/// "20 pages", "1.5 books", "3,000 tk". [small] uses the log unit (pages) when the goal has one.
String amountText(Json g, num v, {bool small = false, bool unit = true}) {
  final per = ((g['perUnit'] ?? 1) as num);
  if (small && per > 1) return '${fmtAmount((v * per).round())}${unit ? ' ${g['logUnit'] ?? ''}' : ''}';
  final u = '${g['unit'] ?? ''}';
  final n = fmtAmount(v);
  if (!unit) return n;
  return u == r'$' ? '\$$n' : '$n $u';
}

String fmtAmount(num v) {
  if (v.abs() >= 1000) return v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.abs() < 1 ? v.toStringAsFixed(2) : v.toStringAsFixed(1);
}

String dayLabel(DateTime d) {
  final k = dayKey(d);
  final w = weekdaysLong[d.weekday - 1].substring(0, 3);
  return '$w ${d.day} ${months[d.month - 1]}${k == todayKey ? ' · today' : ''}';
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
                Text('All goals together', style: t(12, c: C.accentOnInk)),
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
          Text(k, style: t(12, w: bg == C.lime ? w6 : FontWeight.w400, c: bg == C.lime ? C.onLime : C.muted)),
          const SizedBox(height: 4),
          AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: Text(v, key: ValueKey(v), style: t(22, w: w6, c: bg == C.lime ? C.onLime : C.ink))),
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
    final today = DateTime.now();
    final step = s.planOf(g) == 'none' ? s.goalTargets(g)['day']! : s.stepAmount(g, today);
    final c = areaColors['${g['area'] ?? 'Self'}'] ?? (C.chip, C.ink);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(26)),
      child: Col([
        Press(
          onTap: () => push(context, GoalDetail(id: g['id'] as String)),
          scale: 0.98,
          label: '${g['title']}',
          child: Col([
            Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: c.$1, borderRadius: BorderRadius.circular(12)), child: Icon(goalIcon(g), size: 18, color: c.$2)),
              const SizedBox(width: 10),
              Expanded(child: Text('${g['title']}', style: t(17, w: w6, ls: -0.2), maxLines: 2, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              on ? Tag('On plan', bg: C.ink, fg: C.lime) : Tag('A bit behind', bg: C.warnSoft, fg: C.warn),
            ]),
            Row(children: [Expanded(child: Text(levelName, style: t(12.5, c: C.muted))), Text(s.goalPair(g, level), style: t(12.5, w: w6))]),
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
                  style: t(14.5, w: w6, c: done ? const Color(0xFF8E8E96) : C.ink, deco: done ? TextDecoration.lineThrough : null),
                  child: Text(step <= 0 ? 'Rest day' : amountText(g, step, small: true)),
                ),
              ]),
            ),
            TickCircle(
              done: done,
              size: 44,
              label: "today's step",
              onTap: () {
                final k = todayKey;
                done ? s.setGoalLog(g, k, 0) : s.setGoalLog(g, k, step > s.loggedOn(g, k) ? step : s.loggedOn(g, k));
                if (!done) say(context, 'Nice. Year, month, week and today all moved.');
              },
            ),
          ]),
        ),
      ], space: 12),
    );
  }
}

/// New goal, or edit one ([id]).
Future<void> addGoalPage(BuildContext context, {String? id}) => push(context, AddGoalPage(id: id));

class AddGoalPage extends StatefulWidget {
  final String? id;
  const AddGoalPage({super.key, this.id});
  @override
  State<AddGoalPage> createState() => _AddGoalPageState();
}

class _AddGoalPageState extends State<AddGoalPage> {
  String tpl = 'Read books';
  late Map<String, dynamic> d;
  final name = TextEditingController();
  final why = TextEditingController();
  bool edit = false;

  @override
  void initState() {
    super.initState();
    final g = widget.id == null ? null : store(context, listen: false).get('goals', widget.id!);
    if (g != null) {
      edit = true;
      d = Map<String, dynamic>.from(g);
      d['period'] ??= 'Yearly';
      d['amount'] ??= ((d['target'] ?? 1) as num);
      d['plan'] ??= 'none';
      tpl = goalTemplates.entries.firstWhere((e) => e.value['icon'] == d['icon'], orElse: () => goalTemplates.entries.last).key;
      name.text = '${g['title'] ?? ''}';
      why.text = '${g['why'] ?? ''}';
    } else {
      d = {...goalTemplates[tpl]!, 'plan': 'week'};
      name.text = _suggestName(tpl, d);
    }
  }

  String _suggestName(String k, Map<String, dynamic> m) {
    final a = fmtAmount(m['amount'] as num);
    final u = '${m['unit']}';
    final p = '${m['period']}';
    final when = p == 'Daily' ? 'a day' : p == 'Yearly' ? 'this year' : 'a ${p.toLowerCase().replaceAll('ly', '').replaceAll('dai', 'day')}';
    return switch (k) {
      'Read books' => 'Read $a books $when',
      'Lose weight' => 'Lose $a kg',
      'Quran' => 'Finish the Quran',
      'Save money' => 'Save $a tk $when',
      'Walk' => 'Walk $a steps $when',
      'Workout' => 'Work out $a times $when',
      'Custom' => '',
      _ => '$k · $a $u $when',
    };
  }

  /// Ideas from what you type.
  List<(String, Map<String, dynamic>)> _ideas(String q) {
    final x = q.toLowerCase();
    if (x.length < 2) return [];
    final out = <(String, Map<String, dynamic>)>[];
    final n = RegExp(r'\d[\d,]*').firstMatch(x)?.group(0)?.replaceAll(',', '');
    final num? amt = n == null ? null : num.tryParse(n);
    if (x.contains('read') || x.contains('book')) {
      out.add(('Read ${amt ?? 24} books this year', {'unit': 'books', 'period': 'Yearly', 'amount': amt ?? 24, 'icon': 'book', 'logUnit': 'pages', 'perUnit': 300}));
      out.add(('Read ${amt ?? 20} pages every day', {'unit': 'pages', 'period': 'Daily', 'amount': amt ?? 20, 'icon': 'book', 'logUnit': null, 'perUnit': null}));
    }
    if (x.contains('sav') || x.contains('tk') || x.contains('taka') || x.contains('money')) {
      out.add(('Save ${fmtAmount(amt ?? 100000)} tk this year', {'unit': 'tk', 'period': 'Yearly', 'amount': amt ?? 100000, 'icon': 'money'}));
      out.add(('Save ${fmtAmount(amt ?? 5000)} tk a month', {'unit': 'tk', 'period': 'Monthly', 'amount': amt ?? 5000, 'icon': 'money'}));
    }
    if (x.contains('walk') || x.contains('step')) out.add(('Walk ${fmtAmount(amt ?? 8000)} steps a day', {'unit': 'steps', 'period': 'Daily', 'amount': amt ?? 8000, 'icon': 'steps'}));
    if (x.contains('weight') || x.contains('kg') || x.contains('lose')) out.add(('Lose ${amt ?? 5} kg in 6 months', {'unit': 'kg', 'period': 'Half yearly', 'amount': amt ?? 5, 'icon': 'weight'}));
    if (x.contains('quran') || x.contains('juz')) out.add(('Read 2 pages of Quran a day', {'unit': 'pages', 'period': 'Daily', 'amount': 2, 'icon': 'quran'}));
    if (x.contains('earn') || x.contains(r'$') || x.contains('dollar') || x.contains('income')) out.add(('Earn \$${fmtAmount(amt ?? 500)} a month', {'unit': r'$', 'period': 'Monthly', 'amount': amt ?? 500, 'icon': 'income'}));
    if (x.contains('gym') || x.contains('work out') || x.contains('workout') || x.contains('exercise')) out.add(('Work out ${amt ?? 3} times a week', {'unit': 'workouts', 'period': 'Weekly', 'amount': amt ?? 3, 'icon': 'workout'}));
    if (x.contains('learn') || x.contains('course') || x.contains('lesson')) out.add(('Finish ${amt ?? 40} lessons in 3 months', {'unit': 'lessons', 'period': 'Quarterly', 'amount': amt ?? 40, 'icon': 'learn'}));
    return out.where((o) => o.$1.toLowerCase() != x).take(3).toList();
  }

  void _pickTpl(String k) {
    setState(() {
      tpl = k;
      final keepPlan = d['plan'];
      d = {...goalTemplates[k]!, 'plan': keepPlan};
      if (k == 'Save money') d['unit'] = '${store(context, listen: false).settings['currency'] ?? 'tk'}';
      if (!edit) name.text = _suggestName(k, d);
    });
  }

  @override
  Widget build(BuildContext context) {
    final unit = '${d['unit']}';
    final amount = (d['amount'] as num?) ?? 1;
    final year = amount * perYear(d);
    String r(num v) => fmtAmount(v < 1 ? (v * 100).round() / 100 : (v * 10).round() / 10);
    final stepSize = amount >= 10000 ? 1000 : amount >= 1000 ? 100 : amount >= 100 ? 10 : 1;
    final ideas = _ideas(name.text);
    final daysInMonth = DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: bgDecoration,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
            children: gap(stagger([
              Row(children: [const BackBtn(icon: Icons.close_rounded, label: 'Close'), const SizedBox(width: 12), Text(edit ? 'Edit goal' : 'New goal', style: t(17, w: w6))]),
              Panel(
                title: 'Start from',
                child: GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.86,
                  children: [for (final k in goalTemplates.keys) _iconCell(k, goalIcons[goalTemplates[k]!['icon']]!, tpl == k, () => _pickTpl(k))],
                ),
              ),
              if (tpl == 'Custom')
                Panel(
                  title: 'Choose an icon',
                  child: GridView.count(
                    crossAxisCount: 6,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      for (final ic in customIcons)
                        Press(
                          onTap: () => setState(() => d['icon'] = ic),
                          haptic: Haptic.select,
                          label: ic,
                          selected: d['icon'] == ic,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(color: d['icon'] == ic ? C.lime : C.chip, borderRadius: BorderRadius.circular(14)),
                            child: Icon(goalIcons[ic], size: 20, color: d['icon'] == ic ? C.onLime : C.ink),
                          ),
                        ),
                    ],
                  ),
                ),
              Panel(
                title: 'Goal name',
                hint: 'type, LifeOS suggests',
                child: Col([
                  SoftField(controller: name, hint: 'Read 24 books this year', pill: true, onChanged: (_) => setState(() {})),
                  for (final i in ideas)
                    Press(
                      onTap: () => setState(() {
                        name.text = i.$1;
                        i.$2.forEach((k, v) => v == null ? d.remove(k) : d[k] = v);
                      }),
                      label: i.$1,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(14)),
                        child: Row(children: [
                          const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF6E8A12)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(i.$1, style: t(13.5))),
                          Text('${i.$2['unit']} · ${'${i.$2['period']}'.toLowerCase()}', style: t(11, c: C.muted)),
                        ]),
                      ),
                    ),
                ], space: 8),
              ),
              Panel(
                title: 'Counted in',
                child: Chips(
                  options: [...{...units, if (!units.contains(unit)) unit}, 'Custom…'],
                  selected: {unit},
                  onTap: (u) {
                    if (u == 'Custom…') {
                      askLine(context, 'Your unit', 'minutes, km, chapters…', (v) => setState(() {
                            d['unit'] = v;
                            d.remove('perUnit');
                            d.remove('logUnit');
                          }));
                    } else {
                      setState(() {
                        d['unit'] = u;
                        if (u != 'books') {
                          d.remove('perUnit');
                          d.remove('logUnit');
                        } else {
                          d['logUnit'] = 'pages';
                          d['perUnit'] = 300;
                        }
                      });
                    }
                  },
                ),
              ),
              Panel(
                title: 'How often',
                child: Chips(
                  options: [...periods.keys, d['period'] == 'Custom' ? 'Every ${d['customDays']} days' : 'Custom…'],
                  selected: {d['period'] == 'Custom' ? 'Every ${d['customDays']} days' : '${d['period']}'},
                  onTap: (p) async {
                    if (p.startsWith('Every') || p == 'Custom…') {
                      final n = await askNumber(context, 'Every how many days?', '${d['customDays'] ?? 30}');
                      if (n != null && n >= 1) setState(() => d..['period'] = 'Custom'..['customDays'] = n.round());
                    } else {
                      setState(() => d['period'] = p);
                    }
                  },
                ),
              ),
              Panel(
                title: 'How much ${periodLabel(d)}',
                hint: 'tap the number to type',
                child: Stepper2(
                  value: fmtAmount(amount),
                  unit: unit,
                  size: 26,
                  onMinus: () => setState(() => d['amount'] = amount - stepSize <= 0 ? amount : amount - stepSize),
                  onPlus: () => setState(() => d['amount'] = amount + stepSize),
                  onType: (v) => setState(() => d['amount'] = v <= 0 ? amount : v),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: C.limeSoft, borderRadius: BorderRadius.circular(18)),
                child: Col([
                  Text('LifeOS suggests this split', style: t(12, w: w6, c: C.limeText)),
                  Text('${r(year)} a year · ${r(year / 12)} a month · ${r(year / 52)} a week · ${r(year / 365)} a day', style: t(13.5, w: w5, c: C.limeText, h: 1.45)),
                ], space: 4),
              ),
              Panel(
                title: 'Small steps',
                hint: 'each with a date, edit any day',
                child: Chips(
                  options: ['Every day', 'Weekly plan (7 steps)', 'Monthly plan ($daysInMonth steps)', 'No plan'],
                  selected: {
                    switch ('${d['plan']}') { 'day' => 'Every day', 'week' => 'Weekly plan (7 steps)', 'month' => 'Monthly plan ($daysInMonth steps)', _ => 'No plan' }
                  },
                  onTap: (v) => setState(() => d['plan'] = v.startsWith('Every') ? 'day' : v.startsWith('Weekly') ? 'week' : v.startsWith('Monthly') ? 'month' : 'none'),
                ),
              ),
              Panel(title: 'Life area', child: Chips(options: areas, selected: {'${d['area']}'}, onTap: (a) => setState(() => d['area'] = a))),
              Panel(
                title: 'Why it matters',
                hint: 'shows big on the goal page',
                child: Col([
                  SoftField(controller: why, hint: 'The deeper reason, for hard days', lines: 2),
                  Chips(options: const ['For my family', 'For my health', 'To grow', 'For Allah'], onTap: (w) => setState(() => why.text = why.text.isEmpty ? w : '${why.text} $w')),
                ], space: 10),
              ),
              PressPill(edit ? 'Save changes' : 'Create goal', success: true, onTap: () {
                final title = name.text.trim();
                if (title.isEmpty) {
                  say(context, 'Give the goal a name first.', good: false);
                  return;
                }
                final s = store(context, listen: false);
                final data = {...d, 'title': title, 'why': why.text.trim(), 'type': 'count', 'target': amount * perYear(d)}..remove('daily');
                if (edit) {
                  s.patch('goals', widget.id!, data..remove('id'));
                  Navigator.pop(context);
                  toast(context, 'Goal saved.');
                } else {
                  s.add('goals', {...data, 'logs': <String, dynamic>{}, 'planAmounts': <String, dynamic>{}});
                  Haptic.celebrate();
                  Navigator.pop(context);
                  toast(context, d['plan'] == 'none' ? 'Goal created.' : 'Goal created with dated small steps.');
                }
              }),
            ]), 12),
          ),
        ),
      ),
    );
  }

  Widget _iconCell(String name, IconData icon, bool on, VoidCallback onTap) => Press(
        onTap: onTap,
        haptic: Haptic.select,
        label: name,
        selected: on,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(color: on ? C.limeSoft : C.chip, borderRadius: BorderRadius.circular(18), border: Border.all(color: on ? C.ink : C.chip, width: 1.5)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: on ? C.lime : C.white, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 19, color: on ? C.onLime : C.ink),
            ),
            const SizedBox(height: 6),
            Text(name, textAlign: TextAlign.center, maxLines: 2, style: t(10.5, w: w6, h: 1.15)),
          ]),
        ),
      );
}

/// One line of text in a sheet.
void askLine(BuildContext context, String title, String hint, void Function(String v) onSave, {String initial = '', String button = 'Save'}) {
  final c = TextEditingController(text: initial);
  showSheet(context, title, (ctx, _) => Col([
        SoftField(controller: c, hint: hint, pill: true),
        PressPill(button, success: true, onTap: () {
          if (c.text.trim().isEmpty) return;
          onSave(c.text.trim());
          Navigator.pop(ctx);
        }),
      ], space: 12));
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
                        Row(children: [Expanded(child: Text('${g['title']}', style: t(13, c: C.white))), Text('${(p * 100).round()}%', style: t(13, w: w6, c: C.accentOnInk))]),
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
