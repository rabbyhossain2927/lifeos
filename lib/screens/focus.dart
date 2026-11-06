import 'dart:async';
import 'package:flutter/material.dart';
import '../services/notify_service.dart';
import '../services/store.dart';
import '../widgets/form.dart';
import '../widgets/ui.dart';

/// Pomodoro timer. The end time is kept here so leaving the page doesn't stop it.
class FocusTimer {
  static DateTime? endsAt;
  static String mode = 'Focus';
  static String label = '';
  static int sessionMins = 25;
}

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});
  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  static const lengths = {'Focus': 25, 'Short': 5, 'Long': 15};
  Timer? tick;

  @override
  void initState() {
    super.initState();
    tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    tick?.cancel();
    super.dispose();
  }

  void _onTick() {
    final e = FocusTimer.endsAt;
    if (e != null && DateTime.now().isAfter(e)) {
      FocusTimer.endsAt = null;
      if (FocusTimer.mode == 'Focus') {
        store(context, listen: false).add('focus', {'day': todayKey, 'mins': FocusTimer.sessionMins, 'label': FocusTimer.label});
      }
    }
    if (mounted) setState(() {});
  }

  void _start(Store s) {
    FocusTimer.sessionMins = lengths[FocusTimer.mode]!;
    FocusTimer.endsAt = DateTime.now().add(Duration(minutes: FocusTimer.sessionMins));
    NotifyService.focusDoneAt(FocusTimer.endsAt!, FocusTimer.label);
    setState(() {});
  }

  void _stop() {
    FocusTimer.endsAt = null;
    NotifyService.cancelFocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final running = FocusTimer.endsAt != null;
    final total = Duration(minutes: running ? FocusTimer.sessionMins : lengths[FocusTimer.mode]!);
    final left = running ? FocusTimer.endsAt!.difference(DateTime.now()) : total;
    final secs = left.inSeconds < 0 ? 0 : left.inSeconds;
    final time = '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
    final todays = s.list('focus').where((f) => f['day'] == todayKey).toList();
    final minsToday = todays.fold<int>(0, (a, f) => a + ((f['mins'] ?? 0) as num).toInt());
    final ws = weekStart;
    final week = [
      for (var i = 0; i < 7; i++)
        s.list('focus').where((f) => f['day'] == dayKey(ws.add(Duration(days: i)))).fold<int>(0, (a, f) => a + ((f['mins'] ?? 0) as num).toInt())
    ];
    final maxW = week.fold<int>(1, (a, b) => b > a ? b : a);

    return SubPage(title: 'Focus', children: [
      Box(
        dark: true,
        radius: 32,
        padding: const EdgeInsets.all(20),
        child: Col([
          Segmented(
            options: const ['Focus', 'Short', 'Long'],
            selected: FocusTimer.mode,
            dark: true,
            onPick: (m) {
              if (!running) setState(() => FocusTimer.mode = m);
            },
          ),
          Ring(value: running ? 1 - secs / total.inSeconds : 1, size: 200, stroke: 12, center: Text(time, style: t(40, w: w6, c: C.white))),
          GestureDetector(
            onTap: running
                ? null
                : () async {
                    final v = await showForm(context, 'What are you focusing on?', const [Field('l', 'Task')], initial: {'l': FocusTimer.label});
                    if (v != null) setState(() => FocusTimer.label = '${v['l']}');
                  },
            child: Text(
                '${todays.length + (running && FocusTimer.mode == 'Focus' ? 1 : 0)} session${todays.length == 1 ? '' : 's'} today${FocusTimer.label.isEmpty ? ' · tap to name the task' : ' · ${FocusTimer.label}'}',
                textAlign: TextAlign.center,
                style: t(13, c: C.darkMuted)),
          ),
          PillButton(running ? 'Stop' : 'Start ${FocusTimer.mode.toLowerCase()}', bg: running ? C.dark2 : C.lime, fg: running ? C.white : C.ink, onTap: running ? _stop : () => _start(s)),
        ], space: 16, cross: CrossAxisAlignment.center),
      ),
      Box(
        child: Col([
          CardHead('Focus this week', note: '${minsToday ~/ 60}h ${minsToday % 60}m today'),
          Bars(values: [for (final m in week) m == 0 ? -1.0 : m / maxW], height: 56, color: C.ink, empty: C.chip, labels: weekLetters, labelColor: C.muted, radius: 4),
        ]),
      ),
      Box(
        child: Col([
          const H2('Do not disturb and app blocker'),
          Text('Coming in a later version: silencing calls while you focus, blocking chosen apps with a 10-second wait, and phone screen time. These need special Android permissions.',
              style: t(13, c: C.muted, h: 1.45)),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.warnSoft, borderRadius: BorderRadius.circular(16)),
            child: Text('For now: swipe down and turn on Do Not Disturb before you press Start.', style: t(13, c: const Color(0xFF6E2A0A), h: 1.45)),
          ),
        ], space: 10),
      ),
    ]);
  }
}
