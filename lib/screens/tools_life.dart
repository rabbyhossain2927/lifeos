import 'package:flutter/material.dart';
import '../services/photos.dart';
import '../services/store.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import '../widgets/ui.dart';
import 'tools.dart';
import 'tools_daily.dart';

Future<DateTime?> pickDate(BuildContext context, DateTime initial) {
  Haptic.tap();
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(1940),
    lastDate: DateTime(2100),
    builder: (c, child) => Theme(data: Theme.of(c).copyWith(colorScheme: ColorScheme.light(primary: C.ink, onPrimary: C.lime, surface: C.white)), child: child!),
  );
}

/// A pill that shows a date and opens the picker.
class DatePill extends StatelessWidget {
  final DateTime value;
  final String label;
  final ValueChanged<DateTime> onPick;
  const DatePill({super.key, required this.value, required this.label, required this.onPick});
  @override
  Widget build(BuildContext context) => Press(
        onTap: () async {
          final d = await pickDate(context, value);
          if (d != null) onPick(d);
        },
        label: label,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(999)),
          child: Row(children: [
            Text(label, style: t(14, c: C.muted)),
            const Spacer(),
            Text(niceDate(value), style: t(15, w: w6)),
            const SizedBox(width: 6),
            const Icon(Icons.calendar_today_outlined, size: 16),
          ]),
        ),
      );
}

// ------------------------------------------------------------------ Dates
class DatesPage extends StatefulWidget {
  const DatesPage({super.key});
  @override
  State<DatesPage> createState() => _DatesPageState();
}

class _DatesPageState extends State<DatesPage> {
  final name = TextEditingController();
  DateTime date = DateTime.now();
  String kind = 'Birthday';
  String remind = '1 day before';
  static const remindDays = {'On the day': 0, '1 day before': 1, '1 week before': 7};

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final up = upcomingDates(s);
    return ToolFrame('dates', children: [
      up.isEmpty
          ? const HeroCard(label: 'Next up', big: 'No dates yet', sub: 'Add birthdays and big days below. LifeOS reminds you.')
          : HeroCard(label: 'Next up', big: '${up.first.$1['title']}', sub: '${niceDate(up.first.$2)} · ${inDays(up.first.$3)}'),
      RowsPanel(title: 'Coming up', hint: 'hold to delete', empty: 'Nothing yet.', rows: [
        for (final d in up.skip(1))
          Row2(
            title: '${d.$1['title']}',
            sub: '${d.$1['kind'] ?? 'Date'} · ${niceDate(d.$2)}',
            right: d.$3 == 0 ? 'Today' : '${d.$3} days',
            onLongPress: () async {
              if (await confirm(context, 'Delete ${d.$1['title']}?')) s.remove('dates', d.$1['id'] as String);
            },
          ),
      ]),
      Panel(
        title: 'Add a date',
        child: Col([
          SoftField(controller: name, hint: "Name, like Tanim's birthday", pill: true),
          DatePill(value: date, label: 'Date', onPick: (d) => setState(() => date = d)),
        ], space: 10),
      ),
      Panel(title: 'Type', child: Chips(options: const ['Birthday', 'Anniversary', 'Other'], selected: {kind}, onTap: (v) => setState(() => kind = v))),
      Panel(title: 'Remind me', child: Chips(options: remindDays.keys.toList(), selected: {remind}, onTap: (v) => setState(() => remind = v))),
      PressPill('Save date', success: true, onTap: () {
        if (name.text.trim().isEmpty) {
          say(context, 'Type a name first.', good: false);
          return;
        }
        s.add('dates', {'title': name.text.trim(), 'date': dayKey(date), 'kind': kind, 'remindDays': remindDays[remind], 'yearly': kind != 'Other'});
        name.clear();
        FocusScope.of(context).unfocus();
        toast(context, 'Saved. Reminder ${remind.toLowerCase()}.');
      }),
    ]);
  }
}

// ------------------------------------------------------------------ Travel
/// Photo strip with an "+ Add" tile. Photos upload to your server in the background.
class PhotoGrid extends StatelessWidget {
  final List photos;
  final ValueChanged<List> onChanged;
  final int max;
  const PhotoGrid({super.key, required this.photos, required this.onChanged, this.max = 10});
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: [
        for (var i = 0; i < photos.length; i++)
          Press(
            onTap: () => push(context, PhotoViewer(photos: photos, start: i)),
            onLongPress: () => showMenuSheet(context, 'Photo', [MenuItem('Remove photo', Icons.delete_outline_rounded, () => onChanged([...photos]..removeAt(i)), danger: true)]),
            label: 'Photo ${i + 1}',
            child: PhotoBox(photos[i]),
          ),
        if (photos.length < max)
          Press(
            onTap: () async {
              final picked = await Photos.pickMany(limit: max - photos.length);
              if (picked.isEmpty) return;
              final local = [for (final p in picked) {'local': p, 'url': ''}];
              onChanged([...photos, ...local]);
              // Upload, then save the web addresses.
              final done = [for (final p in picked) await Photos.store(p)];
              onChanged([...photos, ...done]);
            },
            label: 'Add photos',
            child: Container(
              decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border, width: 1.2)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate_outlined, color: C.ink), const SizedBox(height: 4), Text('Add', style: t(12, w: w6))]),
            ),
          ),
      ],
    );
  }
}

class PhotoViewer extends StatelessWidget {
  final List photos;
  final int start;
  const PhotoViewer({super.key, required this.photos, this.start = 0});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0),
        body: PageView(
          controller: PageController(initialPage: start),
          children: [for (final p in photos) InteractiveViewer(child: Center(child: PhotoBox(p, fit: BoxFit.contain, radius: 0)))],
        ),
      );
}

int tripDays(Json t) {
  final f = DateTime.tryParse('${t['from']}');
  final to = DateTime.tryParse('${t['to'] ?? ''}') ?? f;
  return f == null ? 1 : to!.difference(f).inDays + 1;
}

String tripWhen(Json t) {
  final f = DateTime.tryParse('${t['from']}');
  final to = DateTime.tryParse('${t['to'] ?? ''}') ?? f;
  if (f == null) return '';
  return tripDays(t) > 1 ? '${shortDate(f)}–${shortDate(to!)} ${f.year}' : '${shortDate(f)} ${f.year}';
}

/// New trip, or edit one.
void editTrip(BuildContext context, Store s, [Json? tr]) {
  final place = TextEditingController(text: '${tr?['place'] ?? ''}');
  var kind = '${tr?['kind'] ?? 'Trip'}';
  var from = DateTime.tryParse('${tr?['from'] ?? ''}') ?? DateTime.now().add(const Duration(days: 7));
  var nights = tr == null ? 2 : tripDays(tr) - 1;
  showSheet(context, tr == null ? 'New trip or visit' : 'Edit', (ctx, set) => Col([
        SoftField(controller: place, hint: "Cox's Bazar · Nanu bari", pill: true),
        Chips(options: const ['Trip', 'Visit', 'Short break'], selected: {kind}, onTap: (v) => set(() => kind = v)),
        DatePill(value: from, label: 'From', onPick: (d) => set(() => from = d)),
        Stepper2(value: '$nights', unit: nights == 1 ? 'night' : 'nights', onMinus: () => set(() => nights = (nights - 1).clamp(0, 365)), onPlus: () => set(() => nights++), onType: (v) => set(() => nights = v.round().clamp(0, 365))),
        PressPill('Save', success: true, onTap: () {
          if (place.text.trim().isEmpty) return;
          final data = {'place': place.text.trim(), 'kind': kind, 'from': dayKey(from), 'to': dayKey(from.add(Duration(days: nights)))};
          if (tr == null) {
            s.add('trips', {...data, 'packing': <dynamic>[], 'plan': <String, dynamic>{}, 'photos': <dynamic>[]});
          } else {
            s.patch('trips', tr['id'] as String, data);
          }
          Navigator.pop(ctx);
        }),
      ], space: 12));
}

class TravelPage extends StatefulWidget {
  const TravelPage({super.key});
  @override
  State<TravelPage> createState() => _TravelPageState();
}

class _TravelPageState extends State<TravelPage> {
  String tab = 'All';

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final all = s.list('trips')..sort((a, b) => '${b['from']}'.compareTo('${a['from']}'));
    final year = '${DateTime.now().year}';
    final thisYear = all.where((t) => '${t['from']}'.startsWith(year) && '${t['from']}'.compareTo(todayKey) <= 0).toList();
    final trips = thisYear.where((t) => '${t['kind'] ?? 'Trip'}' != 'Visit').length;
    final visits = thisYear.where((t) => '${t['kind']}' == 'Visit').length;
    final away = thisYear.fold<int>(0, (a, t) => a + tripDays(t));
    final shown = all.where((t) => switch (tab) {
          'Trips' => '${t['kind'] ?? 'Trip'}' != 'Visit',
          'Visits' => '${t['kind']}' == 'Visit',
          'Upcoming' => '${t['to'] ?? t['from']}'.compareTo(todayKey) >= 0,
          _ => true,
        });
    return ToolFrame('travel', trailing: HeadPill('+ Trip', onTap: () => editTrip(context, s)), children: [
      Row(children: gap([
        Expanded(child: _stat('$year trips', '$trips', '$away days away', dark: true)),
        Expanded(child: _stat('Visits', '$visits', 'relatives, friends')),
        Expanded(child: _stat('Photos', '${all.fold<int>(0, (a, t) => a + ((t['photos'] as List?)?.length ?? 0))}', 'all trips')),
      ], 8)),
      Panel(child: Chips(options: const ['All', 'Trips', 'Visits', 'Upcoming'], selected: {tab}, onTap: (v) => setState(() => tab = v))),
      RowsPanel(title: 'Trip list', hint: 'tap to open · swipe ← to delete', empty: 'No trips yet. Tap + Trip.', rows: [
        for (final tr in shown)
          Row2(
            swipeId: 'trip-${tr['id']}',
            leading: (tr['photos'] as List?)?.isNotEmpty == true
                ? SizedBox(width: 44, height: 44, child: PhotoBox((tr['photos'] as List).first, radius: 12))
                : Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: '${tr['kind']}' == 'Visit' ? C.limeSoft : const Color(0xFFFBEBEB), borderRadius: BorderRadius.circular(12)),
                    child: Icon('${tr['kind']}' == 'Visit' ? Icons.family_restroom_rounded : Icons.flight_takeoff_rounded, size: 20, color: '${tr['kind']}' == 'Visit' ? C.limeText : const Color(0xFFA33A3A)),
                  ),
            title: '${tr['place']}',
            sub: '${tr['kind'] ?? 'Trip'} · ${tripWhen(tr)}${(tr['photos'] as List?)?.isNotEmpty == true ? ' · ${(tr['photos'] as List).length} photos' : ''}',
            right: '${tr['from']}'.compareTo(todayKey) > 0 ? '${DateTime.parse('${tr['from']}').difference(DateTime.now()).inDays + 1}d' : null,
            onTap: () => push(context, TripPage(id: tr['id'] as String)),
            onDots: () => showMenuSheet(context, '${tr['place']}', [
              MenuItem('Open', Icons.open_in_new_rounded, () => push(context, TripPage(id: tr['id'] as String))),
              MenuItem('Edit', Icons.edit_outlined, () => editTrip(context, s, tr)),
              MenuItem('Delete', Icons.delete_outline_rounded, () => s.remove('trips', tr['id'] as String), danger: true),
            ]),
            onDelete: () => s.remove('trips', tr['id'] as String),
            onUndo: () => s.save('trips', tr),
          ),
      ]),
    ]);
  }

  Widget _stat(String k, String v, String sub, {bool dark = false}) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: dark ? C.ink : C.white, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: t(11, c: dark ? C.darkMuted : C.muted)),
          Text(v, style: t(22, w: w6, c: dark ? C.white : C.ink)),
          Text(sub, style: t(10.5, c: dark ? C.lime : C.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      );
}

class TripPage extends StatefulWidget {
  final String id;
  const TripPage({super.key, required this.id});
  @override
  State<TripPage> createState() => _TripPageState();
}

class _TripPageState extends State<TripPage> {
  int day = 0;

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final tr = s.get('trips', widget.id);
    if (tr == null) return ToolFrame('travel', children: [Panel(child: Text('This trip was deleted.', style: t(14, c: C.muted)))]);
    final id = widget.id;
    final days = tripDays(tr).clamp(1, 30);
    final pack = ((tr['packing'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final packed = pack.where((p) => p['done'] == true).length;
    final plan = tr['plan'] is Map ? Map<String, dynamic>.from(tr['plan'] as Map) : <String, dynamic>{};
    final items = ((plan['d${day + 1}'] as List?) ?? const []).map((e) => '$e').toList();
    void savePack(List<Map<String, dynamic>> l) => s.patch('trips', id, {'packing': l});
    void savePlan(List<String> l) => s.patch('trips', id, {'plan': {...plan, 'd${day + 1}': l}});
    return ToolPage(
      title: '${tr['place']}',
      subtitle: '${tr['kind'] ?? 'Trip'} · ${tripWhen(tr)}',
      icon: '${tr['kind']}' == 'Visit' ? Icons.family_restroom_rounded : Icons.flight_takeoff_rounded,
      colors: groupColors['Life']!,
      trailing: HeadPill('Edit', onTap: () => editTrip(context, s, tr)),
      children: [
        Panel(
          title: 'Photos',
          hint: 'shown again next year on this day',
          child: PhotoGrid(photos: (tr['photos'] as List?) ?? const [], onChanged: (l) => s.patch('trips', id, {'photos': l})),
        ),
        Panel(child: Chips(options: [for (var i = 0; i < days; i++) 'Day ${i + 1}'], selected: {'Day ${day + 1}'}, onTap: (v) => setState(() => day = int.parse(v.split(' ').last) - 1))),
        RowsPanel(title: 'Day ${day + 1} plan', hint: 'swipe ← to delete', empty: 'Nothing planned yet.', rows: [
          for (var i = 0; i < items.length; i++)
            Row2(
              swipeId: 'plan-$id-$day-$i-${items[i]}',
              title: items[i],
              onDots: () => showMenuSheet(context, items[i], [
                MenuItem('Edit', Icons.edit_outlined, () => askText(context, 'Edit', items[i], (v) => savePlan([for (var j = 0; j < items.length; j++) j == i ? v : items[j]]), initial: items[i])),
                MenuItem('Delete', Icons.delete_outline_rounded, () => savePlan([...items]..removeAt(i)), danger: true),
              ]),
              onDelete: () => savePlan([...items]..removeAt(i)),
              onUndo: () => savePlan(items),
            ),
        ]),
        PressPill('+ Add to Day ${day + 1}', bg: C.white, fg: C.ink, height: 50, onTap: () => askText(context, 'Add to Day ${day + 1}', 'Sunset at the beach · 5 PM', (v) => savePlan([...items, v]), button: 'Add')),
        RowsPanel(title: 'Packing list', hint: '$packed of ${pack.length} · swipe ← to delete', empty: 'Add things below.', rows: [
          for (var i = 0; i < pack.length; i++)
            Row2(
              swipeId: 'pack-$id-$i-${pack[i]['name']}',
              title: '${pack[i]['name']}',
              done: pack[i]['done'] == true,
              onTick: () => savePack([for (var j = 0; j < pack.length; j++) j == i ? {...pack[j], 'done': pack[j]['done'] != true} : pack[j]]),
              onDots: () => showMenuSheet(context, '${pack[i]['name']}', [
                MenuItem('Rename', Icons.edit_outlined, () => askText(context, 'Rename', '${pack[i]['name']}', (v) => savePack([for (var j = 0; j < pack.length; j++) j == i ? {...pack[j], 'name': v} : pack[j]]), initial: '${pack[i]['name']}')),
                MenuItem('Delete', Icons.delete_outline_rounded, () => savePack([...pack]..removeAt(i)), danger: true),
              ]),
              onDelete: () => savePack([...pack]..removeAt(i)),
              onUndo: () => savePack(pack),
            ),
        ]),
        Panel(
          title: 'Add to bag',
          child: Chips(
            options: [for (final x in const ['Passport / NID', 'Charger', 'Power bank', 'Prayer mat', 'Medicine', 'Towel', 'Snacks', 'Sunscreen', 'Umbrella']) if (!pack.any((p) => p['name'] == x)) x].take(6).toList()..add('Custom…'),
            add: true,
            onTap: (n) => n == 'Custom…' ? askText(context, 'Add to bag', 'Sandals', (v) => savePack([...pack, {'name': v, 'done': false}]), button: 'Add') : savePack([...pack, {'name': n, 'done': false}]),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ Self care
/// Minutes from midnight (older items saved "am"/"pm").
int careMinutes(Json c) {
  final t = '${c['time'] ?? ''}';
  if (t == 'am') return 8 * 60;
  if (t == 'pm') return 21 * 60;
  final p = t.split(':');
  return p.length == 2 ? (int.tryParse(p[0]) ?? 8) * 60 + (int.tryParse(p[1]) ?? 0) : 8 * 60;
}

bool careDue(Json c, DateTime d) => switch ('${c['repeat'] ?? 'Every day'}') {
      'Weekdays' => d.weekday <= 5,
      'Weekly' => d.weekday == ((c['weekday'] ?? d.weekday) as num).toInt(),
      'Date' => '${c['date']}' == dayKey(d),
      _ => true,
    };

String careWhen(Json c) {
  final r = '${c['repeat'] ?? 'Every day'}';
  final when = r == 'Weekly'
      ? 'every ${weekdaysLong[(((c['weekday'] ?? 1) as num).toInt() - 1).clamp(0, 6)]}'
      : r == 'Date'
          ? (DateTime.tryParse('${c['date']}') == null ? 'one day' : shortDate(DateTime.parse('${c['date']}')))
          : r == 'Weekdays'
              ? 'Mon–Fri'
              : 'every day';
  return '${clockOf(careMinutes(c))} · $when${c['remind'] == true ? ' · reminder on' : ''}';
}

void editCare(BuildContext context, Store s, [Json? c]) {
  final name = TextEditingController(text: '${c?['name'] ?? ''}');
  var mins = c == null ? 21 * 60 : careMinutes(c);
  var repeat = '${c?['repeat'] ?? 'Every day'}';
  var weekday = ((c?['weekday'] ?? DateTime.now().weekday) as num).toInt();
  var date = DateTime.tryParse('${c?['date'] ?? ''}') ?? DateTime.now();
  var remind = c?['remind'] ?? true;
  String hhmm(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  showSheet(context, c == null ? 'New self care' : 'Edit self care', (ctx, set) => Col([
        SoftField(controller: name, hint: 'Face mask', pill: true),
        Text('Time', style: t(14, w: w6)),
        Chips(
          options: ['8:00 AM', '6:00 PM', '10:00 PM', 'Pick time · ${clockOf(mins)}'],
          selected: {mins == 480 ? '8:00 AM' : mins == 1080 ? '6:00 PM' : mins == 1320 ? '10:00 PM' : 'Pick time · ${clockOf(mins)}'},
          onTap: (v) async {
            if (v.startsWith('Pick')) {
              final x = await showTimePicker(context: ctx, initialTime: TimeOfDay(hour: mins ~/ 60, minute: mins % 60));
              if (x != null) set(() => mins = x.hour * 60 + x.minute);
            } else {
              set(() => mins = v == '8:00 AM' ? 480 : v == '6:00 PM' ? 1080 : 1320);
            }
          },
        ),
        Text('Repeat', style: t(14, w: w6)),
        Chips(options: const ['Every day', 'Weekdays', 'Weekly', 'One date'], selected: {repeat == 'Date' ? 'One date' : repeat}, onTap: (v) => set(() => repeat = v == 'One date' ? 'Date' : v)),
        if (repeat == 'Weekly') Chips(options: const ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'], selected: {weekdaysLong[weekday - 1].substring(0, 3)}, onTap: (v) => set(() => weekday = const {'Mon': 1, 'Tue': 2, 'Wed': 3, 'Thu': 4, 'Fri': 5, 'Sat': 6, 'Sun': 7}[v]!)),
        if (repeat == 'Date') DatePill(value: date, label: 'Date', onPick: (d) => set(() => date = d)),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Remind me', style: t(15, w: w5)), Text('A notification at that time', style: t(12, c: C.muted))])),
          Toggle(on: remind == true, label: 'Remind me', onChanged: (v) => set(() => remind = v)),
        ]),
        PressPill('Save', success: true, onTap: () {
          final n = name.text.trim();
          if (n.isEmpty) return;
          final data = {'name': n, 'time': hhmm(mins), 'repeat': repeat, 'weekday': weekday, 'date': dayKey(date), 'remind': remind};
          c == null ? s.add('care', {...data, 'logs': <String, dynamic>{}}) : s.patch('care', c['id'] as String, data);
          Navigator.pop(ctx);
        }),
      ], space: 12));
}

class SelfCarePage extends StatefulWidget {
  const SelfCarePage({super.key});
  @override
  State<SelfCarePage> createState() => _SelfCarePageState();
}

class _SelfCarePageState extends State<SelfCarePage> {
  String tab = 'Today';

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final now = DateTime.now();
    final all = s.list('care')..sort((a, b) => careMinutes(a).compareTo(careMinutes(b)));
    bool done(Json c) => (c['logs'] as Map? ?? {})[todayKey] == true;
    final today = all.where((c) => careDue(c, now)).toList();
    final shown = switch (tab) {
      'Today' => today,
      'Morning' => all.where((c) => careMinutes(c) < 12 * 60).toList(),
      'Night' => all.where((c) => careMinutes(c) >= 17 * 60).toList(),
      _ => all,
    };
    final n = today.where(done).length;
    return ToolFrame('selfcare', trailing: HeadPill('+ Add', onTap: () => editCare(context, s)), children: [
      HeroCard(label: 'Today', big: today.isEmpty ? 'Nothing planned' : '$n of ${today.length} done', sub: 'Small and steady care', ring: today.isEmpty ? 0 : n / today.length),
      Panel(child: Chips(options: const ['Today', 'Morning', 'Night', 'All'], selected: {tab}, onTap: (v) => setState(() => tab = v))),
      RowsPanel(title: tab, hint: 'swipe ← to delete', empty: 'Nothing here. Tap + Add.', rows: [
        for (final c in shown)
          Row2(
            swipeId: 'care-${c['id']}',
            title: '${c['name']}',
            sub: careWhen(c),
            done: done(c),
            onTick: () {
              final logs = Map<String, dynamic>.from(c['logs'] as Map? ?? {});
              done(c) ? logs.remove(todayKey) : logs[todayKey] = true;
              s.patch('care', c['id'] as String, {'logs': logs});
            },
            onDots: () => showMenuSheet(context, '${c['name']}', [
              MenuItem('Edit', Icons.edit_outlined, () => editCare(context, s, c)),
              MenuItem('Delete', Icons.delete_outline_rounded, () => s.remove('care', c['id'] as String), danger: true),
            ]),
            onDelete: () => s.remove('care', c['id'] as String),
            onUndo: () => s.save('care', c),
          ),
      ]),
      Panel(
        title: 'Quick add',
        child: Chips(
          options: const ['Face mask', 'Oil hair', 'Walk outside', 'Quiet time', 'Custom…'],
          add: true,
          onTap: (v) => v == 'Custom…' ? editCare(context, s) : s.add('care', {'name': v, 'time': '21:00', 'repeat': 'Every day', 'remind': false, 'logs': <String, dynamic>{}}),
        ),
      ),
      const NoteCard('Tip', 'Small and same time every day beats long and random.'),
    ]);
  }
}

// ------------------------------------------------------------------ Memory
/// A memory: title, short description, date, time, kind, photos.
void editMemory(BuildContext context, Store s, [Json? m]) => push(context, MemoryEditPage(id: m?['id'] as String?));

class MemoryEditPage extends StatefulWidget {
  final String? id;
  const MemoryEditPage({super.key, this.id});
  @override
  State<MemoryEditPage> createState() => _MemoryEditPageState();
}

class _MemoryEditPageState extends State<MemoryEditPage> {
  final title = TextEditingController();
  final note = TextEditingController();
  DateTime date = DateTime.now();
  TimeOfDay time = TimeOfDay.now();
  String kind = 'Family';
  List photos = [];
  String? id;

  @override
  void initState() {
    super.initState();
    final m = widget.id == null ? null : store(context, listen: false).get('moments', widget.id!);
    if (m != null) {
      id = widget.id;
      title.text = '${m['title'] ?? ''}';
      note.text = '${m['note'] ?? ''}';
      date = DateTime.tryParse('${m['date']}') ?? date;
      final p = '${m['time'] ?? ''}'.split(':');
      if (p.length == 2) time = TimeOfDay(hour: int.tryParse(p[0]) ?? 12, minute: int.tryParse(p[1]) ?? 0);
      kind = '${m['kind'] ?? 'Family'}';
      photos = List.of((m['photos'] as List?) ?? const []);
    }
  }

  void _save({bool close = true}) {
    final s = store(context, listen: false);
    if (title.text.trim().isEmpty) {
      if (close) say(context, 'Give it a title first.', good: false);
      return;
    }
    final data = {
      'title': title.text.trim(),
      'note': note.text.trim(),
      'date': dayKey(date),
      'time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      'kind': kind,
      'photos': photos,
    };
    if (id == null) {
      id = s.add('moments', data);
    } else {
      s.patch('moments', id!, data);
    }
    if (close) {
      Navigator.pop(context);
      toast(context, 'Saved. It comes back next year on this day.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolPage(
      title: widget.id == null ? 'New memory' : 'Edit memory',
      subtitle: 'Photos, words, the date',
      icon: Icons.auto_awesome_outlined,
      colors: groupColors['Life']!,
      children: [
        Panel(
          title: 'Photos',
          hint: 'up to 10',
          child: PhotoGrid(
            photos: photos,
            onChanged: (l) {
              setState(() => photos = l);
              if (id != null) store(context, listen: false).patch('moments', id!, {'photos': l});
            },
          ),
        ),
        Panel(title: 'Title', child: SoftField(controller: title, hint: 'Ammu cooked biryani', pill: true)),
        Panel(title: 'Short description', child: SoftField(controller: note, hint: 'Everyone came home, lots of laughing', lines: 2)),
        Panel(
          title: 'Date and time',
          child: Col([
            DatePill(value: date, label: 'Date', onPick: (d) => setState(() => date = d)),
            Press(
              onTap: () async {
                final x = await showTimePicker(context: context, initialTime: time);
                if (x != null) setState(() => time = x);
              },
              label: 'Time',
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(999)),
                child: Row(children: [Text('Time', style: t(14, c: C.muted)), const Spacer(), Text(time.format(context), style: t(15, w: w6)), const SizedBox(width: 6), const Icon(Icons.schedule_rounded, size: 16)]),
              ),
            ),
          ], space: 8),
        ),
        Panel(title: 'Kind', child: Chips(options: const ['Family', 'Win', 'Funny', 'Deen', 'Trip', 'Friends'], selected: {kind}, onTap: (v) => setState(() => kind = v))),
        PressPill('Save memory', success: true, onTap: _save),
      ],
    );
  }
}

class MemoryPage extends StatelessWidget {
  const MemoryPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final all = s.list('moments')..sort((a, b) => '${b['date']} ${b['time'] ?? ''}'.compareTo('${a['date']} ${a['time'] ?? ''}'));
    final md = todayKey.substring(5);
    final year = '${DateTime.now().year}';
    bool sameDay(Object? d) => '$d'.length >= 10 && '$d'.substring(5, 10) == md && !'$d'.startsWith(year);
    final onDay = all.where((m) => sameDay(m['date'])).toList();
    // Trip photos come back as memories too.
    final tripsOnDay = s.list('trips').where((t) => sameDay(t['from']) && (t['photos'] as List?)?.isNotEmpty == true).toList();
    final hero = onDay.isNotEmpty ? onDay.first : (all.isNotEmpty ? all.first : null);
    final heroPhotos = (hero?['photos'] as List?) ?? (tripsOnDay.isNotEmpty ? tripsOnDay.first['photos'] as List : const []);
    return ToolFrame('memory', trailing: HeadPill('+ New', onTap: () => editMemory(context, s)), children: [
      if (heroPhotos.isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(24), child: AspectRatio(aspectRatio: 1.6, child: PhotoBox(heroPhotos.first, radius: 24))),
      if (tripsOnDay.isNotEmpty && onDay.isEmpty)
        HeroCard(label: 'On this day · ${'${tripsOnDay.first['from']}'.substring(0, 4)}', big: '${tripsOnDay.first['place']}', sub: '${(tripsOnDay.first['photos'] as List).length} photos from this trip', btns: [HeroBtn('Open', () => push(context, TripPage(id: tripsOnDay.first['id'] as String)), primary: true)])
      else if (hero == null)
        const HeroCard(label: 'On this day', big: 'Your first memory', sub: 'Add photos, a title and a few words. Next year LifeOS shows it to you on this day.')
      else
        HeroCard(
          label: onDay.isNotEmpty ? 'On this day · ${'${hero['date']}'.substring(0, 4)}' : 'Latest memory',
          big: '${hero['title']}',
          sub: [if ('${hero['note'] ?? ''}'.isNotEmpty) '${hero['note']}', if (DateTime.tryParse('${hero['date']}') != null) shortDate(DateTime.parse('${hero['date']}')), if (hero['time'] != null) '${hero['time']}'].join(' · '),
          btns: [HeroBtn('Open', () => push(context, MemoryView(id: hero['id'] as String)), primary: true)],
        ),
      PressPill('+ New memory', onTap: () => editMemory(context, s)),
      RowsPanel(title: 'All memories', hint: 'tap to open · swipe ← to delete', empty: 'Your memories show here.', rows: [
        for (final m in all.take(50))
          Row2(
            swipeId: 'mem-${m['id']}',
            leading: (m['photos'] as List?)?.isNotEmpty == true
                ? SizedBox(width: 44, height: 44, child: PhotoBox((m['photos'] as List).first, radius: 12))
                : Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFFBEBEB), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.auto_awesome_outlined, size: 20, color: Color(0xFFA33A3A))),
            title: '${m['title']}',
            sub: [
              '${m['kind'] ?? 'Memory'}',
              if (DateTime.tryParse('${m['date']}') != null) shortDate(DateTime.parse('${m['date']}')),
              if ((m['photos'] as List?)?.isNotEmpty == true) '${(m['photos'] as List).length} photos',
            ].join(' · '),
            onTap: () => push(context, MemoryView(id: m['id'] as String)),
            onDots: () => showMenuSheet(context, '${m['title']}', [
              MenuItem('Edit', Icons.edit_outlined, () => editMemory(context, s, m)),
              MenuItem('Delete', Icons.delete_outline_rounded, () => s.remove('moments', m['id'] as String), danger: true),
            ]),
            onDelete: () => s.remove('moments', m['id'] as String),
            onUndo: () => s.save('moments', m),
          ),
      ]),
    ]);
  }
}

class MemoryView extends StatelessWidget {
  final String id;
  const MemoryView({super.key, required this.id});
  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final m = s.get('moments', id);
    if (m == null) return ToolFrame('memory', children: [Panel(child: Text('This memory was deleted.', style: t(14, c: C.muted)))]);
    final photos = (m['photos'] as List?) ?? const [];
    final d = DateTime.tryParse('${m['date']}');
    return ToolPage(
      title: '${m['title']}',
      subtitle: [if (d != null) niceDate(d), if (m['time'] != null) '${m['time']}'].join(' · '),
      icon: Icons.auto_awesome_outlined,
      colors: groupColors['Life']!,
      trailing: HeadPill('Edit', onTap: () => editMemory(context, s, m)),
      children: [
        for (var i = 0; i < photos.length; i++)
          Press(onTap: () => push(context, PhotoViewer(photos: photos, start: i)), label: 'Photo ${i + 1}', child: ClipRRect(borderRadius: BorderRadius.circular(22), child: PhotoBox(photos[i], radius: 22))),
        if ('${m['note'] ?? ''}'.isNotEmpty) Panel(child: Text('${m['note']}', style: t(15, h: 1.55))),
        Panel(child: Row(children: [Tag('${m['kind'] ?? 'Memory'}'), const Spacer(), Text(d == null ? '' : '${d.year}', style: t(13, c: C.muted))])),
      ],
    );
  }
}
