import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/life.dart';
import '../services/store.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import '../widgets/ui.dart';
import 'shell.dart';
import 'tools.dart';

const quickFoods = [('Rice plate', 340), ('Dal bowl', 150), ('Roti', 120), ('Egg', 80), ('Chicken curry', 300), ('Banana', 90), ('Tea', 40)];

String mealNow() {
  final h = DateTime.now().hour;
  return h < 11 ? 'Breakfast' : h < 16 ? 'Lunch' : h < 19 ? 'Snack' : 'Dinner';
}

void addFood(Store s, String name, int kcal, [String? meal]) =>
    s.add('food', {'day': todayKey, 'meal': meal ?? mealNow(), 'name': name, 'size': '1', 'kcal': kcal});

String userName(Store s) => '${s.settings['name'] ?? AuthService.user?.displayName ?? ''}'.trim();

/// Avatar circle: first letter on the chosen colour.
class Avatar extends StatelessWidget {
  final double size;
  final bool onDark;
  const Avatar({super.key, this.size = 48, this.onDark = false});
  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final n = userName(s);
    var c = Color(((s.settings['avatarColor'] ?? 0xFF111111) as num).toInt());
    if (onDark && c.computeLuminance() < 0.05) c = C.lime; // black on the black card would vanish
    final dark = c.computeLuminance() < 0.3;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      child: Text(n.isEmpty ? 'L' : n[0].toUpperCase(), style: t(size * 0.38, w: FontWeight.w700, c: dark ? C.lime : C.ink)),
    );
  }
}

class HomeTab extends StatelessWidget {
  final ValueChanged<int> onTab;
  const HomeTab({super.key, required this.onTab});

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final h = DateTime.now().hour;
    final hello = h < 12 ? 'Good Morning' : h < 17 ? 'Good Afternoon' : 'Good Evening';
    final times = s.prayerTimes;
    final prayed = s.prayedOn();
    final next = s.nextPrayer;
    final habits = s.list('habits');
    final hDone = s.habitsDoneToday;
    final goals = s.todayGoals;
    final gDone = goals.where(s.goalDoneToday).length;
    final total = habits.length + goals.length + 5;
    final done = hDone + gDone + prayed.length;
    final water = s.waterOn();
    final kcal = s.kcalOn(todayKey);
    final focus = s.focusOn(todayKey);
    final steps = s.stepsOn();
    final mood = s.moodToday;
    final sleepToday = s.sleepOn(todayKey) > 0 ? s.sleepOn(todayKey) : s.sleepOn(s.last7[5]);
    final pins = ((s.settings['pins'] as List?) ?? const []).map((e) => '$e').where((k) => tools.any((x) => x.key == k)).toList();

    Widget tile(Widget child, {Color? bg, double r = 22, VoidCallback? onTap, String? label}) => Press(
          onTap: onTap,
          label: label,
          scale: 0.96,
          child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: bg ?? C.white, borderRadius: BorderRadius.circular(r)), child: child),
        );
    Widget small(String k, String v, Widget viz, String tool) => tile(
          SizedBox(height: 62, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(k, style: t(11, c: C.muted)), Text(v, style: t(16, w: w6)), viz])),
          onTap: () => openTool(context, tool),
          label: k,
        );
    Widget miniBars(List<double> v) => SizedBox(
          height: 14,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: gap([
            for (var i = 0; i < v.length; i++)
              Expanded(
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 400 + i * 50),
                  height: 3 + 11 * v[i].clamp(0.0, 1.0),
                  decoration: BoxDecoration(color: i == v.length - 1 ? C.ink : const Color(0xFFDAD8DF), borderRadius: BorderRadius.circular(3)),
                ),
              ),
          ], 3)),
        );

    final bento = Column(children: gap([
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: gap([
          Expanded(
            child: tile(
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Today', style: t(13, c: C.darkMuted)),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Ring(value: total == 0 ? 0 : done / total, size: 100, stroke: 12, center: CountText(total == 0 ? 0 : (done * 100 / total).round(), style: t(22, w: w6, c: C.white), format: (v) => '${v.round()}%')),
                ),
                Text('$done of $total done', style: t(15, w: w6, c: C.white)),
                Text('${s.dayStreak}-day streak · ${s.points} pts', style: t(12, c: C.lime)),
              ]),
              bg: C.ink,
              r: 26,
              onTap: () => onTab(1),
              label: 'Today progress',
            ),
          ),
          Expanded(
            child: Column(children: [
              Expanded(
                child: tile(
                  Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Row(children: [Expanded(child: Text('Prayers', style: t(13, w: w6))), CountText(prayed.length, style: t(18, w: w6), format: (v) => '${v.round()}/5')]),
                    const SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      for (final n in times.keys)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: prayed.contains(n) ? C.ink : const Color(0x26111111), shape: BoxShape.circle),
                          child: Text(n[0], style: t(10, w: FontWeight.w700, c: prayed.contains(n) ? C.lime : C.ink)),
                        ),
                    ]),
                  ]),
                  bg: C.lime,
                  r: 26,
                  onTap: () => openTool(context, 'prayer'),
                  label: 'Prayers',
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: tile(
                  Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Row(children: [Expanded(child: Text('Habits', style: t(13, w: w6))), CountText(hDone, style: t(18, w: w6), format: (v) => '${v.round()}/${habits.length}')]),
                    const SizedBox(height: 10),
                    Row(children: gap([
                      for (final x in habits.take(8))
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 8,
                            decoration: BoxDecoration(color: s.habitDone(x) ? C.ink : C.chip, borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      if (habits.isEmpty) Expanded(child: Container(height: 8, decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(8)))),
                    ], 4)),
                  ]),
                  r: 26,
                  onTap: () => openTool(context, 'habits'),
                  label: 'Habits',
                ),
              ),
            ]),
          ),
        ], 10)),
      ),
      Row(children: gap([
        Expanded(
          child: tile(
            SizedBox(
              height: 62,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  width: 22,
                  height: 44,
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.bottomCenter,
                  decoration: BoxDecoration(border: Border.all(color: C.ink, width: 2), borderRadius: const BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(9))),
                  child: AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    heightFactor: (water / s.waterGoal).clamp(0.0, 1.0),
                    widthFactor: 1,
                    child: Container(color: const Color(0xFFBFE3F7)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text('$water/${s.waterGoal}', style: t(16, w: w6)),
                    Text('Water', style: t(11, c: C.muted)),
                  ]),
                ),
              ]),
            ),
            onTap: () => openTool(context, 'water'),
            label: 'Water',
          ),
        ),
        Expanded(child: small('Food', kcal >= 1000 ? '${(kcal / 1000).toStringAsFixed(1)}k' : '$kcal', Bar(kcal / s.kcalGoal, height: 6), 'food')),
        Expanded(child: small('Sleep', sleepToday > 0 ? '${sleepToday.floor()}h ${((sleepToday % 1) * 60).round()}m' : '—', miniBars([for (final k in s.last7) s.sleepOn(k) / 9]), 'sleep')),
      ], 10)),
      Row(children: gap([
        Expanded(child: small('Mood', mood ?? '—', miniBars([for (final k in s.last7.skip(2)) moodScore(s.day(k)['mood']) / 5]), 'mood')),
        Expanded(
          child: tile(
            SizedBox(
              height: 62,
              child: Row(children: [
                Ring(value: focus / 60, size: 34, stroke: 5, color: C.ink, track: C.chip),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('${focus}m', style: t(16, w: w6)),
                    Text('Focus', style: t(11, c: C.muted)),
                  ]),
                ),
              ]),
            ),
            onTap: () => openTool(context, 'focus'),
            label: 'Focus',
          ),
        ),
        Expanded(child: small('Steps', steps >= 1000 ? '${(steps / 1000).toStringAsFixed(1)}k' : '$steps', Bar(steps / s.stepGoal, height: 6), 'health')),
      ], 10)),
    ], 10));

    final moodIdx = mood == null ? -1 : moodWords.reversed.toList().indexOf(mood == 'Meh' ? 'Low' : mood);
    return TabBody(children: [
      Row(children: [
        Press(onTap: () => onTab(3), label: 'Account', child: const Avatar()),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(hello, style: t(16, w: w6)),
            Text(userName(s).isEmpty ? 'Welcome' : userName(s), style: t(13, c: C.muted)),
          ]),
        ),
        Press(
          onTap: () => openTool(context, 'reminders'),
          label: 'Reminders',
          scale: 0.9,
          child: Container(width: 48, height: 48, decoration: BoxDecoration(color: C.white, shape: BoxShape.circle), child: const Icon(Icons.notifications_none_rounded, size: 22)),
        ),
      ]),
      Text("Let's make today count", style: t(22, w: w6, ls: -0.4), maxLines: 1, overflow: TextOverflow.ellipsis),
      bento,
      if (pins.isNotEmpty)
        SizedBox(
          height: 46,
          child: ListView(scrollDirection: Axis.horizontal, children: gap([
            for (final k in pins)
              Press(
                onTap: () => openTool(context, k),
                label: toolOf(k).name,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
                  decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(999)),
                  child: Row(children: [
                    Container(width: 34, height: 34, decoration: BoxDecoration(color: toolOf(k).colors.$1, shape: BoxShape.circle), child: Icon(toolOf(k).icon, size: 17, color: toolOf(k).colors.$2)),
                    const SizedBox(width: 8),
                    Text(toolOf(k).name, style: t(14, w: w6)),
                  ]),
                ),
              ),
          ], 8)),
        ),
      Padding(padding: const EdgeInsets.only(left: 4, top: 6), child: Text('Daily use', style: t(18, w: w6))),
      Panel(
        title: 'Prayer times',
        hint: 'Next: ${next.key} ${hmA(next.value)}',
        child: Row(children: gap([
          for (final e in times.entries)
            Expanded(
              child: Press(
                onTap: () {
                  s.togglePrayer(e.key);
                },
                haptic: prayed.contains(e.key) ? Haptic.tap : Haptic.success,
                label: e.key,
                selected: prayed.contains(e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 68,
                  decoration: BoxDecoration(
                    color: prayed.contains(e.key) ? C.ink : (e.key == next.key ? C.lime : C.chip),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(e.key, style: t(11, c: prayed.contains(e.key) ? C.darkMuted : C.ink)),
                    Text(hm(e.value), style: t(13, w: w6, c: prayed.contains(e.key) ? C.white : C.ink)),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: prayed.contains(e.key) ? 1 : 0,
                      child: Icon(Icons.check_rounded, size: 13, color: C.lime),
                    ),
                  ]),
                ),
              ),
            ),
        ], 6)),
      ),
      RowsPanel(
        title: 'Habits',
        hint: '$hDone of ${habits.length}',
        empty: 'Add a habit with the + button.',
        rows: [
          for (final x in habits)
            Row2(
              title: '${x['name']}',
              right: s.streak(x) > 0 ? '${s.streak(x)} days' : null,
              done: s.habitDone(x),
              onTick: () => s.toggleHabit(x),
            ),
        ],
      ),
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: gap([
          Expanded(
            child: Panel(
              title: 'Water',
              hint: '$water / ${s.waterGoal}',
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (var i = 0; i < 8; i++)
                  Press(
                    onTap: () => s.setWater(i + 1 == water ? i : i + 1),
                    haptic: Haptic.select,
                    label: 'Glass ${i + 1}',
                    scale: 0.85,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 30,
                      height: 34,
                      decoration: BoxDecoration(color: i < water ? const Color(0xFFBFE3F7) : C.chip, borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.local_drink_outlined, size: 15, color: i < water ? const Color(0xFF1F4F86) : C.border),
                    ),
                  ),
              ]),
            ),
          ),
          Expanded(
            child: Panel(
              title: 'Mood',
              hint: mood ?? 'Tap',
              child: SizedBox(
                height: 60,
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: gap([
                  for (var i = 0; i < 5; i++)
                    Expanded(
                      child: Press(
                        onTap: () => s.patchDay({'mood': moodWords.reversed.toList()[i]}),
                        haptic: Haptic.select,
                        label: moodWords.reversed.toList()[i],
                        selected: i == moodIdx,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          height: 14.0 + i * 11,
                          decoration: BoxDecoration(color: i == moodIdx ? C.ink : (i <= moodIdx ? C.lime : C.chip), borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                ], 4)),
              ),
            ),
          ),
        ], 10)),
      ),
      Panel(
        title: 'What I ate',
        hint: '$kcal / ${s.kcalGoal} kcal',
        child: Col([
          Bar(kcal / s.kcalGoal),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final f in quickFoods.take(6))
              Press(
                onTap: () {
                  addFood(s, f.$1, f.$2);
                  say(context, '+${f.$2} kcal · ${f.$1}');
                },
                haptic: () {},
                label: f.$1,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(999)),
                  child: Center(
                    widthFactor: 1,
                    child: Text.rich(TextSpan(children: [
                    TextSpan(text: '+ ${f.$1} ', style: t(13, w: w5)),
                    TextSpan(text: '${f.$2}', style: t(13, c: C.muted)),
                  ])),
                  ),
                ),
              ),
          ]),
          Text(s.foodOn(todayKey).isEmpty ? 'Nothing logged yet. One tap adds it.' : 'Last: ${s.foodOn(todayKey).last['name']}', style: t(12, c: C.muted)),
        ], space: 10),
      ),
      Press(
        onTap: () => openTool(context, 'focus'),
        scale: 0.98,
        label: 'Focus',
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(24)),
          child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.timer_outlined, size: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Focus', style: t(15, w: w6)),
                Text(focus == 0 ? 'No session yet today' : '$focus min focused today', style: t(12, c: C.muted)),
              ]),
            ),
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(999)),
              child: Text('Start', style: t(14, w: w6, c: C.white)),
            ),
          ]),
        ),
      ),
    ]);
  }
}
