import 'package:flutter/material.dart';
import '../services/license_service.dart';
import '../services/prayer.dart';
import '../widgets/ui.dart';
import 'daily.dart';
import 'dates.dart';
import 'deen.dart';
import 'focus.dart';
import 'food.dart';
import 'health.dart';
import 'learn.dart';
import 'memory.dart';
import 'pro.dart';
import 'rewards.dart';
import 'selfcare.dart';
import 'shell.dart';
import 'stats.dart';
import 'travel.dart';

class _Mod {
  final String name, sub, feature;
  final IconData icon;
  final Widget Function() page;
  final List<String> words;
  const _Mod(this.name, this.sub, this.icon, this.page, {this.feature = '', this.words = const []});
}

final _groups = <String, List<_Mod>>{
  'Body': [
    _Mod('Health', 'Sleep, mood, weight, steps', Icons.monitor_heart_outlined, () => const HealthScreen(), words: ['sleep', 'mood', 'weight', 'steps']),
    _Mod('Food', 'What I ate, calories, water', Icons.restaurant_outlined, () => const FoodScreen(), words: ['calories', 'kcal', 'meal', 'water']),
    _Mod('Self care', 'Skin, hair, haircut, doctor', Icons.favorite_border_rounded, () => const SelfCareScreen(), words: ['skin', 'hair', 'haircut', 'doctor', 'cycle']),
  ],
  'Mind and time': [
    _Mod('Focus', 'Pomodoro, do not disturb', Icons.timer_outlined, () => const FocusScreen(), words: ['pomodoro', 'timer', 'screen time']),
    _Mod('Daily', 'Morning routine, reminders', Icons.wb_twilight_rounded, () => const DailyScreen(), words: ['routine', 'reminder', 'medicine', 'water', 'work']),
    _Mod('Learn', 'Books, courses, skill hours', Icons.auto_stories_outlined, () => const LearnScreen(), words: ['book', 'course', 'skill']),
  ],
  'Faith': [
    _Mod('Deen', 'Prayer times, duas, fasts', Icons.nightlight_round, () => const DeenScreen(), words: ['prayer', 'namaz', 'dua', 'dhikr', 'ramadan', 'fast', 'quran']),
  ],
  'Plans and people': [
    _Mod('Dates', 'Birthdays, renewals, gifts', Icons.event_outlined, () => const DatesScreen(), words: ['birthday', 'renewal', 'gift', 'people']),
    _Mod('Travel', 'Trips, packing, places', Icons.flight_takeoff_rounded, () => const TravelScreen(), feature: 'travel', words: ['trip', 'packing', 'ticket', 'place']),
    _Mod('Memory', 'Photo of the day, timeline', Icons.photo_camera_outlined, () => const MemoryScreen(), feature: 'memory', words: ['photo', 'timeline', 'moment']),
  ],
  'Progress': [
    _Mod('Report', 'Weekly score, streaks', Icons.bar_chart_rounded, () => const StatsScreen(), feature: 'report', words: ['score', 'streak', 'insight', 'review']),
    _Mod('Rewards', 'Points, wins, notes', Icons.redeem_outlined, () => const RewardsScreen(), feature: 'rewards', words: ['points', 'win', 'future']),
  ],
};

class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});
  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final loc = s.settings['city'] is List ? (s.settings['city'] as List).cast<num>() : const [23.8103, 90.4125];
    final times = PrayerTimes.forDay(DateTime.now(), loc[0].toDouble(), loc[1].toDouble());
    final next = PrayerTimes.next(loc[0].toDouble(), loc[1].toDouble());
    final left = next.value.difference(DateTime.now());
    final city = (s.settings['cityName'] ?? 'Dhaka').toString();
    final ql = q.trim().toLowerCase();
    bool match(_Mod m) => ql.isEmpty || m.name.toLowerCase().contains(ql) || m.sub.toLowerCase().contains(ql) || m.words.any((w) => w.contains(ql));

    return TabBody(children: [
      TabHeader(small: '$city · ${shortDate(DateTime.now())}', title: 'Explore'),
      Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(999)),
        child: Row(children: [
          const Icon(Icons.search_rounded, size: 20, color: C.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => q = v),
              style: t(15),
              decoration: InputDecoration(hintText: 'Search habits, dates, duas…', hintStyle: t(15, c: const Color(0xFF8A8A92)), border: InputBorder.none, isDense: true),
            ),
          ),
        ]),
      ),
      if (ql.isEmpty)
        Box(
          onTap: () => push(context, const DeenScreen()),
          child: Col([
            CardHead('Prayer times', note: '${next.key} in ${left.inHours}h ${left.inMinutes % 60}m'),
            Row(children: gap([
              for (final n in PrayerTimes.names)
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(color: n == next.key ? C.ink : C.chip, borderRadius: BorderRadius.circular(12)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(n, style: t(11, w: w5, c: n == next.key ? C.white : C.ink)),
                      Text(hm(times[n]!), style: t(13, w: w6, c: n == next.key ? C.white : C.ink)),
                    ]),
                  ),
                ),
            ], 6)),
          ]),
        ),
      for (final e in _groups.entries)
        if (e.value.any(match))
          Col([
            Padding(padding: const EdgeInsets.only(left: 4, top: 8), child: H2(e.key)),
            Box(
              radius: 24,
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Column(children: [
                for (final m in e.value.where(match))
                  _row(context, m, m == e.value.where(match).last),
              ]),
            ),
          ], space: 8),
    ]);
  }

  Widget _row(BuildContext context, _Mod m, bool last) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => m.feature.isEmpty ? push(context, m.page()) : openPro(context, m.feature, m.page()),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: C.line))),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(14)),
            child: Icon(m.icon, size: 20, color: C.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(m.name, style: t(15, w: w5)),
              Text(m.sub, style: t(12, c: C.muted)),
            ]),
          ),
          Icon(m.feature.isEmpty || License.isPro(store(context, listen: false)) ? Icons.chevron_right_rounded : Icons.lock_outline_rounded, size: 18, color: C.darkFaint),
        ]),
      ),
    );
  }
}

