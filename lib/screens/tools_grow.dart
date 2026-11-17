import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/life.dart';
import '../services/notify_service.dart';
import '../services/store.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import '../widgets/ui.dart';
import 'tools.dart';

// ------------------------------------------------------------------ Journal
const prompts = [
  'What made you smile today?',
  'What is one thing you learned today?',
  'Who helped you today, and how?',
  'What would make tomorrow great?',
  'What are you proud of this week?',
  'What worried you, and is it still big?',
  'Which dua do you want answered?',
];

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});
  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  late final text = TextEditingController(text: '${store(context, listen: false).day()['text'] ?? ''}');

  void _edit(Store s, Json d) {
    final c = TextEditingController(text: '${d['text'] ?? ''}');
    var type = '${d['dayType'] ?? ''}';
    showSheet(context, niceDate(parseDay('${d['id']}')), (ctx, set) => Col([
          Chips(options: const ['Positive', 'Neutral', 'Negative'], selected: {type}, onTap: (v) => set(() => type = type == v ? '' : v)),
          SoftField(controller: c, hint: 'What happened?', lines: 5),
          PressPill('Save', success: true, onTap: () {
            s.patchDay({'text': c.text.trim(), 'dayType': type.isEmpty ? null : type}, '${d['id']}');
            if (d['id'] == todayKey) text.text = c.text.trim();
            Navigator.pop(ctx);
          }),
        ], space: 12));
  }

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final streak = journalStreak(s);
    final type = '${s.day()['dayType'] ?? ''}';
    final grat = ((s.day()['grateful'] as List?) ?? const []).map((e) => '$e').toSet();
    final entries = s.list('days').where((d) => '${d['text'] ?? ''}'.trim().isNotEmpty).toList()..sort((a, b) => '${b['id']}'.compareTo('${a['id']}'));
    final doy = DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    return ToolFrame('journal', children: [
      HeroCard(
        label: 'Streak',
        big: '$streak day${streak == 1 ? '' : 's'}',
        sub: 'Just 3 lines a day',
        dots: [for (var i = 0; i < 7; i++) ('${s.day(s.last7[i])['text'] ?? ''}'.trim().isNotEmpty, s.last7Letters[i])],
      ),
      Panel(
        title: 'How was the day?',
        hint: 'tap again to clear',
        child: Chips(options: const ['Positive', 'Neutral', 'Negative'], selected: {type}, onTap: (v) => s.patchDay({'dayType': type == v ? null : v})),
      ),
      NoteCard("Today's prompt", prompts[doy % prompts.length]),
      Panel(
        title: 'Grateful for',
        hint: 'pick any',
        child: Chips(
          options: const ['Family', 'Health', 'Iman', 'Work', 'Friends', 'Good food'],
          selected: grat,
          onTap: (v) => s.patchDay({'grateful': grat.contains(v) ? (grat..remove(v)).toList() : [...grat, v]}),
        ),
      ),
      Panel(title: 'Write a little', child: SoftField(controller: text, hint: 'Two or three lines is enough…')),
      PressPill('Save entry', success: true, onTap: () {
        if (text.text.trim().isEmpty) {
          say(context, 'Write a line first.', good: false);
          return;
        }
        final first = '${s.day()['text'] ?? ''}'.trim().isEmpty;
        s.patchDay({'text': text.text.trim()});
        FocusScope.of(context).unfocus();
        toast(context, first ? 'Saved. ${streak + 1} day streak!' : 'Saved.');
      }),
      RowsPanel(title: 'Daily journal', hint: 'tap to edit · swipe ← to delete', empty: 'Your entries show here.', rows: [
        for (final d in entries.take(40))
          Row2(
            swipeId: 'journal-${d['id']}',
            title: '${d['text']}'.split('\n').first,
            sub: [d['id'] == todayKey ? 'Today' : shortDate(parseDay('${d['id']}')), if (d['dayType'] != null) '${d['dayType']}', if ((d['grateful'] as List?)?.isNotEmpty == true) '${(d['grateful'] as List).first}'].join(' · '),
            onTap: () => _edit(s, d),
            onDots: () => showMenuSheet(context, shortDate(parseDay('${d['id']}')), [
              MenuItem('Edit', Icons.edit_outlined, () => _edit(s, d)),
              MenuItem('Delete', Icons.delete_outline_rounded, () => s.patchDay({'text': null}, '${d['id']}'), danger: true),
            ]),
            onDelete: () {
              s.patchDay({'text': null}, '${d['id']}');
              if (d['id'] == todayKey) text.clear();
            },
            onUndo: () => s.patchDay({'text': d['text']}, '${d['id']}'),
          ),
      ]),
    ]);
  }
}

// ------------------------------------------------------------------ Focus
/// Lives outside the page so the timer keeps going when you leave it.
class FocusTimer {
  static DateTime? endsAt;
  static int? pausedLeft; // seconds
  static int mins = 25;
  static String label = 'Work';
}

class FocusPage extends StatefulWidget {
  const FocusPage({super.key});
  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> {
  Timer? tick;

  @override
  void initState() {
    super.initState();
    tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    WidgetsBinding.instance.addPostFrameCallback((_) => _onTick());
  }

  @override
  void dispose() {
    tick?.cancel();
    super.dispose();
  }

  int get left {
    final e = FocusTimer.endsAt;
    if (e != null) return e.difference(DateTime.now()).inSeconds.clamp(0, 99999);
    return FocusTimer.pausedLeft ?? FocusTimer.mins * 60;
  }

  bool get running => FocusTimer.endsAt != null;

  void _onTick() {
    if (!mounted) return;
    final e = FocusTimer.endsAt;
    if (e != null && !DateTime.now().isBefore(e)) {
      FocusTimer.endsAt = null;
      FocusTimer.pausedLeft = null;
      store(context, listen: false).add('focus', {'day': todayKey, 'mins': FocusTimer.mins, 'label': FocusTimer.label});
      Haptic.celebrate();
      toast(context, 'Session done! +${FocusTimer.mins} focus minutes.');
    }
    setState(() {});
  }

  void startPause() {
    if (running) {
      FocusTimer.pausedLeft = left;
      FocusTimer.endsAt = null;
      NotifyService.cancelFocus();
    } else {
      FocusTimer.endsAt = DateTime.now().add(Duration(seconds: left));
      FocusTimer.pausedLeft = null;
      NotifyService.focusDoneAt(FocusTimer.endsAt!, FocusTimer.label);
    }
    setState(() {});
  }

  void reset([int? mins]) {
    if (mins != null) FocusTimer.mins = mins;
    FocusTimer.endsAt = null;
    FocusTimer.pausedLeft = null;
    NotifyService.cancelFocus();
    setState(() {});
  }

  String mins(int m) => m >= 60 ? '${m ~/ 60}h ${(m % 60).toString().padLeft(2, '0')}m' : '${m}m';

  Widget _tile(String k, String v, Color bg) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: t(11, c: bg == C.lime ? C.onLime : C.muted)),
          const SizedBox(height: 2),
          Text(v, style: t(17, w: w6, c: bg == C.lime ? C.onLime : C.ink)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final l = left;
    final all = s.list('focus');
    final totalAll = all.fold<int>(0, (a, f) => a + ((f['mins'] ?? 0) as num).toInt());
    final week = all.where((f) => '${f['day']}'.compareTo(dayKey(weekStart)) >= 0).fold<int>(0, (a, f) => a + ((f['mins'] ?? 0) as num).toInt());
    final byDay = <String, List<Json>>{};
    for (final f in all) {
      byDay.putIfAbsent('${f['day']}', () => []).add(f);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return ToolFrame('focus', children: [
      HeroCard(
        label: FocusTimer.label,
        big: running ? 'Stay with it' : (FocusTimer.pausedLeft != null ? 'Paused' : 'Ready?'),
        sub: 'Today ${mins(s.focusOn(todayKey))} · Total ${mins(totalAll)}',
        ring: 1 - l / (FocusTimer.mins * 60),
        ringText: '${(l ~/ 60).toString().padLeft(2, '0')}:${(l % 60).toString().padLeft(2, '0')}',
        btns: [HeroBtn(running ? 'Pause' : 'Start', startPause, primary: true), HeroBtn('Reset', () => reset())],
      ),
      Panel(
        title: 'Length',
        hint: 'minutes',
        child: Chips(options: const ['15 min', '25 min', '45 min', '60 min'], selected: {'${FocusTimer.mins} min'}, onTap: (v) => reset(int.parse(v.split(' ').first))),
      ),
      Panel(title: 'What for', child: Chips(options: const ['Work', 'Study', 'Quran', 'Reading'], selected: {FocusTimer.label}, onTap: (v) => setState(() => FocusTimer.label = v))),
      Row(children: gap([
        Expanded(child: _tile('Today', mins(s.focusOn(todayKey)), C.white)),
        Expanded(child: _tile('This week', mins(week), C.white)),
        Expanded(child: _tile('All time', mins(totalAll), C.lime)),
      ], 8)),
      RowsPanel(title: 'Daily focus', hint: 'swipe ← to delete a day', empty: 'No session yet. Press Start.', rows: [
        for (final k in days.take(30))
          Row2(
            swipeId: 'focus-$k',
            title: k == todayKey ? 'Today' : niceDate(parseDay(k)),
            sub: () {
              final m = <String, int>{};
              for (final f in byDay[k]!) {
                final l = '${f['label'] ?? ''}'.isEmpty ? 'Focus' : '${f['label']}';
                m[l] = (m[l] ?? 0) + ((f['mins'] ?? 0) as num).toInt();
              }
              return m.entries.map((e) => '${e.key} ${mins(e.value)}').join(' · ');
            }(),
            right: mins(byDay[k]!.fold<int>(0, (a, f) => a + ((f['mins'] ?? 0) as num).toInt())),
            onDots: () => showMenuSheet(context, k == todayKey ? 'Today' : niceDate(parseDay(k)), [
              MenuItem('Add minutes by hand', Icons.add_rounded, () async {
                final v = await askNumber(context, 'Minutes', '25');
                if (v != null && v > 0) s.add('focus', {'day': k, 'mins': v.round(), 'label': FocusTimer.label});
              }),
              MenuItem('Delete this day', Icons.delete_outline_rounded, () {
                for (final f in byDay[k]!) {
                  s.remove('focus', f['id'] as String);
                }
              }, danger: true),
            ]),
            onDelete: () {
              for (final f in byDay[k]!) {
                s.remove('focus', f['id'] as String);
              }
            },
            onUndo: () {
              for (final f in byDay[k]!) {
                s.save('focus', f);
              }
            },
          ),
      ]),
    ]);
  }
}

// ------------------------------------------------------------------ Learn
/// kind: (icon, default unit)
const learnKinds = <String, (IconData, String)>{
  'Book': (Icons.menu_book_rounded, 'pages'),
  'Course': (Icons.cast_for_education_outlined, 'lessons'),
  'YouTube': (Icons.smart_display_outlined, 'videos'),
  'Podcast': (Icons.podcasts_rounded, 'episodes'),
  'Quran': (Icons.auto_stories_outlined, 'pages'),
  'Skill': (Icons.code_rounded, 'hours'),
  'Article': (Icons.article_outlined, 'articles'),
  'Other': (Icons.lightbulb_outline_rounded, 'parts'),
};

class LearnPage extends StatelessWidget {
  const LearnPage({super.key});

  /// Books used their own collection before; everything new lives in courses.
  static List<(String col, Json item)> items(Store s) => [
        for (final c in s.list('courses')) ('courses', c),
        for (final b in s.list('books').where((b) => b['done'] != true)) ('books', b),
      ];

  static String unitOf(String col, Json x) => col == 'books' ? 'pages' : '${x['unit'] ?? learnKinds['${x['kind']}']?.$2 ?? 'lessons'}';
  static int doneOf(String col, Json x) => (((col == 'books' ? x['page'] : x['done']) ?? 0) as num).toInt();
  static int totalOf(String col, Json x) => (((col == 'books' ? x['pages'] : x['total']) ?? 1) as num).toInt();

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final list = items(s);
    int doneOn(String k) => s.list('courses').fold(0, (a, c) => a + (((c['logs'] as Map? ?? {})[k] ?? 0) as num).toInt());
    final week = [for (final k in s.last7) doneOn(k).toDouble()];
    return ToolFrame('learn', children: [
      HeroCard(
        label: 'This week',
        big: '${week.reduce((a, b) => a + b).round()} done',
        sub: '${list.length} thing${list.length == 1 ? '' : 's'} going · log pages, lessons or videos',
        bars: [for (var i = 0; i < 7; i++) (week[i], s.last7Letters[i])],
      ),
      Panel(
        title: 'Add something',
        child: GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.95,
          children: [
            for (final k in learnKinds.entries)
              Press(
                onTap: () => editLearn(context, s, kind: k.key),
                label: 'Add ${k.key}',
                child: Container(
                  decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(18)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 34, height: 34, decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(12)), child: Icon(k.value.$1, size: 18)),
                    const SizedBox(height: 6),
                    Text(k.key, style: t(11, w: w6)),
                  ]),
                ),
              ),
          ],
        ),
      ),
      RowsPanel(title: 'My learning', hint: 'swipe ← to delete', empty: 'Nothing yet. Tap a type above.', rows: [
        for (final (col, x) in list)
          Row2(
            swipeId: 'learn-${x['id']}',
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: const Color(0xFFEFEDFF), borderRadius: BorderRadius.circular(12)),
              child: Icon(col == 'books' ? Icons.menu_book_rounded : (learnKinds['${x['kind']}']?.$1 ?? Icons.school_outlined), size: 18, color: const Color(0xFF4A3FB0)),
            ),
            title: '${x['name'] ?? x['title']}',
            sub: '${col == 'books' ? 'Book' : (x['kind'] ?? 'Course')} · ${doneOf(col, x)} of ${totalOf(col, x)} ${unitOf(col, x)}',
            progress: doneOf(col, x) / (totalOf(col, x) == 0 ? 1 : totalOf(col, x)),
            trailing: Press(
              onTap: () => logLearn(context, s, col, x),
              label: 'Log ${x['name'] ?? x['title']}',
              child: Container(height: 34, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: C.lime, borderRadius: BorderRadius.circular(999)), child: Center(widthFactor: 1, child: Text('+ Log', style: t(12.5, w: w6, c: C.onLime)))),
            ),
            onDots: () => showMenuSheet(context, '${x['name'] ?? x['title']}', [
              MenuItem('Log progress', Icons.add_rounded, () => logLearn(context, s, col, x)),
              MenuItem('Edit', Icons.edit_outlined, () => editLearn(context, s, col: col, item: x)),
              MenuItem('Delete', Icons.delete_outline_rounded, () => s.remove(col, x['id'] as String), danger: true),
            ]),
            onDelete: () => s.remove(col, x['id'] as String),
            onUndo: () => s.save(col, x),
          ),
      ]),
    ]);
  }
}

/// How many pages / lessons / videos you did.
void logLearn(BuildContext context, Store s, String col, Json x) {
  final unit = LearnPage.unitOf(col, x);
  final done = LearnPage.doneOf(col, x), total = LearnPage.totalOf(col, x);
  var add = unit == 'pages' ? 10 : 1;
  showSheet(context, 'Log ${x['name'] ?? x['title']}', (ctx, set) => Col([
        Text('Now $done of $total $unit', style: t(13, c: C.muted)),
        Stepper2(value: '+$add', unit: unit, onMinus: () => set(() => add = math.max(1, add - 1)), onPlus: () => set(() => add++), onType: (v) => set(() => add = math.max(1, v.round()))),
        Chips(options: unit == 'pages' ? const ['+5', '+10', '+20', '+50'] : const ['+1', '+2', '+3', '+5'], selected: {'+$add'}, onTap: (v) => set(() => add = int.parse(v.substring(1)))),
        PressPill('Save', success: true, onTap: () {
          final n = math.min(total, done + add);
          if (col == 'books') {
            s.patch('books', x['id'] as String, {'page': n, 'done': n >= total, if (n >= total) 'finishedAt': DateTime.now().millisecondsSinceEpoch});
          } else {
            final logs = Map<String, dynamic>.from(x['logs'] as Map? ?? {});
            logs[todayKey] = ((logs[todayKey] ?? 0) as num) + add;
            s.patch('courses', x['id'] as String, {'done': n, 'logs': logs});
          }
          if (n >= total) Haptic.celebrate();
          Navigator.pop(ctx);
          toast(context, n >= total ? 'Finished! MashaAllah.' : '+$add $unit · $n of $total');
        }),
      ], space: 12));
}

/// Add or edit a book, course, video series…
void editLearn(BuildContext context, Store s, {String kind = 'Course', String? col, Json? item}) {
  final name = TextEditingController(text: '${item?['name'] ?? item?['title'] ?? ''}');
  var k = col == 'books' ? 'Book' : '${item?['kind'] ?? kind}';
  var unit = item == null ? learnKinds[k]!.$2 : LearnPage.unitOf(col!, item);
  var total = item == null ? (unit == 'pages' ? 300 : 20) : LearnPage.totalOf(col!, item);
  showSheet(context, item == null ? 'New $k' : 'Edit', (ctx, set) => Col([
        SoftField(controller: name, hint: k == 'Book' ? 'Atomic Habits' : k == 'YouTube' ? 'Arabic for beginners' : 'Flutter course', pill: true),
        Chips(options: learnKinds.keys.toList(), selected: {k}, onTap: (v) => set(() {
              k = v;
              unit = learnKinds[v]!.$2;
            })),
        Text('Counted in', style: t(14, w: w6)),
        Chips(options: {...['pages', 'chapters', 'lessons', 'modules', 'videos', 'episodes', 'hours'], unit}.toList(), selected: {unit}, onTap: (v) => set(() => unit = v)),
        Text('How many in total', style: t(14, w: w6)),
        Stepper2(value: '$total', unit: unit, onMinus: () => set(() => total = math.max(1, total - (unit == 'pages' ? 10 : 1))), onPlus: () => set(() => total += unit == 'pages' ? 10 : 1), onType: (v) => set(() => total = math.max(1, v.round()))),
        PressPill('Save', success: true, onTap: () {
          final n = name.text.trim();
          if (n.isEmpty) return;
          if (item == null) {
            s.add('courses', {'name': n, 'kind': k, 'unit': unit, 'total': total, 'done': 0, 'logs': <String, dynamic>{}});
          } else if (col == 'books') {
            s.patch('books', item['id'] as String, {'title': n, 'pages': total});
          } else {
            s.patch('courses', item['id'] as String, {'name': n, 'kind': k, 'unit': unit, 'total': total});
          }
          Navigator.pop(ctx);
        }),
      ], space: 12));
}

// ------------------------------------------------------------------ Rewards
class RewardsPage extends StatelessWidget {
  const RewardsPage({super.key});
  static const defaults = [('Coffee out', 150), ('New book', 300), ('Movie night', 400), ('Day off from goals', 500)];

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final pts = s.points;
    final badges = <(String, bool)>[
      ('Fajr 7 days', s.last7.every((k) => s.prayedOn(k).contains('Fajr'))),
      ('First goal', s.list('goals').any((g) => (g['logs'] as Map? ?? {}).isNotEmpty)),
      ('Hydrated week', s.last7.every((k) => s.waterOn(k) >= s.waterGoal)),
      ('Early bird', s.list('days').any((d) => '${d['wake'] ?? '99'}'.compareTo('05:31') < 0)),
      ('30 day streak', s.dayStreak >= 30),
      ('Bookworm', s.list('books').any((b) => b['done'] == true)),
      ('Focus 10h', s.list('focus').fold<num>(0, (a, f) => a + ((f['mins'] ?? 0) as num)) >= 600),
      ('Khatam', s.list('goals').any((g) => '${g['unit']}' == 'juz' && s.goalProgress(g)['year']! >= s.goalTarget(g))),
    ];
    final mine = s.list('rewards');
    final treats = mine.isEmpty ? [for (final d in defaults) (d.$1, d.$2, null as String?)] : [for (final r in mine) ('${r['name']}', ((r['cost'] ?? 0) as num).toInt(), r['id'] as String?)];
    return ToolFrame('rewards', children: [
      HeroCard(tone: HeroTone.lime, label: 'Points to spend', big: '$pts points', sub: 'Level ${s.lvl} · ${s.xpInLevel} / 1000 XP', ring: s.xpInLevel / 1000, ringText: 'LV ${s.lvl}'),
      Panel(
        title: 'Badges',
        hint: '${badges.where((b) => b.$2).length} of ${badges.length}',
        child: GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.82,
          children: [
            for (final b in badges)
              Press(
                onTap: () => toast(context, b.$2 ? '${b.$1} · earned' : '${b.$1} · keep going'),
                haptic: b.$2 ? Haptic.success : Haptic.tap,
                label: '${b.$1}${b.$2 ? ' earned' : ' locked'}',
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: b.$2 ? C.ink : C.chip, borderRadius: BorderRadius.circular(18)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(b.$2 ? Icons.workspace_premium_rounded : Icons.lock_outline_rounded, size: 22, color: b.$2 ? C.lime : C.border),
                    const SizedBox(height: 4),
                    Text(b.$1, textAlign: TextAlign.center, maxLines: 2, style: t(10.5, w: w6, c: b.$2 ? C.lime : const Color(0xFF8A8A84), h: 1.2)),
                  ]),
                ),
              ),
          ],
        ),
      ),
      RowsPanel(title: 'Treat yourself', hint: 'hold to delete', rows: [
        for (final r in treats)
          Row2(
            title: r.$1,
            sub: '${r.$2} points',
            trailing: Press(
              onTap: () {
                if (pts < r.$2) {
                  say(context, 'Need ${r.$2 - pts} more points.', good: false);
                  return;
                }
                s.add('redeems', {'name': r.$1, 'cost': r.$2, 'day': todayKey});
                Haptic.celebrate();
                toast(context, 'Enjoy: ${r.$1}!');
              },
              haptic: () {},
              label: 'Redeem ${r.$1}',
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: pts >= r.$2 ? C.lime : C.chip, borderRadius: BorderRadius.circular(999)),
                child: Text('Redeem', style: t(13, w: w6, c: pts >= r.$2 ? C.ink : const Color(0xFF8A8A84))),
              ),
            ),
            onLongPress: r.$3 == null
                ? null
                : () async {
                    if (await confirm(context, 'Delete ${r.$1}?')) s.remove('rewards', r.$3!);
                  },
          ),
      ]),
      PressPill('+ Add a treat', bg: C.white, fg: C.ink, height: 50, onTap: () {
        final name = TextEditingController();
        var cost = 200;
        showSheet(context, 'New treat', (ctx, set) => Col([
              SoftField(controller: name, hint: 'Biryani night', pill: true),
              Stepper2(value: '$cost', unit: 'points', onMinus: () => set(() => cost = (cost - 50).clamp(50, 99999)), onPlus: () => set(() => cost += 50)),
              PressPill('Add treat', success: true, onTap: () {
                if (name.text.trim().isEmpty) return;
                if (mine.isEmpty) {
                  for (final d in defaults) {
                    s.add('rewards', {'name': d.$1, 'cost': d.$2});
                  }
                }
                s.add('rewards', {'name': name.text.trim(), 'cost': cost});
                Navigator.pop(ctx);
              }),
            ], space: 12));
      }),
      const NoteCard('How to earn', '+10 each prayer · +10 each goal step · +5 each habit · +5 journal entry'),
    ]);
  }
}
