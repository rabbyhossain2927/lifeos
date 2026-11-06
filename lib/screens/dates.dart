import 'package:flutter/material.dart';
import '../services/store.dart';
import '../widgets/form.dart';
import '../widgets/ui.dart';

/// Next time a (yearly) date comes round.
DateTime nextOccurrence(Json d) {
  final date = DateTime.tryParse('${d['date'] ?? ''}') ?? DateTime.now();
  if (d['yearly'] == false) return date;
  final now = DateTime.now();
  var n = DateTime(now.year, date.month, date.day);
  if (n.isBefore(DateTime(now.year, now.month, now.day))) n = DateTime(now.year + 1, date.month, date.day);
  return n;
}

class DatesScreen extends StatelessWidget {
  const DatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final dates = s.list('dates')..sort((a, b) => nextOccurrence(a).compareTo(nextOccurrence(b)));
    final people = s.list('people');
    final first = dates.isEmpty ? null : dates.first;
    final today = DateTime.now();
    int inDays(Json d) => nextOccurrence(d).difference(DateTime(today.year, today.month, today.day)).inDays;

    return SubPage(
      title: 'Dates and people',
      trailing: RoundBtn(icon: Icons.add_rounded, label: 'Add date', bg: C.ink, fg: C.white, onTap: () => _editDate(context, s)),
      children: [
        if (first != null)
          Box(
            dark: true,
            padding: const EdgeInsets.all(18),
            onTap: () => _editDate(context, s, first),
            child: Row(children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: C.lime, borderRadius: BorderRadius.circular(20)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('${nextOccurrence(first).day}', style: t(22, w: w6, h: 1)),
                  Text(months[nextOccurrence(first).month - 1].toUpperCase(), style: t(11, w: w6)),
                ]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${first['title']}', style: t(18, w: w6, c: C.white)),
                  Text(inDays(first) == 0 ? 'Today' : 'In ${inDays(first)} day${inDays(first) == 1 ? '' : 's'} · ${first['kind'] ?? 'Date'}', style: t(13, c: C.darkMuted)),
                ]),
              ),
            ]),
          ),
        ListCard(
          title: 'Coming up',
          rows: [
            for (final d in dates.skip(1))
              ListRow(
                leading: SizedBox(
                  width: 44,
                  child: Column(children: [
                    Text('${nextOccurrence(d).day}', style: t(18, w: w6)),
                    Text(months[nextOccurrence(d).month - 1].toUpperCase(), style: t(11, w: w5, c: C.muted)),
                  ]),
                ),
                title: '${d['title']}',
                sub: '${d['kind'] ?? 'Date'} · remind ${d['remindDays'] ?? 1} day${(d['remindDays'] ?? 1) == 1 ? '' : 's'} before',
                onTap: () => _editDate(context, s, d),
              ),
          ],
          empty: 'Add birthdays, anniversaries and renewals (passport, domain, licence). You get a reminder before each.',
        ),
        Row(children: [
          const Expanded(child: H2('Gift ideas')),
          SmallPill('+ Person', bg: C.white, onTap: () => _editPerson(context, s)),
        ]),
        if (people.isEmpty) Text('Note gift ideas for the people you love, whenever you think of one.', style: t(13, c: C.muted)),
        for (final p in people)
          Box(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            onTap: () => _editPerson(context, s, p),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: C.chip, shape: BoxShape.circle),
                child: Text('${p['name']}'.isEmpty ? '?' : '${p['name']}'[0].toUpperCase(), style: t(15, w: w6)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${p['name']}', style: t(15, w: w5)),
                  Text((p['ideas'] ?? '').toString().isEmpty ? 'Tap to add ideas' : '${p['ideas']}', style: t(12, c: C.muted)),
                ]),
              ),
            ]),
          ),
      ],
    );
  }

  static Future<void> _editDate(BuildContext context, Store s, [Json? d]) async {
    final v = await showForm(context, d == null ? 'New date' : 'Edit date', const [
      Field('title', 'What', required: true, hint: "Mom's birthday"),
      Field('date', 'Date', type: F.date, required: true),
      Field('kind', 'Type', type: F.choice, options: ['Birthday', 'Anniversary', 'Renewal', 'Other']),
      Field('remindDays', 'Remind me how many days before', type: F.number, hint: '3'),
      Field('yearly', 'Every year', type: F.toggle, hint: 'Repeats every year'),
    ], initial: d ?? {'yearly': true, 'remindDays': 1}, onDelete: d == null ? null : () => s.remove('dates', d['id'] as String));
    if (v == null) return;
    final data = {...v, 'remindDays': v['remindDays'] ?? 1};
    if (d == null) {
      s.add('dates', data);
    } else {
      s.patch('dates', d['id'] as String, data);
    }
  }

  static Future<void> _editPerson(BuildContext context, Store s, [Json? p]) async {
    final v = await showForm(context, p == null ? 'New person' : '${p['name']}', const [
      Field('name', 'Name', required: true),
      Field('ideas', 'Gift ideas', type: F.long, hint: 'Warm shawl · perfume'),
      Field('likes', 'Notes (likes, kids names…)', type: F.long),
    ], initial: p, onDelete: p == null ? null : () => s.remove('people', p['id'] as String));
    if (v == null) return;
    if (p == null) {
      s.add('people', v);
    } else {
      s.patch('people', p['id'] as String, v);
    }
  }
}
