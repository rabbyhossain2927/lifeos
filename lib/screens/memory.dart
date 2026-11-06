import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../services/local.dart';
import '../services/store.dart';
import '../widgets/form.dart';
import '../widgets/ui.dart';

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});
  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  // shortcut: photos stay on this phone (not synced); upload to the server later if needed.
  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 82);
    if (x == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dest = '${dir.path}/photo_$todayKey.jpg';
    await File(x.path).copy(dest);
    await Local.setPhoto(todayKey, dest);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final photo = Local.photoFor(todayKey);
    final now = DateTime.now();
    final lastYear = s.day(dayKey(DateTime(now.year - 1, now.month, now.day)));
    final old = (lastYear['text'] ?? '').toString().trim();
    final oldPhoto = Local.photoFor(dayKey(DateTime(now.year - 1, now.month, now.day)));
    final moments = s.list('moments')..sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));

    return SubPage(title: 'Memory', children: [
      GestureDetector(
        onTap: _pickPhoto,
        child: Container(
          height: 240,
          decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: photo.isNotEmpty && File(photo).existsSync()
              ? Image.file(File(photo), fit: BoxFit.cover, width: double.infinity)
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(width: 56, height: 56, decoration: const BoxDecoration(color: C.lime, shape: BoxShape.circle), child: const Icon(Icons.photo_camera_outlined)),
                  const SizedBox(height: 10),
                  Text('Photo of the day', style: t(16, w: w6)),
                  Text('One picture to remember ${weekdaysLong[now.weekday - 1]}', style: t(13, c: C.muted)),
                ]),
        ),
      ),
      Box(
        dark: true,
        padding: const EdgeInsets.all(18),
        child: Col([
          H2('On this day, ${now.year - 1}', color: C.white),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 64,
              height: 64,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: C.dark3, borderRadius: BorderRadius.circular(16)),
              child: oldPhoto.isNotEmpty && File(oldPhoto).existsSync() ? Image.file(File(oldPhoto), fit: BoxFit.cover) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(old.isEmpty ? 'Nothing from a year ago yet. Keep writing; it will show here.' : '“$old”',
                  maxLines: 5, overflow: TextOverflow.ellipsis, style: t(15, c: old.isEmpty ? C.darkMuted : C.white, h: 1.45)),
            ),
          ]),
        ], space: 10),
      ),
      Box(
        child: Col([
          CardHead('Life timeline', action: '+ Big moment', onAction: () => _edit(context, s)),
          if (moments.isEmpty) Text('Add the big moments of your life: a new job, a trip, a first launch.', style: t(13, c: C.muted, h: 1.4)),
          for (var i = 0; i < moments.length; i++)
            GestureDetector(
              onTap: () => _edit(context, s, moments[i]),
              child: IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(
                    width: 60,
                    child: Text(_when('${moments[i]['date'] ?? ''}'), style: t(12, w: w6, c: C.muted)),
                  ),
                  Column(children: [
                    Container(width: 12, height: 12, margin: const EdgeInsets.only(top: 3), decoration: BoxDecoration(shape: BoxShape.circle, color: i == 0 ? C.lime2 : C.ink)),
                    Expanded(child: Container(width: 2, color: i < moments.length - 1 ? C.line : Colors.transparent)),
                  ]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${moments[i]['title']}', style: t(15, w: w5)),
                        if ((moments[i]['note'] ?? '').toString().isNotEmpty) Text('${moments[i]['note']}', style: t(12, c: C.muted)),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
        ], space: 8),
      ),
    ]);
  }

  static String _when(String d) {
    final x = DateTime.tryParse(d);
    return x == null ? '' : '${months[x.month - 1]} ${x.year}';
  }

  static Future<void> _edit(BuildContext context, Store s, [Json? m]) async {
    final v = await showForm(context, m == null ? 'Big moment' : 'Edit moment', const [
      Field('title', 'What happened', required: true),
      Field('note', 'A line about it'),
      Field('date', 'When', type: F.date),
    ], initial: m ?? {'date': todayKey}, onDelete: m == null ? null : () => s.remove('moments', m['id'] as String));
    if (v == null) return;
    if (m == null) {
      s.add('moments', v);
    } else {
      s.patch('moments', m['id'] as String, v);
    }
  }
}
