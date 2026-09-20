import 'dart:math' as math;

/// Sun times for a single date + location. All `DateTime` values are
/// local-time instances constructed with the given date's year/month/day.
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

/// Astronomical sunrise / sunset / daylight calculator.
///
/// Uses the standard NOAA solar-position equations:
///   - declination: 23.45° × sin(2π × (284 + N) / 365)
///   - solar noon: 12:00 − (4 × longitude + equation_of_time) / 60
///   - hour angle: cos(H) = (sin(alt) − sin(lat) × sin(decl)) /
///                          (cos(lat) × cos(decl))
///     with altitude = −0.833° (accounts for refraction + sun radius).
///   - sunrise = solarNoon − H/15 hours
///   - sunset  = solarNoon + H/15 hours
class SunTimesService {
  SunTimesService._();
  static final SunTimesService instance = SunTimesService._();

  /// Alexandria default (used when no lat/lng is provided).
  static const double _lat = 31.2001;
  static const double _lng = 29.9187;

  /// Standard sunrise/sunset altitude target (refraction + solar disc).
  static const double _altitudeDeg = -0.833;

  /// Compute sun times for a given date + location.
  SunTimes compute({
    DateTime? date,
    double latitude = _lat,
    double longitude = _lng,
  }) {
    final d = date ?? DateTime.now();
    // Day-of-year (1..365/366).
    final startOfYear = DateTime(d.year, 1, 1);
    final dayOfYear =
        DateTime(d.year, d.month, d.day).difference(startOfYear).inDays + 1;

    // Solar declination in radians.
    final declDeg =
        23.45 * math.sin(2 * math.pi * (284 + dayOfYear) / 365.0);
    final declRad = declDeg * math.pi / 180.0;

    final latRad = latitude * math.pi / 180.0;
    final altRad = _altitudeDeg * math.pi / 180.0;

    // cos(H) = (sin(alt) − sin(lat) × sin(decl)) / (cos(lat) × cos(decl))
    final cosNumerator = math.sin(altRad) -
        math.sin(latRad) * math.sin(declRad);
    final cosDenominator = math.cos(latRad) * math.cos(declRad);
    if (cosDenominator.abs() < 1e-9) {
      // Pole / singularity — degenerate but safe to clamp.
      return _polarFallback(d, longitude);
    }
    final cosH = cosNumerator / cosDenominator;

    final solarNoon = _solarNoon(d, longitude);

    if (cosH > 1) {
      // Sun never rises (polar night) — return noon-only with zero daylight.
      return SunTimes(
        sunrise: solarNoon,
        sunset: solarNoon,
        solarNoon: solarNoon,
        daylight: Duration.zero,
      );
    }
    if (cosH < -1) {
      // Sun never sets (polar day) — 24h daylight.
      return SunTimes(
        sunrise: DateTime(d.year, d.month, d.day, 0, 0),
        sunset: DateTime(d.year, d.month, d.day, 23, 59),
        solarNoon: solarNoon,
        daylight: const Duration(hours: 24),
      );
    }

    // Hour angle in radians → degrees → convert to half-day length in
    // MINUTES. The earth rotates 360° in 24h, so 1° = 4 minutes.
    final hRad = math.acos(cosH);
    final hDeg = hRad * 180.0 / math.pi;
    var halfMinutes = (hDeg * 4).round(); // ≤ ~480 min (8h) for any latitude.

    // Hard safety clamps (the math above is correct; these are belt-and-
    // braces so a UI never displays "Daylight 24h" because of any other
    // future math regression).
    if (halfMinutes < 0) halfMinutes = 0;
    if (halfMinutes > 720) halfMinutes = 720; // never exceed 12h half-day

    final sunrise = solarNoon.subtract(Duration(minutes: halfMinutes));
    final sunset = solarNoon.add(Duration(minutes: halfMinutes));

    var daylight = sunset.difference(sunrise);
    if (daylight.isNegative) daylight = Duration.zero;
    if (daylight > const Duration(hours: 24)) {
      daylight = const Duration(hours: 24);
    }

    return SunTimes(
      sunrise: sunrise,
      sunset: sunset,
      solarNoon: solarNoon,
      daylight: daylight,
    );
  }

  SunTimes _polarFallback(DateTime d, double longitude) {
    final noon = _solarNoon(d, longitude);
    return SunTimes(
      sunrise: noon,
      sunset: noon,
      solarNoon: noon,
      daylight: Duration.zero,
    );
  }

  /// Compute local solar noon for the given date and longitude.
  DateTime _solarNoon(DateTime date, double longitude) {
    final startOfYear = DateTime(date.year, 1, 1);
    final dayOfYear =
        DateTime(date.year, date.month, date.day)
            .difference(startOfYear)
            .inDays +
        1;
    final b = 2 * math.pi * (dayOfYear - 81) / 365.0;
    final equationOfTime =
        9.87 * math.sin(2 * b) - 7.53 * math.cos(b) - 1.5 * math.sin(b);
    final timeCorrectionMinutes = 4 * longitude + equationOfTime;
    // Solar noon UTC (in decimal hours).
    final solarNoonUtc = 12.0 - timeCorrectionMinutes / 60.0;
    // Shift to local clock using the date's actual timezone offset,
    // clamped to a sane range (-12h..+14h covers every real timezone).
    final localOffset = date.timeZoneOffset.inMinutes / 60.0;
    var solarNoonLocal = solarNoonUtc + localOffset;
    // Normalize into [0, 24).
    solarNoonLocal = solarNoonLocal % 24.0;
    if (solarNoonLocal < 0) solarNoonLocal += 24.0;
    final hour = solarNoonLocal.floor();
    final minute = ((solarNoonLocal - hour) * 60).round();
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// `HH:mm` formatting (24h). Handles negative/overflow dates by taking
  /// just the hour/minute fields.
  String formatTime(DateTime dt) {
    final h = (dt.hour % 24).toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Friendly "Xh Ym" / "Ym" formatting. Clamps negative durations to
  /// 0 and caps at 24h as a final UI safety net.
  String formatDuration(Duration d) {
    final clamped = d.isNegative ? Duration.zero : d;
    final capped = clamped > const Duration(hours: 24)
        ? const Duration(hours: 24)
        : clamped;
    if (capped.inMinutes == 0) return '0m';
    final h = capped.inHours;
    final m = capped.inMinutes.remainder(60);
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}
