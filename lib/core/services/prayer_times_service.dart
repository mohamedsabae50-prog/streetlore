import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

class PrayerTimes {
  final DateTime fajr;
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;
  final DateTime date;
  final String source;
  final String? hijriDate;

  const PrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.date,
    required this.source,
    this.hijriDate,
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
  static const int _method = 5;

  PrayerTimes? _cached;
  DateTime? _cachedAt;

  Future<PrayerTimes>? _inflight;

  Future<PrayerTimes> getTimes({bool force = false}) {
    if (!force && _cached != null && _cachedAt != null) {
      final age = DateTime.now().difference(_cachedAt!);
      if (age.inMinutes < 30) {
        return Future.value(_cached);
      }
    }
    if (_inflight != null && !force) return _inflight!;
    final completer = Completer<PrayerTimes>();
    _inflight = completer.future;
    _fetch(force: force).then((times) {
      _cached = times;
      _cachedAt = DateTime.now();
      _inflight = null;
      if (!completer.isCompleted) completer.complete(times);
    }).catchError((Object e) {
      _inflight = null;
      if (!completer.isCompleted) completer.complete(_computeFallback());
    });
    return completer.future;
  }

  Future<PrayerTimes> _fetch({bool force = false}) async {
    final url = Uri.parse(
      'https://api.aladhan.com/v1/timings/'
      '${_todayDateString()}?latitude=$_lat&longitude=$_lng&method=$_method',
    );
    final res = await http.get(url).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw 'AlAdhan returned ${res.statusCode}';
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['code'] != 200) {
      throw 'AlAdhan API error: ${body['status']}';
    }
    final data = body['data'] as Map<String, dynamic>;
    final timings = data['timings'] as Map<String, dynamic>;
    final dateInfo = data['date'] as Map<String, dynamic>?;
    final hijri = dateInfo?['hijri'] as Map<String, dynamic>?;
    final hijriDate = hijri == null
        ? null
        : '${hijri['day']} ${hijri['month']?['en']} ${hijri['year']}';

    final today = DateTime.now();
    DateTime parseTime(String hhmm) {
      final clean = hhmm.split(' ').first;
      final parts = clean.split(':');
      return DateTime(
        today.year,
        today.month,
        today.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    }

    return PrayerTimes(
      fajr: parseTime(timings['Fajr'] as String),
      sunrise: parseTime(timings['Sunrise'] as String),
      dhuhr: parseTime(timings['Dhuhr'] as String),
      asr: parseTime(timings['Asr'] as String),
      maghrib: parseTime(timings['Maghrib'] as String),
      isha: parseTime(timings['Isha'] as String),
      date: today,
      source: 'AlAdhan',
      hijriDate: hijriDate,
    );
  }

  String _todayDateString() {
    final d = DateTime.now();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd-$mm-${d.year}';
  }

  PrayerTimes _computeFallback() {
    final d = DateTime.now();
    final julian = _julianDate(d);
    final d2r = math.pi / 180.0;
    final r2d = 180.0 / math.pi;

    final D = julian - 2451545.0;
    final g = (357.529 + 0.98560028 * D) % 360;
    final q = (280.459 + 0.98564736 * D) % 360;
    final L = (q + 1.915 * math.sin(g * d2r) + 0.020 * math.sin(2 * g * d2r)) % 360;
    final e = 23.439 - 0.00000036 * D;
    final raRad = r2d *
        math.atan2(math.cos(e * d2r) * math.sin(L * d2r), math.cos(L * d2r)) /
        15.0;
    final decl = r2d * math.asin(math.sin(e * d2r) * math.sin(L * d2r));
    final eqt = q / 15.0 - raRad;

    const fajrAngle = 18.0;
    const ishaAngle = 17.0;

    final dhuhr = _timeFor(12.0 + (-_lng / 15.0) - eqt, d);
    final sunrise = dhuhr.subtract(_hourAngle(d, decl, -0.833, d2r, r2d));
    final fajr = dhuhr.subtract(_hourAngle(d, decl, -fajrAngle, d2r, r2d));
    final asr = dhuhr.add(_asrHourAngle(d, decl, 1, d2r, r2d));
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
      source: 'Local',
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
