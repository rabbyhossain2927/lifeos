import 'package:flutter/material.dart';
import '../services/life.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import '../widgets/ui.dart';
import 'shell.dart';
import 'tools.dart';

class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});
  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  final q = TextEditingController();
  String group = 'All';
  bool editing = false;

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final pins = ((s.settings['pins'] as List?) ?? const []).map((e) => '$e').toList();
    final find = q.text.trim().toLowerCase();
    final next = s.nextPrayer;
    final dates = upcomingDates(s);
    final trip = nextTrip(s);
    final tripFrom = DateTime.tryParse('${trip?['from'] ?? ''}');

    final upcoming = <(String, String, String, bool, String)>[
      ('Next prayer', '${next.key} · ${hmA(next.value)}', 'in ${_left(next.value)}', true, 'prayer'),
      if (dates.isNotEmpty) ('Coming up', '${dates.first.$1['title']}', '${weekdaysLong[dates.first.$2.weekday - 1].substring(0, 3)}, ${shortDate(dates.first.$2)}', false, 'dates'),
      if (trip != null) ('Trip', '${trip['place']}', tripFrom == null ? 'Soon' : '${tripFrom.difference(DateTime.now()).inDays.clamp(0, 9999)} days to go', false, 'travel'),
    ];

    final sections = [
      for (final g in const [('Daily', 'Every day'), ('Grow', 'Grow'), ('Life', 'Life & people')])
        if (group == 'All' || group == g.$1) (g.$2, tools.where((x) => x.group == g.$1 && (find.isEmpty || x.name.toLowerCase().contains(find))).toList()),
    ].where((x) => x.$2.isNotEmpty).toList();

    return TabBody(children: [
      TabTitle('Explore', sub: 'All your tools in one place', trailing: HeadPill(editing ? 'Done' : 'Edit Home', dark: editing, onTap: () => setState(() => editing = !editing))),
      TextField(
        controller: q,
        onChanged: (_) => setState(() {}),
        style: t(15),
        decoration: InputDecoration(
          hintText: 'Find a tool…',
          hintStyle: t(15, c: const Color(0xFF8A8A84)),
          prefixIcon: Icon(Icons.search_rounded, color: C.muted, size: 20),
          filled: true,
          fillColor: C.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
        ),
      ),
      SizedBox(
        height: 100,
        child: ListView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          children: gap([
            for (final u in upcoming)
              Press(
                onTap: () => openTool(context, u.$5),
                label: u.$2,
                child: Container(
                  width: 168,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: u.$4 ? C.ink : C.white, borderRadius: BorderRadius.circular(22)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u.$1, style: t(12, w: w6, c: u.$4 ? C.lime : C.muted)),
                    const SizedBox(height: 4),
                    Text(u.$2, style: t(16, w: w6, c: u.$4 ? C.white : C.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(u.$3, style: t(12, c: u.$4 ? C.darkMuted : C.muted)),
                  ]),
                ),
              ),
          ], 10),
        ),
      ),
      SizedBox(
        height: 42,
        child: ListView(scrollDirection: Axis.horizontal, children: gap([
          for (final g in const ['All', 'Daily', 'Grow', 'Life'])
            Press(
              onTap: () => setState(() => group = g),
              haptic: Haptic.select,
              label: g,
              selected: g == group,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: g == group ? C.ink : C.white, borderRadius: BorderRadius.circular(999)),
                child: Text(g, style: t(14, w: w6, c: g == group ? C.white : C.muted)),
              ),
            ),
        ], 8)),
      ),
      if (editing)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: C.limeSoft, borderRadius: BorderRadius.circular(18)),
          child: Text('Tap the star on a tool to show it on Home. ${pins.length} pinned.', style: t(13, c: C.limeText, h: 1.45)),
        ),
      for (final sec in sections)
        Col([
          Padding(padding: const EdgeInsets.only(left: 4, top: 4), child: Text(sec.$1, style: t(16, w: w6))),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.42,
            children: [
              for (var i = 0; i < sec.$2.length; i++)
                Appear(
                  index: i,
                  child: Stack(children: [
                    Positioned.fill(
                      child: Press(
                        onTap: () => openTool(context, sec.$2[i].key),
                        label: sec.$2[i].name,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(24)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Hero(
                              tag: 'tool-${sec.$2[i].name}',
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(color: sec.$2[i].colors.$1, borderRadius: BorderRadius.circular(14)),
                                child: Icon(sec.$2[i].icon, size: 20, color: sec.$2[i].colors.$2),
                              ),
                            ),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(sec.$2[i].name, style: t(15, w: w6)),
                              Text(sec.$2[i].status(s), style: t(12, c: C.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ]),
                          ]),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: AnimatedScale(
                        scale: editing ? 1 : 0,
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        child: Press(
                          onTap: () {
                            final k = sec.$2[i].key;
                            s.setSetting('pins', pins.contains(k) ? (pins..remove(k)) : [...pins, k]);
                          },
                          haptic: Haptic.success,
                          label: 'Pin ${sec.$2[i].name} to Home',
                          selected: pins.contains(sec.$2[i].key),
                          scale: 0.85,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: pins.contains(sec.$2[i].key) ? C.ink : C.white,
                              shape: BoxShape.circle,
                              border: pins.contains(sec.$2[i].key) ? null : Border.all(color: const Color(0xFFDAD8DF), width: 1.5),
                            ),
                            child: Icon(Icons.star_rounded, size: 18, color: pins.contains(sec.$2[i].key) ? C.lime : C.border),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
            ],
          ),
        ], space: 10),
      if (sections.isEmpty) Padding(padding: const EdgeInsets.all(30), child: Text('No tool called "${q.text}".', textAlign: TextAlign.center, style: t(14, c: C.muted))),
    ]);
  }

  String _left(DateTime d) {
    final m = d.difference(DateTime.now()).inMinutes.clamp(0, 99999);
    return m >= 60 ? '${m ~/ 60}h ${m % 60}m' : '${m}m';
  }
}
