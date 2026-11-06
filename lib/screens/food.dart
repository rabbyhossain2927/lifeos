import 'package:flutter/material.dart';
import '../services/store.dart';
import '../widgets/form.dart';
import '../widgets/ui.dart';

/// Common foods with rough calories (edit freely; your own foods are added on top).
const foodLibrary = <List<Object>>[
  ['Rice', '1 plate', 260], ['Ruti', '1 piece', 120], ['Paratha', '1 piece', 260], ['Dal', '1 bowl', 150],
  ['Boiled egg', '1 egg', 78], ['Fried egg', '1 egg', 90], ['Omelette', '2 eggs', 190], ['Chicken curry', '1 cup', 240],
  ['Beef curry', '1 cup', 330], ['Fish curry', '1 piece', 200], ['Hilsa fry', '1 piece', 250], ['Vegetable curry', '1 cup', 120],
  ['Bhorta', '1 serving', 110], ['Khichuri', '1 plate', 350], ['Biryani', '1 plate', 500], ['Tehari', '1 plate', 450],
  ['Fried rice', '1 plate', 420], ['Noodles', '1 plate', 380], ['Chicken fry', '1 piece', 280], ['Singara', '1 piece', 150],
  ['Samosa', '1 piece', 130], ['Puri', '1 piece', 100], ['Fuchka', '6 pieces', 200], ['Chotpoti', '1 bowl', 250],
  ['Muri', '1 cup', 60], ['Chira with milk', '1 bowl', 250], ['Rice pudding (payesh)', '1 bowl', 220], ['Mishti / roshogolla', '1 piece', 120],
  ['Banana', '1 medium', 105], ['Apple', '1 medium', 95], ['Mango', '1 cup', 100], ['Guava', '1 medium', 70],
  ['Milk', '1 glass', 120], ['Yogurt (doi)', '1 cup', 150], ['Tea with sugar', '1 cup', 60], ['Coffee with milk', '1 cup', 80],
  ['Biscuits', '4 pieces', 140], ['Bread slice', '1 slice', 75], ['Soft drink', '1 can', 140], ['Dates (khejur)', '3 pieces', 70],
];

class FoodScreen extends StatefulWidget {
  const FoodScreen({super.key});
  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  String q = '';
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  String get _meal {
    final h = DateTime.now().hour;
    if (h < 11) return 'Breakfast';
    if (h < 16) return 'Lunch';
    if (h < 19) return 'Snacks';
    return 'Dinner';
  }

  List<Map<String, dynamic>> _all(Store s) {
    final mine = s.list('foods');
    final names = mine.map((f) => '${f['name']}'.toLowerCase()).toSet();
    final out = <Map<String, dynamic>>[
      ...mine,
      for (final f in foodLibrary)
        if (!names.contains('${f[0]}'.toLowerCase())) {'name': f[0], 'size': f[1], 'kcal': f[2], 'uses': 0},
    ];
    out.sort((a, b) => ((b['uses'] ?? 0) as num).compareTo((a['uses'] ?? 0) as num));
    return out;
  }

  void _eat(Store s, Map<String, dynamic> f) {
    s.add('food', {'day': todayKey, 'meal': _meal, 'name': f['name'], 'size': f['size'], 'kcal': f['kcal']});
    // Remember it so it is suggested first next time.
    final mine = s.list('foods').where((x) => '${x['name']}'.toLowerCase() == '${f['name']}'.toLowerCase()).firstOrNull;
    if (mine == null) {
      s.add('foods', {'name': f['name'], 'size': f['size'], 'kcal': f['kcal'], 'uses': 1});
    } else {
      s.patch('foods', mine['id'] as String, {'uses': ((mine['uses'] ?? 0) as num) + 1});
    }
    search.clear();
    setState(() => q = '');
    toast(context, 'Added ${f['name']} to $_meal');
  }

  Future<void> _custom(Store s) async {
    final v = await showForm(context, 'New food', [
      Field('name', 'Food', required: true, hint: q.isEmpty ? 'Shingara' : q),
      const Field('size', 'Amount', hint: '1 plate'),
      const Field('kcal', 'Calories (approx.)', type: F.number, required: true, hint: '250'),
    ], initial: {'name': q}, save: 'Add and eat');
    if (v == null) return;
    _eat(s, v);
  }

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final goal = ((s.settings['kcalGoal'] ?? 2000) as num).toInt();
    final eaten = s.kcalOn(todayKey);
    final water = ((s.day()['water'] ?? 0) as num).toInt();
    final ql = q.trim().toLowerCase();
    final suggestions = _all(s).where((f) => ql.isEmpty || '${f['name']}'.toLowerCase().contains(ql)).take(ql.isEmpty ? 4 : 8).toList();
    final todays = s.list('food').where((f) => f['day'] == todayKey).toList();
    final meals = <String, List<Json>>{};
    for (final f in todays) {
      (meals['${f['meal']}'] ??= []).add(f);
    }

    return SubPage(title: 'What I ate', children: [
      Box(
        dark: true,
        padding: const EdgeInsets.all(18),
        onTap: () async {
          final v = await showForm(context, 'Daily calorie goal', const [Field('n', 'kcal per day', type: F.number, required: true)], initial: {'n': goal});
          if (v?['n'] is num) s.setSetting('kcalGoal', v!['n']);
        },
        child: Row(children: [
          Ring(value: eaten / goal, size: 96, stroke: 10, center: Text('${(eaten * 100 / goal).round()}%', style: t(17, w: w6, c: C.white))),
          const SizedBox(width: 18),
          Expanded(
            child: Col([
              Text('$eaten kcal', style: t(28, w: w6, c: C.white, ls: -0.6)),
              Text(eaten <= goal ? '${goal - eaten} left of $goal' : '${eaten - goal} over $goal', style: t(13, c: C.darkMuted)),
              Row(children: [
                Text('Water $water of 8', style: t(13, c: C.darkMuted)),
                const Spacer(),
                RoundBtn(icon: Icons.remove_rounded, label: 'One glass less', size: 32, bg: C.dark2, fg: C.white, onTap: () => s.patchDay({'water': water > 0 ? water - 1 : 0})),
                const SizedBox(width: 6),
                RoundBtn(icon: Icons.add_rounded, label: 'One more glass', size: 32, bg: C.lime, onTap: () => s.patchDay({'water': water + 1})),
              ]),
            ], space: 4),
          ),
        ]),
      ),
      Box(
        child: Col([
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(999)),
            child: Row(children: [
              const Icon(Icons.search_rounded, size: 18, color: C.muted),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: search,
                  onChanged: (v) => setState(() => q = v),
                  style: t(15),
                  decoration: InputDecoration(hintText: 'Add food…', hintStyle: t(15, c: const Color(0xFF8A8A92)), border: InputBorder.none, isDense: true),
                ),
              ),
            ]),
          ),
          Text.rich(TextSpan(children: [
            TextSpan(text: 'Suggestions ', style: t(15, w: w6)),
            TextSpan(text: '· approx. kcal', style: t(15, c: C.muted)),
          ])),
          for (final f in suggestions)
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${f['name']}', style: t(15, w: w5)),
                  Text('${f['size'] ?? ''}', style: t(12, c: C.muted)),
                ]),
              ),
              Text('${f['kcal']} kcal', style: t(13, c: C.muted)),
              const SizedBox(width: 10),
              RoundBtn(icon: Icons.add_rounded, label: 'Add ${f['name']}', bg: C.lime, onTap: () => _eat(s, f)),
            ]),
          GestureDetector(
            onTap: () => _custom(s),
            child: Text('Not in the list? Type it with calories once. Next time it is suggested.', style: t(12, c: C.muted, deco: TextDecoration.underline)),
          ),
        ]),
      ),
      for (final m in const ['Breakfast', 'Lunch', 'Snacks', 'Dinner'])
        if (meals[m] != null)
          Box(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Col([
              Row(children: [
                Expanded(child: Text(m, style: t(15, w: w6))),
                Text('${meals[m]!.fold<int>(0, (a, f) => a + ((f['kcal'] ?? 0) as num).toInt())} kcal', style: t(14, w: w6)),
              ]),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final f in meals[m]!)
                  GestureDetector(
                    onLongPress: () async {
                      if (await confirm(context, 'Remove ${f['name']}?', ok: 'Remove')) s.remove('food', f['id'] as String);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(999)),
                      child: Text('${f['name']} · ${f['kcal']}', style: t(12)),
                    ),
                  ),
              ]),
            ], space: 8),
          ),
      if (todays.isEmpty) Text('Nothing logged today yet. Long-press a food to remove it.', style: t(13, c: C.muted)),
    ]);
  }
}
