import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/logic/internet_status_tracker.dart';

void main() {
  late List<Duration> delays;
  late InternetStatusTracker tracker;

  InternetStatusTracker make({int failuresBeforeOffline = 2}) =>
      InternetStatusTracker(
        failuresBeforeOffline: failuresBeforeOffline,
        retryDelay: const Duration(seconds: 2),
        delay: (d) async => delays.add(d),
      );

  /// A probe that returns [results] in order and counts its calls.
  ({Future<bool> Function() probe, int Function() calls}) scripted(
    List<bool> results,
  ) {
    var i = 0;
    return (
      probe: () async => results[i++],
      calls: () => i,
    );
  }

  setUp(() {
    delays = [];
    tracker = make();
  });

  group('recordProbe', () {
    test('starts unknown, which must not block the app', () {
      expect(tracker.status, isNull);
      expect(tracker.status == false, isFalse);
    });

    test('a single failed or timed-out probe stays unknown, not offline', () {
      expect(tracker.recordProbe(reachable: false), isNull);
      expect(tracker.status, isNull);
      expect(tracker.consecutiveFailures, 1);
    });

    test('a single failure after being online keeps the app online', () {
      tracker.recordProbe(reachable: true);
      expect(tracker.recordProbe(reachable: false), isTrue);
    });

    test('two consecutive failures go offline', () {
      tracker.recordProbe(reachable: false);
      expect(tracker.recordProbe(reachable: false), isFalse);
    });

    test('failures separated by a success do not add up', () {
      tracker.recordProbe(reachable: false);
      tracker.recordProbe(reachable: true);
      expect(tracker.recordProbe(reachable: false), isTrue);
      expect(tracker.consecutiveFailures, 1);
    });

    test('a success after being offline recovers', () {
      tracker.recordNoNetwork();
      expect(tracker.recordProbe(reachable: true), isTrue);
      expect(tracker.consecutiveFailures, 0);
    });

    test('stays offline on further failures without growing unbounded', () {
      tracker.recordNoNetwork();
      for (var i = 0; i < 5; i++) {
        expect(tracker.recordProbe(reachable: false), isFalse);
      }
      expect(tracker.consecutiveFailures, 2);
    });

    test('the threshold is configurable', () {
      final t = make(failuresBeforeOffline: 3);
      expect(t.recordProbe(reachable: false), isNull);
      expect(t.recordProbe(reachable: false), isNull);
      expect(t.recordProbe(reachable: false), isFalse);
    });
  });

  group('recordNoNetwork', () {
    test('a connectivity_plus "none" result is offline immediately', () {
      expect(tracker.recordNoNetwork(), isFalse);
      expect(tracker.status, isFalse);
    });
  });

  group('check', () {
    test('probes once and goes online when reachable', () async {
      final s = scripted([true]);
      expect(await tracker.check(s.probe), isTrue);
      expect(s.calls(), 1);
      expect(delays, isEmpty);
    });

    test('one timeout then success: never offline, retried after a delay',
        () async {
      final s = scripted([false, true]);
      expect(await tracker.check(s.probe), isTrue);
      expect(s.calls(), 2);
      expect(delays, [const Duration(seconds: 2)]);
      expect(tracker.consecutiveFailures, 0);
    });

    test('two failures in a row go offline after exactly two probes',
        () async {
      final s = scripted([false, false]);
      expect(await tracker.check(s.probe), isFalse);
      expect(s.calls(), 2);
      expect(delays, [const Duration(seconds: 2)]);
    });

    test('status is still unknown while the confirming probe is pending',
        () async {
      bool? seenDuringSecondProbe = true;
      var call = 0;
      final result = await tracker.check(() async {
        call++;
        if (call == 2) seenDuringSecondProbe = tracker.status;
        return false;
      });
      expect(seenDuringSecondProbe, isNull);
      expect(result, isFalse);
    });

    test('when already offline a failed re-check does not loop', () async {
      tracker.recordNoNetwork();
      final s = scripted([false]);
      expect(await tracker.check(s.probe), isFalse);
      expect(s.calls(), 1);
      expect(delays, isEmpty);
    });

    test('an online app survives one failed refresh and one good one',
        () async {
      await tracker.check(scripted([true]).probe);
      expect(await tracker.check(scripted([false, true]).probe), isTrue);
      expect(tracker.status, isTrue);
    });
  });
}
