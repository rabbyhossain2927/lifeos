import 'package:flutter/material.dart';
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
class TravelPage extends StatefulWidget {
  const TravelPage({super.key});
  @override
  State<TravelPage> createState() => _TravelPageState();
}

class _TravelPageState extends State<TravelPage> {
  int day = 0;

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final trip = nextTrip(s);
    final past = s.list('trips').where((x) => x != trip && '${x['to'] ?? x['from'] ?? ''}'.compareTo(todayKey) < 0).toList()
      ..sort((a, b) => '${b['from']}'.compareTo('${a['from']}'));
    if (trip == null) {
      return ToolFrame('travel', children: [
        HeroCard(label: 'Next trip', big: 'Plan a trip', sub: 'Dates, a day plan and a packing list in one place.', btns: [HeroBtn('Plan a trip', () => _newTrip(context, s), primary: true)]),
        if (past.isNotEmpty) _past(past),
      ]);
    }
    final id = trip['id'] as String;
    final from = DateTime.tryParse('${trip['from']}') ?? DateTime.now();
    final to = DateTime.tryParse('${trip['to'] ?? ''}') ?? from;
    final days = to.difference(from).inDays + 1;
    final pack = ((trip['packing'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final packed = pack.where((p) => p['done'] == true).length;
    final plan = trip['plan'] is Map ? Map<String, dynamic>.from(trip['plan'] as Map) : <String, dynamic>{};
    final dayItems = ((plan['d${day + 1}'] as List?) ?? const []).map((e) => '$e').toList();
    void savePack(List<Map<String, dynamic>> l) => s.patch('trips', id, {'packing': l});
    final toGo = from.difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)).inDays;
    return ToolFrame('travel', trailing: HeadPill('+ Trip', onTap: () => _newTrip(context, s)), children: [
      HeroCard(
        label: 'Next trip',
        big: '${trip['place']}',
        sub: '${shortDate(from)}${days > 1 ? '–${shortDate(to)}' : ''} · ${toGo <= 0 ? 'happening now' : '$toGo days to go'} · $packed of ${pack.length} packed',
        ring: pack.isEmpty ? 0 : packed / pack.length,
      ),
      Panel(title: 'Plan', child: Chips(options: [for (var i = 0; i < days.clamp(1, 14); i++) 'Day ${i + 1}'], selected: {'Day ${day + 1}'}, onTap: (v) => setState(() => day = int.parse(v.split(' ').last) - 1))),
      RowsPanel(title: 'Day ${day + 1}', hint: 'hold to delete', empty: 'Nothing planned yet.', rows: [
        for (var i = 0; i < dayItems.length; i++)
          Row2(
            title: dayItems[i],
            onLongPress: () => s.patch('trips', id, {'plan': {...plan, 'd${day + 1}': [...dayItems]..removeAt(i)}}),
          ),
      ]),
      PressPill('+ Add to Day ${day + 1}', bg: C.white, fg: C.ink, height: 50, onTap: () => askText(context, 'Add to Day ${day + 1}', 'Sunset at the beach · 5 PM', (v) => s.patch('trips', id, {'plan': {...plan, 'd${day + 1}': [...dayItems, v]}}), button: 'Add')),
      RowsPanel(title: 'Packing', hint: '$packed of ${pack.length}', empty: 'Add things below.', rows: [
        for (var i = 0; i < pack.length; i++)
          Row2(
            title: '${pack[i]['name']}',
            done: pack[i]['done'] == true,
            onTick: () => savePack([for (var j = 0; j < pack.length; j++) j == i ? {...pack[j], 'done': pack[j]['done'] != true} : pack[j]]),
            onLongPress: () => savePack([...pack]..removeAt(i)),
          ),
      ]),
      Panel(
        title: 'Add to bag',
        child: Chips(
          options: [for (final x in const ['Passport / NID', 'Charger', 'Power bank', 'Prayer mat', 'Medicine', 'Towel', 'Snacks', 'Sunscreen', 'Umbrella']) if (!pack.any((p) => p['name'] == x)) x].take(6).toList()..add('My own'),
          add: true,
          onTap: (n) => n == 'My own' ? askText(context, 'Add to bag', 'Sandals', (v) => savePack([...pack, {'name': v, 'done': false}]), button: 'Add') : savePack([...pack, {'name': n, 'done': false}]),
        ),
      ),
      if (past.isNotEmpty) _past(past),
    ]);
  }

  Widget _past(List<Json> past) => RowsPanel(title: 'Past trips', rows: [
        for (final p in past.take(6)) Row2(title: '${p['place']}', sub: _pastSub(p)),
      ]);

  String _pastSub(Json p) {
    final f = DateTime.tryParse('${p['from']}');
    final tt = DateTime.tryParse('${p['to'] ?? ''}') ?? f;
    if (f == null) return '';
    final n = tt!.difference(f).inDays + 1;
    return '${monthsLong[f.month - 1].substring(0, 3)} ${f.year} · $n day${n == 1 ? '' : 's'}';
  }

  void _newTrip(BuildContext context, Store s) {
    final place = TextEditingController();
    var from = DateTime.now().add(const Duration(days: 14));
    var nights = 2;
    showSheet(context, 'New trip', (ctx, set) => Col([
          SoftField(controller: place, hint: "Cox's Bazar", pill: true),
          DatePill(value: from, label: 'From', onPick: (d) => set(() => from = d)),
          Stepper2(value: '$nights', unit: nights == 1 ? 'night' : 'nights', onMinus: () => set(() => nights = (nights - 1).clamp(0, 60)), onPlus: () => set(() => nights++)),
          PressPill('Save trip', success: true, onTap: () {
            if (place.text.trim().isEmpty) return;
            s.add('trips', {'place': place.text.trim(), 'from': dayKey(from), 'to': dayKey(from.add(Duration(days: nights))), 'packing': <dynamic>[], 'plan': <String, dynamic>{}});
            Navigator.pop(ctx);
            setState(() => day = 0);
          }),
        ], space: 12));
  }
}

// ------------------------------------------------------------------ Self care
class SelfCarePage extends StatefulWidget {
  const SelfCarePage({super.key});
  @override
  State<SelfCarePage> createState() => _SelfCarePageState();
}

class _SelfCarePageState extends State<SelfCarePage> {
  late String r = DateTime.now().hour >= 15 ? 'Night' : 'Morning';

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final time = r == 'Night' ? 'pm' : 'am';
    final steps = s.list('care').where((c) => c['time'] == time).toList();
    bool done(Json c) => (c['logs'] as Map? ?? {})[todayKey] == true;
    final n = steps.where(done).length;
    var streak = 0;
    for (var i = 1; i < 60; i++) {
      final k = dayKey(DateTime.now().subtract(Duration(days: i)));
      if (steps.isNotEmpty && steps.every((c) => (c['logs'] as Map? ?? {})[k] == true)) {
        streak++;
      } else {
        break;
      }
    }
    return ToolFrame('selfcare', children: [
      HeroCard(label: '$r routine', big: steps.isEmpty ? 'No steps yet' : '$n of ${steps.length}', sub: streak > 0 ? '$streak ${r == 'Night' ? 'nights' : 'mornings'} in a row' : 'Small and steady', ring: steps.isEmpty ? 0 : n / steps.length),
      Panel(title: 'Routine', child: Chips(options: const ['Morning', 'Night'], selected: {r}, onTap: (v) => setState(() => r = v))),
      RowsPanel(title: 'Steps', hint: 'hold to delete', empty: 'Add a step below.', rows: [
        for (final c in steps)
          Row2(
            title: '${c['name']}',
            sub: '${c['note'] ?? ''}',
            done: done(c),
            onTick: () {
              final logs = Map<String, dynamic>.from(c['logs'] as Map? ?? {});
              done(c) ? logs.remove(todayKey) : logs[todayKey] = true;
              s.patch('care', c['id'] as String, {'logs': logs});
            },
            onLongPress: () async {
              if (await confirm(context, 'Delete ${c['name']}?')) s.remove('care', c['id'] as String);
            },
          ),
      ]),
      Panel(
        title: 'Add a step',
        child: Chips(
          options: const ['Face mask', 'Oil hair', 'Walk outside', 'Quiet time', 'My own'],
          add: true,
          onTap: (v) => v == 'My own'
              ? askText(context, 'New step', 'Sunscreen', (x) => s.add('care', {'name': x, 'time': time, 'logs': <String, dynamic>{}}), button: 'Add')
              : s.add('care', {'name': v, 'time': time, 'logs': <String, dynamic>{}}),
        ),
      ),
      const NoteCard('Tip', 'Small and same time every day beats long and random.'),
    ]);
  }
}

// ------------------------------------------------------------------ Memory
class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key});
  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  final text = TextEditingController();
  String kind = 'Family';

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final all = s.list('moments')..sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));
    final md = todayKey.substring(5);
    final onDay = all.where((m) => '${m['date']}'.length >= 10 && '${m['date']}'.substring(5) == md && !'${m['date']}'.startsWith('${DateTime.now().year}')).toList();
    final hero = onDay.isNotEmpty ? onDay.first : (all.isNotEmpty ? all.first : null);
    final heroDate = DateTime.tryParse('${hero?['date'] ?? ''}');
    return ToolFrame('memory', children: [
      hero == null
          ? const HeroCard(label: 'On this day', big: 'Your first memory', sub: 'Write one line below. Next year LifeOS shows it to you on this day.')
          : HeroCard(
              label: onDay.isNotEmpty ? 'On this day · ${heroDate?.year}' : 'Latest memory',
              big: '${hero['title']}',
              sub: '${hero['note'] ?? ''}'.isEmpty ? (heroDate == null ? '' : niceDate(heroDate)) : '${hero['note']} · ${heroDate == null ? '' : shortDate(heroDate)}',
            ),
      Panel(title: 'Add a memory', child: SoftField(controller: text, hint: 'What happened today worth keeping?')),
      Panel(title: 'Kind', child: Chips(options: const ['Family', 'Win', 'Funny', 'Deen', 'Trip'], selected: {kind}, onTap: (v) => setState(() => kind = v))),
      PressPill('Save memory', success: true, onTap: () {
        if (text.text.trim().isEmpty) {
          say(context, 'Write one line first.', good: false);
          return;
        }
        s.add('moments', {'title': text.text.trim(), 'note': '', 'date': todayKey, 'kind': kind});
        text.clear();
        FocusScope.of(context).unfocus();
        toast(context, 'Saved. You will see it again next year.');
      }),
      RowsPanel(title: 'Recent', hint: 'hold to delete', empty: 'Your memories show here.', rows: [
        for (final m in all.take(12))
          Row2(
            title: '${m['title']}',
            sub: '${m['kind'] ?? 'Memory'} · ${DateTime.tryParse('${m['date']}') == null ? '' : shortDate(DateTime.parse('${m['date']}'))}',
            onLongPress: () async {
              if (await confirm(context, 'Delete this memory?')) s.remove('moments', m['id'] as String);
            },
          ),
      ]),
    ]);
  }
}
