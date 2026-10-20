import 'package:flutter_test/flutter_test.dart';
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
}
