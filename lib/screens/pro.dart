import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../services/license_service.dart';
import '../widgets/ui.dart';

/// Opens a Pro feature, or the unlock page when there is no key yet.
void openPro(BuildContext context, String feature, Widget page) {
  final s = store(context, listen: false);
  if (License.unlocked(s, feature)) {
    push(context, page);
  } else {
    showPro(context, feature);
  }
}

void showPro(BuildContext context, String feature) => push(context, LicenseScreen(feature: feature));

class LicenseScreen extends StatefulWidget {
  final String? feature;
  const LicenseScreen({super.key, this.feature});
  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  final key = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    key.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    setState(() {
      busy = true;
      error = null;
    });
    final s = store(context, listen: false);
    final r = await License.activate(s, key.text);
    if (!mounted) return;
    setState(() {
      busy = false;
      error = r;
    });
    if (r == null) toast(context, 'LifeOS Pro is unlocked. Thank you!');
  }

  @override
  Widget build(BuildContext context) {
    final s = store(context);
    final pro = License.isPro(s);
    final lic = s.settings['license'] as Map?;
    return SubPage(title: 'LifeOS Pro', children: [
      Box(
        color: C.lime,
        padding: const EdgeInsets.all(20),
        child: Col([
          Text(pro ? 'Pro is on' : 'Unlock Pro', style: t(28, w: w6, ls: -0.6)),
          Text(
              pro
                  ? 'Key ${lic?['key']} is active on this account. Every phone you sign in on is unlocked.'
                  : widget.feature != null && License.proFeatures[widget.feature] != null
                      ? '${License.proFeatures[widget.feature]} is part of Pro. Buy once, use forever.'
                      : 'LifeOS is free. A one-time key unlocks the extras.',
              style: t(14, c: C.limeText, h: 1.45)),
        ], space: 8),
      ),
      ListCard(title: 'Pro includes', rows: [
        for (final f in License.proFeatures.values)
          ListRow(title: f, leading: Icon(pro ? Icons.check_circle_rounded : Icons.lock_outline_rounded, size: 20, color: C.ink), minHeight: 48),
      ]),
      if (!pro) ...[
        Box(
          child: Col([
            const H2('Enter your license key'),
            TextField(
              controller: key,
              style: t(16, w: w5, ls: 1),
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'XXXX-XXXX-XXXX-XXXX',
                hintStyle: t(16, c: const Color(0xFF8A8A92)),
                filled: true,
                fillColor: C.chip,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            if (error != null) Text(error!, style: t(13, c: C.warn, h: 1.4)),
            PillButton(busy ? 'Checking…' : 'Activate', bg: C.ink, fg: C.white, onTap: busy ? null : _activate),
          ], space: 12),
        ),
        PillButton('Buy a key', onTap: () => launchUrl(Uri.parse(Config.buyUrl), mode: LaunchMode.externalApplication)),
      ],
      if (pro)
        PillButton('Remove key from this account', bg: C.white, onTap: () async {
          if (await confirm(context, 'Remove the key?', ok: 'Remove', body: 'Pro features lock again on all your phones. You can enter the key again later.')) {
            await License.deactivate(s);
          }
        }),
    ]);
  }
}
