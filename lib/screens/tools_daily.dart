import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/life.dart';
import '../services/store.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import '../widgets/ui.dart';
import 'home.dart';
import 'tools.dart';

String clockOf(int m) {
  m = ((m % 1440) + 1440) % 1440;
  return hmA(DateTime(2000, 1, 1, m ~/ 60, m % 60));
}

/// Asks for one line of text in a sheet.
void askText(BuildContext context, String title, String hint, void Function(String v) onSave, {String initial = '', String button = 'Save'}) {
  final c = TextEditingController(text: initial);
  showSheet(context, title, (ctx, _) => Col([
        SoftField(controller: c, hint: hint, pill: true),
        PressPill(button, success: true, onTap: () {
          if (c.text.trim().isEmpty) return;
          onSave(c.text.trim());
          Navigator.pop(ctx);
        }),
      ], space: 12));
}

/// Adds or removes a string in a list setting (custom moods, wind-down…).
List<String> listSetting(Store s, String key, List<String> defaults) => ((s.settings[key] as List?) ?? defaults).map((e) => '$e').toList();

// ------------------------------------------------------------------ Prayer
class PrayerPage extends StatelessWidget {
  const PrayerPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final times = s.prayerTimes;
    final prayed = s.prayedOn();
    final next = s.nextPrayer;
    final mins = next.value.difference(DateTime.now()).inMinutes.clamp(0, 99999);
    return ToolFrame('prayer', children: [
      HeroCard(
        label: 'Next prayer',
        big: '${next.key} · ${hmA(next.value)}',
        sub: 'in ${mins >= 60 ? '${mins ~/ 60}h ${mins % 60}m' : '${mins}m'} · ${s.cityName} · ${s.shafi ? 'Shafi' : 'Hanafi'}',
        dots: [for (final n in times.keys) (prayed.contains(n), n[0])],
      ),
      RowsPanel(title: 'Today', hint: '${prayed.length} of 5', rows: [
        for (final e in times.entries)
          Row2(
            title: e.key,
            sub: prayed.contains(e.key) ? 'Prayed · +10 XP' : 'Tap when you pray',
            right: hmA(e.value),
            done: prayed.contains(e.key),
            onTick: () {
              s.togglePrayer(e.key);
              if (!prayed.contains(e.key) && prayed.length == 4) say(context, 'All 5 prayers today. MashaAllah!');
            },
          ),
      ]),
      Panel(
          title: 'Prayed at',
          hint: 'tap again to clear',
          child: Chips(
              options: const ['Mosque', 'Home', 'Work'],
              selected: {'${s.day()['prayedAt'] ?? ''}'},
              onTap: (v) => s.patchDay({'prayedAt': s.day()['prayedAt'] == v ? null : v}))),
      Press(
        onTap: () => openTool(context, 'dhikr'),
        label: 'Dhikr counter',
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(24)),
          child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: C.lime, shape: BoxShape.circle), child: const Icon(Icons.touch_app_outlined, color: C.onLime, size: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Dhikr counter', style: t(15, w: w6)),
                Text('${s.dhikrTotal()} today · big round button', style: t(12, c: C.muted)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: C.muted),
          ]),
        ),
      ),
    ]);
  }
}

// ------------------------------------------------------------------ Dhikr
class DhikrPage extends StatefulWidget {
  const DhikrPage({super.key});
  @override
  State<DhikrPage> createState() => _DhikrPageState();
}

class _DhikrPageState extends State<DhikrPage> {
  String? cur;
  double pressed = 1;

  void _edit(Store s, [Map<String, dynamic>? d]) {
    final name = TextEditingController(text: '${d?['name'] ?? ''}');
    final meaning = TextEditingController(text: '${d?['meaning'] ?? ''}');
    var target = ((d?['target'] ?? 33) as num).toInt();
    showSheet(context, d == null ? 'Add dhikr or dua' : 'Edit dhikr', (ctx, set) => Col([
          SoftField(controller: name, hint: 'Ya Hayyu Ya Qayyum', pill: true),
          SoftField(controller: meaning, hint: 'Meaning (optional)', pill: true),
          Text('Target', style: t(14, w: w6)),
          Stepper2(
            value: '$target',
            unit: 'times',
            onMinus: () => set(() => target = math.max(1, target - 1)),
            onPlus: () => set(() => target++),
            onType: (v) => set(() => target = math.max(1, v.round())),
          ),
          Chips(options: const ['33', '34', '99', '100', '1000'], selected: {'$target'}, onTap: (v) => set(() => target = int.parse(v))),
          PressPill('Save', success: true, onTap: () {
            final n = name.text.trim();
            if (n.isEmpty) return;
            final l = s.dhikrs;
            final item = {'name': n, 'meaning': meaning.text.trim(), 'target': target};
            final i = d == null ? -1 : l.indexWhere((x) => x['name'] == d['name']);
            i < 0 ? l.add(item) : l[i] = item;
            s.setSetting('dhikrs', l);
            setState(() => cur = n);
            Navigator.pop(ctx);
          }),
        ], space: 12));
  }

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final list = s.dhikrs;
    if (list.isEmpty) list.addAll(Life.defaultDhikr.map((e) => Map<String, dynamic>.from(e)));
    final item = list.firstWhere((d) => d['name'] == cur, orElse: () => list.first);
    final name = '${item['name']}';
    final target = ((item['target'] ?? 33) as num).toInt();
    final counts = s.dhikrCounts();
    final c = ((counts[name] ?? 0) as num).toInt();
    final week = s.last7.fold<int>(0, (a, k) => a + s.dhikrTotal(k));
    void setCount(int v) => s.patchDay({'dhikrCounts': {...counts, name: v}});
    return ToolFrame('dhikr', trailing: HeadPill('Reset', onTap: () => setCount(0)), children: [
      SizedBox(
        height: 44,
        child: ListView(scrollDirection: Axis.horizontal, children: gap([
          for (final d in list)
            Chip2('${d['name']}', on: d['name'] == name, off: C.white, onTap: () => setState(() => cur = '${d['name']}')),
        ], 8)),
      ),
      Center(
        child: GestureDetector(
          onTapDown: (_) => setState(() => pressed = 0.96),
          onTapCancel: () => setState(() => pressed = 1),
          onTapUp: (_) {
            setState(() => pressed = 1);
            setCount(c + 1);
            if (c + 1 == target) {
              Haptic.celebrate();
              toast(context, '$target done. MashaAllah!');
            } else {
              Haptic.select();
            }
          },
          child: Semantics(
            button: true,
            label: 'Count $name, $c of $target',
            child: AnimatedScale(
              scale: pressed,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              child: SizedBox(
                width: 240,
                height: 240,
                child: Stack(alignment: Alignment.center, children: [
                  Container(
                    width: 224,
                    height: 224,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(center: const Alignment(0, -0.3), colors: [C.white, C.chip]),
                      boxShadow: const [BoxShadow(color: Color(0x1F1F1F23), blurRadius: 40, offset: Offset(0, 18))],
                    ),
                  ),
                  Ring(value: c / target, size: 232, stroke: 8, color: C.ink, track: C.off),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    CountText(c, style: t(56, w: FontWeight.w700, ls: -2)),
                    Text('of $target · tap anywhere', style: t(12.5, c: C.muted)),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
      Column(children: [
        Text(name, style: t(18, w: w6), textAlign: TextAlign.center),
        if ('${item['meaning'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${item['meaning']}', style: t(13, c: C.muted), textAlign: TextAlign.center)),
      ]),
      Row(children: gap([
        Expanded(child: _stat('Today', '${s.dhikrTotal()}', 'all dhikr')),
        Expanded(child: _stat('This week', '$week', '')),
        Expanded(child: _stat('Rounds', '${c ~/ target}', 'of $target', lime: true)),
      ], 8)),
      RowsPanel(title: 'My dhikr and duas', hint: 'swipe ← to delete', rows: [
        for (final d in list)
          Row2(
            swipeId: 'dhikr-${d['name']}',
            title: '${d['name']}',
            sub: [if ('${d['meaning'] ?? ''}'.isNotEmpty) '${d['meaning']}', 'target ${d['target']}'].join(' · '),
            right: '${counts[d['name']] ?? 0}',
            onTap: () => setState(() => cur = '${d['name']}'),
            onDots: () => showMenuSheet(context, '${d['name']}', [
              MenuItem('Edit', Icons.edit_outlined, () => _edit(s, d)),
              MenuItem('Delete', Icons.delete_outline_rounded, () => s.setSetting('dhikrs', list.where((x) => x['name'] != d['name']).toList()), danger: true),
            ]),
            onDelete: () => s.setSetting('dhikrs', list.where((x) => x['name'] != d['name']).toList()),
            onUndo: () => s.setSetting('dhikrs', list),
          ),
      ]),
      PressPill('+ Add dhikr or dua', bg: C.white, fg: C.ink, height: 50, onTap: () => _edit(s)),
    ]);
  }

  Widget _stat(String k, String v, String sub, {bool lime = false}) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: lime ? C.lime : C.white, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: t(11, c: lime ? C.onLime : C.muted)),
          Text(v, style: t(20, w: w6, c: lime ? C.onLime : C.ink)),
          if (sub.isNotEmpty) Text(sub, style: t(11, c: lime ? C.onLime : C.muted)),
        ]),
      );
}

// ------------------------------------------------------------------ Habits
const habitColors = [0xFFB8DB4A, 0xFFC7B8FF, 0xFF9FD3F2, 0xFFFFC9A8, 0xFFF4B6C8, 0xFFA8E6CF, 0xFFE8D5B5];

/// Seven boxes for this week; tap a box to count that day.
class HabitWeek extends StatelessWidget {
  final Json h;
  const HabitWeek(this.h, {super.key});
  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final color = Color(((h['color'] ?? habitColors.first) as num).toInt());
    final ws = weekStart;
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(children: gap([
      for (var i = 0; i < 7; i++)
        Expanded(
          child: Builder(builder: (_) {
            final d = ws.add(Duration(days: i));
            final k = dayKey(d);
            final on = s.habitDone(h, k);
            final future = d.isAfter(DateTime.now());
            return Press(
              onTap: future ? null : () => s.toggleHabit(h, k),
              haptic: on ? Haptic.tap : Haptic.success,
              label: '${h['name']} ${weekdaysLong[d.weekday - 1]}',
              selected: on,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? color : (future ? Colors.transparent : C.chip),
                  borderRadius: BorderRadius.circular(9),
                  border: k == todayKey && !on ? Border.all(color: C.border, width: 1.2) : null,
                ),
                child: Text(letters[d.weekday - 1], style: t(10, w: FontWeight.w700, c: on ? C.onLime : C.muted.withValues(alpha: future ? 0.5 : 1))),
              ),
            );
          }),
        ),
    ], 5));
  }
}

/// One habit row with streak, week boxes, ⋯ menu and swipe to delete.
Row2 habitRow(BuildContext context, Store s, Json h) => Row2(
      swipeId: 'habit-${h['id']}',
      title: '${h['name']}',
      sub: s.streak(h) > 0 ? '${s.streak(h)} day streak' : 'Start today',
      below: HabitWeek(h),
      onDots: () => showMenuSheet(context, '${h['name']}', [
        MenuItem('Edit', Icons.edit_outlined, () => editHabit(context, s, h)),
        MenuItem('Delete', Icons.delete_outline_rounded, () => s.remove('habits', h['id'] as String), danger: true),
      ]),
      onDelete: () => s.remove('habits', h['id'] as String),
      onUndo: () => s.save('habits', h),
    );

void editHabit(BuildContext context, Store s, [Json? h]) {
  final name = TextEditingController(text: '${h?['name'] ?? ''}');
  var color = ((h?['color'] ?? habitColors[s.list('habits').length % habitColors.length]) as num).toInt();
  showSheet(context, h == null ? 'New habit' : 'Edit habit', (ctx, set) => Col([
        SoftField(controller: name, hint: 'Drink 8 glasses', pill: true),
        Text('Colour', style: t(14, w: w6)),
        Wrap(spacing: 10, children: [
          for (final c in habitColors)
            Press(
              onTap: () => set(() => color = c),
              haptic: Haptic.select,
              label: 'Colour',
              selected: color == c,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle, border: Border.all(color: color == c ? C.ink : Colors.transparent, width: 2.5)),
              ),
            ),
        ]),
        PressPill('Save', success: true, onTap: () {
          final n = name.text.trim();
          if (n.isEmpty) return;
          h == null ? s.add('habits', {'name': n, 'color': color, 'logs': <String, dynamic>{}}) : s.patch('habits', h['id'] as String, {'name': n, 'color': color});
          Navigator.pop(ctx);
        }),
      ], space: 12));
}

class HabitsPage extends StatelessWidget {
  const HabitsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final hs = s.list('habits');
    final done = s.habitsDoneToday;
    final best = hs.fold<int>(0, (a, h) => s.bestStreak(h) > a ? s.bestStreak(h) : a);
    final names = hs.map((h) => '${h['name']}'.toLowerCase()).toSet();
    final presets = ['Meditate 5 min', 'Stretch', 'Sleep by 11', 'Give sadaqah', 'Read Quran', 'Walk 20 min'].where((p) => !names.contains(p.toLowerCase())).toList();
    return ToolFrame('habits', children: [
      HeroCard(label: 'Today', big: '$done of ${hs.length} habits', sub: best > 0 ? 'Best streak $best days · keep going' : 'Tap a box to start a streak', ring: hs.isEmpty ? 0 : done / hs.length),
      RowsPanel(title: 'This week', hint: 'tap a box · swipe ← to delete', empty: 'No habits yet. Add one below.', rows: [for (final h in hs) habitRow(context, s, h)]),
      Panel(
        title: 'Add a habit',
        child: Chips(
          options: [...presets.take(4), 'Custom…'],
          add: true,
          onTap: (n) => n == 'Custom…'
              ? editHabit(context, s)
              : s.add('habits', {'name': n, 'color': habitColors[hs.length % habitColors.length], 'logs': <String, dynamic>{}}),
        ),
      ),
    ]);
  }
}

// ------------------------------------------------------------------ Water
/// A drinking glass; water sits inside the outline, never over it.
class GlassIcon extends StatelessWidget {
  final double fill; // 0..1
  final double size;
  final bool strong;
  const GlassIcon({super.key, required this.fill, this.size = 44, this.strong = false});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: fill.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => CustomPaint(size: Size(size * 0.8, size), painter: _GlassPainter(v, strong ? C.ink : C.border)),
      );
}

class _GlassPainter extends CustomPainter {
  final double fill;
  final Color stroke;
  _GlassPainter(this.fill, this.stroke);
  Path _glass(Size s, double inset) {
    final w = s.width, h = s.height;
    return Path()
      ..moveTo(w * 0.06 + inset, h * 0.06 + inset)
      ..lineTo(w * 0.94 - inset, h * 0.06 + inset)
      ..lineTo(w * 0.80 - inset, h * 0.92 - inset)
      ..quadraticBezierTo(w * 0.78 - inset, h * 0.98 - inset, w * 0.70 - inset, h * 0.98 - inset)
      ..lineTo(w * 0.30 + inset, h * 0.98 - inset)
      ..quadraticBezierTo(w * 0.22 + inset, h * 0.98 - inset, w * 0.20 + inset, h * 0.92 - inset)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size s) {
    const sw = 2.2;
    final inner = _glass(s, sw * 1.2);
    canvas.save();
    canvas.clipPath(inner);
    final top = s.height * 0.98 - (s.height * 0.86) * fill;
    canvas.drawRect(Rect.fromLTRB(0, top, s.width, s.height), Paint()..color = const Color(0xFF9FD3F2));
    canvas.restore();
    canvas.drawPath(
        _glass(s, sw / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeJoin = StrokeJoin.round
          ..color = stroke);
  }

  @override
  bool shouldRepaint(_GlassPainter o) => o.fill != fill || o.stroke != stroke;
}

class WaterPage extends StatelessWidget {
  const WaterPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final ml = s.waterMlOn(), goal = s.waterGoalMl, g = s.glassMl;
    final count = math.max(8, (goal / g).ceil());
    String l(num v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 2)} L' : '${v.round()} ml';
    return ToolFrame('water', children: [
      HeroCard(label: 'Today', big: l(ml), sub: 'of ${l(goal)} · ${(ml / g).toStringAsFixed(ml % g == 0 ? 0 : 1)} glasses', ring: ml / goal),
      Panel(
        title: 'Tap a glass',
        hint: '$g ml each',
        child: GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.9,
          children: [
            for (var i = 0; i < count; i++)
              Press(
                onTap: () {
                  final next = (i + 1) * g;
                  s.setWaterMl(ml >= next && ml < next + g ? i * g : next);
                  if (next >= goal && ml < goal) {
                    Haptic.celebrate();
                    toast(context, 'Water goal done!');
                  }
                },
                haptic: Haptic.select,
                label: 'Glass ${i + 1}',
                scale: 0.92,
                child: Container(
                  decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(18)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    GlassIcon(fill: ((ml - i * g) / g).clamp(0.0, 1.0), size: 44, strong: ml > i * g),
                    const SizedBox(height: 4),
                    Text('${(i + 1) * g}', style: t(10, w: w6, c: C.muted)),
                  ]),
                ),
              ),
          ],
        ),
      ),
      Panel(
        title: 'Add custom amount',
        child: Chips(
          options: const ['+100 ml', '+200 ml', '+330 ml', '+500 ml', 'Other…', '− Undo 250'],
          add: true,
          onTap: (v) async {
            if (v == 'Other…') {
              final n = await askNumber(context, 'How much did you drink? (ml)', '250');
              if (n != null) s.setWaterMl(ml + n.round());
            } else if (v.startsWith('−')) {
              s.setWaterMl(ml - 250);
            } else {
              s.setWaterMl(ml + int.parse(v.replaceAll(RegExp(r'[^0-9]'), '')));
            }
          },
        ),
      ),
      Panel(
        title: 'Daily goal',
        hint: 'tap the number to type',
        child: Stepper2(
          value: '$goal',
          unit: 'ml',
          onMinus: () => s.setSetting('waterGoalMl', math.max(250, goal - 250)),
          onPlus: () => s.setSetting('waterGoalMl', goal + 250),
          onType: (v) => s.setSetting('waterGoalMl', math.max(100, v.round())),
        ),
      ),
      Panel(title: 'Glass size', hint: 'ml', child: Chips(options: const ['200', '250', '330', '500'], selected: {'$g'}, onTap: (v) => s.setSetting('glass', int.parse(v)))),
      HeroCard(
        tone: HeroTone.white,
        label: 'This week',
        big: '${l(s.last7.fold<int>(0, (a, k) => a + s.waterMlOn(k)) / 7)} avg',
        sub: 'A day',
        bars: [for (var i = 0; i < 7; i++) (s.waterMlOn(s.last7[i]).toDouble(), s.last7Letters[i])],
        barMax: goal.toDouble(),
      ),
    ]);
  }
}

// ------------------------------------------------------------------ Food
/// Picks an icon that matches the food name.
IconData foodIcon(String name) {
  final n = name.toLowerCase();
  bool has(List<String> w) => w.any(n.contains);
  if (has(['tea', 'cha'])) return Icons.emoji_food_beverage_outlined;
  if (has(['coffee'])) return Icons.coffee_outlined;
  if (has(['egg', 'dim'])) return Icons.egg_outlined;
  if (has(['rice', 'bhat', 'biryani', 'khichuri', 'polao'])) return Icons.rice_bowl_outlined;
  if (has(['roti', 'paratha', 'bread', 'naan', 'toast', 'luchi'])) return Icons.bakery_dining_outlined;
  if (has(['fish', 'mach', 'hilsa', 'ilish'])) return Icons.set_meal_outlined;
  if (has(['chicken', 'beef', 'mutton', 'kebab', 'meat', 'curry', 'mangsho'])) return Icons.kebab_dining_outlined;
  if (has(['dal', 'soup', 'lentil'])) return Icons.soup_kitchen_outlined;
  if (has(['noodle', 'pasta', 'ramen'])) return Icons.ramen_dining_outlined;
  if (has(['burger', 'sandwich'])) return Icons.lunch_dining_outlined;
  if (has(['pizza'])) return Icons.local_pizza_outlined;
  if (has(['milk', 'juice', 'lassi', 'shake', 'water'])) return Icons.local_drink_outlined;
  if (has(['cake', 'sweet', 'mishti', 'dessert', 'chocolate'])) return Icons.cake_outlined;
  if (has(['ice cream'])) return Icons.icecream_outlined;
  if (has(['cookie', 'biscuit'])) return Icons.cookie_outlined;
  if (has(['banana', 'apple', 'mango', 'fruit', 'orange', 'salad', 'vegetable', 'shobji'])) return Icons.eco_outlined;
  return Icons.restaurant_outlined;
}

class FoodPage extends StatefulWidget {
  const FoodPage({super.key});
  @override
  State<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends State<FoodPage> {
  String meal = mealNow();
  bool editQuick = false;

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final eaten = s.foodOn(todayKey);
    final kcal = s.kcalOn(todayKey), goal = s.kcalGoal;
    final hidden = listSetting(s, 'hiddenQuick', const []);
    final mine = s.list('foods')..sort((a, b) => ((b['uses'] ?? 0) as num).compareTo((a['uses'] ?? 0) as num));
    final quick = <(String, int)>[
      for (final f in mine.take(6)) ('${f['name']}', ((f['kcal'] ?? 0) as num).toInt()),
      for (final f in quickFoods) if (!mine.take(6).any((m) => '${m['name']}'.toLowerCase() == f.$1.toLowerCase())) f,
    ].where((f) => !hidden.contains(f.$1)).take(10).toList();
    return ToolFrame('food', children: [
      HeroCard(label: 'Today', big: '$kcal kcal', sub: '${(goal - kcal).clamp(0, 99999)} left of $goal · ${eaten.length} items', ring: kcal / goal),
      Panel(title: 'Meal', child: Chips(options: const ['Breakfast', 'Lunch', 'Snack', 'Dinner'], selected: {meal}, onTap: (m) => setState(() => meal = m))),
      Panel(
        title: 'Quick add',
        hint: editQuick ? 'tap × to remove' : 'one tap',
        child: Col([
          Wrap(spacing: 8, runSpacing: 10, children: [
            for (final f in quick)
              Stack(clipBehavior: Clip.none, children: [
                Press(
                  onTap: editQuick
                      ? null
                      : () {
                          addFood(s, f.$1, f.$2, meal);
                          toast(context, '+${f.$2} kcal · ${f.$1}');
                        },
                  haptic: Haptic.success,
                  label: f.$1,
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: C.border, width: 1.2)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(foodIcon(f.$1), size: 16, color: C.ink),
                      const SizedBox(width: 6),
                      Text(f.$1, style: t(13.5, w: w5)),
                      const SizedBox(width: 6),
                      Text('${f.$2}', style: t(12.5, c: C.muted)),
                    ]),
                  ),
                ),
                if (editQuick)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Press(
                      onTap: () {
                        s.setSetting('hiddenQuick', [...hidden, f.$1]);
                        final m = mine.where((x) => x['name'] == f.$1).firstOrNull;
                        if (m != null) s.remove('foods', m['id'] as String);
                      },
                      label: 'Remove ${f.$1}',
                      child: Container(width: 22, height: 22, decoration: BoxDecoration(color: C.ink, shape: BoxShape.circle, border: Border.all(color: C.white, width: 2)), child: Icon(Icons.close_rounded, size: 12, color: C.white)),
                    ),
                  ),
              ]),
            if (!editQuick) Chip2('Other food', add: true, onTap: () => _other(context, s)),
          ]),
          Row(children: [
            Expanded(child: PressPill(editQuick ? 'Done' : 'Edit quick add', bg: C.chip, fg: C.ink, height: 44, onTap: () => setState(() => editQuick = !editQuick))),
            if (hidden.isNotEmpty && editQuick) ...[const SizedBox(width: 8), Expanded(child: PressPill('Show all again', bg: C.chip, fg: C.ink, height: 44, onTap: () => s.setSetting('hiddenQuick', <String>[])))],
          ]),
        ], space: 12),
      ),
      RowsPanel(title: 'Eaten today', hint: 'swipe ← to delete', empty: 'Nothing yet. Tap a food above.', rows: [
        for (final f in eaten.reversed)
          Row2(
            swipeId: 'food-${f['id']}',
            leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFF9EEDA), borderRadius: BorderRadius.circular(12)), child: Icon(foodIcon('${f['name']}'), size: 18, color: const Color(0xFF7A5212))),
            title: '${f['name']}',
            sub: '${f['meal'] ?? ''}',
            right: '${f['kcal']} kcal',
            onDots: () => showMenuSheet(context, '${f['name']}', [
              MenuItem('Change calories', Icons.edit_outlined, () async {
                final v = await askNumber(context, 'Calories', '${f['kcal']}');
                if (v != null) s.patch('food', f['id'] as String, {'kcal': v.round()});
              }),
              MenuItem('Delete', Icons.delete_outline_rounded, () => s.remove('food', f['id'] as String), danger: true),
            ]),
            onDelete: () => s.remove('food', f['id'] as String),
            onUndo: () => s.save('food', f),
          ),
      ]),
      Panel(
        title: 'Daily calorie goal',
        hint: 'tap the number to type',
        child: Stepper2(
          value: '$goal',
          unit: 'kcal',
          onMinus: () => s.setSetting('kcalGoal', math.max(800, goal - 50)),
          onPlus: () => s.setSetting('kcalGoal', goal + 50),
          onType: (v) => s.setSetting('kcalGoal', math.max(500, v.round())),
        ),
      ),
    ]);
  }

  void _other(BuildContext context, Store s) {
    final name = TextEditingController();
    var kcal = 200;
    showSheet(context, 'Other food', (ctx, set) => Col([
          SoftField(controller: name, hint: 'Khichuri', pill: true, onChanged: (_) => set(() {})),
          Row(children: [Icon(foodIcon(name.text), size: 20), const SizedBox(width: 8), Text('Icon picked from the name', style: t(12, c: C.muted))]),
          Stepper2(value: '$kcal', unit: 'kcal', onMinus: () => set(() => kcal = (kcal - 50).clamp(0, 5000)), onPlus: () => set(() => kcal += 50), onType: (v) => set(() => kcal = v.round())),
          PressPill('Add', success: true, onTap: () {
            final n = name.text.trim();
            if (n.isEmpty) return;
            addFood(s, n, kcal, meal);
            s.add('foods', {'name': n, 'size': '1', 'kcal': kcal, 'uses': 1});
            Navigator.pop(ctx);
          }),
        ], space: 12));
  }
}

// ------------------------------------------------------------------ Sleep
String sleepMessage(double h) {
  if (h <= 0) return 'Pick how long you slept.';
  if (h < 5) return 'Too little. Focus, mood and hunger control drop. Try a 20 minute nap after Dhuhr and sleep early tonight.';
  if (h < 6) return 'Short night. You may feel tired and snack more. Aim for 7 hours tonight.';
  if (h < 7) return 'A bit short. Fine once, but a week of this adds up. Try going to bed 30 minutes earlier.';
  if (h < 8.5) return 'Good sleep. Best for focus, mood and energy. Keep this rhythm.';
  if (h < 9.5) return 'Great rest. Your body and mind are well charged.';
  return 'Long sleep. Fine sometimes; if it happens often, check your energy and stress.';
}

class SleepPage extends StatelessWidget {
  const SleepPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final h = s.sleepOn(todayKey);
    final winds = listSetting(s, 'windDown', const ['No phone 30 min before bed', 'Wudu and Ayatul Kursi', 'Lights off by 11:30 PM']);
    final doneW = ((s.day()['wind'] as List?) ?? const []).map((e) => '$e').toSet();
    final q = '${s.day()['sleepQ'] ?? ''}';
    final ins = s.sleepInsight;
    String hm(double x) => '${x.floor()}h ${((x % 1) * 60).round().toString().padLeft(2, '0')}m';
    return ToolFrame('sleep', children: [
      HeroCard(
        label: 'Last night',
        big: h > 0 ? hm(h) : '—',
        sub: ins.$1 > 0 ? '7 day average ${hm(ins.$1)}' : 'Pick your hours below',
        bars: [for (var i = 0; i < 7; i++) (s.sleepOn(s.last7[i]), s.last7Letters[i])],
        barMax: 10,
      ),
      Panel(
        title: 'Hours slept',
        child: Chips(
          options: [for (final x in [4, 5, 6, 7, 8, 9]) '${x}h', if (h > 0 && h != h.roundToDouble()) hm(h), 'Custom…'],
          selected: {h == h.roundToDouble() ? '${h.round()}h' : hm(h)},
          onTap: (v) async {
            if (v == 'Custom…') {
              final n = await askNumber(context, 'Hours slept (like 6.5)', h > 0 ? '$h' : '7');
              if (n != null) s.patchDay({'sleepH': n.toDouble()});
            } else if (v.endsWith('h')) {
              final x = double.parse(v.replaceAll('h', ''));
              s.patchDay({'sleepH': h == x ? null : x});
            }
          },
        ),
      ),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: h > 0 && h < 6 ? C.warnSoft : C.limeSoft, borderRadius: BorderRadius.circular(22)),
        child: Col([
          Text(h > 0 ? 'What ${hm(h)} means' : 'How sleep helps', style: t(12, w: w6, c: h > 0 && h < 6 ? C.warn : C.limeText)),
          Text(sleepMessage(h), style: t(14, w: w5, h: 1.45, c: h > 0 && h < 6 ? C.warn : C.limeText)),
        ], space: 4),
      ),
      Panel(
        title: 'How did you sleep?',
        hint: 'tap again to clear',
        child: Chips(options: const ['Great', 'Okay', 'Poor'], selected: {q}, onTap: (v) => s.patchDay({'sleepQ': q == v ? null : v})),
      ),
      RowsPanel(title: 'Wind-down', hint: 'swipe ← to delete', empty: 'Add a step below.', rows: [
        for (final w in winds)
          Row2(
            swipeId: 'wind-$w',
            title: w,
            done: doneW.contains(w),
            onTick: () => s.patchDay({'wind': doneW.contains(w) ? (doneW..remove(w)).toList() : [...doneW, w]}),
            onDots: () => showMenuSheet(context, w, [
              MenuItem('Rename', Icons.edit_outlined, () => askText(context, 'Rename step', w, (v) => s.setSetting('windDown', [for (final x in winds) x == w ? v : x]), initial: w)),
              MenuItem('Delete', Icons.delete_outline_rounded, () => s.setSetting('windDown', winds.where((x) => x != w).toList()), danger: true),
            ]),
            onDelete: () => s.setSetting('windDown', winds.where((x) => x != w).toList()),
            onUndo: () => s.setSetting('windDown', winds),
          ),
      ]),
      PressPill('+ Add wind-down step', bg: C.white, fg: C.ink, height: 50, onTap: () => askText(context, 'New wind-down step', 'Read 10 minutes', (v) => s.setSetting('windDown', [...winds, v]), button: 'Add')),
    ]);
  }
}

// ------------------------------------------------------------------ Mood
class MoodPage extends StatelessWidget {
  const MoodPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final m = s.moodToday;
    final moods = listSetting(s, 'moods', moodWords);
    final reasons = listSetting(s, 'moodReasons', const ['Work', 'Family', 'Health', 'Sleep', 'Deen', 'Friends', 'Weather']);
    final why = ((s.day()['moodWhy'] as List?) ?? const []).map((e) => '$e').toSet();
    final history = s.list('days').where((d) => d['mood'] != null).toList()..sort((a, b) => '${b['id']}'.compareTo('${a['id']}'));
    var good = 0;
    for (final k in s.last7.reversed) {
      if (moodScore(s.day(k)['mood']) >= 4) {
        good++;
      } else if (k != todayKey) {
        break;
      }
    }
    void editList(String key, List<String> l, String item) => showMenuSheet(context, item, [
          MenuItem('Rename', Icons.edit_outlined, () => askText(context, 'Rename', item, (v) => s.setSetting(key, [for (final x in l) x == item ? v : x]), initial: item)),
          MenuItem('Delete', Icons.delete_outline_rounded, () => s.setSetting(key, l.where((x) => x != item).toList()), danger: true),
        ]);
    return ToolFrame('mood', children: [
      HeroCard(
        label: 'Right now',
        big: m ?? 'Tap a mood',
        sub: good >= 2 ? '$good good days in a row' : 'One tap a day shows your pattern',
        bars: [for (var i = 0; i < 7; i++) (moodScore(s.day(s.last7[i])['mood']).toDouble(), s.last7Letters[i])],
        barMax: 5,
      ),
      Panel(
        title: 'How are you now?',
        hint: 'hold to edit',
        child: Chips(
          options: [...moods, '+ New mood'],
          selected: {m ?? ''},
          onLong: (v) => v.startsWith('+') ? null : editList('moods', moods, v),
          onTap: (v) => v == '+ New mood' ? askText(context, 'New mood', 'Grateful', (x) => s.setSetting('moods', [...moods, x]), button: 'Add') : s.patchDay({'mood': m == v ? null : v}),
        ),
      ),
      Panel(
        title: "What's behind it?",
        hint: 'pick any · hold to edit',
        child: Chips(
          options: [...reasons, '+ New'],
          selected: why,
          onLong: (v) => v.startsWith('+') ? null : editList('moodReasons', reasons, v),
          onTap: (v) => v == '+ New'
              ? askText(context, 'New reason', 'Study', (x) => s.setSetting('moodReasons', [...reasons, x]), button: 'Add')
              : s.patchDay({'moodWhy': why.contains(v) ? (why..remove(v)).toList() : [...why, v]}),
        ),
      ),
      RowsPanel(title: 'Daily moods', hint: 'swipe ← to delete', empty: 'Your moods show here.', rows: [
        for (final d in history.take(30))
          Row2(
            swipeId: 'mood-${d['id']}',
            title: '${d['mood']}',
            sub: '${d['id'] == todayKey ? 'Today' : shortDate(parseDay('${d['id']}'))}${(d['moodWhy'] as List?)?.isNotEmpty == true ? ' · ${(d['moodWhy'] as List).join(', ')}' : ''}',
            onDots: () => showSheet(context, 'Change mood', (ctx, _) => Chips(
                options: moods,
                selected: {'${d['mood']}'},
                onTap: (v) {
                  s.patchDay({'mood': v}, '${d['id']}');
                  Navigator.pop(ctx);
                })),
            onDelete: () => s.patchDay({'mood': null, 'moodWhy': null}, '${d['id']}'),
            onUndo: () => s.patchDay({'mood': d['mood'], 'moodWhy': d['moodWhy']}, '${d['id']}'),
          ),
      ]),
    ]);
  }
}

// ------------------------------------------------------------------ Health
class HealthPage extends StatelessWidget {
  const HealthPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final steps = s.stepsOn(), goal = s.stepGoal;
    final w = (s.day()['weight'] ?? s.weight ?? 70) as num;
    final works = ((s.day()['workouts'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final past = s.list('days').where((d) => d['id'] != todayKey && (d['steps'] != null || d['weight'] != null || (d['workouts'] as List?)?.isNotEmpty == true)).toList()
      ..sort((a, b) => '${b['id']}'.compareTo('${a['id']}'));
    num r1(num x) => (x * 10).round() / 10;
    void setWorks(List<Map<String, dynamic>> l) => s.patchDay({'workouts': l});
    return ToolFrame('health', children: [
      HeroCard(label: 'Steps today', big: '$steps', sub: '${(steps * 0.00072).toStringAsFixed(1)} km · goal $goal', ring: steps / goal),
      Panel(
        title: 'Steps',
        hint: 'tap the number to type',
        child: Stepper2(
          value: '$steps',
          onMinus: () => s.patchDay({'steps': (steps - 500).clamp(0, 99999)}),
          onPlus: () => s.patchDay({'steps': steps + 500}),
          onType: (v) => s.patchDay({'steps': v.round().clamp(0, 200000)}),
        ),
      ),
      Panel(
        title: 'Weight',
        hint: 'tap the number to type',
        child: Stepper2(
          value: r1(w).toStringAsFixed(1),
          unit: 'kg',
          onMinus: () => s.patchDay({'weight': r1(w - 0.1)}),
          onPlus: () => s.patchDay({'weight': r1(w + 0.1)}),
          onType: (v) => s.patchDay({'weight': r1(v)}),
        ),
      ),
      Panel(
        title: 'Log a workout',
        child: Chips(
          options: const ['Walk 20 min', 'Push-ups', 'Stretch', 'Cycling', 'Football', 'Custom…'],
          add: true,
          onTap: (n) async {
            if (n == 'Custom…') {
              askText(context, 'Workout name', 'Swimming', (name) async {
                final m = await askNumber(context, 'Minutes', '30');
                setWorks([...works, {'n': name, 'min': (m ?? 30).round()}]);
              }, button: 'Next');
              return;
            }
            const mins = {'Walk 20 min': 20, 'Push-ups': 10, 'Stretch': 10, 'Cycling': 30, 'Football': 60};
            s.patchDay({'workouts': [...works, {'n': n, 'min': mins[n]}], if (n.startsWith('Walk')) 'steps': steps + 2400});
            toast(context, '$n logged.');
          },
        ),
      ),
      RowsPanel(title: 'Today', hint: 'swipe ← to delete', empty: 'No workout yet.', rows: [
        for (var i = 0; i < works.length; i++)
          Row2(
            swipeId: 'work-$todayKey-$i-${works[i]['n']}',
            title: '${works[i]['n']}',
            right: '${works[i]['min']} min',
            onDots: () => showMenuSheet(context, '${works[i]['n']}', [
              MenuItem('Change minutes', Icons.edit_outlined, () async {
                final m = await askNumber(context, 'Minutes', '${works[i]['min']}');
                if (m != null) setWorks([for (var j = 0; j < works.length; j++) j == i ? {...works[j], 'min': m.round()} : works[j]]);
              }),
              MenuItem('Delete', Icons.delete_outline_rounded, () => setWorks([...works]..removeAt(i)), danger: true),
            ]),
            onDelete: () => setWorks([...works]..removeAt(i)),
            onUndo: () => setWorks(works),
          ),
      ]),
      RowsPanel(title: 'Past days', hint: 'swipe ← to delete a day', empty: 'Older days show here.', rows: [
        for (final d in past.take(14))
          Row2(
            swipeId: 'hday-${d['id']}',
            title: niceDate(parseDay('${d['id']}')),
            sub: [
              if (d['steps'] != null) '${d['steps']} steps',
              if (d['weight'] != null) '${d['weight']} kg',
              if ((d['workouts'] as List?)?.isNotEmpty == true) '${(d['workouts'] as List).length} workout${(d['workouts'] as List).length == 1 ? '' : 's'}',
            ].join(' · '),
            onDelete: () => s.patchDay({'steps': null, 'weight': null, 'workouts': null}, '${d['id']}'),
            onUndo: () => s.patchDay({'steps': d['steps'], 'weight': d['weight'], 'workouts': d['workouts']}, '${d['id']}'),
          ),
      ]),
    ]);
  }
}

// ------------------------------------------------------------------ Reminders
class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});
  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  final title = TextEditingController();
  TimeOfDay time = const TimeOfDay(hour: 21, minute: 0);
  String repeat = 'Every day';
  static const repeats = ['Once', 'Every day', 'Weekdays', 'Every week', 'Every month'];

  String _hhmm(TimeOfDay x) => '${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final rs = s.list('reminders');
    String timesOf(Json r) => (r['times'] as List? ?? const []).map((x) {
          final p = '$x'.split(':');
          return p.length == 2 ? clockOf((int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0)) : '$x';
        }).join(', ');
    String repeatOf(Json r) => '${r['repeat'] ?? (r['weekdays'] == true ? 'Weekdays' : 'Every day')}';
    final now = DateTime.now().hour * 60 + DateTime.now().minute;
    final left = <(int, String)>[];
    for (final r in rs.where((r) => r['on'] != false)) {
      for (final tm in (r['times'] as List? ?? const [])) {
        final p = '$tm'.split(':');
        if (p.length == 2) {
          final m = (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
          if (m > now) left.add((m, '${r['title']}'));
        }
      }
    }
    left.sort((a, b) => a.$1.compareTo(b.$1));
    return ToolFrame('reminders', children: [
      HeroCard(label: 'Today', big: '${left.length} left', sub: left.isEmpty ? 'All done for today' : 'Next: ${left.first.$2} at ${clockOf(left.first.$1)}'),
      Panel(
        title: 'New reminder',
        child: Col([
          SoftField(controller: title, hint: 'Pay internet bill', pill: true),
          Chips(
            options: ['9:00 AM', '2:00 PM', '9:00 PM', 'Pick time · ${time.format(context)}'],
            selected: {
              time == const TimeOfDay(hour: 9, minute: 0)
                  ? '9:00 AM'
                  : time == const TimeOfDay(hour: 14, minute: 0)
                      ? '2:00 PM'
                      : time == const TimeOfDay(hour: 21, minute: 0)
                          ? '9:00 PM'
                          : 'Pick time · ${time.format(context)}'
            },
            onTap: (v) async {
              if (v.startsWith('Pick')) {
                final x = await showTimePicker(context: context, initialTime: time);
                if (x != null) setState(() => time = x);
              } else {
                setState(() => time = v == '9:00 AM' ? const TimeOfDay(hour: 9, minute: 0) : v == '2:00 PM' ? const TimeOfDay(hour: 14, minute: 0) : const TimeOfDay(hour: 21, minute: 0));
              }
            },
          ),
          Chips(options: repeats, selected: {repeat}, onTap: (v) => setState(() => repeat = v)),
          PressPill('Add reminder', success: true, onTap: () {
            if (title.text.trim().isEmpty) {
              say(context, 'Type what to remind you about.', good: false);
              return;
            }
            s.add('reminders', {'title': title.text.trim(), 'times': [_hhmm(time)], 'repeat': repeat, 'weekdays': repeat == 'Weekdays', 'date': todayKey, 'on': true});
            title.clear();
            FocusScope.of(context).unfocus();
            toast(context, 'Reminder added · $repeat at ${time.format(context)}');
          }),
        ], space: 10),
      ),
      RowsPanel(title: 'All reminders', hint: 'swipe ← to delete', empty: 'No reminders yet.', rows: [
        for (final r in rs)
          Row2(
            swipeId: 'rem-${r['id']}',
            title: '${r['title']}',
            sub: '${repeatOf(r)} · ${timesOf(r)}',
            trailing: Toggle(on: r['on'] != false, label: '${r['title']}', onChanged: (v) => s.patch('reminders', r['id'] as String, {'on': v})),
            onDots: () => showMenuSheet(context, '${r['title']}', [
              MenuItem('Rename', Icons.edit_outlined, () => askText(context, 'Rename', '${r['title']}', (v) => s.patch('reminders', r['id'] as String, {'title': v}), initial: '${r['title']}')),
              MenuItem('Change time', Icons.schedule_rounded, () async {
                final x = await showTimePicker(context: context, initialTime: time);
                if (x != null) s.patch('reminders', r['id'] as String, {'times': [_hhmm(x)]});
              }),
              MenuItem('Delete', Icons.delete_outline_rounded, () => s.remove('reminders', r['id'] as String), danger: true),
            ]),
            onDelete: () => s.remove('reminders', r['id'] as String),
            onUndo: () => s.save('reminders', r),
          ),
      ]),
    ]);
  }
}
