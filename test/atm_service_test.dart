import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:streetlore/core/services/atm_service.dart';

void main() {
  test('the instant Alexandria ATM seed contains 27 land locations', () {
    expect(AtmService.alexandriaAtms, hasLength(27));
    expect(AtmService.curatedAlexandriaAtms, hasLength(27));

    for (final atm in AtmService.curatedAlexandriaAtms) {
      expect(
        AtmService.isOnAlexandriaLand(atm.lat, atm.lng),
        isTrue,
        reason: '${atm.id} must be inside the Alexandria land boundary',
      );
    }
  });

  test('the land boundary rejects offshore and out-of-city coordinates', () {
    expect(AtmService.isOnAlexandriaLand(31.30, 29.95), isFalse);
    expect(AtmService.isOnAlexandriaLand(31.20, 29.70), isFalse);
    expect(AtmService.isOnAlexandriaLand(30.95, 29.95), isFalse);
    expect(AtmService.isOnAlexandriaLand(double.nan, 29.95), isFalse);
  });

  test('Overpass HTTP failures return all curated terrestrial ATMs', () async {
    final client = MockClient(
      (_) async => http.Response('Gateway Timeout', 504),
    );
    addTearDown(client.close);

    final atms = await AtmService.fetchNearby(
      latitude: 31.2,
      longitude: 29.9,
      client: client,
    );

    expect(atms.length, greaterThanOrEqualTo(27));
    expect(atms.take(27).map((atm) => atm.id), [
      for (final atm in AtmService.curatedAlexandriaAtms) atm.id,
    ]);
  });

  test(
    'invalid search coordinates still return the curated fallback',
    () async {
      final atms = await AtmService.fetchNearby(
        latitude: double.nan,
        longitude: 29.9,
      );

      expect(atms, hasLength(27));
    },
  );
}
