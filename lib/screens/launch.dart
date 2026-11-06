import 'dart:async';
import 'package:flutter/material.dart';
import '../services/notify_service.dart';
import '../widgets/ui.dart';
import 'stuck.dart';

/// Launch mode: one task, one first step, a short timer. Nothing else.
class LaunchScreen extends StatefulWidget {
  final String task, firstStep;
  final int minutes;
  const LaunchScreen({super.key, required this.task, required this.firstStep, this.minutes = 5});
  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen> {
  DateTime? endsAt;
  Timer? tick;

  @override
  void dispose() {
    tick?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() => endsAt = DateTime.now().add(Duration(minutes: widget.minutes)));
    NotifyService.focusDoneAt(endsAt!, 'Launch done. Keep going or stop, your choice');
    tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (DateTime.now().isAfter(endsAt!)) tick?.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.minutes * 60;
    final left = endsAt == null ? total : endsAt!.difference(DateTime.now()).inSeconds.clamp(0, total);
    final done = endsAt != null && left == 0;
    return Scaffold(
      backgroundColor: C.ink,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(children: [
            Row(children: [
              RoundBtn(icon: Icons.close_rounded, label: 'Close', bg: C.dark2, fg: C.white, onTap: () => Navigator.pop(context)),
              Expanded(child: Text('Launch mode', textAlign: TextAlign.center, style: t(17, w: w6, c: C.white))),
              const SizedBox(width: 44),
            ]),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(widget.task, textAlign: TextAlign.center, style: t(14, c: C.darkFaint)),
                const SizedBox(height: 8),
                Text(widget.firstStep, textAlign: TextAlign.center, style: t(26, w: w6, c: C.white, h: 1.25, ls: -0.4)),
                const SizedBox(height: 28),
                Ring(
                  value: endsAt == null ? 1 : left / total,
                  size: 240,
                  stroke: 14,
                  center: Text('${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}', style: t(48, w: w6, c: C.white)),
                ),
                const SizedBox(height: 28),
                Text(done ? 'You started. That was the hard part.\nKeep going if you like.' : 'Just ${widget.minutes} minutes.\nAfter that, you are free to stop.',
                    textAlign: TextAlign.center, style: t(15, c: C.darkMuted, h: 1.5)),
              ]),
            ),
            PillButton(endsAt == null ? 'Start' : (done ? 'Done' : 'Running…'), height: 60,
                onTap: endsAt == null ? _start : (done ? () => Navigator.pop(context) : null)),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StuckScreen())),
              child: Text('Still stuck?', style: t(14, c: C.darkMuted, deco: TextDecoration.underline)),
            ),
          ]),
        ),
      ),
    );
  }
}
