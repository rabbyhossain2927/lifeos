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

  // ---- water
  int waterOn([String? k]) => ((day(k)['water'] ?? 0) as num).toInt();
  int get waterGoal => ((settings['waterGoal'] ?? 8) as num).toInt();
  int get glassMl => ((settings['glass'] ?? 250) as num).toInt();
  void setWater(int n) => patchDay({'water': n < 0 ? 0 : n});

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
