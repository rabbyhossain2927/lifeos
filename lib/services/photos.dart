import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import '../config.dart';

/// A photo is saved as {'local': path on this phone, 'url': copy on your server}.
/// Shown from the phone when the file is there, else from the server.
class Photos {
  static final _picker = ImagePicker();

  static Future<Directory> _dir() async {
    final d = Directory('${(await getApplicationDocumentsDirectory()).path}/photos');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<String> _keep(String path) async {
    final out = '${(await _dir()).path}/${const Uuid().v4()}.jpg';
    await File(path).copy(out);
    return out;
  }

  /// One photo, optionally cropped round (profile picture).
  static Future<String?> pickOne({bool camera = false, bool round = false}) async {
    final x = await _picker.pickImage(source: camera ? ImageSource.camera : ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (x == null) return null;
    var path = x.path;
    if (round) {
      final c = await ImageCropper().cropImage(
        sourcePath: path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        maxWidth: 800,
        maxHeight: 800,
        compressQuality: 85,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop photo',
            toolbarColor: const Color(0xFF1F1F23),
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: const Color(0xFFD4F06B),
            cropStyle: CropStyle.circle,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
        ],
      );
      if (c == null) return null;
      path = c.path;
    }
    return _keep(path);
  }

  /// Up to [limit] photos from the gallery.
  static Future<List<String>> pickMany({int limit = 10}) async {
    final xs = await _picker.pickMultiImage(maxWidth: 1600, imageQuality: 82, limit: limit);
    return [for (final x in xs.take(limit)) await _keep(x.path)];
  }

  /// Sends a photo to your server. Returns its web address, or null if offline / not set up yet.
  static Future<String?> upload(String local) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final token = await user.getIdToken();
      final req = http.MultipartRequest('POST', Uri.parse('${Config.apiBase}/upload.php'))
        ..headers['Authorization'] = 'Bearer ${token ?? ''}'
        ..headers['X-Auth-Token'] = token ?? ''
        ..files.add(await http.MultipartFile.fromPath('file', local));
      final r = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 60)));
      if (r.statusCode != 200) return null;
      return (jsonDecode(r.body) as Map)['url'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Saves locally and uploads; returns the photo map.
  static Future<Map<String, dynamic>> store(String local) async => {'local': local, 'url': await upload(local) ?? ''};
}

/// Shows a saved photo map ({local, url}) or a plain path/url string.
class PhotoBox extends StatelessWidget {
  final Object? photo;
  final double? size;
  final BoxFit fit;
  final double radius;
  const PhotoBox(this.photo, {super.key, this.size, this.fit = BoxFit.cover, this.radius = 14});

  static String localOf(Object? p) => p is Map ? '${p['local'] ?? ''}' : (p is String && !p.startsWith('http') ? p : '');
  static String urlOf(Object? p) => p is Map ? '${p['url'] ?? ''}' : (p is String && p.startsWith('http') ? p : '');

  @override
  Widget build(BuildContext context) {
    final local = localOf(photo), url = urlOf(photo);
    Widget img;
    if (local.isNotEmpty && File(local).existsSync()) {
      img = Image.file(File(local), width: size, height: size, fit: fit, cacheWidth: 900);
    } else if (url.isNotEmpty) {
      img = Image.network(url, width: size, height: size, fit: fit, cacheWidth: 900, errorBuilder: (_, __, ___) => _empty());
    } else {
      img = _empty();
    }
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: img);
  }

  Widget _empty() => Container(width: size, height: size, color: const Color(0x14000000), child: const Icon(Icons.image_outlined, color: Color(0x66000000)));
}
