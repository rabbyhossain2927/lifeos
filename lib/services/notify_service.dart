import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'life.dart';
import 'prayer.dart';
import 'store.dart';

/// Phone notifications: daily reminders, dates, haircut, update alerts.
class NotifyService {
  static final plugin = FlutterLocalNotificationsPlugin();
  static final navigatorKey = GlobalKey<NavigatorState>();
  static void Function()? onOpenUpdate;

  static const icon = 'ic_stat_lifeos';

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      // The phone's zone (Bangladesh by default). Offsets are what matter here.
      final off = DateTime.now().timeZoneOffset;
      final match = tz.timeZoneDatabase.locations.values.where((l) => l.currentTimeZone.offset == off.inMilliseconds);
      final pick = match.where((l) => l.name == 'Asia/Dhaka').firstOrNull ?? match.firstOrNull;
      if (pick != null) tz.setLocalLocation(pick);
    } catch (_) {}
    await plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings(icon)),
      onDidReceiveNotificationResponse: (r) {
        if (r.payload == 'update') onOpenUpdate?.call();
      },
    );
    final a = _android;
    if (a != null) {
      for (final c in const [
        AndroidNotificationChannel('reminders', 'Reminders', description: 'Water, meals, medicine, work and your own reminders', importance: Importance.high),
        AndroidNotificationChannel('dates', 'Important dates', description: 'Birthdays, renewals and haircut', importance: Importance.high),
        AndroidNotificationChannel('prayer', 'Prayer times', description: '10 minutes before each prayer', importance: Importance.high),
        AndroidNotificationChannel('nudges', 'Nudges', description: 'Habit nudge and weekly review', importance: Importance.defaultImportance),
        AndroidNotificationChannel('focus', 'Focus timer', description: 'When a focus session ends', importance: Importance.high),
        AndroidNotificationChannel('updates', 'App updates', description: 'When a new version of LifeOS is ready', importance: Importance.high),
      ]) {
        await a.createNotificationChannel(c);
      }
    }
  }

  static Future<void> requestPermission() async {
    try {
      await _android?.requestNotificationsPermission();
    } catch (_) {}
  }

  static NotificationDetails _d(String ch, String name) => NotificationDetails(
      android: AndroidNotificationDetails(ch, name, importance: Importance.high, priority: Priority.high, icon: icon));

  static int _id(String key) => key.hashCode & 0x7fffffff;

  static Future<void> _zoned(int id, String title, String body, tz.TZDateTime at, NotificationDetails d, {DateTimeComponents? repeat}) async {
    try {
      await plugin.zonedSchedule(id, title, body, at, d,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: repeat);
    } catch (_) {
      await plugin.zonedSchedule(id, title, body, at, d,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: repeat);
    }
  }

  static tz.TZDateTime _nextAt(int h, int m, {int? weekday}) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
    while (t.isBefore(now) || (weekday != null && t.weekday != weekday)) {
      t = t.add(const Duration(days: 1));
    }
    return t;
  }

  /// Rebuilds every scheduled notification from the user's data.
  /// Cheap enough to run after changes (debounced in main).
  static Future<void> rescheduleAll(Store s) async {
    if (kIsWeb) return;
    try {
      await plugin.cancelAll();
      // 1. Reminders: each time, every day (or weekdays only).
      for (final r in s.list('reminders')) {
        if (r['on'] == false) continue;
        final title = '${r['title'] ?? 'Reminder'}';
        final body = '${r['note'] ?? ''}';
        final weekdays = r['weekdays'] == true;
        for (final t in (r['times'] as List? ?? const [])) {
          final p = '$t'.split(':');
          if (p.length != 2) continue;
          final h = int.tryParse(p[0]) ?? 9, m = int.tryParse(p[1]) ?? 0;
          final repeat = '${r['repeat'] ?? (weekdays ? 'Weekdays' : 'Every day')}';
          final base = DateTime.tryParse('${r['date'] ?? ''}') ?? DateTime.now();
          if (repeat == 'Weekdays') {
            for (var wd = 1; wd <= 5; wd++) {
              await _zoned(_id('${r['id']}$t$wd'), title, body, _nextAt(h, m, weekday: wd), _d('reminders', 'Reminders'),
                  repeat: DateTimeComponents.dayOfWeekAndTime);
            }
          } else if (repeat == 'Every week') {
            await _zoned(_id('${r['id']}$t'), title, body, _nextAt(h, m, weekday: base.weekday), _d('reminders', 'Reminders'), repeat: DateTimeComponents.dayOfWeekAndTime);
          } else if (repeat == 'Every month') {
            var at = DateTime(DateTime.now().year, DateTime.now().month, base.day, h, m);
            if (at.isBefore(DateTime.now())) at = DateTime(at.year, at.month + 1, base.day, h, m);
            await _zoned(_id('${r['id']}$t'), title, body, tz.TZDateTime.from(at, tz.local), _d('reminders', 'Reminders'), repeat: DateTimeComponents.dayOfMonthAndTime);
          } else if (repeat == 'Once') {
            var at = DateTime(base.year, base.month, base.day, h, m);
            if (at.isBefore(DateTime.now()) && dayKey(base) == dayKey(DateTime.now())) at = at.add(const Duration(days: 1));
            if (at.isAfter(DateTime.now())) await _zoned(_id('${r['id']}$t'), title, body, tz.TZDateTime.from(at, tz.local), _d('reminders', 'Reminders'));
          } else {
            await _zoned(_id('${r['id']}$t'), title, body, _nextAt(h, m), _d('reminders', 'Reminders'), repeat: DateTimeComponents.time);
          }
        }
      }
      // 2. Important dates: 9 AM, some days before (yearly ones repeat).
      final now = DateTime.now();
      for (final d in s.list('dates')) {
        final date = DateTime.tryParse('${d['date'] ?? ''}');
        if (date == null) continue;
        final before = ((d['remindDays'] ?? 1) as num).toInt();
        var when = DateTime(d['yearly'] == false ? date.year : now.year, date.month, date.day, 9).subtract(Duration(days: before));
        if (when.isBefore(now) && d['yearly'] != false) when = DateTime(when.year + 1, when.month, when.day, 9);
        if (when.isBefore(now)) continue;
        await _zoned(_id('date${d['id']}'), '${d['title']}', before == 0 ? 'Today' : 'In $before day${before == 1 ? '' : 's'}',
            tz.TZDateTime.from(when, tz.local), _d('dates', 'Important dates'));
      }
      // 3. Prayer alerts: 10 minutes before each prayer, today and the next 2 days.
      if (s.settings['prayerAlerts'] != false) {
        final loc = s.settings['city'] is List ? (s.settings['city'] as List).map((e) => (e as num).toDouble()).toList() : const [23.8103, 90.4125];
        for (var d = 0; d < 3; d++) {
          final times = PrayerTimes.forDay(now.add(Duration(days: d)), loc[0], loc[1], shafi: s.shafi);
          for (final e in times.entries) {
            final at = e.value.subtract(const Duration(minutes: 10));
            if (at.isBefore(now)) continue;
            await _zoned(_id('prayer${e.key}$d'), '${e.key} in 10 minutes', 'At ${e.value.hour % 12 == 0 ? 12 : e.value.hour % 12}:${e.value.minute.toString().padLeft(2, '0')}',
                tz.TZDateTime.from(at, tz.local), _d('prayer', 'Prayer times'));
          }
        }
      }
      // 4. Habit nudge at 9 PM when habits are not all done.
      if (s.settings['habitNudge'] != false && s.list('habits').isNotEmpty) {
        final left = s.list('habits').length - s.habitsDoneToday;
        if (left > 0) {
          final at = DateTime(now.year, now.month, now.day, 21);
          if (at.isAfter(now)) {
            await _zoned(_id('nudge'), '$left habit${left == 1 ? '' : 's'} left today', 'A small tick still counts. Open LifeOS.', tz.TZDateTime.from(at, tz.local), _d('nudges', 'Nudges'));
          }
        }
      }
      // 5. Weekly review, Friday 3 PM.
      if (s.settings['weeklyReview'] != false) {
        await _zoned(_id('review'), 'Week review', 'Three taps: how did your week go?', _nextAt(15, 0, weekday: DateTime.friday), _d('nudges', 'Nudges'),
            repeat: DateTimeComponents.dayOfWeekAndTime);
      }
      // 6. Self care with a reminder.
      for (final c in s.list('care')) {
        if (c['remind'] != true) continue;
        final p = '${c['time'] ?? ''}'.split(':');
        if (p.length != 2) continue;
        final h = int.tryParse(p[0]) ?? 21, m = int.tryParse(p[1]) ?? 0;
        final title = '${c['name']}', body = 'Self care time';
        switch ('${c['repeat'] ?? 'Every day'}') {
          case 'Weekdays':
            for (var wd = 1; wd <= 5; wd++) {
              await _zoned(_id('care${c['id']}$wd'), title, body, _nextAt(h, m, weekday: wd), _d('reminders', 'Reminders'), repeat: DateTimeComponents.dayOfWeekAndTime);
            }
          case 'Weekly':
            await _zoned(_id('care${c['id']}'), title, body, _nextAt(h, m, weekday: ((c['weekday'] ?? 1) as num).toInt()), _d('reminders', 'Reminders'), repeat: DateTimeComponents.dayOfWeekAndTime);
          case 'Date':
            final d = DateTime.tryParse('${c['date']}');
            if (d != null) {
              final at = DateTime(d.year, d.month, d.day, h, m);
              if (at.isAfter(DateTime.now())) await _zoned(_id('care${c['id']}'), title, body, tz.TZDateTime.from(at, tz.local), _d('reminders', 'Reminders'));
            }
          default:
            await _zoned(_id('care${c['id']}'), title, body, _nextAt(h, m), _d('reminders', 'Reminders'), repeat: DateTimeComponents.time);
        }
      }
      // 7. Morning summary at 7 AM.
      if (s.settings['morningSummary'] == true) {
        final goals = s.list('goals').where((g) => g['archived'] != true).length;
        final habits = s.list('habits').length;
        await _zoned(_id('morning'), 'Good morning', '$goals goals and $habits habits today. One small step at a time.', _nextAt(7, 0), _d('nudges', 'Nudges'), repeat: DateTimeComponents.time);
      }
      // 8. Haircut.
      final hc = DateTime.tryParse('${s.settings['haircutNext'] ?? ''}');
      if (hc != null) {
        final when = DateTime(hc.year, hc.month, hc.day, 10);
        if (when.isAfter(now)) {
          await _zoned(_id('haircut'), 'Haircut time', 'Book your haircut today.', tz.TZDateTime.from(when, tz.local), _d('dates', 'Important dates'));
        }
      }
    } catch (e) {
      debugPrint('Reminders not scheduled: $e');
    }
  }

  static Future<void> focusDoneAt(DateTime when, String label) async {
    try {
      await _zoned(_id('focus'), 'Focus done', label.isEmpty ? 'Take a short break.' : '$label: take a short break.',
          tz.TZDateTime.from(when, tz.local), _d('focus', 'Focus timer'));
    } catch (_) {}
  }

  static Future<void> cancelFocus() => plugin.cancel(_id('focus'));

  static Future<void> showUpdate(String version) async {
    try {
      await plugin.show(777, 'LifeOS $version is ready', 'Tap to see what is new and update.', _d('updates', 'App updates'), payload: 'update');
    } catch (_) {}
  }
}
