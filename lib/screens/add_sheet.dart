import 'package:flutter/material.dart';
import '../widgets/form.dart';
import '../widgets/ui.dart';
import 'daily.dart';
import 'food.dart';
import 'goals.dart';
import 'habits.dart';
import 'health.dart';
import 'stuck.dart';

/// What the lime + button opens.
void showAddSheet(BuildContext context) {
  final s = store(context, listen: false);
  final items = <(String, IconData, Future<void> Function())>[
    ('Goal', Icons.track_changes_rounded, () => addGoal(context)),
    ('Habit', Icons.check_box_outlined, () => addHabit(context)),
    ('Mood', Icons.sentiment_satisfied_alt_outlined, () async {
      final v = await showForm(context, 'How do you feel?', const [Field('m', 'Mood', type: F.choice, options: ['Low', 'Meh', 'Okay', 'Good', 'Great'])],
          initial: {'m': s.day()['mood'] ?? 'Good'});
      if (v != null) s.patchDay({'mood': v['m']});
    }),
    ('Food', Icons.restaurant_outlined, () async => push(context, const FoodScreen())),
    ('Win', Icons.emoji_events_outlined, () async {
      final v = await showForm(context, 'A small win', const [Field('w', 'What went well?', required: true)]);
      if (v != null) s.patchDay({'wins': [...((s.day()['wins'] as List?) ?? const []), v['w']]});
    }),
    ('Reminder', Icons.notifications_none_rounded, () => editReminder(context)),
    ('Sleep', Icons.bedtime_outlined, () async => push(context, const HealthScreen())),
    ('Water', Icons.water_drop_outlined, () async {
      final n = ((s.day()['water'] ?? 0) as num).toInt() + 1;
      s.patchDay({'water': n});
      toast(context, 'Glass $n of 8. Nice.');
    }),
  ];
  showModalBottomSheet(
    context: context,
    backgroundColor: C.white,
    barrierColor: const Color(0x8C111111),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 5, decoration: BoxDecoration(color: const Color(0xFFDAD8DF), borderRadius: BorderRadius.circular(5))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Text('Add', style: t(22, w: w6, ls: -0.4))),
            RoundBtn(icon: Icons.close_rounded, label: 'Close', bg: C.chip, onTap: () => Navigator.pop(c)),
          ]),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 10,
            childAspectRatio: 0.82,
            children: [
              for (final it in items)
                GestureDetector(
                  onTap: () {
                    Navigator.pop(c);
                    it.$3();
                  },
                  child: Column(children: [
                    Container(width: 64, height: 64, decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(22)), child: Icon(it.$2, size: 22)),
                    const SizedBox(height: 8),
                    Text(it.$1, style: t(12, w: w5)),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: C.ink,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                Navigator.pop(c);
                push(context, const StuckScreen());
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 6, 6),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("I'm stuck", style: t(15, w: w6, c: C.white)),
                      Text('30-second check-in', style: t(12, c: C.darkMuted)),
                    ]),
                  ),
                  Container(width: 44, height: 44, decoration: const BoxDecoration(color: C.lime, shape: BoxShape.circle), child: const Icon(Icons.chevron_right_rounded)),
                ]),
              ),
            ),
          ),
        ]),
      ),
    ),
  );
}
