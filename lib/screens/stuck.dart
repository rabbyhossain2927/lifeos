import 'package:flutter/material.dart';
import '../widgets/form.dart';
import '../widgets/ui.dart';
import 'launch.dart';

/// "I'm stuck": a 30-second check-in that gives a different fix for each feeling.
class StuckScreen extends StatefulWidget {
  const StuckScreen({super.key});
  @override
  State<StuckScreen> createState() => _StuckScreenState();
}

class _StuckScreenState extends State<StuckScreen> {
  String pick = 'Overwhelmed';
  String task = '';

  static const options = [
    ('Overwhelmed', 'Too big, too much', 'Only one 5-minute step. Shrink it until it feels easy, then start.', 'Start 5 minutes'),
    ('Unclear', 'Not sure what to do', 'Answer: what does "done" look like? What is the very first action? Write it, then start.', 'Write the next step'),
    ('Anxious', 'Scared to do it badly', 'Make a terrible first draft. Nobody sees it. You fix it later.', 'Start ugly draft'),
    ('Bored', 'No fun at all', 'Race the clock: 10 minutes with your favourite focus music.', 'Start the race'),
    ('Tired', 'Low energy', 'Swap to an easy task, or rest 10 minutes first. Then try again.', 'Rest 10 minutes'),
  ];

  Future<void> _go() async {
    var step = switch (pick) {
      'Overwhelmed' => 'Do the smallest first part for 5 minutes',
      'Anxious' => 'Write a rough, ugly first version',
      'Bored' => 'Work fast for 10 minutes',
      'Tired' => 'Close your eyes and rest',
      _ => '',
    };
    if (pick == 'Unclear') {
      final v = await showForm(context, 'Make it clear', const [
        Field('done', 'What does "done" look like?', type: F.long),
        Field('first', 'The very first action', required: true, hint: 'Open the doc and write one sentence'),
      ], save: 'Start');
      if (v == null) return;
      step = '${v['first']}';
    }
    if (!mounted) return;
    push(context, LaunchScreen(task: task.isEmpty ? 'Your task' : task, firstStep: step, minutes: pick == 'Bored' || pick == 'Tired' ? 10 : 5));
  }

  @override
  Widget build(BuildContext context) {
    final sel = options.firstWhere((o) => o.$1 == pick);
    return SubPage(title: '', closeIcon: true, trailing: Text('30 sec', textAlign: TextAlign.right, style: t(12, c: C.muted)), children: [
      Text.rich(TextSpan(children: [
        TextSpan(text: "What's going\n", style: t(32, ls: -0.6, h: 1.15)),
        TextSpan(text: 'on right now?', style: t(32, w: w6, ls: -0.6, h: 1.15)),
      ])),
      TextField(
        onChanged: (v) => task = v,
        style: t(15),
        decoration: InputDecoration(
          hintText: 'Task you are stuck on (optional)',
          hintStyle: t(15, c: const Color(0xFF8A8A92)),
          filled: true,
          fillColor: C.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        ),
      ),
      Col([
        for (final o in options)
          GestureDetector(
            onTap: () => setState(() => pick = o.$1),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: pick == o.$1 ? C.lime : C.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: pick == o.$1 ? C.ink : C.white, width: 1.5),
              ),
              child: Row(children: [
                Expanded(child: Text(o.$1, style: t(15, w: w6))),
                Text(o.$2, style: t(12, c: pick == o.$1 ? C.limeText : C.muted)),
              ]),
            ),
          ),
      ], space: 8),
      Box(
        dark: true,
        padding: const EdgeInsets.all(18),
        child: Col([
          const H2('Try this', color: C.white),
          Text(sel.$3, style: t(16, c: C.white, h: 1.45)),
          PillButton(sel.$4, height: 44, expand: false, onTap: _go),
        ]),
      ),
    ]);
  }
}
