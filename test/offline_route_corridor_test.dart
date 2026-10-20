import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:streetlore/core/services/offline_storage_service.dart';

void main() {
  test('offline Alexandria route follows a multi-point road corridor', () {
    final route = OfflineStorageService.instance.buildOfflineRoadCorridor(
      const LatLng(31.2050, 29.8800),
      const [LatLng(31.2050, 29.9750)],
    );

    expect(route.length, greaterThan(2));
    expect(route.first, const LatLng(31.2050, 29.8800));
    expect(route.last, const LatLng(31.2050, 29.9750));
    expect(route.every((point) => point.latitude > 31.18), isTrue);
  });
}
