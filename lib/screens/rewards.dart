import 'package:flutter/material.dart';
import '../services/store.dart';
import '../widgets/form.dart';
import '../widgets/ui.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final pts = s.points;
    final rewards = s.list('rewards');
    final ws = weekStart;
    final weekWins = <String>[];
    for (var i = 0; i < 7; i++) {
      weekWins.addAll(((s.day(dayKey(ws.add(Duration(days: i))))['wins'] as List?) ?? const []).map((e) => '$e'));
    }
    final notes = s.list('notes');
    final style = (s.settings['motivation'] ?? 'Gentle').toString();
    final hardDay = s.day()['energy'] == 'Low' || s.day()['mood'] == 'Low' || s.day()['mood'] == 'Meh';

    return SubPage(title: 'Rewards', children: [
      Box(
        color: C.lime,
        padding: const EdgeInsets.all(20),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Your points', style: t(13, c: C.limeText)),
              Text('$pts', style: t(44, w: w6, ls: -1.2)),
            ]),
          ),
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('+${s.pointsToday} today', style: t(13, c: C.limeText))),
        ]),
      ),
      ListCard(
        title: 'My rewards',
        action: '+ New',
        onAction: () => _edit(context, s),
        rows: [
          for (final r in rewards)
            ListRow(
              title: '${r['name']}',
              sub: '${r['cost'] ?? 0} points',
              onLongPress: () => _edit(context, s, r),
              trailing: pts >= ((r['cost'] ?? 0) as num)
                  ? SmallPill('Redeem', bg: C.ink, fg: C.white, onTap: () async {
                      if (await confirm(context, 'Enjoy ${r['name']}?', ok: 'Redeem', body: '${r['cost']} points will be used.')) {
                        s.add('redeems', {'name': r['name'], 'cost': r['cost'], 'day': todayKey});
                      }
                    })
                  : Text('${((r['cost'] ?? 0) as num) - pts} to go', style: t(13, w: w6, c: C.muted)),
            ),
        ],
        empty: 'Pick treats you earn: a movie night, your favourite meal. Habits give 5 points, goals 10.',
      ),
      Box(
        dark: true,
        padding: const EdgeInsets.all(18),
        child: Col([
          Text('${weekWins.length} wins this week', style: t(28, w: w6, c: C.white)),
          Text(weekWins.isEmpty ? 'Log small wins in your Journal.' : 'Best one: “${weekWins.last}”', style: t(13, c: C.darkMuted, h: 1.45)),
        ], space: 6),
      ),
      Box(
        child: Col([
          CardHead('Notes from past me', action: '+ Write', onAction: () async {
            final v = await showForm(context, 'A note to future you', const [Field('text', 'Open it on a hard day', type: F.long, required: true)]);
            if (v != null) s.add('notes', {'text': v['text'], 'locked': true});
          }),
          if (notes.isEmpty) Text('Write to yourself on a good day. LifeOS opens it when you feel low.', style: t(13, c: C.muted, h: 1.4)),
          for (final n in notes)
            GestureDetector(
              onTap: () {
                if (n['locked'] == true && !hardDay) {
                  toast(context, 'This opens on a hard day (low mood or energy on Today).');
                  return;
                }
                showDialog(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: C.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    title: Text('From past you', style: t(18, w: w6)),
                    content: Text('${n['text']}', style: t(15, h: 1.5)),
                    actions: [
                      TextButton(onPressed: () {
                        s.remove('notes', n['id'] as String);
                        Navigator.pop(c);
                      }, child: Text('Delete', style: t(14, w: w6, c: C.warn))),
                      TextButton(onPressed: () => Navigator.pop(c), child: Text('Thanks', style: t(14, w: w6))),
                    ],
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(18)),
                child: Row(children: [
                  Icon(n['locked'] == true && !hardDay ? Icons.lock_outline_rounded : Icons.mail_outline_rounded, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(n['locked'] == true && !hardDay ? 'Locked · opens on a hard day' : 'Open now', style: t(14))),
                ]),
              ),
            ),
        ], space: 10),
      ),
      Box(
        child: Col([
          const H2('How should the app push you?'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3.2,
            children: [
              for (final o in const ['Gentle', 'Tough love', 'Numbers', 'Challenge'])
                GestureDetector(
                  onTap: () => s.setSetting('motivation', o),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: style == o ? C.lime : C.chip,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: style == o ? C.ink : C.chip, width: 1.5),
                    ),
                    child: Text(o, style: t(14, w: w5)),
                  ),
                ),
            ],
          ),
        ]),
      ),
    ]);
  }

  static Future<void> _edit(BuildContext context, Store s, [Json? r]) async {
    final v = await showForm(context, r == null ? 'New reward' : 'Edit reward', const [
      Field('name', 'Reward', required: true, hint: 'Movie night'),
      Field('cost', 'Points it costs', type: F.number, required: true, hint: '200'),
    ], initial: r, onDelete: r == null ? null : () => s.remove('rewards', r['id'] as String));
    if (v == null) return;
    if (r == null) {
      s.add('rewards', v);
    } else {
      s.patch('rewards', r['id'] as String, v);
    }
  }
}
