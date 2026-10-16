import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/core/services/prayer_times_service.dart';

void main() {
  // Alexandria (31.2001, 29.9187), 2026-10-16. Solar noon is 12:00 UTC minus
  // 29.9187/15 h (longitude) minus ~14.4 min (equation of time) = ~09:46 UTC.
  // All assertions go through .toUtc() so they hold in any machine timezone.
  final times = PrayerTimesService.instance.computeFallback(
    now: DateTime(2026, 10, 16, 8, 30),
  );

  int minutesOfDayUtc(DateTime t) => t.toUtc().hour * 60 + t.toUtc().minute;

  group('PrayerTimesService local fallback', () {
    test('Dhuhr is solar noon in UTC, not shifted by the local offset', () {
      final dhuhr = times.dhuhr.toUtc();
      expect(dhuhr.year, 2026);
      expect(dhuhr.month, 10);
      expect(dhuhr.day, 16);
      const expected = 9 * 60 + 46;
      expect(
        (minutesOfDayUtc(times.dhuhr) - expected).abs(),
        lessThanOrEqualTo(3),
        reason: 'Dhuhr was ${dhuhr.toIso8601String()}',
      );
    });

    test('prayers are in chronological order', () {
      final order = [
        times.fajr,
        times.sunrise,
        times.dhuhr,
        times.asr,
        times.maghrib,
        times.isha,
      ];
      for (var i = 1; i < order.length; i++) {
        expect(order[i].isAfter(order[i - 1]), isTrue, reason: 'index $i');
      }
    });

    test('Fajr uses 19.5 degrees: ~88 min before sunrise in mid-October', () {
      final gap = times.sunrise.difference(times.fajr).inMinutes;
      expect(gap, inInclusiveRange(84, 92));
    });

    test('Isha uses 17.5 degrees: ~78 min after Maghrib in mid-October', () {
      final gap = times.isha.difference(times.maghrib).inMinutes;
      expect(gap, inInclusiveRange(74, 82));
    });

    test('Maghrib is about 5h41m after solar noon (UTC)', () {
      final gap = times.maghrib.difference(times.dhuhr).inMinutes;
      expect(gap, inInclusiveRange(337, 346));
    });

    test('result does not depend on the hour of the day it is asked', () {
      final late = PrayerTimesService.instance.computeFallback(
        now: DateTime(2026, 10, 16, 23, 45),
      );
      expect(late.dhuhr, times.dhuhr);
      expect(late.fajr, times.fajr);
      expect(late.isha, times.isha);
    });

    test('Dhuhr stays on the right day, near 09:50 UTC, all year round', () {
      // Regression: the equation of time was ~24 h off for roughly half the
      // year, which moved Dhuhr to the previous day.
      for (var day = 0; day < 365; day++) {
        final date = DateTime(2026, 1, 1).add(Duration(days: day, hours: 12));
        final t = PrayerTimesService.instance.computeFallback(now: date);
        final utc = t.dhuhr.toUtc();
        final label = '${date.year}-${date.month}-${date.day}';
        expect(
          [utc.year, utc.month, utc.day],
          [date.year, date.month, date.day],
          reason: 'Dhuhr date for $label was $utc',
        );
        final m = minutesOfDayUtc(t.dhuhr);
        expect(m, inInclusiveRange(9 * 60 + 35, 10 * 60 + 25), reason: label);
        expect(t.isha.isAfter(t.maghrib), isTrue, reason: label);
        expect(t.fajr.isBefore(t.sunrise), isTrue, reason: label);
      }
    });

    test('is labelled as the local source', () {
      expect(times.source, 'Local');
    });
  });
}
