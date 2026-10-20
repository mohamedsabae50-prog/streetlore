import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/core/services/atm_service.dart';

void main() {
  test('ATM candidates must be close to mapped street geometry', () {
    final roads = [
      [
        {'lat': 31.2, 'lon': 29.899},
        {'lat': 31.2, 'lon': 29.901},
      ],
    ];

    expect(
      AtmService.isWithinStreetDistance(
        latitude: 31.2001,
        longitude: 29.9,
        roadGeometries: roads,
      ),
      isTrue,
    );
    expect(
      AtmService.isWithinStreetDistance(
        latitude: 31.205,
        longitude: 29.9,
        roadGeometries: roads,
      ),
      isFalse,
    );
    expect(
      AtmService.isWithinStreetDistance(
        latitude: 31.2,
        longitude: 29.9,
        roadGeometries: const [],
      ),
      isFalse,
    );
  });
}
