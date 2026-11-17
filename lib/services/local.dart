import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Settings that belong to this phone only (not synced): app lock PIN,
/// device id for the license, photos of the day.
class Local {
  static late SharedPreferences sp;

  static Future<void> init() async {
    sp = await SharedPreferences.getInstance();
    if ((sp.getString('device_id') ?? '').isEmpty) {
      await sp.setString('device_id', const Uuid().v4());
    }
  }

  static String get deviceId => sp.getString('device_id') ?? 'unknown';

  static String get pin => sp.getString('pin') ?? '';
  static Future<void> setPin(String v) => v.isEmpty ? sp.remove('pin') : sp.setString('pin', v);

  static String photoFor(String day) => sp.getString('photo_$day') ?? '';
  static Future<void> setPhoto(String day, String path) => sp.setString('photo_$day', path);

  static bool get haptics => sp.getBool('haptics') ?? true;
  static Future<void> setHaptics(bool v) => sp.setBool('haptics', v);
  static int get lastBackup => sp.getInt('last_backup') ?? 0;
  static Future<void> setLastBackup(int v) => sp.setInt('last_backup', v);
  static bool get reduceMotion => sp.getBool('reduce_motion') ?? false;
  static bool get time24 => sp.getBool('time24') ?? false;
  static int get weekStartDay => sp.getInt('week_start') ?? DateTime.saturday;
  static Future<void> setWeekStart(int d) => sp.setInt('week_start', d);
  static String get avatarPath => sp.getString('avatar_path') ?? '';
  static Future<void> setAvatarPath(String v) => sp.setString('avatar_path', v);
  static int get lastUpdateCheck => sp.getInt('update_checked') ?? 0;
  static Future<void> setLastUpdateCheck(int v) => sp.setInt('update_checked', v);
}
