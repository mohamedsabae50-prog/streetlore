import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/core/services/realtime_resilience.dart';
import 'package:streetlore/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('following activity returns empty rows for gateway timeout', () async {
    final rows = await SupabaseService.runFollowingActivitySafely(
      () => Future.error(
        const PostgrestException(
          message: 'Gateway Timeout',
          code: '504',
          details: 'Gateway Timeout',
        ),
      ),
    );

    expect(rows, isEmpty);
  });

  test('following activity returns empty rows for request timeout', () async {
    final rows = await SupabaseService.runFollowingActivitySafely(
      () => Future.error(TimeoutException('request timed out')),
    );

    expect(rows, isEmpty);
  });

  test('transient realtime stream errors are swallowed and later data arrives',
      () async {
    final values = <int>[];
    final errors = <Object>[];
    final source = Stream<int>.multi((controller) {
      controller.addError(SocketException('WebSocket HTTP status code: 500'));
      controller.add(7);
      controller.close();
    });

    await swallowTransientRealtimeErrors(
      source,
      onTransientError: (error, _) => errors.add(error),
    ).forEach(values.add);

    expect(values, [7]);
    expect(errors, hasLength(1));
  });

  test('RealtimeSubscribeException and gateway drops are filtered', () {
    expect(
      isTransientNetworkError(Exception('RealtimeSubscribeException: 500')),
      isTrue,
    );
    expect(isTransientNetworkError(Exception('504 Gateway Timeout')), isTrue);
  });
}
