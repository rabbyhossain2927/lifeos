import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'local.dart';
import 'store.dart';

/// LifeOS is free. A license key from your shop unlocks the Pro extras.
/// The key is saved in the account, so every phone signed in to the same
/// Google account is unlocked (each phone counts as one activation).
class License {
  /// Change this list to choose what a key unlocks.
  static const proFeatures = {
    'report': 'Weekly report and insights',
    'rewards': 'Rewards, wins and notes to future you',
    'memory': 'Memory: photo of the day and life timeline',
    'travel': 'Travel: trips, packing lists, places',
    'voice': 'Voice notes to journal',
  };

  static bool isPro(Store s) => (s.settings['license'] as Map?)?['key'] != null;

  static bool unlocked(Store s, String feature) => !proFeatures.containsKey(feature) || isPro(s);

  static Future<Map<String, dynamic>> _call(String action, String key) async {
    final q = 'key=${Uri.encodeQueryComponent(key)}'
        '&product=${Uri.encodeQueryComponent(Config.licenseProduct)}'
        '&device=${Uri.encodeQueryComponent(Local.deviceId)}';
    final r = await http.get(Uri.parse('${Config.licenseApi}/$action?$q')).timeout(const Duration(seconds: 20));
    try {
      final d = jsonDecode(r.body);
      return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
    } catch (_) {
      return {'ok': false, 'error': 'The shop sent an unexpected reply (${r.statusCode}).'};
    }
  }

  static String _msg(Map<String, dynamic> m, String fallback) {
    final t = '${m['message'] ?? m['error'] ?? ''}'.trim();
    if (t.isEmpty || t == 'null') return fallback;
    return switch (t) {
      'invalid_key' => 'This license key is not valid. Check it and try again.',
      'limit_reached' => 'This key is already used on the most phones it allows. Deactivate it on an old phone first.',
      'wrong_product' => 'This key is for another product, not LifeOS.',
      _ => t.replaceAll('_', ' '),
    };
  }

  /// Unlocks Pro. Returns null when it worked, else a message.
  static Future<String?> activate(Store s, String raw) async {
    final key = raw.trim().toUpperCase();
    if (key.length < 6) return 'Enter the license key you received.';
    try {
      final r = await _call('activate', key);
      if (r['ok'] != true) return _msg(r, 'This license key could not be used.');
      s.setSetting('license', {
        'key': key,
        'product': '${r['product'] ?? 'LifeOS Pro'}',
        'activatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      return null;
    } catch (_) {
      return 'Could not reach the license shop. Check your internet and try again.';
    }
  }

  /// Checks the saved key again (a refunded or blocked key stops working).
  /// Offline never locks anyone out.
  static Future<void> recheck(Store s) async {
    final l = s.settings['license'] as Map?;
    if (l == null) return;
    try {
      final r = await _call('check', '${l['key']}');
      if (r['ok'] == false && (r['error'] == 'invalid_key' || r['error'] == 'revoked' || r['error'] == 'refunded')) {
        s.setSetting('license', null);
      } else if (r['ok'] == true && r['activated'] == false) {
        await _call('activate', '${l['key']}');
      }
    } catch (_) {}
  }

  /// Frees this phone's activation and removes the key from the account.
  static Future<void> deactivate(Store s) async {
    final l = s.settings['license'] as Map?;
    if (l == null) return;
    try {
      await _call('deactivate', '${l['key']}');
    } catch (_) {}
    s.setSetting('license', null);
  }
}
