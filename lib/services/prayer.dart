import 'dart:math' as math;

/// Prayer times on the phone, no internet needed.
/// Method: Fajr and Isha at 18 degrees (Islamic Foundation Bangladesh /
/// Karachi), Asr Hanafi (shadow factor 2). Based on the praytimes.org formulas.
class PrayerTimes {
  static const names = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

  static const cities = <String, List<double>>{
    'Dhaka': [23.8103, 90.4125],
    'Chattogram': [22.3569, 91.7832],
    'Sylhet': [24.8949, 91.8687],
    'Rajshahi': [24.3745, 88.6042],
    'Khulna': [22.8456, 89.5403],
    'Barishal': [22.7010, 90.3535],
    'Rangpur': [25.7439, 89.2752],
    'Mymensingh': [24.7471, 90.4203],
    'Cumilla': [23.4607, 91.1809],
    'Makkah': [21.3891, 39.8579],
    'London': [51.5072, -0.1276],
  };

  static double _d2r(double d) => d * math.pi / 180;
  static double _r2d(double r) => r * 180 / math.pi;
  static double _fix(double a, double b) {
    a = a - b * (a / b).floorToDouble();
    return a < 0 ? a + b : a;
  }

  static double _julian(int y, int m, int d) {
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    final a = (y / 100).floorToDouble();
    final b = 2 - a + (a / 4).floorToDouble();
    return (365.25 * (y + 4716)).floorToDouble() + (30.6001 * (m + 1)).floorToDouble() + d + b - 1524.5;
  }

  /// [decl, eqt] for a julian date.
  static List<double> _sun(double jd) {
    final dd = jd - 2451545.0;
    final g = _fix(357.529 + 0.98560028 * dd, 360);
    final q = _fix(280.459 + 0.98564736 * dd, 360);
    final l = _fix(q + 1.915 * math.sin(_d2r(g)) + 0.020 * math.sin(_d2r(2 * g)), 360);
    final e = 23.439 - 0.00000036 * dd;
    final ra = _r2d(math.atan2(math.cos(_d2r(e)) * math.sin(_d2r(l)), math.cos(_d2r(l)))) / 15;
    final eqt = q / 15 - _fix(ra, 24);
    final decl = _r2d(math.asin(math.sin(_d2r(e)) * math.sin(_d2r(l))));
    return [decl, eqt];
  }

  /// Times for a day as DateTime in the phone's time zone.
  static Map<String, DateTime> forDay(DateTime date, double lat, double lng) {
    final tz = date.timeZoneOffset.inMinutes / 60.0;
    final jd = _julian(date.year, date.month, date.day) - lng / (15 * 24);

    double midDay(double t) => _fix(12 - _sun(jd + t)[1], 24);
    double angleTime(double angle, double t, {bool ccw = false}) {
      final decl = _sun(jd + t)[0];
      final noon = midDay(t);
      final c = (-math.sin(_d2r(angle)) - math.sin(_d2r(decl)) * math.sin(_d2r(lat))) /
          (math.cos(_d2r(decl)) * math.cos(_d2r(lat)));
      final tt = _r2d(math.acos(c.clamp(-1.0, 1.0))) / 15;
      return noon + (ccw ? -tt : tt);
    }

    double asr(double t) {
      final decl = _sun(jd + t)[0];
      final angle = -_r2d(math.atan(1 / (2 + math.tan(_d2r((lat - decl).abs())))));
      return angleTime(angle, t);
    }

    final fajr = angleTime(18, 5 / 24, ccw: true);
    final dhuhr = midDay(12 / 24) + 1 / 60;
    final asrT = asr(13 / 24);
    final maghrib = angleTime(0.833, 18 / 24) + 2 / 60;
    final isha = angleTime(18, 18 / 24);

    DateTime at(double h) {
      final local = _fix(h + tz - lng / 15, 24);
      final mins = (local * 60).round();
      return DateTime(date.year, date.month, date.day).add(Duration(minutes: mins));
    }

    return {'Fajr': at(fajr), 'Dhuhr': at(dhuhr), 'Asr': at(asrT), 'Maghrib': at(maghrib), 'Isha': at(isha)};
  }

  /// The next prayer from now: name and time (tomorrow's Fajr after Isha).
  static MapEntry<String, DateTime> next(double lat, double lng) {
    final now = DateTime.now();
    final t = forDay(now, lat, lng);
    for (final n in names) {
      if (t[n]!.isAfter(now)) return MapEntry(n, t[n]!);
    }
    final tm = forDay(now.add(const Duration(days: 1)), lat, lng);
    return MapEntry('Fajr', tm['Fajr']!);
  }
}
