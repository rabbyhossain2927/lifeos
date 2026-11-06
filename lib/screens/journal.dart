import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../services/license_service.dart';
import '../services/store.dart';
import '../widgets/form.dart';
import '../widgets/ui.dart';
import 'pro.dart';
import 'shell.dart';

class JournalTab extends StatefulWidget {
  const JournalTab({super.key});
  @override
  State<JournalTab> createState() => _JournalTabState();
}

class _JournalTabState extends State<JournalTab> {
  final entry = TextEditingController();
  final g = [TextEditingController(), TextEditingController(), TextEditingController()];
  String _loadedFor = '';
  Timer? _debounce;
  final speech = SpeechToText();
  bool listening = false;

  @override
  void dispose() {
    _debounce?.cancel();
    entry.dispose();
    for (final c in g) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(Store s) {
    if (_loadedFor == todayKey) return;
    _loadedFor = todayKey;
    final d = s.day();
    entry.text = (d['text'] ?? '').toString();
    final gr = (d['grateful'] as List?) ?? const [];
    for (var i = 0; i < 3; i++) {
      g[i].text = i < gr.length ? '${gr[i]}' : '';
    }
  }

  void _save(Store s) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      s.patchDay({'text': entry.text, 'grateful': [for (final c in g) c.text]});
    });
  }

  Future<void> _mic(Store s) async {
    if (!License.unlocked(s, 'voice')) {
      showPro(context, 'voice');
      return;
    }
    if (listening) {
      await speech.stop();
      setState(() => listening = false);
      return;
    }
    final ok = await speech.initialize();
    if (!ok) {
      if (mounted) toast(context, 'Voice typing is not available on this phone.');
      return;
    }
    final before = entry.text;
    setState(() => listening = true);
    await speech.listen(
      onResult: (r) {
        entry.text = '${before.isEmpty ? '' : '$before '}${r.recognizedWords}';
        entry.selection = TextSelection.collapsed(offset: entry.text.length);
        if (r.finalResult) {
          setState(() => listening = false);
          _save(s);
        }
      },
    );
  }

  Future<void> _review(Store s, String key, String label) async {
    final v = await showForm(context, label, [Field('v', label, type: F.long)], initial: {'v': s.day()[key]});
    if (v != null) s.patchDay({key: v['v']});
  }

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    _load(s);
    final d = s.day();
    final now = DateTime.now();
    final lastYear = s.day(dayKey(DateTime(now.year - 1, now.month, now.day)));
    final old = (lastYear['text'] ?? '').toString().trim();

    return TabBody(children: [
      TabHeader(
        small: niceDate(now),
        title: 'Journal',
        trailing: RoundBtn(icon: listening ? Icons.stop_rounded : Icons.mic_none_rounded, label: 'Voice note', bg: listening ? C.lime : C.white, onTap: () => _mic(s)),
      ),
      Box(
        child: Col([
          const H2("Today's entry"),
          TextField(
            controller: entry,
            onChanged: (_) => _save(s),
            minLines: 5,
            maxLines: 12,
            style: t(15, h: 1.5),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: listening ? 'Listening…' : 'How was your day? Write anything, or tap the mic.',
              hintStyle: t(15, c: const Color(0xFF8A8A92)),
              filled: true,
              fillColor: C.chip,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            ),
          ),
          Text(d['mood'] == null ? 'Set your mood on Today' : 'Mood today: ${d['mood']}, from your check-in', style: t(12, c: C.muted)),
        ], space: 10),
      ),
      Box(
        child: Col([
          const H2('Grateful for'),
          for (var i = 0; i < 3; i++)
            Row(children: [
              SizedBox(width: 18, child: Text('${i + 1}', style: t(13, w: w6))),
              Expanded(
                child: TextField(
                  controller: g[i],
                  onChanged: (_) => _save(s),
                  style: t(15),
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: i == 2 ? 'One more thing…' : '',
                    hintStyle: t(15, c: const Color(0xFF8A8A92)),
                    border: i == 2 ? InputBorder.none : const UnderlineInputBorder(borderSide: BorderSide(color: C.line)),
                    enabledBorder: i == 2 ? InputBorder.none : const UnderlineInputBorder(borderSide: BorderSide(color: C.line)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: C.ink)),
                  ),
                ),
              ),
            ]),
        ], space: 2),
      ),
      const H2('Night review'),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: gap([
        for (final r in const [('good', 'Good', C.good), ('hard', 'Hard', C.warn), ('learned', 'Learned', C.ink)])
          Expanded(
            child: Box(
              radius: 24,
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
              onTap: () => _review(s, r.$1, r.$2),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 76),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.$2, style: t(12, w: w6, c: r.$3)),
                  const SizedBox(height: 6),
                  Text((d[r.$1] ?? '').toString().isEmpty ? 'Tap to write' : '${d[r.$1]}',
                      maxLines: 4, overflow: TextOverflow.ellipsis, style: t(13, h: 1.4, c: (d[r.$1] ?? '').toString().isEmpty ? C.muted : C.ink)),
                ]),
              ),
            ),
          ),
      ], 10)),
      Box(
        child: Col([
          CardHead('Small wins today', action: '+ Win', onAction: () async {
            final v = await showForm(context, 'A small win', const [Field('w', 'What went well?', required: true)]);
            if (v == null) return;
            s.patchDay({'wins': [...((s.day()['wins'] as List?) ?? const []), v['w']]});
          }),
          if (((d['wins'] as List?) ?? const []).isEmpty) Text('Log three small wins. They add up.', style: t(13, c: C.muted)),
          for (final w in ((d['wins'] as List?) ?? const [])) Text('• $w', style: t(14, h: 1.4)),
        ], space: 8),
      ),
      Box(
        dark: true,
        child: Col([
          H2('On this day, ${now.year - 1}', color: C.white),
          Text(old.isEmpty ? 'Write today. Next year this card shows what you wrote.' : '“$old”',
              maxLines: 5, overflow: TextOverflow.ellipsis, style: t(15, c: old.isEmpty ? C.darkMuted : C.white, h: 1.45)),
        ], space: 8),
      ),
    ]);
  }
}
