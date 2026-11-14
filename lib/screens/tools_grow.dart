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

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final streak = journalStreak(s);
    final grat = ((s.day()['grateful'] as List?) ?? const []).map((e) => '$e').toSet();
    final past = s.list('days').where((d) => d['id'] != todayKey && '${d['text'] ?? ''}'.trim().isNotEmpty).toList()
      ..sort((a, b) => '${b['id']}'.compareTo('${a['id']}'));
    final doy = DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    return ToolFrame('journal', children: [
      HeroCard(
        label: 'Streak',
        big: '$streak day${streak == 1 ? '' : 's'}',
        sub: 'Just 3 lines a day',
        dots: [for (var i = 0; i < 7; i++) ('${s.day(s.last7[i])['text'] ?? ''}'.trim().isNotEmpty, s.last7Letters[i])],
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
      RowsPanel(title: 'Past entries', empty: 'Your entries show here.', rows: [
        for (final d in past.take(10))
          Row2(
            title: '${d['text']}'.split('\n').first,
            sub: '${shortDate(parseDay('${d['id']}'))}${(d['grateful'] as List?)?.isNotEmpty == true ? ' · ${(d['grateful'] as List).first}' : ''}',
            onTap: () => showSheet(context, shortDate(parseDay('${d['id']}')), (_, __) => Text('${d['text']}', style: t(15, h: 1.5))),
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

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final l = left;
    final todays = s.list('focus').where((f) => f['day'] == todayKey).toList();
    return ToolFrame('focus', children: [
      HeroCard(
        label: FocusTimer.label,
        big: running ? 'Stay with it' : (FocusTimer.pausedLeft != null ? 'Paused' : 'Ready?'),
        sub: '${s.focusOn(todayKey)} min focused today',
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
      RowsPanel(title: 'Today', empty: 'No session yet. Press Start.', rows: [
        for (final f in todays.reversed)
          Row2(title: '${f['label'] ?? 'Focus'}'.isEmpty ? 'Focus' : '${f['label']}', sub: hmA(DateTime.fromMillisecondsSinceEpoch(((f['createdAt'] ?? 0) as num).toInt())), right: '${f['mins']} min'),
      ]),
    ]);
  }
}

// ------------------------------------------------------------------ Learn
class LearnPage extends StatelessWidget {
  const LearnPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final courses = s.list('courses');
    final books = s.list('books').where((b) => b['done'] != true).toList();
    int lessonsOn(String k) => courses.fold(0, (a, c) => a + (((c['logs'] as Map? ?? {})[k] ?? 0) as num).toInt());
    final week = [for (final k in s.last7) lessonsOn(k).toDouble()];
    return ToolFrame('learn', children: [
      HeroCard(
        label: 'This week',
        big: '${week.reduce((a, b) => a + b).round()} lessons',
        sub: '${courses.length} courses · ${books.length} books going',
        bars: [for (var i = 0; i < 7; i++) (week[i], s.last7Letters[i])],
      ),
      RowsPanel(title: 'My learning', hint: 'tick = 1 done', empty: 'Nothing yet. Start something below.', rows: [
        for (final c in courses)
          (() {
            final logs = Map<String, dynamic>.from(c['logs'] as Map? ?? {});
            final today = logs[todayKey] != null;
            final done = ((c['done'] ?? 0) as num).toInt(), total = ((c['total'] ?? 1) as num).toInt();
            return Row2(
              title: '${c['name']}',
              sub: 'Lesson $done of $total${today ? ' · done today' : ''}',
              done: today,
              progress: done / (total == 0 ? 1 : total),
              onTick: () {
                if (today) {
                  logs.remove(todayKey);
                } else {
                  logs[todayKey] = 1;
                }
                s.patch('courses', c['id'] as String, {'logs': logs, 'done': (done + (today ? -1 : 1)).clamp(0, total)});
              },
              onLongPress: () async {
                if (await confirm(context, 'Delete ${c['name']}?')) s.remove('courses', c['id'] as String);
              },
            );
          })(),
        for (final b in books)
          (() {
            final page = ((b['page'] ?? 0) as num).toInt(), pages = ((b['pages'] ?? 300) as num).toInt();
            return Row2(
              title: '${b['title']}',
              sub: 'Page $page of $pages · tap to update',
              progress: page / (pages == 0 ? 1 : pages),
              onTap: () {
                var p = page;
                showSheet(context, '${b['title']}', (ctx, set) => Col([
                      Stepper2(value: '$p', unit: 'of $pages pages', onMinus: () => set(() => p = (p - 10).clamp(0, pages)), onPlus: () => set(() => p = (p + 10).clamp(0, pages))),
                      PressPill(p >= pages ? 'Finished it!' : 'Save', success: true, onTap: () {
                        s.patch('books', b['id'] as String, {'page': p, 'done': p >= pages, if (p >= pages) 'finishedAt': DateTime.now().millisecondsSinceEpoch});
                        if (p >= pages) Haptic.celebrate();
                        Navigator.pop(ctx);
                      }),
                    ], space: 12));
              },
            );
          })(),
      ]),
      Panel(
        title: 'Start something new',
        child: Chips(options: const ['Language', 'Quran', 'A skill', 'A book'], add: true, onTap: (k) => _add(context, s, k)),
      ),
    ]);
  }

  void _add(BuildContext context, Store s, String kind) {
    final name = TextEditingController();
    final book = kind == 'A book';
    var n = book ? 300 : 20;
    showSheet(context, book ? 'New book' : 'New $kind course', (ctx, set) => Col([
          SoftField(controller: name, hint: book ? 'Atomic Habits' : (kind == 'Quran' ? 'Tajweed' : 'Arabic basics'), pill: true),
          Stepper2(value: '$n', unit: book ? 'pages' : 'lessons', onMinus: () => set(() => n = (n - (book ? 20 : 5)).clamp(1, 5000)), onPlus: () => set(() => n += book ? 20 : 5)),
          PressPill('Add', success: true, onTap: () {
            final v = name.text.trim();
            if (v.isEmpty) return;
            book ? s.add('books', {'title': v, 'pages': n, 'page': 0, 'done': false}) : s.add('courses', {'name': v, 'total': n, 'done': 0, 'kind': kind, 'logs': <String, dynamic>{}});
            Navigator.pop(ctx);
          }),
        ], space: 12));
  }
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
      const NoteCard('How to earn', '+5 each habit · +10 each goal step · +5 journal entry · +2 each win'),
    ]);
  }
}
