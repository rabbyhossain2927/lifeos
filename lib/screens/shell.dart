import 'package:flutter/material.dart';
import '../services/backup.dart';
import '../services/license_service.dart';
import '../services/local.dart';
import '../services/notify_service.dart';
import '../services/update_service.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import '../widgets/ui.dart';
import 'account.dart';
import 'add_sheet.dart';
import 'explore.dart';
import 'goals.dart';
import 'home.dart';
import 'update_screen.dart';

/// Four tabs, the floating pill nav and the lime + button.
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int tab = 0;
  late final AnimationController _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 320), value: 1);

  static const _tabs = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.track_changes_outlined, Icons.track_changes_rounded, 'Goals'),
    (Icons.grid_view_outlined, Icons.grid_view_rounded, 'Explore'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Account'),
  ];

  void go(int i) {
    if (i == tab) return;
    Haptic.select();
    setState(() => tab = i);
    _fade.forward(from: 0);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotifyService.requestPermission();
      if (!mounted) return;
      final s = store(context, listen: false);
      await License.recheck(s);
      await Backup.auto(s);
      await _checkUpdate();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fade.dispose();
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
      Haptic.success();
      showSheet(context, 'Update ready', (c, _) => Col([
            Text('LifeOS ${u.version} is here. ${u.summary}', style: t(14, c: C.muted, h: 1.45)),
            PressPill('Update now', onTap: () {
              Navigator.pop(c);
              push(context, const UpdateScreen());
            }),
            PressPill('Later', bg: C.chip, fg: C.ink, height: 50, onTap: () => Navigator.pop(c)),
          ], space: 12));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final pages = [
      HomeTab(onTab: go),
      const GoalsTab(),
      const ExploreTab(),
      const AccountTab(),
    ];
    final fade = CurvedAnimation(parent: _fade, curve: Curves.easeOutCubic);
    return Scaffold(
      body: Container(
        decoration: bgDecoration,
        child: Stack(children: [
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: FadeTransition(
                opacity: fade,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(fade),
                  child: IndexedStack(index: tab, children: pages),
                ),
              ),
            ),
          ),
          // + above the nav, right side, on Home and Goals.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            right: 20,
            bottom: (tab <= 1 ? 104 : 40) + bottom,
            child: AnimatedScale(
              scale: tab <= 1 ? 1 : 0,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: Press(
                onTap: () => tab == 1 ? addGoalPage(context) : showAddSheet(context),
                label: tab == 1 ? 'Add goal' : 'Add',
                scale: 0.9,
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: const BoxDecoration(
                    color: C.lime,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Color(0x29111111), blurRadius: 24, offset: Offset(0, 8))],
                  ),
                  child: Icon(Icons.add_rounded, size: 30, color: C.ink),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 18 + bottom,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: C.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [BoxShadow(color: Color(0x14111111), blurRadius: 24, offset: Offset(0, 8))],
              ),
              child: LayoutBuilder(builder: (context, box) {
                final w = (box.maxWidth - 12) / _tabs.length;
                return SizedBox(
                  height: 58,
                  child: Stack(children: [
                    // The black pill slides to the chosen tab.
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 360),
                      curve: Curves.easeOutCubic,
                      left: tab * (w + 4),
                      top: 0,
                      bottom: 0,
                      width: w,
                      child: Container(decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(999))),
                    ),
                    Row(children: gap([
                      for (var i = 0; i < _tabs.length; i++)
                        Expanded(
                          child: Semantics(
                            selected: i == tab,
                            button: true,
                            label: _tabs[i].$3,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => go(i),
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                                  child: Icon(i == tab ? _tabs[i].$2 : _tabs[i].$1, key: ValueKey(i == tab), size: 20, color: i == tab ? C.white : C.muted),
                                ),
                                const SizedBox(height: 3),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: t(11, w: i == tab ? w6 : w5, c: i == tab ? C.white : C.muted),
                                  child: Text(_tabs[i].$3),
                                ),
                              ]),
                            ),
                          ),
                        ),
                    ], 4)),
                  ]),
                );
              }),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Scrolling body of a tab, with room for the nav bar and + button.
class TabBody extends StatelessWidget {
  final List<Widget> children;
  const TabBody({super.key, required this.children});
  @override
  Widget build(BuildContext context) {
    final s = store(context, listen: false);
    return RefreshIndicator(
      color: C.ink,
      onRefresh: () async {
        Haptic.tap();
        await s.syncQuietly();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 190),
        physics: const AlwaysScrollableScrollPhysics(),
        children: gap(stagger(children), 14),
      ),
    );
  }
}
