import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../services/api.dart';
import '../services/auth_service.dart';
import '../services/license_service.dart';
import '../services/local.dart';
import '../services/update_service.dart';
import '../widgets/form.dart';
import '../widgets/ui.dart';
import 'pro.dart';
import 'stats.dart';
import 'update_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String version = '';

  @override
  void initState() {
    super.initState();
    UpdateService.current().then((v) {
      if (mounted) setState(() => version = '${v.version} (${v.build})');
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final user = AuthService.user;
    final name = (s.settings['name'] ?? user?.displayName ?? '').toString();
    final best = s.list('habits').fold<int>(0, (a, h) => s.bestStreak(h) > a ? s.bestStreak(h) : a);
    final pro = License.isPro(s);
    final synced = s.lastSyncedAt;

    return SubPage(title: 'Profile', children: [
      Col([
        GestureDetector(
          onTap: () async {
            final v = await showForm(context, 'Your name', const [Field('n', 'Name', required: true)], initial: {'n': name});
            if (v != null) s.setSetting('name', v['n']);
          },
          child: Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: C.ink, shape: BoxShape.circle),
            child: Text(name.isEmpty ? 'L' : name[0].toUpperCase(), style: t(34, w: w6, c: C.lime)),
          ),
        ),
        Text(name.isEmpty ? 'Tap the circle to add your name' : name, style: t(22, w: w6, ls: -0.4)),
        Text('Level ${s.level} · ${s.points} XP${pro ? ' · Pro' : ''}', style: t(13, c: C.muted)),
        SizedBox(width: 200, child: Bar(s.levelProgress, track: C.white)),
      ], space: 10, cross: CrossAxisAlignment.center),
      Row(children: gap([
        Expanded(child: _stat('$best', 'Best streak', C.white)),
        Expanded(child: _stat('${(s.weekScore() * 100).round()}%', 'Week score', C.lime)),
        Expanded(child: _stat('${s.points}', 'Points', C.white)),
      ], 10)),
      Box(
        dark: true,
        radius: 24,
        onTap: () => openPro(context, 'report', const StatsScreen()),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Streaks and weekly report', style: t(15, w: w6, c: C.white)),
              Text('Your week, life balance and patterns', style: t(12, c: C.darkMuted)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: C.white),
        ]),
      ),
      Box(
        radius: 24,
        onTap: () => push(context, const LicenseScreen()),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pro ? 'LifeOS Pro is on' : 'Unlock LifeOS Pro', style: t(15, w: w6)),
              Text(pro ? 'Thank you for supporting LifeOS' : 'One-time license key from the shop', style: t(12, c: C.muted)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded),
        ]),
      ),
      ListCard(rows: [
        ListRow(
          title: 'App lock',
          sub: Local.pin.isEmpty ? 'Ask for a 4-digit PIN when the app opens' : 'PIN is on',
          trailing: Toggle(
            on: Local.pin.isNotEmpty,
            label: 'App lock',
            onChanged: (on) async {
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
              setState(() {});
            },
          ),
        ),
        ListRow(
          title: 'Sync with your server',
          sub: s.syncing
              ? 'Syncing…'
              : s.syncError != null
                  ? s.syncError!
                  : synced == null
                      ? 'Not synced yet'
                      : 'Synced at ${hmA(synced)}${s.pendingCount > 0 ? ' · ${s.pendingCount} waiting' : ''}',
          trailing: SmallPill('Sync now', onTap: () async {
            try {
              await s.sync();
              if (context.mounted) toast(context, 'Synced.');
            } catch (e) {
              if (context.mounted) toast(context, e is ApiError ? e.message : 'Could not reach your server.');
            }
          }),
        ),
        ListRow(title: 'Offline first', sub: 'Works without internet, syncs when you are back online', trailing: const Icon(Icons.check_rounded)),
        ListRow(
          title: 'App updates',
          sub: 'Version $version',
          trailing: SmallPill('Check', onTap: () => push(context, const UpdateScreen())),
        ),
        ListRow(
          title: 'Help and support',
          sub: Config.supportEmail,
          onTap: () => launchUrl(Uri.parse('mailto:${Config.supportEmail}?subject=LifeOS')),
        ),
      ]),
      PillButton('Sign out', bg: C.white, onTap: () async {
        if (await confirm(context, 'Sign out?', ok: 'Sign out', body: 'Your data stays on your server. Sign in again to get it back.')) {
          await s.flush();
          if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
          await AuthService.signOut();
        }
      }),
      Center(child: Text(user?.email ?? '', style: t(12, c: C.muted))),
    ]);
  }

  Widget _stat(String n, String label, Color bg) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(n, style: t(22, w: w6)),
          Text(label, style: t(12, c: bg == C.lime ? C.limeText : C.muted)),
        ]),
      );
}
