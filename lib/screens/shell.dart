import 'package:flutter/material.dart';
import '../services/license_service.dart';
import '../services/local.dart';
import '../services/notify_service.dart';
import '../services/update_service.dart';
import '../widgets/ui.dart';
import 'add_sheet.dart';
import 'explore.dart';
import 'goals.dart';
import 'habits.dart';
import 'journal.dart';
import 'today.dart';
import 'update_screen.dart';

/// The five tabs, the floating pill nav bar and the lime + button.
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int tab = 0;

  static const _tabs = [
    (Icons.home_outlined, 'Today'),
    (Icons.track_changes_rounded, 'Goals'),
    (Icons.check_box_outlined, 'Habits'),
    (Icons.menu_book_outlined, 'Journal'),
    (Icons.grid_view_rounded, 'Explore'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotifyService.requestPermission();
      if (!mounted) return;
      final s = store(context, listen: false);
      await License.recheck(s);
      await _checkUpdate();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final s = store(context, listen: false);
    if (state == AppLifecycleState.paused) s.flush();
    if (state == AppLifecycleState.resumed) {
      s.syncQuietly();
      _checkUpdate();
    }
  }

  /// Looks for a new version at most every 3 hours; shows a notification and a popup.
  Future<void> _checkUpdate() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - Local.lastUpdateCheck < 3 * 3600 * 1000) return;
    await Local.setLastUpdateCheck(now);
    try {
      final u = await UpdateService.check();
      if (u == null || !mounted) return;
      await NotifyService.showUpdate(u.version);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: C.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Update ready', style: t(20, w: w6)),
          content: Text('LifeOS ${u.version} is here. ${u.summary}', style: t(14, c: C.muted, h: 1.4)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text('Later', style: t(14, w: w6, c: C.muted))),
            TextButton(
              onPressed: () {
                Navigator.pop(c);
                push(context, const UpdateScreen());
              },
              child: Text('Update now', style: t(14, w: w6)),
            ),
          ],
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayTab(onTab: (i) => setState(() => tab = i)),
      const GoalsTab(),
      const HabitsTab(),
      const JournalTab(),
      const ExploreTab(),
    ];
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: bgGradient),
        child: Stack(children: [
          Positioned.fill(child: SafeArea(bottom: false, child: IndexedStack(index: tab, children: pages))),
          // The + button sits above the nav bar, on the right.
          Positioned(
            right: 20,
            bottom: 104 + MediaQuery.of(context).padding.bottom,
            child: Semantics(
              button: true,
              label: 'Add',
              child: Material(
                color: C.lime,
                shape: const CircleBorder(),
                elevation: 6,
                shadowColor: const Color(0x33111111),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => showAddSheet(context),
                  child: const SizedBox(width: 60, height: 60, child: Icon(Icons.add_rounded, size: 28, color: C.ink)),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 20 + MediaQuery.of(context).padding.bottom,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: C.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [BoxShadow(color: Color(0x14111111), blurRadius: 24, offset: Offset(0, 8))],
              ),
              child: Row(children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: Semantics(
                      selected: i == tab,
                      button: true,
                      label: _tabs[i].$2,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => tab = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          height: 56,
                          decoration: BoxDecoration(color: i == tab ? C.ink : Colors.transparent, borderRadius: BorderRadius.circular(999)),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(_tabs[i].$1, size: 20, color: i == tab ? C.white : C.muted),
                            const SizedBox(height: 3),
                            Text(_tabs[i].$2, style: t(11, w: i == tab ? w6 : w5, c: i == tab ? C.white : C.muted)),
                          ]),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Top of a tab: small line + big title, optional right widget.
class TabHeader extends StatelessWidget {
  final String small, title;
  final Widget? trailing;
  const TabHeader({super.key, required this.small, required this.title, this.trailing});
  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(small, style: t(13, w: w5, c: C.muted)),
          const SizedBox(height: 4),
          Text(title, style: t(28, w: w6, ls: -0.6, h: 1.15)),
        ]),
      ),
      if (trailing != null) trailing!,
    ]);
  }
}

/// Scrolling body of a tab, with room for the nav bar and + button.
class TabBody extends StatelessWidget {
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  const TabBody({super.key, required this.children, this.onRefresh});
  @override
  Widget build(BuildContext context) {
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 190),
      physics: const AlwaysScrollableScrollPhysics(),
      children: gap(children, 14),
    );
    final s = store(context, listen: false);
    return RefreshIndicator(color: C.ink, onRefresh: onRefresh ?? s.syncQuietly, child: list);
  }
}
