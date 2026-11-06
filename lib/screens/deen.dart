import 'package:flutter/material.dart';
import '../services/prayer.dart';
import '../services/store.dart';
import '../widgets/form.dart';
import '../widgets/ui.dart';

class DeenScreen extends StatelessWidget {
  const DeenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final city = (s.settings['cityName'] ?? 'Dhaka').toString();
    final loc = s.settings['city'] is List ? (s.settings['city'] as List).cast<num>() : const [23.8103, 90.4125];
    final times = PrayerTimes.forDay(DateTime.now(), loc[0].toDouble(), loc[1].toDouble());
    final next = PrayerTimes.next(loc[0].toDouble(), loc[1].toDouble());
    final left = next.value.difference(DateTime.now());
    final d = s.day();
    final prayed = ((d['prayed'] as List?) ?? const []).map((e) => '$e').toSet();
    final dhikrName = (s.settings['dhikr'] ?? 'SubhanAllah').toString();
    final dhikrTarget = ((s.settings['dhikrTarget'] ?? 33) as num).toInt();
    final count = ((d['dhikr'] ?? 0) as num).toInt();
    final duas = s.list('duas');
    final duaCounts = Map<String, dynamic>.from((d['duas'] as Map?) ?? const {});
    final year = DateTime.now().year;
    final fastDoc = s.get('fasts', 'ramadan-$year');
    final fasts = ((fastDoc?['days'] as List?) ?? List.filled(30, false)).map((e) => e == true).toList();

    return SubPage(
      title: 'Deen',
      trailing: GestureDetector(
        onTap: () => _pickCity(context, s),
        child: Text(city, textAlign: TextAlign.right, style: t(12, c: C.muted), overflow: TextOverflow.ellipsis),
      ),
      children: [
        Box(
          dark: true,
          padding: const EdgeInsets.all(18),
          child: Col([
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Next prayer', style: t(13, c: C.darkMuted)),
              Text('${next.key} · ${hmA(next.value)}', style: t(32, w: w6, c: C.white, ls: -0.6)),
              Text('in ${left.inHours}h ${left.inMinutes % 60}m', style: t(13, c: C.lime)),
            ]),
            Row(children: gap([
              for (final n in PrayerTimes.names)
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      final l = {...prayed};
                      l.contains(n) ? l.remove(n) : l.add(n);
                      s.patchDay({'prayed': l.toList()});
                    },
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: n == next.key ? C.lime : (prayed.contains(n) ? C.dark3 : C.dark2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(n, style: t(11, c: n == next.key ? C.ink : C.white)),
                        Text(hm(times[n]!), style: t(13, w: w6, c: n == next.key ? C.ink : C.white)),
                        if (prayed.contains(n)) Icon(Icons.check_rounded, size: 12, color: n == next.key ? C.ink : C.lime),
                      ]),
                    ),
                  ),
                ),
            ], 6)),
            Text('Tap a prayer when you have prayed it. ${prayed.length} of 5 today.', style: t(12, c: C.darkMuted)),
          ], space: 14),
        ),
        Box(
          padding: const EdgeInsets.all(18),
          child: Col([
            GestureDetector(
              onTap: () async {
                final v = await showForm(context, 'Dhikr', const [
                  Field('n', 'Words', required: true, hint: 'SubhanAllah'),
                  Field('t', 'Target count', type: F.number, hint: '33'),
                ], initial: {'n': dhikrName, 't': dhikrTarget});
                if (v == null) return;
                s.setSetting('dhikr', v['n']);
                if (v['t'] is num) s.setSetting('dhikrTarget', v['t']);
                s.patchDay({'dhikr': 0});
              },
              child: Text(dhikrName, style: t(20, w: w6)),
            ),
            Semantics(
              button: true,
              label: 'Count one, $count of $dhikrTarget',
              child: GestureDetector(
                onTap: () => s.patchDay({'dhikr': count >= dhikrTarget ? 0 : count + 1}),
                child: Container(
                  width: 148,
                  height: 148,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: C.lime, border: Border.all(color: C.chip, width: 10)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('$count', style: t(40, w: w6)),
                    Text('of $dhikrTarget · tap', style: t(12)),
                  ]),
                ),
              ),
            ),
          ], space: 12, cross: CrossAxisAlignment.center),
        ),
        ListCard(
          title: 'My duas',
          action: '+ Write dua',
          onAction: () => _editDua(context, s),
          rows: [
            for (final du in duas)
              ListRow(
                title: '${du['name']}',
                sub: (du['text'] ?? '').toString(),
                onTap: () {
                  final n = ((duaCounts[du['id']] ?? 0) as num).toInt();
                  final target = ((du['target'] ?? 1) as num).toInt();
                  s.patchDay({'duas': {...duaCounts, du['id'] as String: n >= target ? 0 : n + 1}});
                },
                onLongPress: () => _editDua(context, s, du),
                trailing: Text('${duaCounts[du['id']] ?? 0} / ${du['target'] ?? 1}', style: t(13, c: C.muted)),
              ),
          ],
          empty: 'Write the duas you read and how many times. Tap a dua each time you read it.',
        ),
        Box(
          child: Col([
            CardHead('Ramadan fast log', note: '$year · ${fasts.where((x) => x).length} of 30'),
            GridView.count(
              crossAxisCount: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: [
                for (var i = 0; i < 30; i++)
                  GestureDetector(
                    onTap: () {
                      final l = [...fasts];
                      l[i] = !l[i];
                      s.save('fasts', {'id': 'ramadan-$year', 'days': l});
                    },
                    child: Container(decoration: BoxDecoration(color: fasts[i] ? C.lime2 : C.chip, borderRadius: BorderRadius.circular(6))),
                  ),
              ],
            ),
            Text('Tap a day to mark the fast.', style: t(12, c: C.muted)),
          ], space: 10),
        ),
      ],
    );
  }

  static Future<void> _editDua(BuildContext context, Store s, [Json? du]) async {
    final v = await showForm(context, du == null ? 'New dua' : 'Edit dua', const [
      Field('name', 'Name', required: true, hint: 'Dua for parents'),
      Field('text', 'Dua text', type: F.long),
      Field('target', 'Times to read each day', type: F.number, hint: '3'),
    ], initial: du, onDelete: du == null ? null : () => s.remove('duas', du['id'] as String));
    if (v == null) return;
    if (du == null) {
      s.add('duas', v);
    } else {
      s.patch('duas', du['id'] as String, v);
    }
  }

  static Future<void> _pickCity(BuildContext context, Store s) async {
    final v = await showForm(context, 'Your city', [
      Field('c', 'City for prayer times', type: F.choice, options: PrayerTimes.cities.keys.toList()),
    ], initial: {'c': s.settings['cityName'] ?? 'Dhaka'});
    if (v == null) return;
    final c = '${v['c']}';
    s.setSetting('cityName', c);
    s.setSetting('city', PrayerTimes.cities[c]);
  }
}
