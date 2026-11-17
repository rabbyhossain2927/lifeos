import 'prayer.dart';
import 'store.dart';

/// Everyday numbers shared by Home, Explore and the tool pages.
const moodWords = ['Great', 'Good', 'Okay', 'Low', 'Bad'];

/// 1..5 (older entries used Meh).
int moodScore(Object? m) => switch ('$m') { 'Great' => 5, 'Good' => 4, 'Okay' => 3, 'Meh' || 'Low' => 2, 'Bad' => 1, _ => 0 };

extension Life on Store {
  List<String> get last7 => [for (var i = 6; i >= 0; i--) dayKey(DateTime.now().subtract(Duration(days: i)))];
  static const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  List<String> get last7Letters => [for (final k in last7) dayLetters[parseDay(k).weekday - 1]];

  // ---- prayer
  bool get shafi => settings['asr'] == 'Shafi';
  List<double> get _loc => settings['city'] is List ? (settings['city'] as List).map((e) => (e as num).toDouble()).toList() : const [23.8103, 90.4125];
  String get cityName => '${settings['cityName'] ?? 'Dhaka'}';
  Map<String, DateTime> get prayerTimes => PrayerTimes.forDay(DateTime.now(), _loc[0], _loc[1], shafi: shafi);
  MapEntry<String, DateTime> get nextPrayer => PrayerTimes.next(_loc[0], _loc[1], shafi: shafi);
  Set<String> prayedOn([String? k]) => ((day(k)['prayed'] as List?) ?? const []).map((e) => '$e').toSet();
  void togglePrayer(String name) {
    final l = prayedOn();
    l.contains(name) ? l.remove(name) : l.add(name);
    patchDay({'prayed': l.toList()});
  }

  // ---- water (saved in ml; older days only had glasses)
  int get glassMl => ((settings['glass'] ?? 250) as num).toInt();
  int waterMlOn([String? k]) {
    final d = day(k);
    if (d['waterMl'] is num) return (d['waterMl'] as num).toInt();
    return ((d['water'] ?? 0) as num).toInt() * glassMl;
  }

  int get waterGoalMl => ((settings['waterGoalMl'] ?? ((settings['waterGoal'] ?? 8) as num) * glassMl) as num).toInt();
  int waterOn([String? k]) => (waterMlOn(k) / glassMl).round();
  int get waterGoal => (waterGoalMl / glassMl).round();
  void setWaterMl(int ml) {
    final v = ml < 0 ? 0 : ml;
    patchDay({'waterMl': v, 'water': (v / glassMl).round()});
  }

  void setWater(int glasses) => setWaterMl(glasses * glassMl);

  // ---- dhikr: list in settings, counts per day
  static const defaultDhikr = [
    {'name': 'SubhanAllah', 'meaning': 'Glory be to Allah', 'target': 33},
    {'name': 'Alhamdulillah', 'meaning': 'All praise is for Allah', 'target': 33},
    {'name': 'Allahu Akbar', 'meaning': 'Allah is the Greatest', 'target': 34},
    {'name': 'Astaghfirullah', 'meaning': 'I seek forgiveness from Allah', 'target': 100},
  ];
  List<Map<String, dynamic>> get dhikrs => ((settings['dhikrs'] as List?) ?? defaultDhikr).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  Map<String, dynamic> dhikrCounts([String? k]) => Map<String, dynamic>.from(day(k)['dhikrCounts'] as Map? ?? {});
  int dhikrTotal([String? k]) => dhikrCounts(k).values.fold<int>(0, (a, v) => a + ((v ?? 0) as num).toInt());

  // ---- sleep insight from the last 7 nights
  (double avg, int short, String text) get sleepInsight {
    final nights = [for (final k in last7) sleepOn(k)].where((h) => h > 0).toList();
    if (nights.isEmpty) return (0, 0, 'Log how long you slept to see how sleep affects your days.');
    final avg = nights.reduce((a, b) => a + b) / nights.length;
    final short = nights.where((h) => h < 6).length;
    final lowMoodShort = last7.where((k) => sleepOn(k) > 0 && sleepOn(k) < 6 && moodScore(day(k)['mood']) > 0 && moodScore(day(k)['mood']) <= 2).length;
    final text = avg >= 7
        ? 'Great rhythm. ${avg.toStringAsFixed(1)}h a night keeps focus and mood steady.${short > 0 ? ' $short short night${short == 1 ? '' : 's'} this week.' : ''}'
        : avg >= 6
            ? 'A little short. Try going to bed 30 minutes earlier.${lowMoodShort > 0 ? ' On short nights your mood was low.' : ''}'
            : 'Too little sleep this week. Energy, mood and hunger control drop. Aim for 7 hours.';
    return (avg, short, text);
  }

  // ---- XP per day (same rules as points)
  int xpOn(String k) {
    var p = 0;
    for (final h in list('habits')) {
      if ((h['logs'] as Map? ?? {})[k] == true) p += 5;
    }
    for (final g in list('goals')) {
      if ((g['logs'] as Map? ?? {})[k] != null) p += 10;
    }
    final d = day(k);
    if ('${d['text'] ?? ''}'.trim().isNotEmpty) p += 5;
    p += ((d['wins'] as List?) ?? const []).length * 2;
    p += ((d['prayed'] as List?) ?? const []).length * 10;
    return p;
  }

  /// Where XP came from over [days] ("Prayers" -> xp).
  Map<String, int> xpSources(List<String> days) {
    var pr = 0, go = 0, ha = 0, jo = 0;
    for (final k in days) {
      pr += prayedOn(k).length * 10;
      jo += '${day(k)['text'] ?? ''}'.trim().isNotEmpty ? 5 : 0;
      for (final h in list('habits')) {
        if ((h['logs'] as Map? ?? {})[k] == true) ha += 5;
      }
      for (final g in list('goals')) {
        if ((g['logs'] as Map? ?? {})[k] != null) go += 10;
      }
    }
    return {'Prayers': pr, 'Goal steps': go, 'Habits': ha, 'Journal': jo};
  }

  // ---- food
  int get kcalGoal => ((settings['kcalGoal'] ?? 2000) as num).toInt();
  List<Json> foodOn(String k) => list('food').where((f) => f['day'] == k).toList();

  // ---- mood
  String? get moodToday => day()['mood'] as String?;

  // ---- sleep (minutes from midnight; stored as "HH:mm" like before)
  int _mins(Object? v, int def) {
    final p = '${v ?? ''}'.split(':');
    if (p.length != 2) return def;
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
  }

  String _hhmm(int m) {
    m = ((m % 1440) + 1440) % 1440;
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }

  int get bedMins => _mins(day()['bed'], 23 * 60);
  int get wakeMins => _mins(day()['wake'], 6 * 60 + 30);
  void setSleep(int bed, int wake) {
    final diff = ((wake - bed) % 1440 + 1440) % 1440;
    patchDay({'bed': _hhmm(bed), 'wake': _hhmm(wake), 'sleepH': (diff / 6).round() / 10});
  }

  double sleepOn(String k) => ((day(k)['sleepH'] ?? 0) as num).toDouble();

  // ---- focus
  int focusOn(String k) => list('focus').where((f) => f['day'] == k).fold(0, (a, f) => a + ((f['mins'] ?? 0) as num).toInt());

  // ---- health
  int stepsOn([String? k]) => ((day(k)['steps'] ?? 0) as num).toInt();
  int get stepGoal => ((settings['stepGoal'] ?? 8000) as num).toInt();
  num? get weight {
    final w = list('days').where((d) => d['weight'] is num).toList()..sort((a, b) => '${a['id']}'.compareTo('${b['id']}'));
    return w.isEmpty ? null : w.last['weight'] as num;
  }

  // ---- habits
  int get habitsDoneToday => list('habits').where((h) => habitDone(h)).length;

  // ---- XP: level every 1000 XP (points stay what you can spend)
  int get xp => points + list('redeems').fold<int>(0, (a, r) => a + ((r['cost'] ?? 0) as num).toInt());
  int get lvl => 1 + xp ~/ 1000;
  int get xpInLevel => xp % 1000;
  String get lvlName => switch (lvl) { 1 => 'Starter', 2 || 3 => 'Steady', 4 || 5 || 6 => 'Strong', 7 || 8 || 9 => 'Focused', _ => 'Master' };

  /// Whole-app backup: every collection.
  Map<String, dynamic> exportAll() => {
        'app': 'LifeOS',
        'exportedAt': DateTime.now().toIso8601String(),
        'data': {for (final c in Store.collections) c: list(c)},
      };

  /// Puts every item of a backup back (merging with what is here). Returns item count.
  int importAll(Map<String, dynamic> backup) {
    var n = 0;
    final data = backup['data'];
    if (data is! Map) return 0;
    data.forEach((col, items) {
      if (!Store.collections.contains(col) || items is! List) return;
      for (final it in items) {
        if (it is Map && it['id'] != null) {
          save('$col', cleanDoc(it));
          n++;
        }
      }
    });
    return n;
  }
}
