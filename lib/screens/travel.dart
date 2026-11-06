import 'package:flutter/material.dart';
import '../services/store.dart';
import '../widgets/form.dart';
import '../widgets/ui.dart';

const packingTemplates = {
  'Beach': ['NID and tickets', 'Phone charger', 'Power bank', 'Sunglasses', 'Sandals', 'Towel', 'Medicine kit', 'Sunscreen'],
  'City': ['NID and tickets', 'Phone charger', 'Power bank', 'Comfortable shoes', 'Medicine kit', 'Toothbrush'],
  'Umrah': ['Passport and visa', 'Ihram', 'Prayer mat', 'Medicine kit', 'Phone charger', 'Comfortable sandals'],
};

class TravelScreen extends StatelessWidget {
  const TravelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final now = DateTime.now();
    final trips = s.list('trips')..sort((a, b) => '${a['from']}'.compareTo('${b['from']}'));
    final upcoming = trips.where((tr) => (DateTime.tryParse('${tr['to'] ?? tr['from']}') ?? now).isAfter(now.subtract(const Duration(days: 1)))).toList();
    final trip = upcoming.isEmpty ? null : upcoming.first;
    final places = s.list('places');

    return SubPage(
      title: 'Travel',
      trailing: RoundBtn(icon: Icons.add_rounded, label: 'New trip', bg: C.ink, fg: C.white, onTap: () => _editTrip(context, s)),
      children: [
        if (trip == null)
          Box(
            onTap: () => _editTrip(context, s),
            child: Col([const H2('Plan your next trip'), Text('Add dates, tickets and a packing list from a template.', style: t(13, c: C.muted))], space: 6),
          ),
        if (trip != null) ..._tripCards(context, s, trip, now),
        Box(
          child: Col([
            const H2('Places I want to visit'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in places)
                GestureDetector(
                  onLongPress: () => s.remove('places', p['id'] as String),
                  onTap: () => s.patch('places', p['id'] as String, {'visited': p['visited'] != true}),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(color: p['visited'] == true ? C.lime : C.chip, borderRadius: BorderRadius.circular(999)),
                    child: Text('${p['name']}', style: t(13, w: w5)),
                  ),
                ),
              GestureDetector(
                onTap: () async {
                  final v = await showForm(context, 'A place to visit', const [Field('name', 'Place', required: true, hint: 'Sajek Valley')]);
                  if (v != null) s.add('places', v);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: C.border, width: 1.5)),
                  child: Text('+ Add', style: t(13, w: w5)),
                ),
              ),
            ]),
            if (places.isNotEmpty) Text('Tap when visited. Long-press to remove.', style: t(12, c: C.muted)),
          ]),
        ),
        if (trips.length > upcoming.length) ListCard(title: 'Past trips', rows: [
          for (final tr in trips.where((x) => !upcoming.contains(x)))
            ListRow(title: '${tr['place']}', sub: '${tr['from'] ?? ''}', onTap: () => _editTrip(context, s, tr)),
        ]),
      ],
    );
  }

  List<Widget> _tripCards(BuildContext context, Store s, Json trip, DateTime now) {
    final from = DateTime.tryParse('${trip['from']}');
    final to = DateTime.tryParse('${trip['to'] ?? ''}');
    final days = from == null ? null : from.difference(DateTime(now.year, now.month, now.day)).inDays;
    final items = ((trip['packing'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final tickets = ((trip['tickets'] as List?) ?? const []).map((e) => '$e').toList();
    final packed = items.where((i) => i['done'] == true).length;

    void savePacking(List<Map<String, dynamic>> l) => s.patch('trips', trip['id'] as String, {'packing': l});

    return [
      Box(
        dark: true,
        padding: const EdgeInsets.all(18),
        onTap: () => _editTrip(context, s, trip),
        child: Col([
          Text('${trip['place']}', style: t(26, w: w6, c: C.white, ls: -0.5)),
          Text([
            if (from != null) '${from.day} ${months[from.month - 1]}',
            if (to != null) '– ${to.day} ${months[to.month - 1]}',
            if (from != null && to != null) '· ${to.difference(from).inDays} nights',
          ].join(' '), style: t(13, c: C.darkMuted)),
          if (days != null) Text(days <= 0 ? 'Happening now' : 'In $days days', style: t(13, w: w6, c: C.lime)),
          if (tickets.isNotEmpty)
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final tk in tickets)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: C.dark2, borderRadius: BorderRadius.circular(18)),
                  child: Text(tk, style: t(13, w: w6, c: C.white)),
                ),
            ]),
        ], space: 4),
      ),
      Box(
        child: Col([
          CardHead('Packing list', note: '$packed of ${items.length}', action: items.isEmpty ? 'Use template' : '+ Item', onAction: () async {
            if (items.isEmpty) {
              final v = await showForm(context, 'Packing template', [Field('t', 'Template', type: F.choice, options: packingTemplates.keys.toList())]);
              if (v != null) savePacking([for (final x in packingTemplates['${v['t']}']!) {'name': x, 'done': false}]);
            } else {
              final v = await showForm(context, 'Add item', const [Field('n', 'Item', required: true)]);
              if (v != null) savePacking([...items, {'name': v['n'], 'done': false}]);
            }
          }),
          for (var i = 0; i < items.length; i++)
            Row(children: [
              Tick(
                done: items[i]['done'] == true,
                square: true,
                size: 22,
                label: '${items[i]['name']}',
                onTap: () {
                  final l = [...items];
                  l[i] = {...l[i], 'done': l[i]['done'] != true};
                  savePacking(l);
                },
              ),
              Expanded(child: GestureDetector(onLongPress: () => savePacking([...items]..removeAt(i)), child: doneText('${items[i]['name']}', items[i]['done'] == true))),
            ]),
        ], space: 2),
      ),
    ];
  }

  static Future<void> _editTrip(BuildContext context, Store s, [Json? tr]) async {
    final v = await showForm(context, tr == null ? 'New trip' : 'Edit trip', const [
      Field('place', 'Where', required: true, hint: "Cox's Bazar"),
      Field('from', 'From', type: F.date, required: true),
      Field('to', 'To', type: F.date),
      Field('tickets', 'Tickets and bookings (comma separated)', hint: 'Bus ticket saved, Hotel booked'),
      Field('notes', 'Plan', type: F.long),
    ], initial: tr == null ? null : {...tr, 'tickets': ((tr['tickets'] as List?) ?? const []).join(', ')}, onDelete: tr == null ? null : () => s.remove('trips', tr['id'] as String));
    if (v == null) return;
    final data = {...v, 'tickets': '${v['tickets'] ?? ''}'.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList()};
    if (tr == null) {
      s.add('trips', {...data, 'packing': <dynamic>[]});
    } else {
      s.patch('trips', tr['id'] as String, data);
    }
  }
}
