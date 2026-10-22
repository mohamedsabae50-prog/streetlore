import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:streetlore/core/services/atm_service.dart';
import 'package:streetlore/core/services/governorate_service.dart';
import 'package:streetlore/data/mock_data.dart';
import 'package:streetlore/data/models/egypt_governorate.dart';
import 'package:streetlore/data/models/map_seed.dart';
import 'package:streetlore/presentation/widgets/alexandria_shoreline.dart';

const _mediterraneanShoreline = <LatLng>[
  LatLng(31.135, 29.65),
  LatLng(31.150, 29.70),
  LatLng(31.170, 29.77),
  LatLng(31.185, 29.82),
  LatLng(31.195, 29.86),
  LatLng(31.214, 29.8856),
  LatLng(31.205, 29.888),
  LatLng(31.2025, 29.8975),
  LatLng(31.2025, 29.906),
  LatLng(31.208, 29.9095),
  LatLng(31.213, 29.9212),
  LatLng(31.228, 29.9435),
  LatLng(31.2355, 29.9535),
  LatLng(31.245, 29.966),
  LatLng(31.258, 29.9875),
  LatLng(31.273, 30.0065),
  LatLng(31.290, 30.016),
  LatLng(31.305, 30.08),
  LatLng(31.320, 30.15),
];

void main() {
  test(
    'all Alexandria places, hotels, and ATMs are inland and inside the boundary',
    () {
      final alexandria = EgyptGovernorate.byId['alexandria']!;
      final qaitbay = fallbackPlaces.singleWhere(
        (place) => place.id == 'fallback_qaitbay',
      );
      final greekClub = curatedAlexandriaPlaces.singleWhere(
        (place) => place.id == 'alex_white_blue_greek_club',
      );
      expect((qaitbay.lat, qaitbay.lng), (31.2140, 29.8856));
      expect((greekClub.lat, greekClub.lng), (31.2112, 29.8852));
      final locations = <({String id, double lat, double lng})>[
        for (final place in fallbackPlaces)
          (id: place.id, lat: place.lat, lng: place.lng),
        for (final place in getSeedAlexandriaPlaces())
          (id: place.id, lat: place.lat, lng: place.lng),
        for (final hotel in getSeedHotels())
          (id: hotel.id, lat: hotel.lat, lng: hotel.lng),
        for (final atm in AtmService.curatedAlexandriaAtms)
          (id: atm.id, lat: atm.lat, lng: atm.lng),
      ];
      final violations = <String>[];

      for (final location in locations) {
        final inAlexandria = GovernorateService.containsCoordinates(
          alexandria,
          location.lat,
          location.lng,
        );
        if (!inAlexandria) violations.add('${location.id} outside Alexandria');

        if (location.id == 'fallback_qaitbay' ||
            location.id == 'alex_white_blue_greek_club') {
          continue;
        }

        final coastLatitude = _shorelineLatitude(location.lng);
        if (location.lat >= coastLatitude - 30 / 111320) {
          violations.add(
            '${location.id} is not 30 m inland '
            '(lat ${location.lat}, coastline $coastLatitude)',
          );
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    },
  );

  test('waveY oscillates around the baseline within the amplitude', () {
    for (var x = 0.0; x <= 400; x += 7) {
      final y = ShorelinePainter.waveY(
        x: x,
        width: 400,
        baseline: 80,
        amplitude: 6,
        wavelengths: 2,
        phase: 1.3,
      );
      expect(y, inInclusiveRange(74, 86));
    }
  });

  test('repaints only when the animation progresses', () {
    final a = ShorelinePainter(progress: 0.2);
    expect(a.shouldRepaint(ShorelinePainter(progress: 0.2)), isFalse);
    expect(a.shouldRepaint(ShorelinePainter(progress: 0.3)), isTrue);
  });

  testWidgets('animates and paints without errors', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AlexandriaShoreline())),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(AlexandriaShoreline), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stays still when the platform asks to reduce motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: Scaffold(body: AlexandriaShoreline())),
      ),
    );
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}

double _shorelineLatitude(double longitude) {
  for (var index = 0; index < _mediterraneanShoreline.length - 1; index++) {
    final start = _mediterraneanShoreline[index];
    final end = _mediterraneanShoreline[index + 1];
    if (longitude >= start.longitude && longitude <= end.longitude) {
      final ratio =
          (longitude - start.longitude) / (end.longitude - start.longitude);
      return start.latitude + (end.latitude - start.latitude) * ratio;
    }
  }
  throw RangeError('Longitude $longitude is outside the shoreline polyline');
}
