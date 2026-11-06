import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
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
          if (weekdays) {
            for (var wd = 1; wd <= 5; wd++) {
              await _zoned(_id('${r['id']}$t$wd'), title, body, _nextAt(h, m, weekday: wd), _d('reminders', 'Reminders'),
                  repeat: DateTimeComponents.dayOfWeekAndTime);
            }
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
      // 3. Haircut.
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
