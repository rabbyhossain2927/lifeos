import 'package:flutter/material.dart';
import '../services/life.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import '../widgets/ui.dart';
import 'goals.dart';
import 'tools.dart';

/// The lime + button: one tap to the thing you want to add.
void showAddSheet(BuildContext context) {
  final s = store(context, listen: false);
  final items = <(String, IconData, VoidCallback)>[
    ('Goal', Icons.flag_outlined, () => addGoalPage(context)),
    ('Habit', Icons.check_rounded, () => openTool(context, 'habits')),
    ('Meal', Icons.restaurant_outlined, () => openTool(context, 'food')),
    ('Glass of water', Icons.water_drop_outlined, () {
      s.setWater(s.waterOn() + 1);
      toast(context, 'Water ${s.waterOn()} of ${s.waterGoal}.');
    }),
    ('Mood', Icons.sentiment_satisfied_outlined, () => openTool(context, 'mood')),
    ('Journal', Icons.menu_book_outlined, () => openTool(context, 'journal')),
    ('Reminder', Icons.notifications_none_rounded, () => openTool(context, 'reminders')),
    ('Date', Icons.event_outlined, () => openTool(context, 'dates')),
    ('Memory', Icons.auto_awesome_outlined, () => openTool(context, 'memory')),
    ('Focus', Icons.timer_outlined, () => openTool(context, 'focus')),
  ];
  showSheet(context, 'Add', (ctx, _) => GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.05,
        children: [
          for (var i = 0; i < items.length; i++)
            Appear(
              index: i,
              child: Press(
                onTap: () {
                  Navigator.pop(ctx);
                  items[i].$3();
                },
                haptic: i == 3 ? Haptic.success : Haptic.tap,
                label: items[i].$1,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: i == 0 ? C.lime : C.chip, borderRadius: BorderRadius.circular(22)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Icon(items[i].$2, size: 22),
                    Text(items[i].$1, style: t(13, w: w6, h: 1.2)),
                  ]),
                ),
              ),
            ),
        ],
      ));
}
