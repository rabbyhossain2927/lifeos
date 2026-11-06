import 'package:flutter/material.dart';
import '../services/store.dart';
import '../widgets/form.dart';
import '../widgets/ui.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final books = s.list('books');
    final reading = books.where((b) => b['done'] != true).toList();
    final finished = books.where((b) => b['done'] == true).toList().reversed.toList();
    final courses = s.list('courses');
    final skills = s.list('skills');
    double hoursOf(Json k) => (k['logs'] as Map? ?? {}).values.fold<double>(0, (a, v) => a + (v is num ? v.toDouble() : 0));
    final maxH = skills.fold<double>(1, (a, k) => hoursOf(k) > a ? hoursOf(k) : a);
    final totalH = skills.fold<double>(0, (a, k) => a + hoursOf(k));
    final cur = reading.isEmpty ? null : reading.first;

    return SubPage(title: 'Learn', children: [
      Box(
        dark: true,
        padding: const EdgeInsets.all(18),
        onTap: () => cur == null ? _editBook(context, s) : _updatePage(context, s, cur),
        child: Row(children: [
          Container(width: 72, height: 104, decoration: BoxDecoration(color: C.lime, borderRadius: BorderRadius.circular(12))),
          const SizedBox(width: 16),
          Expanded(
            child: cur == null
                ? Col([Text('Add the book you are reading', style: t(18, w: w6, c: C.white)), Text('Tap to add', style: t(13, c: C.darkMuted))], space: 6)
                : Col([
                    Text('${cur['title']}', style: t(18, w: w6, c: C.white)),
                    Text('Reading now · page ${cur['page'] ?? 0} of ${cur['pages'] ?? '?'}', style: t(13, c: C.darkMuted)),
                    Bar(((cur['page'] ?? 0) as num) / (((cur['pages'] ?? 1) as num) == 0 ? 1 : (cur['pages'] ?? 1) as num), height: 6, color: C.lime, track: C.dark3),
                  ], space: 6),
          ),
        ]),
      ),
      ListCard(
        title: 'Books',
        action: '+ Book',
        onAction: () => _editBook(context, s),
        rows: [
          for (final b in reading.skip(1))
            ListRow(title: '${b['title']}', sub: 'Page ${b['page'] ?? 0} of ${b['pages'] ?? '?'}', onTap: () => _updatePage(context, s, b), onLongPress: () => _editBook(context, s, b)),
        ],
        empty: 'Your reading list. Tap the black card to update your page.',
      ),
      Box(
        child: Col([
          CardHead('Courses', action: '+ Course', onAction: () => _editCourse(context, s)),
          if (courses.isEmpty) Text('Track online courses lesson by lesson.', style: t(13, c: C.muted)),
          for (final c in courses)
            GestureDetector(
              onTap: () {
                final done = ((c['done'] ?? 0) as num).toInt(), total = ((c['total'] ?? 1) as num).toInt();
                if (done < total) s.patch('courses', c['id'] as String, {'done': done + 1});
              },
              onLongPress: () => _editCourse(context, s, c),
              child: Col([
                Row(children: [
                  Expanded(child: Text('${c['name']}', style: t(14, w: w5))),
                  Text('${c['done'] ?? 0} / ${c['total'] ?? 1} lessons', style: t(14, c: C.muted)),
                ]),
                Bar(((c['done'] ?? 0) as num) / ((c['total'] ?? 1) as num), height: 6),
              ], space: 6),
            ),
          if (courses.isNotEmpty) Text('Tap a course after each lesson. Long-press to edit.', style: t(12, c: C.muted)),
        ]),
      ),
      Box(
        child: Col([
          CardHead('Skill hours', action: '+ Log hours', onAction: () => _logHours(context, s, skills)),
          if (skills.isEmpty) Text('Log the hours you practise each skill.', style: t(13, c: C.muted)),
          for (final k in skills)
            GestureDetector(
              onLongPress: () async {
                if (await confirm(context, 'Delete ${k['name']}?')) s.remove('skills', k['id'] as String);
              },
              child: Row(children: [
                SizedBox(width: 72, child: Text('${k['name']}', style: t(13, w: w5), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 10),
                Expanded(child: Bar(hoursOf(k) / maxH, height: 10, color: C.lime2)),
                SizedBox(width: 48, child: Text('${numText(hoursOf(k))}h', textAlign: TextAlign.right, style: t(13, w: w6))),
              ]),
            ),
          if (skills.isNotEmpty) Text('${numText(totalH)} hours total', style: t(12, c: C.muted)),
        ]),
      ),
      ListCard(
        title: 'Finished · ${finished.length} book${finished.length == 1 ? '' : 's'}',
        rows: [
          for (final b in finished)
            ListRow(
              title: '${b['title']}',
              sub: (b['author'] ?? '').toString(),
              trailing: Text(b['finishedAt'] is num ? shortDate(DateTime.fromMillisecondsSinceEpoch((b['finishedAt'] as num).toInt())) : '', style: t(12, c: C.muted)),
              onLongPress: () => _editBook(context, s, b),
            ),
        ],
        empty: 'Finished books show here.',
      ),
    ]);
  }

  static Future<void> _editBook(BuildContext context, Store s, [Json? b]) async {
    final v = await showForm(context, b == null ? 'New book' : 'Edit book', const [
      Field('title', 'Title', required: true),
      Field('author', 'Author'),
      Field('pages', 'Pages', type: F.number, hint: '300'),
    ], initial: b, onDelete: b == null ? null : () => s.remove('books', b['id'] as String));
    if (v == null) return;
    if (b == null) {
      s.add('books', {...v, 'page': 0, 'done': false});
    } else {
      s.patch('books', b['id'] as String, v);
    }
  }

  static Future<void> _updatePage(BuildContext context, Store s, Json b) async {
    final v = await showForm(context, '${b['title']}', const [
      Field('page', 'I am on page', type: F.number, required: true),
      Field('done', 'Finished it', type: F.toggle, hint: 'I finished this book'),
    ], initial: {'page': b['page'], 'done': b['done'] == true});
    if (v == null) return;
    final done = v['done'] == true || (v['page'] is num && b['pages'] is num && (v['page'] as num) >= (b['pages'] as num));
    s.patch('books', b['id'] as String, {'page': v['page'], 'done': done, if (done) 'finishedAt': DateTime.now().millisecondsSinceEpoch});
    if (done && context.mounted) toast(context, 'Book finished. Nice work!');
  }

  static Future<void> _editCourse(BuildContext context, Store s, [Json? c]) async {
    final v = await showForm(context, c == null ? 'New course' : 'Edit course', const [
      Field('name', 'Course', required: true),
      Field('total', 'Number of lessons', type: F.number, required: true, hint: '20'),
      Field('done', 'Lessons done', type: F.number, hint: '0'),
    ], initial: c, onDelete: c == null ? null : () => s.remove('courses', c['id'] as String));
    if (v == null) return;
    final data = {...v, 'done': v['done'] ?? 0};
    if (c == null) {
      s.add('courses', data);
    } else {
      s.patch('courses', c['id'] as String, data);
    }
  }

  static Future<void> _logHours(BuildContext context, Store s, List<Json> skills) async {
    final v = await showForm(context, 'Log skill hours', [
      Field('name', 'Skill', required: true, hint: skills.isEmpty ? 'Design' : '${skills.first['name']}'),
      const Field('h', 'Hours today', type: F.number, required: true, hint: '1.5'),
    ], save: 'Log');
    if (v == null || v['h'] is! num) return;
    final name = '${v['name']}'.trim();
    final k = skills.where((x) => '${x['name']}'.toLowerCase() == name.toLowerCase()).firstOrNull;
    if (k == null) {
      s.add('skills', {'name': name, 'logs': {todayKey: v['h']}});
    } else {
      final logs = Map<String, dynamic>.from(k['logs'] as Map? ?? {});
      logs[todayKey] = ((logs[todayKey] ?? 0) as num) + (v['h'] as num);
      s.patch('skills', k['id'] as String, {'logs': logs});
    }
  }
}
