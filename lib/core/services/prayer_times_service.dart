import 'dart:math' as math;

class PrayerTimes {
  final DateTime fajr;
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;
  final DateTime date;

  const PrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.date,
  });

  String get currentPrayer {
    final now = DateTime.now();
    if (now.isBefore(fajr)) return 'Isha';
    if (now.isBefore(sunrise)) return 'Fajr';
    if (now.isBefore(dhuhr)) return 'Sunrise';
    if (now.isBefore(asr)) return 'Dhuhr';
    if (now.isBefore(maghrib)) return 'Asr';
    if (now.isBefore(isha)) return 'Maghrib';
    return 'Isha';
  }

  DateTime get nextPrayer {
    final now = DateTime.now();
    if (now.isBefore(fajr)) return fajr;
    if (now.isBefore(sunrise)) return sunrise;
    if (now.isBefore(dhuhr)) return dhuhr;
    if (now.isBefore(asr)) return asr;
    if (now.isBefore(maghrib)) return maghrib;
    if (now.isBefore(isha)) return isha;
    return fajr.add(const Duration(days: 1));
  }

  String nextPrayerName() {
    final n = nextPrayer;
    if (n == fajr) return 'Fajr';
    if (n == sunrise) return 'Sunrise';
    if (n == dhuhr) return 'Dhuhr';
    if (n == asr) return 'Asr';
    if (n == maghrib) return 'Maghrib';
    return 'Isha';
  }

  Duration get timeUntilNext {
    return nextPrayer.difference(DateTime.now());
  }
}

class PrayerTimesService {
  PrayerTimesService._();
  static final PrayerTimesService instance = PrayerTimesService._();

  static const double _lat = 31.2001;
  static const double _lng = 29.9187;

  static const int _asrMethod = 1;

  PrayerTimes compute({DateTime? date}) {
    final d = date ?? DateTime.now();
    final julian = _julianDate(d);
    final d2r = math.pi / 180.0;
    final r2d = 180.0 / math.pi;

    final D = julian - 2451545.0;
    final g = (357.529 + 0.98560028 * D) % 360;
    final q = (280.459 + 0.98564736 * D) % 360;
    final L = (q + 1.915 * math.sin(g * d2r) + 0.020 * math.sin(2 * g * d2r)) % 360;
    final e = 23.439 - 0.00000036 * D;
    final RA = r2d * math.atan2(math.cos(e * d2r) * math.sin(L * d2r), math.cos(L * d2r)) / 15.0;
    final decl = r2d * math.asin(math.sin(e * d2r) * math.sin(L * d2r));
    final eqt = q / 15.0 - RA;

    final fajrAngle = 18.0;
    final ishaAngle = 17.0;

    final dhuhr = _timeFor(12.0 + (-_lng / 15.0) - eqt, d);
    final sunrise = dhuhr.subtract(_hourAngle(d, decl, -0.833, d2r, r2d));
    final fajr = dhuhr.subtract(_hourAngle(d, decl, -fajrAngle, d2r, r2d));
    final asr = dhuhr.add(_asrHourAngle(d, decl, _asrMethod, d2r, r2d));
    final maghrib = dhuhr.add(_hourAngle(d, decl, -0.833, d2r, r2d));
    final isha = dhuhr.add(_hourAngle(d, decl, -ishaAngle, d2r, r2d));

    return PrayerTimes(
      fajr: fajr,
      sunrise: sunrise,
      dhuhr: dhuhr,
      asr: asr,
      maghrib: maghrib,
      isha: isha,
      date: d,
    );
  }

  double _julianDate(DateTime d) {
    int y = d.year;
    int m = d.month;
    final day = d.day + (d.hour - 12) / 24.0;
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    final a = (y / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (y + 4716)).floor() +
        (30.6001 * (m + 1)).floor() +
        day +
        b -
        1524.5;
  }

  Duration _hourAngle(
      DateTime d, double decl, double angle, double d2r, double r2d) {
    final lat = _lat * d2r;
    final dec = decl * d2r;
    final cosH = (math.sin(angle * d2r) - math.sin(lat) * math.sin(dec)) /
        (math.cos(lat) * math.cos(dec));
    if (cosH > 1) return const Duration(hours: 6);
    if (cosH < -1) return const Duration(hours: 6);
    final H = r2d * math.acos(cosH);
    return Duration(minutes: (H * 4).round());
  }

  Duration _asrHourAngle(
      DateTime d, double decl, int asrMethod, double d2r, double r2d) {
    final lat = _lat * d2r;
    final dec = decl * d2r;
    final angle = asrMethod == 1
        ? r2d * math.atan(1.0 / (1 + math.tan((lat - dec).abs() / 2.0)))
        : r2d * math.atan(1.0 / (2 + math.tan((lat - dec).abs() / 2.0)));
    final cosH = (math.sin((90 - angle) * d2r) - math.sin(lat) * math.sin(dec)) /
        (math.cos(lat) * math.cos(dec));
    if (cosH > 1) return const Duration(hours: 3);
    if (cosH < -1) return const Duration(hours: 3);
    final H = r2d * math.acos(cosH);
    return Duration(minutes: (H * 4).round());
  }

  DateTime _timeFor(double t, DateTime d) {
    final hour = t.floor();
    final minute = ((t - hour) * 60).round();
    return DateTime(d.year, d.month, d.day, hour, minute);
  }
}
