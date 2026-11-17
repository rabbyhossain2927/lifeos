import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../services/api.dart';
import '../services/auth_service.dart';
import '../services/backup.dart';
import '../services/license_service.dart';
import '../services/life.dart';
import '../services/local.dart';
import '../services/photos.dart';
import '../services/prayer.dart';
import '../services/store.dart';
import '../services/update_service.dart';
import '../widgets/form.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import '../widgets/ui.dart';
import 'home.dart';
import 'shell.dart';
import 'update_screen.dart';

const feedbackEmail = 'hello@rabbyhossain.com';

/// "26.1.0" stays "26.1.0"; shown as "LifeOS 26.1.0".
String niceVersion(String v) => v;

class AccountTab extends StatefulWidget {
  const AccountTab({super.key});
  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  String version = '26.1.0';
  String update = 'idle'; // idle, checking, available, latest, error
  UpdateInfo? found;

  @override
  void initState() {
    super.initState();
    UpdateService.current().then((v) {
      if (mounted) setState(() => version = v.version);
    }).catchError((_) {});
  }

  Future<void> _check() async {
    if (update == 'checking') return;
    if (update == 'available') {
      push(context, const UpdateScreen());
      return;
    }
    setState(() => update = 'checking');
    try {
      found = await UpdateService.check();
      if (!mounted) return;
      setState(() => update = found == null ? 'latest' : 'available');
      found == null ? Haptic.tap() : Haptic.success();
    } catch (_) {
      if (mounted) setState(() => update = 'error');
      Haptic.warn();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final pro = License.isPro(s);
    final name = userName(s);
    final lastBackup = math.max(Local.lastBackup, Backup.lastDrive);
    Widget icon(IconData i, (Color, Color) c) => Container(width: 36, height: 36, decoration: BoxDecoration(color: c.$1, borderRadius: BorderRadius.circular(12)), child: Icon(i, size: 18, color: c.$2));
    final lime = (C.limeSoft, C.limeText), violet = (Look.dark ? const Color(0xFF2E2A4A) : const Color(0xFFEFEDFF), const Color(0xFF7C6FE0)), blue = (Look.dark ? const Color(0xFF1C2B3A) : const Color(0xFFE7F1FB), const Color(0xFF3B7BC4)), grey = (C.chip, C.muted);
    Row2 link(String title, String sub, IconData i, (Color, Color) c, VoidCallback onTap) => Row2(title: title, sub: sub, leading: icon(i, c), trailing: Icon(Icons.chevron_right_rounded, color: C.muted), onTap: onTap);
    final upSub = switch (update) {
      'checking' => 'Checking…',
      'available' => 'LifeOS ${found?.version} is ready',
      'latest' => 'You have the latest',
      'error' => 'Could not check. Try again.',
      _ => 'LifeOS $version installed',
    };

    return TabBody(children: [
      Text('Account', style: t(22, w: w6, ls: -0.4)),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(28)),
        child: Col([
          Row(children: [
            Press(onTap: () => editProfile(context), label: 'Change photo', child: const Avatar(size: 60, onDark: true)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name.isEmpty ? 'Add your name' : name, style: t(20, w: w6, c: C.white)),
                const SizedBox(height: 3),
                Text('${pro ? 'LifeOS Pro' : 'Free plan'} · Google account', style: t(12.5, c: C.darkMuted)),
              ]),
            ),
            Press(
              onTap: () => editProfile(context),
              label: 'Edit profile',
              child: Container(height: 40, padding: const EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(color: C.dark2.withValues(alpha: Look.dark ? 0.2 : 1), borderRadius: BorderRadius.circular(999)), child: Center(widthFactor: 1, child: Text('Edit', style: t(13, w: w6, c: C.white)))),
            ),
          ]),
          // The XP card opens the XP dashboard.
          Press(
            onTap: () => push(context, const XpPage()),
            label: 'Open XP dashboard',
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: C.dark2.withValues(alpha: Look.dark ? 0.12 : 1), borderRadius: BorderRadius.circular(22)),
              child: Row(children: [
                LevelBadge(level: s.lvl),
                const SizedBox(width: 14),
                Expanded(
                  child: Col([
                    Row(children: [
                      Expanded(child: Text('Level ${s.lvl} · ${s.lvlName}', style: t(13, w: w6, c: C.white))),
                      CountText(s.xpInLevel, style: t(13, w: w6, c: Look.dark ? C.limeText : C.lime), format: (v) => '${v.round()} / 1000 XP'),
                    ]),
                    Bar(s.xpInLevel / 1000, color: C.lime, track: C.dark3),
                    Row(children: [
                      Expanded(child: Text('${1000 - s.xpInLevel} XP to level ${s.lvl + 1}', style: t(12, c: C.darkMuted))),
                      Text('See all', style: t(12, w: w6, c: C.white)),
                      Icon(Icons.chevron_right_rounded, size: 16, color: C.white),
                    ]),
                  ], space: 6),
                ),
              ]),
            ),
          ),
        ], space: 16),
      ),
      _group('Account', [
        link('Edit profile', 'Name, photo and colour', Icons.person_outline_rounded, lime, () => editProfile(context)),
        link('License', pro ? 'Pro · active' : 'Free plan · add a key', Icons.key_outlined, lime, () => licenseSheet(context)),
        link('Backup', lastBackup == 0 ? 'Google Drive, phone and server' : 'Last backup: ${_when(lastBackup)}', Icons.cloud_upload_outlined, lime, () => push(context, const BackupPage()).then((_) => setState(() {}))),
      ]),
      _group('App', [
        Row2(
          title: 'Check for update',
          sub: upSub,
          leading: icon(Icons.system_update_alt_rounded, blue),
          trailing: Press(
            onTap: _check,
            label: 'Check for update',
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: update == 'available' ? C.lime : C.chip, borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (update == 'checking') ...[SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: C.ink)), const SizedBox(width: 6)],
                Text(update == 'checking' ? 'Wait' : update == 'available' ? 'Update' : 'Check', style: t(13, w: w6, c: update == 'available' ? C.onLime : C.ink)),
              ]),
            ),
          ),
        ),
        link("What's new", 'Last 5 updates', Icons.card_giftcard_rounded, blue, () => push(context, WhatsNewPage(current: version))),
        link('Preferences', 'Week start, time, notifications and more', Icons.tune_rounded, violet, () => push(context, const PrefsPage())),
        link('Theme', '${Look.theme} · ${Look.mode}${Look.texture ? ' · texture' : ''}', Icons.palette_outlined, violet, () => push(context, const ThemePage())),
      ]),
      _group('Help', [
        link('How to use', 'Everything, step by step', Icons.menu_book_outlined, grey, () => push(context, const HowToPage())),
        link('About LifeOS', 'LifeOS $version', Icons.info_outline_rounded, grey, () => push(context, AboutPage(version: version))),
        link('Terms and conditions', 'Privacy and use', Icons.description_outlined, grey, () => terms(context)),
        link('Feedback', feedbackEmail, Icons.chat_bubble_outline_rounded, grey, () => push(context, FeedbackPage(version: version))),
      ]),
      PressPill('Sign out', bg: C.white, fg: C.warn, height: 54, onTap: () => signOutSheet(context)),
      Center(child: Text('LifeOS $version', style: t(12, c: C.muted))),
    ]);
  }

  Widget _group(String name, List<Row2> rows) => Col([
        Padding(padding: const EdgeInsets.only(left: 4, top: 4), child: Text(name, style: t(13, w: w6, c: C.muted))),
        RowsPanel(rows: rows),
      ], space: 8);
}

String _when(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final now = DateTime.now();
  final day = dayKey(d) == todayKey ? 'Today' : dayKey(d) == dayKey(now.subtract(const Duration(days: 1))) ? 'Yesterday' : shortDate(d);
  return '$day, ${hmA(d)}';
}

/// A page from the Account tab.
class AccountPage extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;
  const AccountPage({super.key, required this.title, required this.subtitle, required this.icon, required this.children, this.trailing});
  @override
  Widget build(BuildContext context) => ToolPage(title: title, subtitle: subtitle, icon: icon, colors: (C.lime, C.onLime), trailing: trailing, children: children);
}

class LevelBadge extends StatelessWidget {
  final int level;
  const LevelBadge({super.key, required this.level});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.6, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, sc, child) => Transform.scale(scale: sc, child: child),
        child: SizedBox(
          width: 58,
          height: 64,
          child: CustomPaint(
            painter: _HexPainter(),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('LV', style: t(9, w: FontWeight.w700, h: 1, c: C.onLime)),
                Text('$level', style: t(19, w: FontWeight.w700, h: 1.1, c: C.onLime)),
              ]),
            ),
          ),
        ),
      );
}

class _HexPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    Path hex(double inset) {
      final c = Offset(s.width / 2, s.height / 2);
      final r = s.height / 2 - inset;
      final p = Path();
      for (var i = 0; i < 6; i++) {
        final a = math.pi / 3 * i - math.pi / 2;
        final pt = c + Offset(math.cos(a) * r * 0.9, math.sin(a) * r);
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      return p..close();
    }

    canvas.drawPath(hex(1), Paint()..color = C.lime);
    canvas.drawPath(
        hex(8),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0x40111111));
  }

  @override
  bool shouldRepaint(_HexPainter o) => false;
}


// ------------------------------------------------------------------ XP dashboard
class XpPage extends StatelessWidget {
  const XpPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final week = [for (final k in s.last7) s.xpOn(k)];
    final total = week.fold<int>(0, (a, b) => a + b);
    var best = 0, bestI = 0;
    for (var i = 0; i < 7; i++) {
      if (week[i] > best) {
        best = week[i];
        bestI = i;
      }
    }
    final src = s.xpSources(s.last7);
    const srcIcons = {'Prayers': Icons.mosque_outlined, 'Goal steps': Icons.flag_outlined, 'Habits': Icons.check_rounded, 'Journal': Icons.menu_book_outlined};
    const srcRule = {'Prayers': '+10 each', 'Goal steps': '+10 each day you log', 'Habits': '+5 each', 'Journal': '+5 each entry'};
    // Recent XP from the last 3 days.
    final recent = <(String, String, int)>[];
    for (var i = 0; i < 3; i++) {
      final k = dayKey(DateTime.now().subtract(Duration(days: i)));
      final when = i == 0 ? 'Today' : i == 1 ? 'Yesterday' : shortDate(parseDay(k));
      for (final p in s.prayedOn(k)) {
        recent.add(('$p prayed', when, 10));
      }
      for (final h in s.list('habits').where((h) => s.habitDone(h, k))) {
        recent.add(('${h['name']}', when, 5));
      }
      for (final g in s.list('goals').where((g) => (g['logs'] as Map? ?? {})[k] != null)) {
        recent.add(('${g['title']}', when, 10));
      }
      if ('${s.day(k)['text'] ?? ''}'.trim().isNotEmpty) recent.add(('Journal entry', when, 5));
    }
    final names = ['Starter', 'Steady', 'Steady', 'Strong', 'Strong', 'Strong', 'Focused', 'Focused', 'Focused', 'Master'];
    return AccountPage(title: 'XP and level', subtitle: 'How you earn and grow', icon: Icons.emoji_events_outlined, children: [
      HeroCard(tone: HeroTone.lime, label: 'Level ${s.lvl} · ${s.lvlName}', big: '${s.xp} XP total', sub: '${1000 - s.xpInLevel} XP to level ${s.lvl + 1} · ${s.points} points to spend', ring: s.xpInLevel / 1000, ringText: 'LV ${s.lvl}'),
      Row(children: gap([
        Expanded(child: _stat('This week', '+$total', 'XP', dark: true)),
        Expanded(child: _stat('Best day', '+$best', best == 0 ? '—' : s.last7Letters[bestI])),
        Expanded(child: _stat('Streak', '${s.dayStreak}', 'days')),
      ], 8)),
      HeroCard(tone: HeroTone.white, label: 'Last 7 days', big: '+$total XP', sub: 'Every bar is one day', bars: [for (var i = 0; i < 7; i++) (week[i].toDouble(), s.last7Letters[i])]),
      RowsPanel(title: 'Where your XP comes from', hint: 'this week', rows: [
        for (final e in src.entries)
          Row2(
            leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: C.limeSoft, borderRadius: BorderRadius.circular(12)), child: Icon(srcIcons[e.key], size: 18, color: C.limeText)),
            title: e.key,
            sub: srcRule[e.key],
            right: '${e.value}',
          ),
      ]),
      RowsPanel(title: 'Levels', rows: [
        for (var l = s.lvl + 1; l <= math.min(s.lvl + 3, 12); l++)
          Row2(title: 'Level $l · ${names[math.min(l - 1, 9)]}', sub: 'at ${(l - 1) * 1000} XP · ${(l - 1) * 1000 - s.xp} to go', progress: (s.xp / ((l - 1) * 1000)).clamp(0.0, 1.0)),
      ]),
      RowsPanel(title: 'Recent', empty: 'Pray, tick a habit or log a goal to earn XP.', rows: [
        for (final r in recent.take(12)) Row2(title: r.$1, sub: r.$2, right: '+${r.$3}'),
      ]),
      NoteCard('Points vs XP', 'XP only grows and sets your level. Points are XP you can spend on treats in Rewards.'),
    ]);
  }

  Widget _stat(String k, String v, String sub, {bool dark = false}) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: dark ? C.ink : C.white, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: t(11, c: dark ? C.darkMuted : C.muted)),
          Text(v, style: t(20, w: w6, c: dark ? C.white : C.ink)),
          Text(sub, style: t(11, c: dark ? (Look.dark ? C.limeText : C.lime) : C.muted)),
        ]),
      );
}

// ------------------------------------------------------------------ profile
void editProfile(BuildContext context) {
  final s = store(context, listen: false);
  final name = TextEditingController(text: userName(s));
  var color = ((s.settings['avatarColor'] ?? 0xFF1F1F23) as num).toInt();
  const colors = [0xFF1F1F23, 0xFFD4F06B, 0xFFC7B8FF, 0xFFFFC9A8, 0xFFA8E6CF];
  var busy = false;
  showSheet(context, 'Edit profile', (ctx, set) {
    Future<void> pick(bool camera) async {
      final path = await Photos.pickOne(camera: camera, round: true);
      if (path == null) return;
      set(() => busy = true);
      await Local.setAvatarPath(path);
      s.setSetting('avatar', {'url': ''});
      final url = await Photos.upload(path);
      if (url != null) s.setSetting('avatar', {'url': url});
      set(() => busy = false);
    }

    return Col([
      Center(child: Stack(alignment: Alignment.center, children: [const Avatar(size: 96), if (busy) const SizedBox(width: 96, height: 96, child: CircularProgressIndicator(strokeWidth: 2, color: C.lime))])),
      Row(children: gap([
        Expanded(child: PressPill('Gallery', icon: Icons.photo_library_outlined, bg: C.chip, fg: C.ink, height: 46, onTap: () => pick(false))),
        Expanded(child: PressPill('Camera', icon: Icons.photo_camera_outlined, bg: C.chip, fg: C.ink, height: 46, onTap: () => pick(true))),
      ], 8)),
      if (Local.avatarPath.isNotEmpty || ('${(s.settings['avatar'] as Map?)?['url'] ?? ''}').isNotEmpty)
        PressPill('Remove photo', bg: Colors.transparent, fg: C.warn, height: 40, onTap: () async {
          await Local.setAvatarPath('');
          s.setSetting('avatar', null);
          set(() {});
        }),
      Text('Crop it round after you pick it. Saved on your phone and your LifeOS server.', style: t(12, c: C.muted)),
      Text('Name', style: t(14, w: w6)),
      SoftField(controller: name, hint: 'Your name', pill: true),
      Text('Colour (when there is no photo)', style: t(14, w: w6)),
      Row(children: [
        for (final k in colors)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Press(
              onTap: () => set(() => color = k),
              haptic: Haptic.select,
              label: 'Colour',
              selected: color == k,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: Color(k), shape: BoxShape.circle, border: Border.all(color: color == k ? C.ink : C.white, width: 3), boxShadow: [BoxShadow(color: C.border, spreadRadius: 1)]),
              ),
            ),
          ),
      ]),
      PressPill('Save', success: true, onTap: () {
        if (name.text.trim().isNotEmpty) s.setSetting('name', name.text.trim());
        s.setSetting('avatarColor', color);
        Navigator.pop(ctx);
        toast(context, 'Profile saved.');
      }),
    ], space: 12);
  });
}

void licenseSheet(BuildContext context) {
  final s = store(context, listen: false);
  final key = TextEditingController();
  var busy = false;
  showSheet(context, 'License', (ctx, set) {
    final pro = License.isPro(s);
    final l = s.settings['license'] as Map?;
    final k = '${l?['key'] ?? ''}';
    if (pro) {
      return Col([
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(22)),
          child: Col([
            const Tag('PRO · ACTIVE', bg: C.lime, fg: C.onLime),
            Text(k.length > 4 ? '${k.substring(0, k.length > 5 ? 5 : 0)}••••-${k.substring(k.length - 4)}' : k, style: t(17, w: w6, c: C.white, ls: 0.6)),
            Text('${l?['product'] ?? 'LifeOS Pro'} · works on every phone with this Google account', style: t(12, c: C.darkMuted)),
          ], space: 6),
        ),
        PressPill('Remove key from this phone', bg: C.chip, fg: C.ink, height: 52, onTap: () async {
          if (!await confirm(ctx, 'Remove the key?', ok: 'Remove', body: 'You can use it again on another phone.')) return;
          await License.deactivate(s);
          if (ctx.mounted) Navigator.pop(ctx);
        }),
      ], space: 12);
    }
    return Col([
      Text('LifeOS is free. A Pro key unlocks ${License.proFeatures.values.take(3).join(', ').toLowerCase()} and more.', style: t(14, c: C.muted, h: 1.45)),
      TextField(
        controller: key,
        textCapitalization: TextCapitalization.characters,
        style: t(16, w: w6, ls: 0.6),
        decoration: InputDecoration(
          hintText: 'LIFE-XXXX-XXXX-XXXX',
          filled: true,
          fillColor: C.chip,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
        ),
      ),
      PressPill(busy ? 'Checking…' : 'Activate', onTap: () async {
        if (busy) return;
        set(() => busy = true);
        final err = await License.activate(s, key.text);
        set(() => busy = false);
        if (err != null) {
          Haptic.warn();
          if (ctx.mounted) toast(ctx, err);
          return;
        }
        Haptic.celebrate();
        if (ctx.mounted) Navigator.pop(ctx);
        if (context.mounted) toast(context, 'Pro unlocked. Thank you!');
      }),
      PressPill('Get a key at the shop', bg: Colors.transparent, fg: C.ink, height: 48, onTap: () => launchUrl(Uri.parse(Config.buyUrl), mode: LaunchMode.externalApplication)),
    ], space: 12);
  });
}


// ------------------------------------------------------------------ backup
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  String busy = '';
  List<BackupItem>? last;
  bool? drive;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await Backup.lastFive();
    final d = await Backup.driveConnected();
    if (mounted) {
      setState(() {
        last = l;
        drive = d;
      });
    }
  }

  Future<void> run(String what, Future<String?> Function() f) async {
    if (busy.isNotEmpty) return;
    setState(() => busy = what);
    try {
      final msg = await f();
      Haptic.success();
      if (mounted && msg != null) toast(context, msg);
    } catch (e) {
      Haptic.warn();
      if (mounted) toast(context, e is ApiError ? e.message : '$e');
    }
    if (mounted) setState(() => busy = '');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final synced = s.lastSyncedAt;
    final count = Store.collections.fold<int>(0, (a, c) => a + s.list(c).length);
    Row2 place(String title, String sub, IconData icon, (Color, Color) c, String btn, String key, Future<String?> Function() f) => Row2(
          title: title,
          sub: sub,
          leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: c.$1, borderRadius: BorderRadius.circular(13)), child: Icon(icon, size: 19, color: c.$2)),
          trailing: Press(
            onTap: () => run(key, f),
            label: btn,
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: C.lime, borderRadius: BorderRadius.circular(999)),
              child: Center(widthFactor: 1, child: busy == key ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: C.onLime)) : Text(btn, style: t(12.5, w: w6, c: C.onLime))),
            ),
          ),
        );
    return AccountPage(title: 'Backup', subtitle: '$count items · three safe places', icon: Icons.cloud_upload_outlined, children: [
      RowsPanel(title: 'Back up to', rows: [
        place('Google Drive', drive == true ? (Backup.lastDrive == 0 ? 'Connected' : 'Last: ${_when(Backup.lastDrive)}') : 'Tap to connect your Google account', Icons.add_to_drive_rounded, (const Color(0xFFE7F1FB), const Color(0xFF1F4F86)),
            drive == true ? 'Back up' : 'Connect', 'drive', () async {
          await Backup.toDrive(s);
          return 'Saved to Google Drive.';
        }),
        place('This phone', Local.lastBackup == 0 ? 'Download/LifeOS folder' : 'Last: ${_when(Local.lastBackup)}', Icons.smartphone_rounded, (C.limeSoft, C.limeText), 'Back up', 'phone', () async {
          final f = await Backup.toPhone(s);
          return 'Saved: ${f.path.split('/').last}';
        }),
        place('LifeOS server', synced == null ? 'Live sync, every change' : 'Live sync · ${hmA(synced)}', Icons.dns_outlined, (const Color(0xFFEFEDFF), const Color(0xFF4A3FB0)), 'Sync', 'server', () async {
          await s.sync();
          return 'Synced with your server.';
        }),
      ]),
      RowsPanel(rows: [
        Row2(
          title: 'Auto backup every day',
          sub: 'Phone + Google Drive (when connected)',
          trailing: Toggle(on: s.settings['autoBackup'] != false, label: 'Auto backup', onChanged: (v) => s.setSetting('autoBackup', v)),
        ),
      ]),
      RowsPanel(
        title: 'Last 5 backups',
        hint: 'restore any of them',
        empty: last == null ? 'Looking…' : 'No backups yet. Tap Back up above.',
        rows: [
          for (final b in last ?? const <BackupItem>[])
            Row2(
              leading: Icon(b.where == 'Drive' ? Icons.add_to_drive_rounded : Icons.smartphone_rounded, size: 20, color: C.muted),
              title: _when(b.at.millisecondsSinceEpoch),
              sub: '${b.where}${b.size.isEmpty ? '' : ' · ${b.size}'}',
              trailing: Press(
                onTap: () async {
                  if (!await confirm(context, 'Restore this backup?', ok: 'Restore', body: 'A backup of what you have now is saved first. Items from the backup are added back; nothing is deleted.')) return;
                  await run('restore', () async {
                    final n = await Backup.restore(s, b);
                    return 'Restored $n items.';
                  });
                },
                label: 'Restore',
                child: Container(height: 36, padding: const EdgeInsets.symmetric(horizontal: 13), decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(999)), child: Center(widthFactor: 1, child: Text('Restore', style: t(12.5, w: w6)))),
              ),
            ),
        ],
      ),
      NoteCard('Google Drive', 'Backups go to a hidden LifeOS folder in your own Drive. Only LifeOS can see them. The newest 10 are kept.'),
    ]);
  }
}

// ------------------------------------------------------------------ what's new
class WhatsNewPage extends StatefulWidget {
  final String current;
  const WhatsNewPage({super.key, required this.current});
  @override
  State<WhatsNewPage> createState() => _WhatsNewPageState();
}

class _WhatsNewPageState extends State<WhatsNewPage> {
  late final Future<List<UpdateInfo>> f = UpdateService.releases(count: 5);
  String? tab;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UpdateInfo>>(
      future: f,
      builder: (context, snap) {
        final list = (snap.data ?? const <UpdateInfo>[]).take(5).toList();
        final names = [for (final u in list) 'LifeOS ${u.version}'];
        final sel = tab ?? (names.contains('LifeOS ${widget.current}') ? 'LifeOS ${widget.current}' : (names.isEmpty ? '' : names.first));
        final u = list.where((x) => 'LifeOS ${x.version}' == sel).firstOrNull;
        final installed = u != null && u.version == widget.current;
        return AccountPage(title: "What's new", subtitle: 'Last 5 updates', icon: Icons.card_giftcard_rounded, children: [
          if (snap.connectionState == ConnectionState.waiting) LinearProgressIndicator(color: C.ink, backgroundColor: C.chip),
          if (snap.hasError) Panel(child: Text('Could not load updates. Check your internet.', style: t(14, c: C.muted))),
          if (names.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(scrollDirection: Axis.horizontal, children: gap([for (final n in names) Chip2(n, on: n == sel, off: C.white, onTap: () => setState(() => tab = n))], 8)),
            ),
          if (u != null) ...[
            HeroCard(
              label: installed ? 'Installed' : (UpdateService.isNewer(u.version, widget.current) ? 'Newer' : 'Older version'),
              big: 'LifeOS ${u.version}',
              sub: [if (u.published != null) niceDate(u.published!.toLocal()), if (u.sizeLabel.isNotEmpty) u.sizeLabel].join(' · '),
              btns: installed || u.apkUrl.isEmpty
                  ? null
                  : [
                      HeroBtn(UpdateService.isNewer(u.version, widget.current) ? 'Update to this' : 'Download this version', () {
                        if (UpdateService.isNewer(u.version, widget.current)) {
                          push(context, const UpdateScreen());
                        } else {
                          launchUrl(Uri.parse(u.apkUrl), mode: LaunchMode.externalApplication);
                        }
                      }, primary: true),
                    ],
            ),
            RowsPanel(title: 'In this update', empty: 'Small fixes.', rows: [
              for (final a in u.added) Row2(leading: Icon(Icons.add_circle_outline_rounded, size: 20, color: C.limeText), title: a),
              for (final x in u.fixed) Row2(leading: Icon(Icons.build_circle_outlined, size: 20, color: C.muted), title: x, sub: 'Fixed'),
            ]),
          ],
          NoteCard('Going back to an older version', 'Android only installs an older version after you uninstall LifeOS. Then sign in again: your data comes back from your server.'),
        ]);
      },
    );
  }
}

// ------------------------------------------------------------------ theme
class ThemePage extends StatelessWidget {
  const ThemePage({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Look.rev,
      builder: (context, _, __) => AccountPage(title: 'Theme', subtitle: '${Look.theme} · ${Look.mode}', icon: Icons.palette_outlined, children: [
        Panel(title: 'Mode', child: Chips(options: const ['Light', 'Dark', 'Auto'], selected: {Look.mode}, onTap: (v) => Look.set('mode', v))),
        Panel(
          title: 'Colour',
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.95,
            children: [
              for (final e in Look.themes.entries)
                Press(
                  onTap: () => Look.set('theme', e.key),
                  haptic: Haptic.select,
                  label: '${e.key} theme',
                  selected: Look.theme == e.key,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    decoration: BoxDecoration(
                      color: Look.theme == e.key ? C.limeSoft : C.chip,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Look.theme == e.key ? C.ink : C.chip, width: 1.5),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [e.value.$2, e.value.$1]),
                          border: Border.all(color: C.border),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(e.key, style: t(11, w: w6)),
                    ]),
                  ),
                ),
            ],
          ),
        ),
        RowsPanel(rows: [
          Row2(title: 'Background texture', sub: 'Soft paper dots', trailing: Toggle(on: Look.texture, label: 'Texture', onChanged: (v) => Look.set('texture', v))),
        ]),
        Panel(title: 'Text size', child: Chips(options: const ['Small', 'Normal', 'Large'], selected: {Look.textSize}, onTap: (v) => Look.set('text_size', v))),
        HeroCard(label: 'Preview', big: "Let's make today count", sub: 'Cards, chips and buttons follow your theme', btns: [HeroBtn('Button', () {}, primary: true), HeroBtn('Second', () {})]),
      ]),
    );
  }
}

// ------------------------------------------------------------------ preferences
class PrefsPage extends StatefulWidget {
  const PrefsPage({super.key});
  @override
  State<PrefsPage> createState() => _PrefsPageState();
}

class _PrefsPageState extends State<PrefsPage> {
  @override
  Widget build(BuildContext context) {
    final s = store(context);
    Row2 tog(String title, String sub, bool on, ValueChanged<bool> f) => Row2(title: title, sub: sub, trailing: Toggle(on: on, label: title, onChanged: (v) => setState(() => f(v))));
    const days = {'Saturday': DateTime.saturday, 'Sunday': DateTime.sunday, 'Monday': DateTime.monday};
    return AccountPage(title: 'Preferences', subtitle: 'Make LifeOS yours', icon: Icons.tune_rounded, children: [
      Panel(
        title: 'Week starts on',
        child: Chips(
          options: days.keys.toList(),
          selected: {days.entries.firstWhere((e) => e.value == Local.weekStartDay, orElse: () => days.entries.first).key},
          onTap: (v) async {
            await Local.setWeekStart(days[v]!);
            Look.rev.value++;
          },
        ),
      ),
      Panel(title: 'Time format', child: Chips(options: const ['12 hour', '24 hour'], selected: {Local.time24 ? '24 hour' : '12 hour'}, onTap: (v) => Look.set('time24', v == '24 hour'))),
      Panel(title: 'Text size', child: Chips(options: const ['Small', 'Normal', 'Large'], selected: {Look.textSize}, onTap: (v) => Look.set('text_size', v))),
      Panel(title: 'Money goals use', child: Chips(options: const ['tk', r'$', '€', '£', '₹'], selected: {'${s.settings['currency'] ?? 'tk'}'}, onTap: (v) => s.setSetting('currency', v))),
      Panel(title: 'Asr time', child: Chips(options: const ['Hanafi', 'Shafi'], selected: {s.shafi ? 'Shafi' : 'Hanafi'}, onTap: (v) => s.setSetting('asr', v))),
      Panel(
        title: 'City for prayer times',
        child: Chips(
          options: PrayerTimes.cities.keys.toList(),
          selected: {s.cityName},
          onTap: (v) {
            s.setSetting('cityName', v);
            s.setSetting('city', PrayerTimes.cities[v]);
          },
        ),
      ),
      RowsPanel(title: 'Notifications', rows: [
        tog('Prayer alerts', '10 min before each prayer', s.settings['prayerAlerts'] != false, (v) => s.setSetting('prayerAlerts', v)),
        tog('Habit nudge', 'At 9 PM if habits are not done', s.settings['habitNudge'] != false, (v) => s.setSetting('habitNudge', v)),
        tog('Weekly review', 'Friday after Jummah', s.settings['weeklyReview'] != false, (v) => s.setSetting('weeklyReview', v)),
        tog('Morning summary', '7 AM: your day in one line', s.settings['morningSummary'] == true, (v) => s.setSetting('morningSummary', v)),
      ]),
      RowsPanel(title: 'App', rows: [
        tog('Haptic feedback', 'Gentle taps when you press things', Local.haptics, (v) {
          Local.setHaptics(v);
          if (v) Haptic.success();
        }),
        tog('Reduce motion', 'Fewer animations', Local.reduceMotion, (v) => Look.set('reduce_motion', v)),
        tog('App lock', Local.pin.isEmpty ? 'Ask for a 4-digit PIN when the app opens' : 'PIN is on', Local.pin.isNotEmpty, (on) async {
          if (!on) {
            await Local.setPin('');
          } else {
            final v = await showForm(context, 'Choose a 4-digit PIN', const [Field('p', 'PIN', type: F.number, required: true, hint: '1234')]);
            final p = '${v?['p'] ?? ''}'.replaceAll('.0', '');
            if (p.length == 4) {
              await Local.setPin(p);
            } else if (v != null && context.mounted) {
              toast(context, 'The PIN must be 4 digits.');
            }
          }
          if (mounted) setState(() {});
        }),
      ]),
    ]);
  }
}

// ------------------------------------------------------------------ how to use
class HowToPage extends StatefulWidget {
  const HowToPage({super.key});
  @override
  State<HowToPage> createState() => _HowToPageState();
}

class _HowToPageState extends State<HowToPage> {
  String tab = 'Start';
  static const guide = <String, List<(String, String)>>{
    'Start': [
      ('Open Home each morning', 'All your stats in one look: prayers, habits, water, food, sleep, focus and XP.'),
      ("Tap, don't type", 'Most things are one tap: tick a habit, fill a glass, pick a mood, tap a food.'),
      ('Use the lime + button', 'It adds a goal, habit, meal, glass of water, journal line, reminder, date or memory.'),
      ('Pin your tools', 'Explore → Edit Home → star the tools you use most. They show on Home.'),
      ('Swipe and ⋯', 'Swipe a row to the left to delete it (Undo shows). Tap ⋯ to edit. Hold a chip to rename it.'),
    ],
    'Goals': [
      ('Tap + on the Goals tab', 'Pick a start like Read books, or Custom and choose your own icon.'),
      ('Say how much and how often', 'Daily, weekly, half monthly, monthly, quarterly, half yearly, yearly or every N days. Pick the unit: pages, tk, steps, \$ or your own.'),
      ('Take a suggestion', 'Type a name and LifeOS suggests a full goal. It also shows the split per year, month, week and day.'),
      ('Pick a small steps plan', 'Weekly gives 7 dated steps, monthly gives a step for every day of the month. Change any day with ⋯, skip a day with a swipe.'),
      ('Tick or log', 'Tick a step, or use Custom log for any amount on any day. Every bar moves.'),
      ('Fix a mistake', 'Open Log history, tap ⋯, then Edit amount or Delete.'),
      ('Ahead or behind', 'It compares what you did with the plan up to today. Behind is a nudge, not a fail.'),
      ('Review on Friday', 'Goals → Review: how it went, what helped, next week\'s focus.'),
    ],
    'Daily': [
      ('Prayer', 'Tick each prayer when you pray (+10 XP). Prayer alerts come 10 minutes before.'),
      ('Dhikr', 'Explore → Dhikr. Tap the big circle to count. Add your own dhikr or dua with its target.'),
      ('Habits', 'Tap a box in the week row to count that day. ⋯ edits the name and colour.'),
      ('Water and food', 'Tap glasses or add a custom ml amount. Food icons match the name; edit quick add to remove items.'),
      ('Sleep and mood', 'Pick the hours you slept and see what it means. Pick a mood and what is behind it; add your own.'),
    ],
    'Tools': [
      ('Journal', 'Mark the day positive, neutral or negative, write a few lines. Tap an entry to edit it.'),
      ('Focus', 'Start the timer. Daily focus shows each day and your total time.'),
      ('Learn', 'Add a book, course, video series or anything. Log pages or lessons with + Log.'),
      ('Travel', 'Add trips and visits, a day plan, a packing list and photos. Photos come back next year on the same day.'),
      ('Self care and memory', 'Self care has a time, repeat and reminder. Memories keep photos, a title, words, date and time.'),
    ],
    'Data': [
      ('Sync', 'Every change syncs to your own LifeOS server, so a new phone gets everything after sign-in.'),
      ('Backup', 'Account → Backup: Google Drive, this phone and your server. The last 5 backups can be restored.'),
      ('Theme', 'Account → Theme: 8 colours, paper texture, light, dark or auto.'),
      ('Updates', 'LifeOS tells you when an update is ready. What\'s new shows the last 5 updates.'),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final steps = guide[tab]!;
    return AccountPage(title: 'How to use', subtitle: 'Everything, step by step', icon: Icons.menu_book_outlined, children: [
      SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal, children: gap([for (final k in guide.keys) Chip2(k, on: k == tab, off: C.white, onTap: () => setState(() => tab = k))], 8))),
      for (var i = 0; i < steps.length; i++)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: C.white, borderRadius: BorderRadius.circular(20)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 30, height: 30, decoration: const BoxDecoration(color: C.lime, shape: BoxShape.circle), child: Center(child: Text('${i + 1}', style: t(14, w: FontWeight.w700, c: C.onLime)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(steps[i].$1, style: t(15, w: w6)), const SizedBox(height: 3), Text(steps[i].$2, style: t(13, c: C.muted, h: 1.45))])),
          ]),
        ),
    ]);
  }
}

// ------------------------------------------------------------------ about
class AboutPage extends StatelessWidget {
  final String version;
  const AboutPage({super.key, required this.version});
  @override
  Widget build(BuildContext context) {
    return AccountPage(title: 'About LifeOS', subtitle: 'LifeOS $version', icon: Icons.info_outline_rounded, children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: C.lime, borderRadius: BorderRadius.circular(28)),
        child: Col([
          const LogoMark(size: 64),
          Text('One calm place for your whole day', style: t(24, w: FontWeight.w700, c: C.onLime, ls: -0.6, h: 1.15)),
          Text('Prayer, habits, goals, health and the people you love, in one place. Tap, don\'t type.', style: t(14, c: C.onLime, h: 1.45)),
        ], space: 12),
      ),
      Row(children: gap([
        Expanded(child: _tile('Version', version)),
        Expanded(child: _tile('Tools', '17')),
        Expanded(child: _tile('Made in', 'Dhaka', dark: true)),
      ], 8)),
      Panel(title: 'About LifeOS', child: Text('Big goals feel heavy. LifeOS breaks them into today-sized steps with dates, and keeps your faith, health, learning and family in one view. A small tick every day adds up to a big year. Your data lives on your phone and your own server, never sold.', style: t(14, h: 1.55))),
      RowsPanel(rows: [
        Row2(leading: Icon(Icons.person_outline_rounded, color: C.muted), title: 'Made by', right: 'Rabby Hossain'),
        Row2(leading: Icon(Icons.mail_outline_rounded, color: C.muted), title: 'Email', right: feedbackEmail, onTap: () => launchUrl(Uri(scheme: 'mailto', path: feedbackEmail))),
        Row2(leading: Icon(Icons.dns_outlined, color: C.muted), title: 'Your data', sub: 'Your phone + ${Config.apiBase.replaceFirst('https://', '')}'),
        Row2(leading: Icon(Icons.verified_outlined, color: C.muted), title: 'Licenses', onTap: () => showLicensePage(context: context, applicationName: 'LifeOS', applicationVersion: version)),
      ]),
    ]);
  }

  Widget _tile(String k, String v, {bool dark = false}) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: dark ? C.ink : C.white, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(k, style: t(11, c: dark ? C.darkMuted : C.muted)), Text(v, style: t(17, w: w6, c: dark ? C.white : C.ink))]),
      );
}

void terms(BuildContext context) {
  const items = [
    ('Your data', 'Your data is yours. It is saved on your phone and on the LifeOS server only so it can sync between your phones. It is never sold.'),
    ('Google sign-in', 'Google is used only to know it is you. LifeOS reads your name and email, nothing else.'),
    ('Pro license', 'A key is for your personal use. Remove it from an old phone to use it on a new one.'),
    ('Not medical advice', 'Health, food and sleep numbers are for your own tracking, not medical advice.'),
    ('Changes', 'If these terms change, What\'s new will say so.'),
  ];
  showSheet(context, 'Terms and conditions', (ctx, _) => Col([
        for (final i in items) Col([Text(i.$1, style: t(15, w: w6)), Text(i.$2, style: t(14, c: C.ink.withValues(alpha: 0.8), h: 1.5))], space: 4),
      ], space: 14));
}


// ------------------------------------------------------------------ feedback
class FeedbackPage extends StatefulWidget {
  final String version;
  const FeedbackPage({super.key, required this.version});
  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final text = TextEditingController();
  String kind = 'Idea';
  int stars = 5;

  @override
  Widget build(BuildContext context) {
    return AccountPage(title: 'Send feedback', subtitle: 'Goes to $feedbackEmail', icon: Icons.chat_bubble_outline_rounded, children: [
      Panel(title: 'What is it about?', child: Chips(options: const ['Bug', 'Idea', 'Love it', 'Question'], selected: {kind}, onTap: (v) => setState(() => kind = v))),
      Panel(
        title: 'How do you like LifeOS?',
        child: Row(children: [
          for (var i = 1; i <= 5; i++)
            Press(
              onTap: () => setState(() => stars = i),
              haptic: Haptic.select,
              scale: 0.85,
              label: '$i stars',
              child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.star_rounded, size: 40, color: i <= stars ? C.ink : C.off)),
            ),
        ]),
      ),
      Panel(title: 'Your message', child: SoftField(controller: text, hint: 'Tell us what happened or what you want…', lines: 5)),
      Text('Your app version and phone are added so bugs get fixed faster.', style: t(12, c: C.muted)),
      PressPill('Send to $feedbackEmail', onTap: () async {
        if (text.text.trim().isEmpty) {
          say(context, 'Write a few words first.', good: false);
          return;
        }
        final body = '${text.text.trim()}\n\n---\nType: $kind\nRating: $stars/5\nLifeOS ${widget.version}\n${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
        final uri = Uri(scheme: 'mailto', path: feedbackEmail, query: 'subject=${Uri.encodeComponent('LifeOS $kind')}&body=${Uri.encodeComponent(body)}');
        final ok = await launchUrl(uri);
        if (!context.mounted) return;
        if (ok) {
          Haptic.success();
          Navigator.pop(context);
          toast(context, 'Thank you! Press send in your mail app.');
        } else {
          say(context, 'No mail app found. Email $feedbackEmail.', good: false);
        }
      }),
    ]);
  }
}

void signOutSheet(BuildContext context) {
  final s = store(context, listen: false);
  showSheet(context, 'Sign out?', (ctx, _) => Col([
        Text('Your data is saved on the server. Sign in again with Google to get it all back.', style: t(14, c: C.muted, h: 1.45)),
        PressPill('Sign out', bg: C.warn, onTap: () async {
          Haptic.warn();
          await s.flush();
          if (ctx.mounted) Navigator.of(ctx).popUntil((r) => r.isFirst);
          await AuthService.signOut();
        }),
        PressPill('Stay signed in', bg: C.chip, fg: C.ink, height: 52, onTap: () => Navigator.pop(ctx)),
      ], space: 10));
}
