import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../widgets/ui.dart';

/// Checks GitHub for a new version, downloads it inside the app and opens
/// Android's installer. Your data is safe: it lives on your server and phone.
class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});
  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  bool checking = true, downloading = false;
  String? error;
  UpdateInfo? update;
  String current = '';
  double progress = 0;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      checking = true;
      error = null;
    });
    try {
      current = (await UpdateService.current()).version;
      update = await UpdateService.check();
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => checking = false);
  }

  Future<void> _download() async {
    final u = update!;
    setState(() {
      downloading = true;
      error = null;
    });
    try {
      final f = await UpdateService.downloadApk(u, (got, total) {
        if (mounted && total > 0) setState(() => progress = got / total);
      });
      final r = await UpdateService.install(f);
      if (r != null && mounted) setState(() => error = 'Could not open the installer: $r. Allow "Install unknown apps" for LifeOS in phone settings.');
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
    if (mounted) setState(() => downloading = false);
  }

  @override
  Widget build(BuildContext context) {
    final u = update;
    return SubPage(title: 'App updates', children: [
      Box(
        dark: u != null,
        padding: const EdgeInsets.all(20),
        child: Col([
          Text(
              checking
                  ? 'Checking…'
                  : u == null
                      ? (error == null ? 'You have the newest version' : 'Could not check')
                      : 'LifeOS ${u.version} is ready',
              style: t(24, w: w6, ls: -0.4, c: u == null ? C.ink : C.white)),
          Text(u == null ? 'Installed: $current' : 'Installed: $current${u.sizeLabel.isEmpty ? '' : ' · download ${u.sizeLabel}'}',
              style: t(13, c: u == null ? C.muted : C.darkMuted)),
          if (downloading) Bar(progress, color: C.lime, track: C.dark3),
        ], space: 8),
      ),
      if (u != null && u.added.isNotEmpty) ListCard(title: 'New', rows: [for (final a in u.added) ListRow(title: a, minHeight: 40)]),
      if (u != null && u.fixed.isNotEmpty) ListCard(title: 'Fixed', rows: [for (final f in u.fixed) ListRow(title: f, minHeight: 40)]),
      if (error != null) Text(error!, style: t(13, c: C.warn, h: 1.4)),
      if (u != null) PillButton(downloading ? 'Downloading ${(progress * 100).round()}%' : 'Update now', onTap: downloading ? null : _download),
      if (u != null && !downloading) PillButton('Open download in browser', bg: C.white, onTap: () => UpdateService.openInBrowser(u)),
      if (u == null && !checking) PillButton('Check again', bg: C.ink, fg: C.white, onTap: _check),
    ]);
  }
}
