import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'api.dart';

typedef Json = Map<String, dynamic>;

const _uuid = Uuid();
String newId() => _uuid.v4();

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String get todayKey => dayKey(DateTime.now());
DateTime parseDay(String k) => DateTime.tryParse(k) ?? DateTime.now();

/// All of the user's data.
///
/// * Saved on the phone first (a JSON file), so the app works offline.
/// * Every change also goes into an "outbox" and is sent to YOUR server
///   (lifeos-api on your hosting) a moment later.
/// * Each sync also pulls what changed on other phones.
class Store extends ChangeNotifier {
  final String uid;
  Store(this.uid) {
    _init();
  }

  static const collections = [
    'goals', 'habits', 'days', 'food', 'foods', 'reminders', 'focus', 'duas', 'fasts', 'books', 'courses', 'skills',
    'moments', 'dates', 'people', 'trips', 'places', 'care', 'visits', 'rewards', 'redeems', 'notes', 'meta',
  ];

  bool loaded = false;
  bool syncing = false;
  String? syncError;
  DateTime? lastSyncedAt;
  int get pendingCount => _outbox.length;

  final Map<String, Map<String, Json>> _data = {};
  final Map<String, Json> _outbox = {};
  String _cursor = '0';
  File? _file;
  Timer? _saveTimer, _syncTimer, _periodic;
  Future<void>? _running;
  bool _syncedOnce = false;

  /// Called after every change (reminders are rescheduled from main).
  void Function()? onChanged;

  Future<void> _init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/lifeos_${uid.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '')}.json');
      if (await _file!.exists()) {
        final j = jsonDecode(await _file!.readAsString()) as Json;
        (j['data'] as Map? ?? {}).forEach((col, docs) {
          _data[col as String] = {
            for (final e in (docs as Map).entries) e.key as String: Map<String, dynamic>.from(e.value as Map)
          };
        });
        (j['outbox'] as Map? ?? {}).forEach((k, v) => _outbox[k as String] = Map<String, dynamic>.from(v as Map));
        _cursor = (j['cursor'] ?? '0').toString();
        final ls = j['lastSyncedAt'];
        if (ls is int) lastSyncedAt = DateTime.fromMillisecondsSinceEpoch(ls);
        _syncedOnce = j['syncedOnce'] == true;
      }
    } catch (e) {
      debugPrint('Local data could not be read: $e');
    }
    loaded = true;
    notifyListeners();
    unawaited(syncQuietly());
    _periodic = Timer.periodic(const Duration(seconds: 60), (_) => syncQuietly());
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _syncTimer?.cancel();
    _periodic?.cancel();
    _writeFile();
    super.dispose();
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    await _writeFile();
    unawaited(syncQuietly());
  }

  void _persist() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), _writeFile);
  }

  Future<void> _writeFile() async {
    final f = _file;
    if (f == null) return;
    try {
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode({
        'data': _data,
        'outbox': _outbox,
        'cursor': _cursor,
        'lastSyncedAt': lastSyncedAt?.millisecondsSinceEpoch,
        'syncedOnce': _syncedOnce,
      }));
      await tmp.rename(f.path);
    } catch (e) {
      debugPrint('Local save failed: $e');
    }
  }

  void _changed() {
    notifyListeners();
    _persist();
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 2), syncQuietly);
    onChanged?.call();
  }

  // ---------------- generic data ----------------

  /// Every change goes through here. `data == null` deletes.
  void _put(String col, String id, Json? data) {
    if (data == null) {
      _data[col]?.remove(id);
    } else {
      final copy = jsonDecode(jsonEncode(data)) as Json;
      copy.remove('id');
      (_data[col] ??= {})[id] = copy;
    }
    _outbox['$col/$id'] = {'col': col, 'id': id, 'data': data == null ? null : _data[col]![id], 'deleted': data == null};
    _changed();
  }

  /// Items of a collection, oldest first. Each map has its 'id'.
  List<Json> list(String col) {
    final out = <Json>[];
    (_data[col] ?? {}).forEach((id, m) => out.add({...m, 'id': id}));
    out.sort((a, b) => ((a['createdAt'] ?? 0) as num).compareTo((b['createdAt'] ?? 0) as num));
    return out;
  }

  Json? get(String col, String id) {
    final m = _data[col]?[id];
    return m == null ? null : {...m, 'id': id};
  }

  String add(String col, Json data) {
    final id = newId();
    _put(col, id, {...data, 'createdAt': DateTime.now().millisecondsSinceEpoch});
    return id;
  }

  void save(String col, Json data) {
    final id = (data['id'] ?? newId()).toString();
    _put(col, id, {'createdAt': DateTime.now().millisecondsSinceEpoch, ...data});
  }

  void patch(String col, String id, Json changes) {
    final cur = _data[col]?[id] ?? {'createdAt': DateTime.now().millisecondsSinceEpoch};
    _put(col, id, {...cur, ...changes});
  }

  void remove(String col, String id) => _put(col, id, null);

  // ---------------- days (journal, mood, health...) ----------------
  Json day([String? key]) => _data['days']?[key ?? todayKey] ?? <String, dynamic>{};
  void patchDay(Json changes, [String? key]) => patch('days', key ?? todayKey, changes);

  // ---------------- settings (synced) ----------------
  Json get settings => _data['meta']?['user'] ?? <String, dynamic>{};
  void setSetting(String k, dynamic v) => patch('meta', 'user', {k: v});

  // ---------------- sync ----------------
  Future<void> syncQuietly() async {
    try {
      await sync();
    } catch (_) {}
  }

  Future<void> sync() => _running ??= _doSync().whenComplete(() => _running = null);

  Future<void> _doSync() async {
    syncing = true;
    notifyListeners();
    var got = false;
    try {
      var more = true;
      var rounds = 0;
      while (more && rounds++ < 50) {
        final batch = Map<String, Json>.of(_outbox).entries.take(400).toList();
        final res = await Api.post('sync.php', {
          'since': _cursor,
          'changes': [for (final e in batch) e.value],
        });
        for (final e in batch) {
          if (identical(_outbox[e.key], e.value)) _outbox.remove(e.key);
        }
        for (final c in (res['changes'] as List? ?? const [])) {
          final m = c as Json;
          final col = m['col'] as String, id = m['id'] as String;
          if (_outbox.containsKey('$col/$id')) continue; // our newer local edit wins
          if (m['deleted'] == true || m['data'] == null) {
            _data[col]?.remove(id);
          } else {
            (_data[col] ??= {})[id] = Map<String, dynamic>.from(m['data'] as Map);
          }
          got = true;
        }
        _cursor = (res['cursor'] ?? _cursor).toString();
        more = res['more'] == true || (_outbox.isNotEmpty && batch.length == 400);
      }
      lastSyncedAt = DateTime.now();
      syncError = null;
      if (!_syncedOnce) {
        _syncedOnce = true;
        _seedIfEmpty();
      }
    } catch (e) {
      syncError = e is SocketException || e is TimeoutException ? 'You are offline. Changes are saved on this phone.' : e.toString();
      // Never synced and the server can't be reached: still give a first-time
      // user a starting set so the app isn't empty.
      if (!_syncedOnce && list('habits').isEmpty && settings['seeded'] != true && e is ApiError && e.status == 404) {
        _seedIfEmpty();
      }
      rethrow;
    } finally {
      syncing = false;
      _persist();
      notifyListeners();
      if (got) onChanged?.call();
    }
  }

  /// A brand-new account starts with a few useful habits and reminders.
  void _seedIfEmpty() {
    if (settings['seeded'] == true || list('habits').isNotEmpty) return;
    for (final h in const ['Five prayers', 'Drink 8 glasses', 'Read 15 pages', 'Workout', 'Quran, 1 page', 'Sleep by 11 PM']) {
      add('habits', {'name': h, 'logs': <String, dynamic>{}});
    }
    for (final r in const [
      ['Drink water', 'Every 2 hours', ['09:00', '11:00', '13:00', '15:00', '17:00', '19:00', '21:00']],
      ['Start work', 'Weekdays', ['09:30']],
      ['Wind down', 'Phone away, get ready for sleep', ['22:30']],
    ]) {
      add('reminders', {'title': r[0], 'note': r[1], 'times': r[2], 'on': true});
    }
    for (final s in const ['Face wash|am', 'Moisturiser|am', 'Sunscreen|am', 'Face wash|pm', 'Night cream|pm']) {
      final p = s.split('|');
      add('care', {'name': p[0], 'time': p[1], 'logs': <String, dynamic>{}});
    }
    setSetting('seeded', true);
  }

  // ======================================================================
  // Domain helpers used by many screens
  // ======================================================================

  // ---- habits ----
  bool habitDone(Json h, [String? day]) => (h['logs'] as Map? ?? {})[day ?? todayKey] == true;

  void toggleHabit(Json h, [String? day]) {
    final logs = Map<String, dynamic>.from(h['logs'] as Map? ?? {});
    final k = day ?? todayKey;
    if (logs[k] == true) {
      logs.remove(k);
    } else {
      logs[k] = true;
    }
    patch('habits', h['id'] as String, {'logs': logs});
  }

  int streak(Json h) {
    final logs = h['logs'] as Map? ?? {};
    var d = DateTime.now();
    if (logs[dayKey(d)] != true) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (logs[dayKey(d)] == true) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  int bestStreak(Json h) {
    final keys = (h['logs'] as Map? ?? {}).entries.where((e) => e.value == true).map((e) => e.key as String).toList()..sort();
    var best = 0, cur = 0;
    DateTime? prev;
    for (final k in keys) {
      final d = parseDay(k);
      cur = (prev != null && d.difference(prev).inDays == 1) ? cur + 1 : 1;
      if (cur > best) best = cur;
      prev = d;
    }
    return best;
  }

  /// Did the habit miss yesterday (for "never miss twice")?
  bool missedYesterday(Json h) {
    final y = dayKey(DateTime.now().subtract(const Duration(days: 1)));
    final created = DateTime.fromMillisecondsSinceEpoch(((h['createdAt'] ?? 0) as num).toInt());
    return created.isBefore(DateTime.now().subtract(const Duration(days: 1))) && (h['logs'] as Map? ?? {})[y] != true;
  }

  // ---- goals (year -> month -> week -> day, all from one log) ----
  num _sumLogs(Json g, bool Function(DateTime) inRange) {
    num t = 0;
    (g['logs'] as Map? ?? {}).forEach((k, v) {
      if (v is num && inRange(parseDay(k as String))) t += v;
    });
    return t;
  }

  num goalTarget(Json g) => (g['target'] ?? 1) as num;

  Map<String, num> goalProgress(Json g) {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    return {
      'year': _sumLogs(g, (d) => d.year == now.year),
      'month': _sumLogs(g, (d) => d.year == now.year && d.month == now.month),
      'week': _sumLogs(g, (d) => !d.isBefore(weekStart)),
      'day': _sumLogs(g, (d) => dayKey(d) == todayKey),
    };
  }

  /// Share of the yearly target for each level. Daily is at least 1.
  Map<String, num> goalTargets(Json g) {
    final t = goalTarget(g);
    num r(num v) => v < 1 ? 1 : (v * 10).round() / 10;
    return {'year': t, 'month': r(t / 12), 'week': r(t / 52), 'day': g['daily'] is num ? g['daily'] as num : r(t / 365)};
  }

  bool goalDoneToday(Json g) => goalProgress(g)['day']! >= goalTargets(g)['day']!;

  void logGoal(Json g, num amount, [String? day]) {
    final logs = Map<String, dynamic>.from(g['logs'] as Map? ?? {});
    final k = day ?? todayKey;
    final v = ((logs[k] ?? 0) as num) + amount;
    if (v <= 0) {
      logs.remove(k);
    } else {
      logs[k] = v;
    }
    patch('goals', g['id'] as String, {'logs': logs});
  }

  void toggleGoalToday(Json g) {
    final daily = goalTargets(g)['day']!;
    final have = goalProgress(g)['day']!;
    logGoal(g, have >= daily ? -have : daily - have);
  }

  /// How many days behind the yearly pace, and the catch-up suggestion.
  num goalBehind(Json g) {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year)).inDays + 1;
    final expected = goalTarget(g) * dayOfYear / (DateTime(now.year, 12, 31).difference(DateTime(now.year)).inDays + 1);
    return expected - goalProgress(g)['year']!;
  }

  // ---- today ----
  List<Json> get todayGoals => list('goals').where((g) => g['archived'] != true).toList();

  int get todayTotal => todayGoals.length + list('habits').length;
  int get todayDone => todayGoals.where(goalDoneToday).length + list('habits').where((h) => habitDone(h)).length;

  int get dayStreak {
    var d = DateTime.now();
    bool any(String k) => list('habits').any((h) => habitDone(h, k)) || list('goals').any((g) => (g['logs'] as Map? ?? {})[k] != null);
    if (!any(dayKey(d))) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (any(dayKey(d)) && n < 3650) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// 0..1 share of today's habits and goals done on a given day.
  double dayScore(String k) {
    final hs = list('habits'), gs = list('goals');
    final total = hs.length + gs.length;
    if (total == 0) return 0;
    final done = hs.where((h) => habitDone(h, k)).length +
        gs.where((g) => (((g['logs'] as Map? ?? {})[k] ?? 0) as num) >= goalTargets(g)['day']!).length;
    return done / total;
  }

  double weekScore([int weeksAgo = 0]) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1 + 7 * weeksAgo));
    var sum = 0.0, n = 0;
    for (var i = 0; i < 7; i++) {
      final d = start.add(Duration(days: i));
      if (d.isAfter(now)) break;
      sum += dayScore(dayKey(d));
      n++;
    }
    return n == 0 ? 0 : sum / n;
  }

  // ---- points & rewards ----
  int get points {
    var p = 0;
    for (final h in list('habits')) {
      p += (h['logs'] as Map? ?? {}).values.where((v) => v == true).length * 5;
    }
    for (final g in list('goals')) {
      p += (g['logs'] as Map? ?? {}).length * 10;
    }
    for (final d in list('days')) {
      if ((d['text'] ?? '').toString().trim().isNotEmpty) p += 5;
      p += ((d['wins'] as List?) ?? const []).length * 2;
    }
    for (final r in list('redeems')) {
      p -= ((r['cost'] ?? 0) as num).toInt();
    }
    return p < 0 ? 0 : p;
  }

  int get pointsToday {
    var p = 0;
    for (final h in list('habits')) {
      if (habitDone(h)) p += 5;
    }
    for (final g in list('goals')) {
      if ((g['logs'] as Map? ?? {})[todayKey] != null) p += 10;
    }
    final d = day();
    if ((d['text'] ?? '').toString().trim().isNotEmpty) p += 5;
    p += ((d['wins'] as List?) ?? const []).length * 2;
    return p;
  }

  int get level => 1 + points ~/ 500;
  double get levelProgress => (points % 500) / 500;

  // ---- food ----
  int kcalOn(String k) => list('food').where((f) => f['day'] == k).fold(0, (s, f) => s + ((f['kcal'] ?? 0) as num).toInt());
}
