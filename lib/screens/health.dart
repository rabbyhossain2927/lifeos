import 'package:flutter/material.dart';
import '../services/store.dart';
import '../widgets/form.dart';
import '../widgets/ui.dart';
import 'food.dart';
import 'today.dart' show moods;

class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final ws = weekStart;
    final days = [for (var i = 0; i < 7; i++) ws.add(Duration(days: i))];
    final now = DateTime.now();
    final moodVals = [
      for (final d in days)
        () {
          final m = s.day(dayKey(d))['mood'];
          final i = moods.indexOf('${m ?? ''}');
          return i < 0 ? -1.0 : (i + 1) / 5;
        }()
    ];
    final sleepVals = [
      for (final d in days)
        () {
          final h = s.day(dayKey(d))['sleepH'];
          return h is num ? (h / 9).toDouble() : -1.0;
        }()
    ];
    final today = s.day();
    final last = s.day(dayKey(now.subtract(const Duration(days: 1))));
    final sleepNow = today['sleepH'] is num ? today : last;
    final weights = s.list('days').where((d) => d['weight'] is num).toList()..sort((a, b) => '${a['id']}'.compareTo('${b['id']}'));
    final w = weights.isEmpty ? null : weights.last['weight'] as num;
    final monthAgo = weights.where((d) => parseDay('${d['id']}').isBefore(now.subtract(const Duration(days: 28)))).toList();
    final wDiff = (w != null && monthAgo.isNotEmpty) ? w - (monthAgo.last['weight'] as num) : null;
    final steps = (today['steps'] ?? 0) as num;
    final stepGoal = ((s.settings['stepGoal'] ?? 8000) as num);
    final goodSleepMood = _insight(s);

    return SubPage(title: 'Health', children: [
      Box(
        child: Col([
          CardHead('Mood this week', note: moodVals.where((v) => v >= 0.8).length >= 3 ? 'Mostly good' : ''),
          Bars(values: moodVals, height: 72, color: C.lime2, empty: C.chip, labels: weekLetters, labelColor: C.muted, radius: 10),
          Text(goodSleepMood, style: t(13, c: C.muted, h: 1.45)),
        ]),
      ),
      Box(
        dark: true,
        padding: const EdgeInsets.all(18),
        onTap: () => _logSleep(context, s),
        child: Col([
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sleep last night', style: t(13, c: C.darkMuted)),
                Text(sleepNow['sleepH'] is num ? _hours(sleepNow['sleepH'] as num) : 'Tap to log', style: t(32, w: w6, c: C.white, ls: -0.6)),
              ]),
            ),
            if (sleepNow['bed'] != null) Text('${sleepNow['bed']} – ${sleepNow['wake']}', style: t(13, c: C.darkMuted)),
          ]),
          Bars(values: sleepVals, height: 48, color: C.lime, radius: 6),
        ]),
      ),
      Row(children: [
        Expanded(
          child: Box(
            radius: 24,
            onTap: () => _logNumber(context, s, 'weight', 'Weight today (kg)'),
            child: Col([
              Text('Weight', style: t(13, c: C.muted)),
              Text(w == null ? 'Log' : '${numText(w)} kg', style: t(24, w: w6)),
              Text(wDiff == null ? 'Tap to log today' : '${numText(wDiff.abs())} kg ${wDiff <= 0 ? 'down' : 'up'} this month',
                  style: t(12, w: w6, c: wDiff == null ? C.muted : C.good)),
            ], space: 4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Box(
            radius: 24,
            onTap: () => _logNumber(context, s, 'steps', 'Steps today'),
            child: Col([
              Text('Steps', style: t(13, c: C.muted)),
              Text(numText(steps), style: t(24, w: w6)),
              Bar(steps / stepGoal, height: 6, color: C.lime2),
              Text('Goal ${numText(stepGoal)}', style: t(12, c: C.muted)),
            ], space: 4),
          ),
        ),
      ]),
      Box(
        radius: 24,
        onTap: () => push(context, const FoodScreen()),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('What I ate', style: t(15, w: w6)),
              Text('${s.kcalOn(todayKey)} of ${s.settings['kcalGoal'] ?? 2000} kcal today', style: t(12, c: C.muted)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded),
        ]),
      ),
    ]);
  }

  static String _hours(num h) => '${h.floor()}h ${((h - h.floor()) * 60).round()}m';

  static String _insight(Store s) {
    var good = 0, goodN = 0, bad = 0, badN = 0;
    for (final d in s.list('days')) {
      final h = d['sleepH'], m = moods.indexOf('${d['mood'] ?? ''}');
      if (h is! num || m < 0) continue;
      if (h >= 7) {
        good += m;
        goodN++;
      } else {
        bad += m;
        badN++;
      }
    }
    if (goodN >= 2 && badN >= 2 && good / goodN > bad / badN) return 'Better mood on days you slept 7+ hours.';
    return 'Tap one mood a day on Today. After a few weeks, LifeOS shows what makes your good days.';
  }

  static Future<void> _logSleep(BuildContext context, Store s) async {
    final v = await showForm(context, 'Sleep last night', const [
      Field('bed', 'Went to bed', type: F.time),
      Field('wake', 'Woke up', type: F.time),
    ], initial: {'bed': '23:30', 'wake': '06:30'});
    if (v == null || v['bed'] == null || v['wake'] == null) return;
    int mins(String x) => int.parse(x.split(':')[0]) * 60 + int.parse(x.split(':')[1]);
    var diff = mins('${v['wake']}') - mins('${v['bed']}');
    if (diff <= 0) diff += 24 * 60;
    s.patchDay({'bed': v['bed'], 'wake': v['wake'], 'sleepH': (diff / 6).round() / 10});
  }

  static Future<void> _logNumber(BuildContext context, Store s, String key, String label) async {
    final v = await showForm(context, label, [Field('n', label, type: F.number, required: true)], initial: {'n': s.day()[key]});
    if (v?['n'] is num) s.patchDay({key: v!['n']});
  }
}
