import 'dart:math' as math;

class SunTimes {
  final DateTime sunrise;
  final DateTime sunset;
  final DateTime solarNoon;
  final Duration daylight;

  const SunTimes({
    required this.sunrise,
    required this.sunset,
    required this.solarNoon,
    required this.daylight,
  });

  bool get isDaylightNow {
    final now = DateTime.now();
    return now.isAfter(sunrise) && now.isBefore(sunset);
  }

  Duration get timeUntilSunset {
    final now = DateTime.now();
    if (now.isAfter(sunset)) return Duration.zero;
    return sunset.difference(now);
  }

  Duration get timeUntilSunrise {
    final now = DateTime.now();
    if (now.isBefore(sunrise)) return sunrise.difference(now);
    return Duration.zero;
  }
}

class SunTimesService {
  SunTimesService._();
  static final SunTimesService instance = SunTimesService._();

  static const double _lat = 31.2001;
  static const double _lng = 29.9187;

  SunTimes compute({
    DateTime? date,
    double latitude = _lat,
    double longitude = _lng,
  }) {
    final d = date ?? DateTime.now();
    final dayOfYear = int.parse(
      DateTime(d.year, d.month, d.day)
          .difference(DateTime(d.year, 1, 1))
          .inDays
          .toString(),
    );

    final decl = 23.45 * math.pi / 180.0 * math.sin(2 * math.pi * (284 + dayOfYear) / 365.0);

    final latRad = latitude * math.pi / 180.0;

    final cosH = -math.tan(latRad) * math.tan(decl);
    if (cosH > 1) {
      final noon = _solarNoon(d, longitude);
      return SunTimes(
        sunrise: DateTime(d.year, d.month, d.day, 12, 0),
        sunset: DateTime(d.year, d.month, d.day, 12, 0),
        solarNoon: noon,
        daylight: Duration.zero,
      );
    }
    if (cosH < -1) {
      final noon = _solarNoon(d, longitude);
      return SunTimes(
        sunrise: DateTime(d.year, d.month, d.day, 0, 0),
        sunset: DateTime(d.year, d.month, d.day, 23, 59),
        solarNoon: noon,
        daylight: const Duration(hours: 24),
      );
    }

    final h = math.acos(cosH) * 180.0 / math.pi;
    final solarNoon = _solarNoon(d, longitude);

    final sunrise = solarNoon.subtract(Duration(minutes: (h * 60).round()));
    final sunset = solarNoon.add(Duration(minutes: (h * 60).round()));

    return SunTimes(
      sunrise: sunrise,
      sunset: sunset,
      solarNoon: solarNoon,
      daylight: sunset.difference(sunrise),
    );
  }

  DateTime _solarNoon(DateTime date, double longitude) {
    final d = DateTime(date.year, date.month, date.day);
    final dayOfYear = d.difference(DateTime(date.year, 1, 1)).inDays + 1;
    final b = 2 * math.pi * (dayOfYear - 81) / 365.0;
    final equationOfTime = 9.87 * math.sin(2 * b) - 7.53 * math.cos(b) - 1.5 * math.sin(b);
    final timeCorrectionMinutes = 4 * longitude + equationOfTime;
    final solarNoonUtc = 12.0 - timeCorrectionMinutes / 60.0;
    final localOffset = date.timeZoneOffset.inHours;
    final solarNoonLocal = solarNoonUtc + localOffset.toDouble();
    final hour = solarNoonLocal.floor();
    final minute = ((solarNoonLocal - hour) * 60).round();
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  String formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String formatDuration(Duration d) {
    if (d.inHours == 0 && d.inMinutes == 0) return '0m';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}
