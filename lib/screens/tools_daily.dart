import 'package:flutter/material.dart';
import '../services/life.dart';
import '../services/store.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import '../widgets/ui.dart';
import 'home.dart';
import 'tools.dart';

String clockOf(int m) {
  m = ((m % 1440) + 1440) % 1440;
  final h = m ~/ 60;
  return '${h % 12 == 0 ? 12 : h % 12}:${(m % 60).toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
}

/// Asks for one line of text in a sheet.
void askText(BuildContext context, String title, String hint, void Function(String v) onSave, {String initial = '', String button = 'Save'}) {
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

// ------------------------------------------------------------------ Prayer
class PrayerPage extends StatelessWidget {
  const PrayerPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final times = s.prayerTimes;
    final prayed = s.prayedOn();
    final next = s.nextPrayer;
    final mins = next.value.difference(DateTime.now()).inMinutes.clamp(0, 99999);
    final dhikr = ((s.day()['dhikr'] ?? 0) as num).toInt();
    final dName = '${s.settings['dhikr'] ?? 'SubhanAllah'}';
    final dTarget = ((s.settings['dhikrTarget'] ?? 33) as num).toInt();
    return ToolFrame('prayer', children: [
      HeroCard(
        label: 'Next prayer',
        big: '${next.key} · ${hmA(next.value)}',
        sub: 'in ${mins >= 60 ? '${mins ~/ 60}h ${mins % 60}m' : '${mins}m'} · ${s.cityName} · ${s.shafi ? 'Shafi' : 'Hanafi'}',
        dots: [for (final n in times.keys) (prayed.contains(n), n[0])],
      ),
      RowsPanel(title: 'Today', hint: '${prayed.length} of 5', rows: [
        for (final e in times.entries)
          Row2(
            title: e.key,
            sub: prayed.contains(e.key) ? 'Prayed · +10 XP' : 'Tap when you pray',
            right: hmA(e.value),
            done: prayed.contains(e.key),
            onTick: () {
              s.togglePrayer(e.key);
              if (!prayed.contains(e.key) && prayed.length == 4) say(context, 'All 5 prayers today. MashaAllah!');
            },
          ),
      ]),
      Panel(title: 'Prayed at', child: Chips(options: const ['Mosque', 'Home', 'Work'], selected: {'${s.day()['prayedAt'] ?? ''}'}, onTap: (v) => s.patchDay({'prayedAt': v}))),
      Panel(
        title: 'Dhikr counter',
        hint: 'tap +',
        child: Stepper2(
          value: '$dhikr / $dTarget',
          unit: dName,
          onMinus: () => s.patchDay({'dhikr': dhikr > 0 ? dhikr - 1 : 0}),
          onPlus: () {
            s.patchDay({'dhikr': dhikr + 1});
            if (dhikr + 1 == dTarget) {
              Haptic.celebrate();
              toast(context, '$dTarget done. MashaAllah!');
            }
          },
        ),
      ),
    ]);
  }
}

// ------------------------------------------------------------------ Habits
class HabitsPage extends StatelessWidget {
  const HabitsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final hs = s.list('habits');
    final done = s.habitsDoneToday;
    final best = hs.fold<int>(0, (a, h) => s.bestStreak(h) > a ? s.bestStreak(h) : a);
    final names = hs.map((h) => '${h['name']}'.toLowerCase()).toSet();
    final presets = ['Meditate 5 min', 'Stretch', 'Sleep by 11', 'Give sadaqah', 'Read Quran', 'Walk 20 min'].where((p) => !names.contains(p.toLowerCase())).toList();
    return ToolFrame('habits', children: [
      HeroCard(label: 'Today', big: '$done of ${hs.length} habits', sub: best > 0 ? 'Best streak $best days · keep going' : 'Tick one to start a streak', ring: hs.isEmpty ? 0 : done / hs.length),
      RowsPanel(
        title: 'My habits',
        hint: 'hold to edit',
        empty: 'No habits yet. Add one below.',
        rows: [
          for (final h in hs)
            Row2(
              title: '${h['name']}',
              sub: s.streak(h) > 0 ? '${s.streak(h)} day streak' : 'Start today',
              done: s.habitDone(h),
              onTick: () => s.toggleHabit(h),
              onLongPress: () => showSheet(context, '${h['name']}', (ctx, _) => Col([
                    PressPill('Rename', bg: C.chip, fg: C.ink, height: 52, onTap: () {
                      Navigator.pop(ctx);
                      askText(context, 'Rename habit', 'Habit name', (v) => s.patch('habits', h['id'] as String, {'name': v}), initial: '${h['name']}');
                    }),
                    PressPill('Delete habit', bg: C.warnSoft, fg: C.warn, height: 52, onTap: () async {
                      if (!await confirm(ctx, 'Delete ${h['name']}?')) return;
                      s.remove('habits', h['id'] as String);
                      if (ctx.mounted) Navigator.pop(ctx);
                    }),
                  ], space: 10)),
            ),
        ],
      ),
      Panel(
        title: 'Add a habit',
        child: Chips(
          options: [...presets.take(4), 'My own'],
          add: true,
          onTap: (n) {
            if (n == 'My own') {
              askText(context, 'New habit', 'Drink 8 glasses', (v) => s.add('habits', {'name': v, 'logs': <String, dynamic>{}}), button: 'Add habit');
            } else {
              s.add('habits', {'name': n, 'logs': <String, dynamic>{}});
              toast(context, '$n added.');
            }
          },
        ),
      ),
      HeroCard(
        tone: HeroTone.white,
        label: 'This week',
        big: '${(s.weekScore() * 100).round()}%',
        sub: 'Habits and goals done',
        bars: [for (final k in s.last7) (hs.where((h) => s.habitDone(h, k)).length.toDouble(), s.last7Letters[s.last7.indexOf(k)])],
        barMax: hs.isEmpty ? 1 : hs.length.toDouble(),
      ),
    ]);
  }
}

// ------------------------------------------------------------------ Water
class WaterPage extends StatelessWidget {
  const WaterPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final g = s.waterOn(), goal = s.waterGoal, ml = s.glassMl;
    final week = [for (final k in s.last7) s.waterOn(k).toDouble()];
    String l(num ml) => (ml / 1000).toStringAsFixed(ml % 1000 == 0 ? 0 : 1);
    return ToolFrame('water', children: [
      HeroCard(label: 'Today', big: '$g of $goal glasses', sub: '${l(g * ml)} L of ${l(goal * ml)} L', ring: g / goal),
      Panel(
        title: 'Tap a glass',
        hint: 'Goal $goal',
        child: GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.95,
          children: [
            for (var i = 0; i < goal; i++)
              Press(
                onTap: () {
                  s.setWater(i + 1 == g ? i : i + 1);
                  if (i + 1 == goal && g < goal) {
                    Haptic.celebrate();
                    toast(context, '$goal glasses! Goal done.');
                  }
                },
                haptic: Haptic.select,
                label: 'Glass ${i + 1}',
                scale: 0.88,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: C.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14), bottom: Radius.circular(22)),
                    border: Border.all(color: i < g ? C.ink : const Color(0xFFDAD8DF), width: 2),
                  ),
                  child: Stack(alignment: Alignment.bottomCenter, children: [
                    AnimatedContainer(duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic, height: i < g ? 48 : 0, color: const Color(0xFFBFE3F7)),
                    Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('${i + 1}', style: t(11, w: w6))),
                  ]),
                ),
              ),
          ],
        ),
      ),
      Panel(title: 'Glass size', hint: 'ml', child: Chips(options: const ['200', '250', '330', '500'], selected: {'$ml'}, onTap: (v) => s.setSetting('glass', int.parse(v)))),
      HeroCard(
        tone: HeroTone.white,
        label: 'This week',
        big: '${(week.reduce((a, b) => a + b) / 7).toStringAsFixed(1)} avg',
        sub: 'Glasses a day',
        bars: [for (var i = 0; i < 7; i++) (week[i], s.last7Letters[i])],
        barMax: goal.toDouble(),
      ),
    ]);
  }
}

// ------------------------------------------------------------------ Food
class FoodPage extends StatefulWidget {
  const FoodPage({super.key});
  @override
  State<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends State<FoodPage> {
  String meal = mealNow();
  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final eaten = s.foodOn(todayKey);
    final kcal = s.kcalOn(todayKey), goal = s.kcalGoal;
    final mine = s.list('foods')..sort((a, b) => ((b['uses'] ?? 0) as num).compareTo((a['uses'] ?? 0) as num));
    final quick = <(String, int)>[
      for (final f in mine.take(4)) ('${f['name']}', ((f['kcal'] ?? 0) as num).toInt()),
      for (final f in quickFoods) if (!mine.take(4).any((m) => '${m['name']}'.toLowerCase() == f.$1.toLowerCase())) f,
    ];
    return ToolFrame('food', children: [
      HeroCard(label: 'Today', big: '$kcal kcal', sub: '${(goal - kcal).clamp(0, 99999)} left of $goal · ${eaten.length} items', ring: kcal / goal),
      Panel(title: 'Meal', child: Chips(options: const ['Breakfast', 'Lunch', 'Snack', 'Dinner'], selected: {meal}, onTap: (m) => setState(() => meal = m))),
      Panel(
        title: 'Quick add',
        hint: 'one tap',
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in quick.take(9))
            Chip2('${f.$1}  ${f.$2}', add: true, onTap: () {
              addFood(s, f.$1, f.$2, meal);
              toast(context, '+${f.$2} kcal · ${f.$1}');
            }),
          Chip2('Other food', add: true, onTap: () => _other(context, s)),
        ]),
      ),
      RowsPanel(title: 'Eaten today', hint: 'hold to remove', empty: 'Nothing yet. Tap a food above.', rows: [
        for (final f in eaten.reversed)
          Row2(
            title: '${f['name']}',
            sub: '${f['meal'] ?? ''}',
            right: '${f['kcal']} kcal',
            onLongPress: () async {
              if (await confirm(context, 'Remove ${f['name']}?', ok: 'Remove')) s.remove('food', f['id'] as String);
            },
          ),
      ]),
    ]);
  }

  void _other(BuildContext context, Store s) {
    final name = TextEditingController();
    var kcal = 200;
    showSheet(context, 'Other food', (ctx, set) => Col([
          SoftField(controller: name, hint: 'Khichuri', pill: true),
          Stepper2(value: '$kcal', unit: 'kcal', onMinus: () => set(() => kcal = (kcal - 50).clamp(0, 5000)), onPlus: () => set(() => kcal += 50)),
          PressPill('Add', success: true, onTap: () {
            final n = name.text.trim();
            if (n.isEmpty) return;
            addFood(s, n, kcal, meal);
            s.add('foods', {'name': n, 'size': '1', 'kcal': kcal, 'uses': 1});
            Navigator.pop(ctx);
          }),
        ], space: 12));
  }
}

// ------------------------------------------------------------------ Sleep
class SleepPage extends StatelessWidget {
  const SleepPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final bed = s.bedMins, wake = s.wakeMins;
    final logged = s.day()['bed'] != null;
    final dur = ((wake - bed) % 1440 + 1440) % 1440;
    final wind = ((s.day()['wind'] as List?) ?? const []).map((e) => '$e').toSet();
    const winds = ['No phone 30 min before bed', 'Wudu and Ayatul Kursi', 'Lights off by 11:30 PM'];
    return ToolFrame('sleep', children: [
      HeroCard(
        label: logged ? 'Last night' : 'Last night (tap − / + to log)',
        big: '${dur ~/ 60}h ${(dur % 60).toString().padLeft(2, '0')}m',
        sub: 'Bed ${clockOf(bed)} · Up ${clockOf(wake)}',
        bars: [for (var i = 0; i < 7; i++) (i == 6 ? dur / 60 : s.sleepOn(s.last7[i]), s.last7Letters[i])],
        barMax: 9,
      ),
      Panel(title: 'Went to bed', hint: '15 min steps', child: Stepper2(value: clockOf(bed), onMinus: () => s.setSleep(bed - 15, wake), onPlus: () => s.setSleep(bed + 15, wake))),
      Panel(title: 'Woke up', hint: '15 min steps', child: Stepper2(value: clockOf(wake), onMinus: () => s.setSleep(bed, wake - 15), onPlus: () => s.setSleep(bed, wake + 15))),
      Panel(title: 'How did you sleep?', child: Chips(options: const ['Great', 'Okay', 'Poor'], selected: {'${s.day()['sleepQ'] ?? ''}'}, onTap: (v) => s.patchDay({'sleepQ': v}))),
      RowsPanel(title: 'Wind-down', rows: [
        for (final w in winds)
          Row2(title: w, done: wind.contains(w), onTick: () => s.patchDay({'wind': wind.contains(w) ? (wind..remove(w)).toList() : [...wind, w]})),
      ]),
    ]);
  }
}

// ------------------------------------------------------------------ Mood
class MoodPage extends StatelessWidget {
  const MoodPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final m = s.moodToday;
    final why = ((s.day()['moodWhy'] as List?) ?? const []).map((e) => '$e').toSet();
    var good = 0;
    for (final k in s.last7.reversed) {
      if (moodScore(s.day(k)['mood']) >= 4) {
        good++;
      } else if (k != todayKey) {
        break;
      }
    }
    return ToolFrame('mood', children: [
      HeroCard(
        label: 'Right now',
        big: m ?? 'Tap a mood',
        sub: good >= 2 ? '$good good days in a row' : 'One tap a day shows your pattern',
        bars: [for (var i = 0; i < 7; i++) (moodScore(s.day(s.last7[i])['mood']).toDouble(), s.last7Letters[i])],
        barMax: 5,
      ),
      Panel(title: 'How are you now?', child: Chips(options: moodWords, selected: {m == 'Meh' ? 'Low' : m ?? ''}, onTap: (v) => s.patchDay({'mood': v}))),
      Panel(
        title: "What's behind it?",
        hint: 'pick any',
        child: Chips(
          options: const ['Work', 'Family', 'Health', 'Sleep', 'Deen', 'Friends', 'Weather'],
          selected: why,
          onTap: (v) => s.patchDay({'moodWhy': why.contains(v) ? (why..remove(v)).toList() : [...why, v]}),
        ),
      ),
      PressPill('Save mood', success: true, onTap: () {
        if (m == null) {
          say(context, 'Pick a mood first.', good: false);
          return;
        }
        Navigator.pop(context);
        toast(context, 'Mood saved.');
      }),
    ]);
  }
}

// ------------------------------------------------------------------ Health
class HealthPage extends StatelessWidget {
  const HealthPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final steps = s.stepsOn(), goal = s.stepGoal;
    final w = (s.day()['weight'] ?? s.weight ?? 70) as num;
    final works = ((s.day()['workouts'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    num r1(num x) => (x * 10).round() / 10;
    return ToolFrame('health', children: [
      HeroCard(label: 'Steps today', big: '$steps', sub: '${(steps * 0.00072).toStringAsFixed(1)} km · goal $goal', ring: steps / goal),
      Panel(
        title: 'Steps',
        hint: '±500',
        child: Stepper2(value: '$steps', onMinus: () => s.patchDay({'steps': (steps - 500).clamp(0, 99999)}), onPlus: () {
          s.patchDay({'steps': steps + 500});
          if (steps < goal && steps + 500 >= goal) {
            Haptic.celebrate();
            toast(context, 'Step goal done!');
          }
        }),
      ),
      Panel(title: 'Weight', hint: 'kg', child: Stepper2(value: r1(w).toStringAsFixed(1), unit: 'kg', onMinus: () => s.patchDay({'weight': r1(w - 0.1)}), onPlus: () => s.patchDay({'weight': r1(w + 0.1)}))),
      Panel(
        title: 'Log a workout',
        child: Chips(
          options: const ['Walk 20 min', 'Push-ups', 'Stretch', 'Cycling', 'Football'],
          add: true,
          onTap: (n) {
            const mins = {'Walk 20 min': 20, 'Push-ups': 10, 'Stretch': 10, 'Cycling': 30, 'Football': 60};
            s.patchDay({'workouts': [...works, {'n': n, 'min': mins[n]}], if (n.startsWith('Walk')) 'steps': steps + 2400});
            toast(context, '$n logged.');
          },
        ),
      ),
      RowsPanel(title: 'Today', empty: 'No workout yet.', rows: [for (final x in works) Row2(title: '${x['n']}', right: '${x['min']} min')]),
    ]);
  }
}

// ------------------------------------------------------------------ Reminders
class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});
  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  static const whens = {'Morning 9 AM': '09:00', 'Afternoon 2 PM': '14:00', 'Night 9 PM': '21:00', 'Weekdays 10 AM': '10:00'};
  String when = 'Night 9 PM';

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final rs = s.list('reminders');
    final now = DateTime.now().hour * 60 + DateTime.now().minute;
    final todayTimes = <(int, String)>[];
    for (final r in rs.where((r) => r['on'] != false)) {
      for (final tm in (r['times'] as List? ?? const [])) {
        final p = '$tm'.split(':');
        if (p.length == 2) todayTimes.add(((int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0), '${r['title']}'));
      }
    }
    final left = todayTimes.where((x) => x.$1 > now).toList()..sort((a, b) => a.$1.compareTo(b.$1));
    String timesOf(Json r) => (r['times'] as List? ?? const []).map((x) {
          final p = '$x'.split(':');
          return p.length == 2 ? clockOf((int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0)) : '$x';
        }).join(', ');
    return ToolFrame('reminders', children: [
      HeroCard(label: 'Today', big: '${left.length} left', sub: left.isEmpty ? 'All done for today' : 'Next: ${left.first.$2} at ${clockOf(left.first.$1)}'),
      Panel(title: 'When', child: Chips(options: whens.keys.toList(), selected: {when}, onTap: (v) => setState(() => when = v))),
      Panel(
        title: 'Quick add',
        hint: 'uses the time above',
        child: Chips(
          options: const ['Medicine', 'Call someone', 'Bill due', 'Drink water', 'Charge phone', 'My own'],
          add: true,
          onTap: (n) {
            void add(String title) {
              s.add('reminders', {'title': title, 'note': when, 'times': [whens[when]], 'weekdays': when.startsWith('Weekdays'), 'on': true});
              toast(context, '$title · $when');
            }

            n == 'My own' ? askText(context, 'New reminder', 'Pay internet bill', add, button: 'Add reminder') : add(n);
          },
        ),
      ),
      RowsPanel(title: 'All reminders', hint: 'hold to delete', empty: 'No reminders yet.', rows: [
        for (final r in rs)
          Row2(
            title: '${r['title']}',
            sub: '${r['weekdays'] == true ? 'Weekdays' : 'Every day'} · ${timesOf(r)}',
            trailing: Toggle(on: r['on'] != false, label: '${r['title']}', onChanged: (v) => s.patch('reminders', r['id'] as String, {'on': v})),
            onLongPress: () async {
              if (await confirm(context, 'Delete ${r['title']}?')) s.remove('reminders', r['id'] as String);
            },
          ),
      ]),
    ]);
  }
}
