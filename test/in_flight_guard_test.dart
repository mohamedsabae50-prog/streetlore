import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/logic/in_flight_guard.dart';

void main() {
  group('InFlightGuard', () {
    test('a second tap while the first is running does not run again', () async {
      final guard = InFlightGuard();
      final gate = Completer<void>();
      var runs = 0;

      // Two taps in the same frame, before the first action has finished.
      final first = guard.run(() async {
        runs++;
        await gate.future; // e.g. a 20 s GPS fix
      });
      final second = guard.run(() async => runs++);

      expect(guard.isBusy, isTrue);
      expect(await second, isFalse);
      expect(runs, 1);

      gate.complete();
      expect(await first, isTrue);
      expect(runs, 1);
      expect(guard.isBusy, isFalse);
    });

    test('is busy synchronously, before the action first yields', () {
      final guard = InFlightGuard();
      final gate = Completer<void>();
      guard.run(() => gate.future);
      expect(guard.isBusy, isTrue);
      gate.complete();
    });

    test('can run again once the previous action finished', () async {
      final guard = InFlightGuard();
      var runs = 0;
      await guard.run(() async => runs++);
      await guard.run(() async => runs++);
      expect(runs, 2);
    });

    test('is released after an early return', () async {
      final guard = InFlightGuard();
      var runs = 0;
      Future<void> action() async {
        runs++;
        if (runs == 1) return; // like the "too far" / "sign in" exits
        runs += 10;
      }

      await guard.run(action);
      expect(guard.isBusy, isFalse);
      await guard.run(action);
      expect(runs, 12);
    });

    test('is released and the error propagates when the action throws',
        () async {
      final guard = InFlightGuard();
      await expectLater(
        guard.run(() async => throw StateError('gps failed')),
        throwsStateError,
      );
      expect(guard.isBusy, isFalse);
      expect(await guard.run(() async {}), isTrue);
    });

    test('notifies on start and finish so the UI can show a spinner', () async {
      final states = <bool>[];
      late final InFlightGuard guard;
      guard = InFlightGuard(onChange: () => states.add(guard.isBusy));
      await guard.run(() async {});
      expect(states, [true, false]);
    });

    test('does not notify for a rejected tap', () async {
      final states = <bool>[];
      late final InFlightGuard guard;
      guard = InFlightGuard(onChange: () => states.add(guard.isBusy));
      final gate = Completer<void>();
      final first = guard.run(() => gate.future);
      await guard.run(() async {});
      expect(states, [true]);
      gate.complete();
      await first;
      expect(states, [true, false]);
    });
  });
}
