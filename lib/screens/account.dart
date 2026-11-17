import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../services/api.dart';
import '../services/auth_service.dart';
import '../services/license_service.dart';
import '../services/life.dart';
import '../services/local.dart';
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

/// "26.0.0" -> "26.0"
String niceVersion(String v) => v.endsWith('.0') && v.split('.').length == 3 ? v.substring(0, v.length - 2) : v;

class AccountTab extends StatefulWidget {
  const AccountTab({super.key});
  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  String version = '26.0';
  String update = 'idle'; // idle, checking, available, latest, error
  UpdateInfo? found;

  @override
  void initState() {
    super.initState();
    UpdateService.current().then((v) {
      if (mounted) setState(() => version = niceVersion(v.version));
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
    final lastBackup = Local.lastBackup;
    final theme = '${s.settings['theme'] ?? 'Light'}';

    Widget icon(IconData i, (Color, Color) c) => Container(width: 36, height: 36, decoration: BoxDecoration(color: c.$1, borderRadius: BorderRadius.circular(12)), child: Icon(i, size: 18, color: c.$2));
    final lime = (C.limeSoft, Color(0xFF4D5A10)), violet = (Color(0xFFEFEDFF), Color(0xFF4A3FB0)), blue = (Color(0xFFE7F1FB), Color(0xFF1F4F86)), grey = (C.chip, Color(0xFF4A4A52));
    const chev = Icon(Icons.chevron_right_rounded, color: Color(0xFF8A8A84));
    Row2 link(String title, String sub, IconData i, (Color, Color) c, VoidCallback onTap) => Row2(title: title, sub: sub, leading: icon(i, c), trailing: chev, onTap: onTap);

    final upSub = switch (update) {
      'checking' => 'Checking…',
      'available' => '${found?.version} is ready',
      'latest' => 'You have the latest',
      'error' => 'Could not check. Try again.',
      _ => '$version installed',
    };

    return TabBody(children: [
      Text('Account', style: t(22, w: w6, ls: -0.4)),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(28)),
        child: Col([
          Row(children: [
            const Avatar(size: 60, onDark: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name.isEmpty ? 'Add your name' : name, style: t(20, w: w6, c: C.white)),
                const SizedBox(height: 3),
                Text('${pro ? 'LifeOS Pro' : 'Free plan'} · Google account', style: t(13, c: C.darkMuted)),
              ]),
            ),
            Press(
              onTap: () => editProfile(context),
              label: 'Edit profile',
              child: Container(height: 40, padding: const EdgeInsets.symmetric(horizontal: 14), alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFF262626), borderRadius: BorderRadius.circular(999)), child: Text('Edit', style: t(13, w: w6, c: C.white))),
            ),
          ]),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(22)),
            child: Row(children: [
              LevelBadge(level: s.lvl),
              const SizedBox(width: 14),
              Expanded(
                child: Col([
                  Row(children: [
                    Expanded(child: Text('Level ${s.lvl} · ${s.lvlName}', style: t(13, w: w6, c: C.white))),
                    CountText(s.xpInLevel, style: t(13, w: w6, c: C.lime), format: (v) => '${v.round()} / 1000 XP'),
                  ]),
                  Bar(s.xpInLevel / 1000, color: C.lime, track: const Color(0xFF333333)),
                  Text('${1000 - s.xpInLevel} XP to level ${s.lvl + 1} · earn XP by doing habits and goals', style: t(12, c: C.darkMuted, h: 1.35)),
                ], space: 6),
              ),
            ]),
          ),
        ], space: 16),
      ),
      _group('Account', [
        link('Edit profile', 'Name and avatar', Icons.person_outline_rounded, lime, () => editProfile(context)),
        link('License', pro ? 'Pro · active' : 'Free plan · add a key', Icons.key_outlined, lime, () => licenseSheet(context)),
        link('Backup', lastBackup == 0 ? 'Not backed up to this phone yet' : 'Last backup: ${_when(lastBackup)}', Icons.cloud_upload_outlined, lime, () => backupSheet(context).then((_) => setState(() {}))),
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
                Text(update == 'checking' ? 'Wait' : update == 'available' ? 'Update' : 'Check', style: t(13, w: w6)),
              ]),
            ),
          ),
        ),
        link("What's new", 'See what changed in $version', Icons.card_giftcard_rounded, blue, () => whatsNew(context, version)),
        link('Preferences', 'Reminders, prayer, haptics, lock', Icons.tune_rounded, violet, () => prefsSheet(context)),
        Row2(
          title: 'Theme',
          sub: theme == 'Light' ? 'Light' : theme,
          leading: icon(Icons.dark_mode_outlined, violet),
          trailing: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (final th in const [('Light', Icons.light_mode_outlined), ('Dark', Icons.dark_mode_outlined), ('Auto', Icons.contrast_rounded)])
                Press(
                  onTap: () {
                    if (th.$1 != 'Light') {
                      say(context, 'Dark mode is coming in the next update. Light for now.', good: false);
                      return;
                    }
                    s.setSetting('theme', th.$1);
                  },
                  haptic: Haptic.select,
                  label: '${th.$1} theme',
                  selected: theme == th.$1,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 38,
                    height: 34,
                    decoration: BoxDecoration(color: theme == th.$1 ? C.ink : Colors.transparent, borderRadius: BorderRadius.circular(999)),
                    child: Icon(th.$2, size: 16, color: theme == th.$1 ? C.lime : C.muted),
                  ),
                ),
            ]),
          ),
        ),
      ]),
      _group('Help', [
        link('How to use', '5 quick steps', Icons.menu_book_outlined, grey, () => howTo(context)),
        link('About LifeOS', 'Version and maker', Icons.info_outline_rounded, grey, () => about(context, version)),
        link('Terms and conditions', 'Privacy and use', Icons.description_outlined, grey, () => terms(context)),
        link('Feedback', 'Report a bug or share an idea', Icons.chat_bubble_outline_rounded, grey, () => feedback(context, version)),
      ]),
      PressPill('Sign out', bg: C.white, fg: C.warn, height: 54, onTap: () => signOutSheet(context)),
      Center(child: Text('LifeOS $version', style: t(12, c: const Color(0xFF8A8A84)))),
    ]);
  }

  String _when(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final day = dayKey(d) == todayKey ? 'Today' : dayKey(d) == dayKey(now.subtract(const Duration(days: 1))) ? 'Yesterday' : shortDate(d);
    return '$day, ${hmA(d)}';
  }

  Widget _group(String name, List<Row2> rows) => Col([
        Padding(padding: const EdgeInsets.only(left: 4, top: 4), child: Text(name, style: t(13, w: w6, c: C.muted))),
        RowsPanel(rows: rows),
      ], space: 8);
}

/// Hexagon level badge.
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
                Text('LV', style: t(9, w: FontWeight.w700, h: 1)),
                Text('$level', style: t(19, w: FontWeight.w700, h: 1.1)),
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

// ------------------------------------------------------------------ sheets

void editProfile(BuildContext context) {
  final s = store(context, listen: false);
  final name = TextEditingController(text: userName(s));
  var color = ((s.settings['avatarColor'] ?? 0xFF111111) as num).toInt();
  const colors = [0xFF111111, 0xFFD4F06B, 0xFFC7B8FF, 0xFFFFC9A8, 0xFFA8E6CF];
  showSheet(context, 'Edit profile', (ctx, set) {
    final c = Color(color);
    final n = name.text.trim();
    return Col([
      Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 84,
          height: 84,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          child: Text(n.isEmpty ? 'L' : n[0].toUpperCase(), style: t(34, w: FontWeight.w700, c: c.computeLuminance() < 0.3 ? C.lime : C.ink)),
        ),
      ),
      Text('Name', style: t(14, w: w6)),
      SoftField(controller: name, hint: 'Your name', pill: true, onChanged: (_) => set(() {})),
      Text('Avatar colour', style: t(14, w: w6)),
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: Color(k), shape: BoxShape.circle, border: Border.all(color: color == k ? C.ink : C.white, width: 3), boxShadow: const [BoxShadow(color: Color(0xFFDAD8DF), spreadRadius: 1)]),
              ),
            ),
          ),
      ]),
      Text('Signed in with Google${AuthService.user?.email == null ? '' : ' as ${AuthService.user!.email}'}.', style: t(13, c: C.muted)),
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
            Tag('PRO · ACTIVE', bg: C.lime, fg: C.ink),
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

Future<void> backupSheet(BuildContext context) {
  final s = store(context, listen: false);
  var busy = '';
  return showSheet(context, 'Backup', (ctx, set) {
    final last = Local.lastBackup;
    final synced = s.lastSyncedAt;
    final count = Store.collections.fold<int>(0, (a, c) => a + s.list(c).length);
    Future<void> run(String what, Future<void> Function() f) async {
      if (busy.isNotEmpty) return;
      set(() => busy = what);
      try {
        await f();
      } catch (e) {
        Haptic.warn();
        if (ctx.mounted) toast(ctx, e is ApiError ? e.message : 'That did not work: $e');
      }
      set(() => busy = '');
    }

    return Col([
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(22)),
        child: Col([
          Text('Last backup', style: t(12, w: w6, c: C.lime)),
          Text(last == 0 ? 'Not yet on this phone' : '${dayKey(DateTime.fromMillisecondsSinceEpoch(last)) == todayKey ? 'Today' : shortDate(DateTime.fromMillisecondsSinceEpoch(last))}, ${hmA(DateTime.fromMillisecondsSinceEpoch(last))}', style: t(20, w: w6, c: C.white)),
          Text('$count items · ${synced == null ? 'not synced to your server yet' : 'server synced at ${hmA(synced)}'}', style: t(12, c: C.darkMuted)),
        ], space: 4),
      ),
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Auto backup', style: t(15, w: w5)),
            Text('Once a day, saved to this phone', style: t(12, c: C.muted)),
          ]),
        ),
        Toggle(on: s.settings['autoBackup'] != false, label: 'Auto backup', onChanged: (v) => set(() => s.setSetting('autoBackup', v))),
      ]),
      PressPill(busy == 'now' ? 'Backing up…' : 'Back up now', onTap: () => run('now', () async {
            await s.sync();
            final f = await backupToPhone(s);
            Haptic.success();
            if (ctx.mounted) toast(ctx, 'Backup done. Saved to server and ${f.path.contains('Download') ? 'Downloads' : 'phone'}.');
          })),
      Row(children: gap([
        Expanded(
          child: PressPill(busy == 'file' ? 'Saving…' : 'Save to phone', bg: C.chip, fg: C.ink, height: 50, onTap: () => run('file', () async {
                final f = await backupToPhone(s);
                Haptic.success();
                if (ctx.mounted) toast(ctx, 'Saved: ${f.path}');
              })),
        ),
        Expanded(
          child: PressPill('Restore', bg: C.chip, fg: C.ink, height: 50, onTap: () => run('restore', () async {
                final f = await backupFile();
                if (!await f.exists() || (await f.length()) == 0) throw 'No backup file found. Save one first.';
                final j = jsonDecode(await f.readAsString());
                if (!ctx.mounted) return;
                if (!await confirm(ctx, 'Restore this backup?', ok: 'Restore', body: 'Items from the file are added back. Nothing is deleted.')) return;
                final n = s.importAll(Map<String, dynamic>.from(j as Map));
                Haptic.success();
                if (ctx.mounted) toast(ctx, 'Restored $n items.');
              })),
        ),
      ], 8)),
    ], space: 12);
  });
}

void whatsNew(BuildContext context, String current) {
  showSheet(context, "What's new", (ctx, _) => FutureBuilder<List<UpdateInfo>>(
        future: UpdateService.releases(count: 6),
        builder: (c, snap) {
          final list = snap.data ?? const <UpdateInfo>[];
          final items = <(String, List<String>)>[
            if (!list.any((u) => niceVersion(u.version) == current)) (current, const ['Brand new look, easy and calm', 'Motion and better haptics everywhere', 'Backup and Feedback in Account']),
            for (final u in list) (niceVersion(u.version), [...u.added, ...u.fixed.map((f) => 'Fixed: $f')]),
          ];
          return Col([
            if (snap.connectionState == ConnectionState.waiting) LinearProgressIndicator(color: C.ink, backgroundColor: C.chip),
            for (final r in items)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(22)),
                child: Col([
                  Row(children: [
                    Expanded(child: Text(r.$1, style: t(16, w: w6))),
                    r.$1 == current ? Tag('Installed', bg: C.ink, fg: C.white) : (UpdateService.isNewer(r.$1, current) ? Tag('New', bg: C.lime, fg: C.ink) : Tag('Older', bg: C.white)),
                  ]),
                  if (r.$2.isEmpty) Text('Small fixes.', style: t(14, c: C.muted)),
                  for (final i in r.$2.take(6))
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(padding: const EdgeInsets.only(top: 6), child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF6E8A12), shape: BoxShape.circle))),
                      const SizedBox(width: 8),
                      Expanded(child: Text(i, style: t(14, h: 1.4))),
                    ]),
                ], space: 8),
              ),
          ], space: 12);
        },
      ));
}

void prefsSheet(BuildContext context) {
  final s = store(context, listen: false);
  showSheet(context, 'Preferences', (ctx, set) {
    Widget tog(String title, String sub, bool on, ValueChanged<bool> f) => Row2(
          title: title,
          sub: sub,
          trailing: Toggle(on: on, label: title, onChanged: (v) => set(() => f(v))),
        );
    Widget chips(String title, List<String> opts, String sel, ValueChanged<String> f) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Col([Text(title, style: t(15, w: w5)), Chips(options: opts, selected: {sel}, onTap: (v) => set(() => f(v)))], space: 8),
        );
    return Col([
      tog('Prayer alerts', '10 min before each prayer', s.settings['prayerAlerts'] != false, (v) => s.setSetting('prayerAlerts', v)),
      tog('Habit nudge', 'At 9 PM if habits are not done', s.settings['habitNudge'] != false, (v) => s.setSetting('habitNudge', v)),
      tog('Weekly review', 'Friday after Jummah', s.settings['weeklyReview'] != false, (v) => s.setSetting('weeklyReview', v)),
      tog('Haptic feedback', 'Gentle taps when you press things', Local.haptics, (v) {
        Local.setHaptics(v);
        if (v) Haptic.success();
      }),
      tog('App lock', Local.pin.isEmpty ? 'Ask for a 4-digit PIN when the app opens' : 'PIN is on', Local.pin.isNotEmpty, (on) async {
        if (!on) {
          await Local.setPin('');
        } else {
          final v = await showForm(ctx, 'Choose a 4-digit PIN', const [Field('p', 'PIN', type: F.number, required: true, hint: '1234')]);
          final p = '${v?['p'] ?? ''}'.replaceAll('.0', '');
          if (p.length == 4) {
            await Local.setPin(p);
          } else if (v != null && ctx.mounted) {
            toast(ctx, 'The PIN must be 4 digits.');
          }
        }
        set(() {});
      }),
      chips('Asr time', const ['Hanafi', 'Shafi'], s.shafi ? 'Shafi' : 'Hanafi', (v) => s.setSetting('asr', v)),
      chips('City for prayer times', PrayerTimes.cities.keys.toList(), s.cityName, (v) {
        s.setSetting('cityName', v);
        s.setSetting('city', PrayerTimes.cities[v]);
      }),
      chips('Water goal (glasses)', const ['6', '8', '10', '12'], '${s.waterGoal}', (v) => s.setSetting('waterGoal', int.parse(v))),
      chips('Calorie goal', const ['1600', '1800', '2000', '2200', '2500'], '${s.kcalGoal}', (v) => s.setSetting('kcalGoal', int.parse(v))),
    ], space: 0);
  });
}

void howTo(BuildContext context) {
  const steps = [
    ('Check Home each morning', 'All your stats in one look: prayer, habits, water, food, sleep.'),
    ("Tap, don't type", 'Most things are one tap: tick a habit, add a glass, pick a mood.'),
    ('Use + for anything new', 'The lime button adds a habit, goal, meal, note or reminder.'),
    ('Set one goal', 'LifeOS splits it into month, week and a small step for today.'),
    ('Review on Friday', 'Three quick taps. See what worked and pick next week\'s focus.'),
  ];
  showSheet(context, 'How to use', (ctx, _) => Col([
        for (var i = 0; i < steps.length; i++)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(20)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 30, height: 30, alignment: Alignment.center, decoration: const BoxDecoration(color: C.lime, shape: BoxShape.circle), child: Text('${i + 1}', style: t(14, w: FontWeight.w700))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(steps[i].$1, style: t(15, w: w6)), const SizedBox(height: 2), Text(steps[i].$2, style: t(13, c: C.muted, h: 1.4))])),
            ]),
          ),
      ], space: 10));
}

void about(BuildContext context, String version) {
  showSheet(context, 'About LifeOS', (ctx, _) => Col([
        const LogoMark(size: 76),
        Text('LifeOS $version', style: t(18, w: w6)),
        Text('One calm place for prayer, habits, goals, health and the people you love. Made by Rabby Hossain.', textAlign: TextAlign.center, style: t(14, c: C.muted, h: 1.5)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(color: C.chip, borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            for (final r in [('Version', version), ('Made by', 'Rabby Hossain'), ('Support', Config.supportEmail), ('Website', Config.apiBase.replaceFirst('https://', ''))])
              Container(
                height: 46,
                decoration: BoxDecoration(border: r.$1 == 'Website' ? null : const Border(bottom: BorderSide(color: Color(0xFFE4E2E8)))),
                child: Row(children: [Text(r.$1, style: t(14, c: C.muted)), const Spacer(), Flexible(child: Text(r.$2, style: t(14, w: w6), overflow: TextOverflow.ellipsis))]),
              ),
          ]),
        ),
      ], space: 12, cross: CrossAxisAlignment.center));
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
        for (final i in items) Col([Text(i.$1, style: t(15, w: w6)), Text(i.$2, style: t(14, c: const Color(0xFF3F3F46), h: 1.5))], space: 4),
      ], space: 14));
}

void feedback(BuildContext context, String version) {
  final text = TextEditingController();
  var kind = 'Idea';
  var stars = 5;
  showSheet(context, 'Send feedback', (ctx, set) => Col([
        Text('What is it about?', style: t(14, w: w6)),
        Chips(options: const ['Bug', 'Idea', 'Love it'], selected: {kind}, onTap: (v) => set(() => kind = v)),
        Text('How do you like LifeOS?', style: t(14, w: w6)),
        Row(children: [
          for (var i = 1; i <= 5; i++)
            Press(
              onTap: () => set(() => stars = i),
              haptic: Haptic.select,
              scale: 0.8,
              label: '$i stars',
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: AnimatedScale(
                  scale: i <= stars ? 1 : 0.85,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: Icon(Icons.star_rounded, size: 40, color: i <= stars ? C.ink : const Color(0xFFDAD8DF)),
                ),
              ),
            ),
        ]),
        SoftField(controller: text, hint: 'Tell us what happened or what you want…', lines: 4),
        Text('Your app version and phone are added so bugs get fixed faster.', style: t(12, c: C.muted)),
        PressPill('Send', onTap: () async {
          if (text.text.trim().isEmpty) {
            say(ctx, 'Write a few words first.', good: false);
            return;
          }
          final body = '${text.text.trim()}\n\n---\nType: $kind\nRating: $stars/5\nLifeOS $version\n${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
          final uri = Uri(scheme: 'mailto', path: Config.supportEmail, query: 'subject=${Uri.encodeComponent('LifeOS $kind')}&body=${Uri.encodeComponent(body)}');
          final ok = await launchUrl(uri);
          if (!ctx.mounted) return;
          if (ok) {
            Haptic.success();
            Navigator.pop(ctx);
            toast(context, 'Thank you! Press send in your mail app.');
          } else {
            say(ctx, 'No mail app found. Email ${Config.supportEmail}.', good: false);
          }
        }),
      ], space: 12));
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
