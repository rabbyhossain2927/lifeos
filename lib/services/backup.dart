import 'dart:convert';
import 'dart:io';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import '../config.dart';
import 'life.dart';
import 'local.dart';
import 'store.dart';

/// One backup you can restore.
class BackupItem {
  final String where; // Drive or Phone
  final String name;
  final DateTime at;
  final int bytes;
  final String ref; // file path or Drive file id
  BackupItem(this.where, this.name, this.at, this.bytes, this.ref);
  String get size => bytes <= 0 ? '' : bytes > 1048576 ? '${(bytes / 1048576).toStringAsFixed(1)} MB' : '${(bytes / 1024).round()} KB';
}

/// Backups in three places: Google Drive (hidden app folder), this phone, your server (live sync).
class Backup {
  static String _stamp(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}-${d.hour.toString().padLeft(2, '0')}${d.minute.toString().padLeft(2, '0')}';

  static String json(Store s) => const JsonEncoder.withIndent(' ').convert(s.exportAll());

  // ---------------- phone ----------------
  /// Download/LifeOS when Android allows it, else the app's own folder.
  static Future<Directory> phoneDir() async {
    final dl = Directory('/storage/emulated/0/Download/LifeOS');
    try {
      if (!await dl.exists()) await dl.create(recursive: true);
      final probe = File('${dl.path}/.probe');
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return dl;
    } catch (_) {
      final base = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final d = Directory('${base.path}/backups');
      if (!await d.exists()) await d.create(recursive: true);
      return d;
    }
  }

  static Future<File> toPhone(Store s) async {
    final d = await phoneDir();
    final f = File('${d.path}/LifeOS-backup-${_stamp(DateTime.now())}.json');
    await f.writeAsString(json(s), flush: true);
    await Local.setLastBackup(DateTime.now().millisecondsSinceEpoch);
    // Keep the newest 10.
    final all = await phoneList();
    for (final old in all.skip(10)) {
      try {
        await File(old.ref).delete();
      } catch (_) {}
    }
    return f;
  }

  static Future<List<BackupItem>> phoneList() async {
    try {
      final d = await phoneDir();
      final files = d.listSync().whereType<File>().where((f) => f.path.split('/').last.startsWith('LifeOS-backup')).toList();
      final items = [for (final f in files) BackupItem('Phone', f.path.split('/').last, f.lastModifiedSync(), f.lengthSync(), f.path)];
      items.sort((a, b) => b.at.compareTo(a.at));
      return items;
    } catch (_) {
      return [];
    }
  }

  // ---------------- Google Drive ----------------
  static final _google = GoogleSignIn(serverClientId: Config.googleWebClientId, scopes: const ['email', drive.DriveApi.driveAppdataScope]);

  static Future<drive.DriveApi?> _drive({bool ask = true}) async {
    var acc = _google.currentUser ?? await _google.signInSilently();
    if (acc == null && ask) acc = await _google.signIn();
    if (acc == null) return null;
    if (ask && !await _google.canAccessScopes([drive.DriveApi.driveAppdataScope])) {
      if (!await _google.requestScopes([drive.DriveApi.driveAppdataScope])) return null;
    }
    final client = await _google.authenticatedClient();
    return client == null ? null : drive.DriveApi(client);
  }

  static Future<bool> driveConnected() async => (await _drive(ask: false)) != null;

  static Future<void> toDrive(Store s, {bool ask = true}) async {
    final api = await _drive(ask: ask);
    if (api == null) throw 'Google Drive is not connected.';
    final bytes = utf8.encode(json(s));
    final meta = drive.File()
      ..name = 'LifeOS-backup-${_stamp(DateTime.now())}.json'
      ..parents = ['appDataFolder'];
    await api.files.create(meta, uploadMedia: drive.Media(Stream.value(bytes), bytes.length, contentType: 'application/json'));
    await Local.sp.setInt('last_drive_backup', DateTime.now().millisecondsSinceEpoch);
    final all = await driveList(api: api, count: 30);
    for (final old in all.skip(10)) {
      try {
        await api.files.delete(old.ref);
      } catch (_) {}
    }
  }

  static Future<List<BackupItem>> driveList({drive.DriveApi? api, int count = 5}) async {
    try {
      api ??= await _drive(ask: false);
      if (api == null) return [];
      final r = await api.files.list(spaces: 'appDataFolder', orderBy: 'createdTime desc', pageSize: count, $fields: 'files(id,name,createdTime,size)');
      return [
        for (final f in r.files ?? <drive.File>[]) BackupItem('Drive', f.name ?? 'Backup', f.createdTime?.toLocal() ?? DateTime.now(), int.tryParse(f.size ?? '') ?? 0, f.id ?? ''),
      ];
    } catch (_) {
      return [];
    }
  }

  static int get lastDrive => Local.sp.getInt('last_drive_backup') ?? 0;

  // ---------------- both ----------------
  static Future<List<BackupItem>> lastFive() async {
    final all = [...await phoneList(), ...await driveList()]..sort((a, b) => b.at.compareTo(a.at));
    return all.take(5).toList();
  }

  /// Saves a fresh phone backup first, then adds the chosen backup's items back.
  static Future<int> restore(Store s, BackupItem b) async {
    String text;
    if (b.where == 'Drive') {
      final api = await _drive();
      if (api == null) throw 'Google Drive is not connected.';
      final media = await api.files.get(b.ref, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      text = await utf8.decodeStream(media.stream);
    } else {
      text = await File(b.ref).readAsString();
    }
    await toPhone(s);
    return s.importAll(Map<String, dynamic>.from(jsonDecode(text) as Map));
  }

  /// Once a day, if auto backup is on: phone always, Drive when connected.
  static Future<void> auto(Store s) async {
    if (s.settings['autoBackup'] == false) return;
    if (DateTime.now().millisecondsSinceEpoch - Local.lastBackup < 20 * 3600 * 1000) return;
    try {
      await s.syncQuietly();
      await toPhone(s);
      await toDrive(s, ask: false);
    } catch (_) {}
  }
}
