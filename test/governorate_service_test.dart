import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetlore/core/services/atm_service.dart';
import 'package:streetlore/core/services/governorate_service.dart';
import 'package:streetlore/data/mock_data.dart';
import 'package:streetlore/data/models/egypt_governorate.dart';
import 'package:streetlore/data/models/itinerary_model.dart';
import 'package:streetlore/data/models/map_seed.dart';
import 'package:streetlore/data/models/place_model.dart';
import 'package:streetlore/logic/governorate_provider.dart';

void main() {
  test(
    'defines all 26 displayed governorates with unique IDs and bilingual data',
    () {
      final governorates = GovernorateService.governorates;
      expect(governorates, hasLength(26));
      expect(
        governorates.map((governorate) => governorate.id).toSet(),
        hasLength(26),
      );

      for (final governorate in governorates) {
        expect(governorate.nameEn.trim(), isNotEmpty);
        expect(governorate.nameAr.trim(), isNotEmpty);
        expect(governorate.boundaryPolygon.length, greaterThanOrEqualTo(4));
        expect(
          governorate.boundaryPolygon.every(
            (point) =>
                point.latitude.isFinite &&
                point.longitude.isFinite &&
                point.latitude >= -90 &&
                point.latitude <= 90 &&
                point.longitude >= -180 &&
                point.longitude <= 180,
          ),
          isTrue,
          reason: '${governorate.id} polygon must contain valid coordinates',
        );
      }
      expect(EgyptGovernorate.byId, hasLength(27));
      final alexandria = EgyptGovernorate.byId['alexandria']!;
      expect(alexandria.boundaryPolygon, const [
        LatLng(31.3800, 30.1150),
        LatLng(31.2600, 30.1400),
        LatLng(31.1200, 30.0800),
        LatLng(30.9500, 29.9800),
        LatLng(30.8000, 29.8500),
        LatLng(30.7800, 29.5500),
        LatLng(30.8800, 29.3500),
        LatLng(31.0500, 29.6800),
        LatLng(31.1600, 29.8200),
        LatLng(31.2800, 29.9500),
      ]);
      expect(EgyptGovernorate.byId['cairo']!.boundaryPolygon, const [
        LatLng(30.2600, 30.7500),
        LatLng(30.2800, 31.1500),
        LatLng(30.2800, 31.5200),
        LatLng(30.2200, 31.8800),
        LatLng(29.9200, 31.8800),
        LatLng(29.6000, 31.5000),
        LatLng(29.5500, 31.1800),
        LatLng(29.7800, 30.8200),
        LatLng(30.0200, 30.7200),
      ]);
      expect(EgyptGovernorate.byId['luxor']!.boundaryPolygon, const [
        LatLng(25.9000, 32.3000),
        LatLng(25.9000, 33.1500),
        LatLng(25.2000, 33.2500),
        LatLng(24.5000, 33.4500),
        LatLng(23.8000, 33.5500),
        LatLng(22.1500, 32.1000),
        LatLng(22.1500, 31.3500),
        LatLng(23.1000, 31.4500),
        LatLng(24.1500, 32.2500),
        LatLng(25.2500, 32.2500),
      ]);
      expect(
        _selfIntersectingEdges(alexandria.boundaryPolygon),
        isNull,
        reason: 'Alexandria boundary must not self-intersect',
      );
      for (final id in ['alexandria', 'cairo', 'luxor', 'red_sea']) {
        expect(
          _selfIntersectingEdges(EgyptGovernorate.byId[id]!.boundaryPolygon),
          isNull,
          reason: '$id boundary must not self-intersect',
        );
      }
      final redSea = EgyptGovernorate.byId['red_sea']!;
      expect(redSea.nameEn, 'Hurghada & Marsa Alam');
      expect(redSea.nameAr, 'الغردقة ومرسى علم');
      expect((redSea.centerLat, redSea.centerLng), (26.8500, 33.9500));
      expect(redSea.defaultZoom, 8.8);
      expect(
        GovernorateService.containsCoordinates(
          redSea,
          redSea.centerLat,
          redSea.centerLng,
        ),
        isTrue,
      );
      expect(EgyptGovernorate.normalizeId('Hurghada'), 'red_sea');
      expect(EgyptGovernorate.normalizeId('marsa_alam'), 'red_sea');
      for (final (lat, lng) in const [
        (30.8411, 29.6633),
        (31.1535, 29.8442),
        (30.9985, 29.7850),
      ]) {
        expect(
          GovernorateService.containsCoordinates(alexandria, lat, lng),
          isTrue,
        );
      }
    },
  );

  test('all four active catalogs fit their polygons and map image rules', () {
    final regionIds = {'alexandria', 'cairo', 'luxor', 'red_sea'};
    final imageOwners = <String, String>{};
    expect(MockData.places, hasLength(431));
    expect(
      MockData.places
          .map((place) => EgyptGovernorate.normalizeId(place.governorate))
          .toSet(),
      regionIds,
    );
    for (final place in MockData.places) {
      final governorate = EgyptGovernorate.byId[place.governorate]!;
      expect(
        place.lat.isFinite && place.lng.isFinite,
        isTrue,
        reason: place.id,
      );
      expect(place.lat, inInclusiveRange(-90, 90), reason: place.id);
      expect(place.lng, inInclusiveRange(-180, 180), reason: place.id);
      expect(
        GovernorateService.containsCoordinates(
          governorate,
          place.lat,
          place.lng,
        ),
        isTrue,
        reason: '${place.id} must lie in ${governorate.id}',
      );
      for (final url in place.officialImages) {
        final uri = Uri.parse(url);
        expect(uri.scheme, 'https', reason: place.id);
        expect(uri.host, 'upload.wikimedia.org', reason: place.id);
        expect(
          imageOwners.putIfAbsent(url, () => place.id),
          place.id,
          reason: '$url must be unique',
        );
      }
    }
    expect(MockData.places.where((place) => place.isVisitable), hasLength(393));
    expect(MockData.places.where((place) => place.isAtm), hasLength(38));
  });

  test('Beheira coordinates are outside Alexandria', () {
    final alexandria = EgyptGovernorate.byId['alexandria']!;
    for (final point in const [(31.133, 30.300), (31.0409, 30.4700)]) {
      expect(
        GovernorateService.containsCoordinates(alexandria, point.$1, point.$2),
        isFalse,
      );
      expect(
        GovernorateService.detectFromCoordinates(point.$1, point.$2).id,
        isNot('alexandria'),
      );
    }
  });

  test(
    'Cairo boundary keeps the core city inside and external points outside',
    () {
      final cairo = EgyptGovernorate.byId['cairo']!;
      final checks = <({double lat, double lng, bool expected})>[
        (lat: 30.0444, lng: 31.2357, expected: true),
        (lat: 30.0287, lng: 31.2599, expected: true),
        (lat: 30.0459, lng: 31.2243, expected: true),
        (lat: 30.1030, lng: 31.3650, expected: true),
        (lat: 29.9792, lng: 31.1342, expected: true),
        (lat: 30.4660, lng: 31.1840, expected: false),
        (lat: 31.2140, lng: 29.8856, expected: false),
      ];

      for (final check in checks) {
        expect(
          GovernorateService.containsCoordinates(cairo, check.lat, check.lng),
          check.expected,
          reason:
              '(${check.lat}, ${check.lng}) should resolve to ${check.expected}',
        );
      }
    },
  );

  test(
    'all Alexandria mock places and terrestrial ATMs resolve to Alexandria',
    () {
      void expectComfortablyInside(String id, double lat, double lng) {
        final boundary = EgyptGovernorate.byId['alexandria']!.boundaryPolygon;
        final isInside = GovernorateService.containsCoordinates(
          EgyptGovernorate.byId['alexandria']!,
          lat,
          lng,
        );
        expect(isInside, isTrue, reason: '$id must lie inside Alexandria');
        expect(
          _distanceToPolygonEdges(boundary, LatLng(lat, lng)),
          greaterThan(0.003),
          reason: '$id must have a comfortable boundary buffer',
        );
        expect(
          GovernorateService.detectFromCoordinates(lat, lng).id,
          'alexandria',
          reason: '$id should resolve to Alexandria',
        );
      }

      for (final place in fallbackPlaces) {
        expectComfortablyInside(place.id, place.lat, place.lng);
      }
      for (final hotel in getSeedHotelPlaces()) {
        expectComfortablyInside(hotel.id, hotel.lat, hotel.lng);
      }
      for (final hotel in getSeedHotels()) {
        expectComfortablyInside(hotel.id, hotel.lat, hotel.lng);
      }
      expect(AtmService.curatedAlexandriaAtms, hasLength(27));
      expect(AtmService.alexandriaAtms, hasLength(27));
      for (final atm in AtmService.curatedAlexandriaAtms) {
        expectComfortablyInside(atm.id, atm.lat, atm.lng);
      }
    },
  );

  test(
    'curated dining, cafes, and shopping seeds are complete and on land',
    () {
      final alexandria = EgyptGovernorate.byId['alexandria']!;
      expect(curatedAlexandriaPlaces, hasLength(27));
      for (final place in curatedAlexandriaPlaces) {
        expect(
          GovernorateService.containsCoordinates(
            alexandria,
            place.lat,
            place.lng,
          ),
          isTrue,
          reason: '${place.id} must be within Alexandria',
        );
        expect(
          place.lat,
          lessThan(31.28),
          reason: '${place.id} must be south of the Mediterranean coast',
        );
        expect(
          place.nameAr,
          isNotEmpty,
          reason: '${place.id} needs Arabic name',
        );
        expect(
          place.descriptionAr,
          isNotEmpty,
          reason: '${place.id} needs Arabic description',
        );
        expect(place.descriptionEn, isNotEmpty);
        expect(place.rating, inInclusiveRange(4.4, 4.9));
        expect(
          place.imageUrl,
          startsWith('https://upload.wikimedia.org/'),
          reason: '${place.id} must have a Wikimedia Commons photo',
        );
        expect(place.governorate, 'alexandria');
      }
    },
  );

  test('legacy and empty governorate values default to Alexandria', () {
    final legacyPlace = PlaceModel.fromJson({
      'id': 'legacy',
      'name': 'Legacy place',
      'description': '',
      'image_url': '',
      'lat': 31.2,
      'lng': 29.9,
    });
    final emptyPlace = PlaceModel.fromJson({
      'id': 'empty',
      'governorate': ' ',
      'lat': 31.2,
      'lng': 29.9,
    });
    final legacyTour = ItineraryModel.fromJson({'id': 'legacy-tour'});
    final emptyTour = ItineraryModel.fromJson({
      'id': 'empty-tour',
      'governorate': '',
    });

    expect(legacyPlace.governorate, 'alexandria');
    expect(emptyPlace.governorate, 'alexandria');
    expect(legacyTour.governorate, 'alexandria');
    expect(emptyTour.governorate, 'alexandria');
    expect(legacyPlace.toJson()['governorate'], 'alexandria');
    expect(legacyTour.toJson()['governorate'], 'alexandria');
  });

  test(
    'known governorate centers resolve and unavailable areas fall back',
    () async {
      SharedPreferences.setMockInitialValues({});
      final provider = GovernorateProvider();
      addTearDown(provider.dispose);
      await Future<void>.delayed(Duration.zero);

      const cases = {
        'cairo': (30.0444, 31.2357),
        'matrouh': (31.3543, 27.2373),
        'luxor': (25.6872, 32.6396),
        'aswan': (24.0889, 32.8998),
        'red_sea': (26.8500, 33.9500),
      };

      for (final entry in cases.entries) {
        final (lat, lng) = entry.value;
        final expectedId = entry.key == 'aswan' ? 'luxor' : entry.key;
        expect(
          GovernorateService.detectFromCoordinates(lat, lng).id,
          expectedId,
        );
        final availableGovernorateIds = entry.key == 'red_sea'
            ? const {'alexandria', 'red_sea'}
            : const {'alexandria'};
        await provider.syncWithCoordinates(
          lat,
          lng,
          availableGovernorateIds: availableGovernorateIds,
        );
        expect(provider.detectedGovernorate, expectedId);
        if (entry.key == 'red_sea') {
          expect(provider.activeGovernorate, 'red_sea');
          expect(provider.unlockedGovernorateIds, {'alexandria', 'red_sea'});
        } else {
          expect(provider.activeGovernorate, 'alexandria');
          expect(provider.unlockedGovernorateIds, {'alexandria'});
        }
        final notice = provider.takeNoticeMessage('en');
        if (entry.key == 'aswan' || entry.key == 'red_sea') {
          expect(notice, isNull);
        } else {
          expect(notice, contains(EgyptGovernorate.byId[expectedId]!.nameEn));
        }
      }
    },
  );

  test(
    'legacy Giza identifiers normalize to the unified Cairo region',
    () async {
      SharedPreferences.setMockInitialValues({});
      final provider = GovernorateProvider();
      addTearDown(provider.dispose);

      expect(EgyptGovernorate.normalizeId(' GIZA '), 'cairo');
      expect(EgyptGovernorate.byId['giza']!.id, 'cairo');
      expect(
        PlaceModel.fromJson({
          'id': 'legacy-giza-place',
          'governorate': 'giza',
        }).governorate,
        'cairo',
      );
      expect(
        ItineraryModel.fromJson({
          'id': 'legacy-giza-tour',
          'governorate': 'giza',
        }).governorate,
        'cairo',
      );
      expect(provider.unlockAndSelectGovernorate('giza'), isTrue);
      expect(provider.activeGovernorate, 'cairo');
    },
  );

  test(
    'nearby unavailable governorates select the closest active region in Egypt',
    () async {
      SharedPreferences.setMockInitialValues({});
      final provider = GovernorateProvider();
      addTearDown(provider.dispose);

      await provider.syncWithCoordinates(
        30.4660,
        31.1840,
        availableGovernorateIds: const {'alexandria', 'cairo', 'luxor'},
      );

      expect(provider.detectedGovernorate, 'qalyubia');
      expect(provider.activeGovernorate, 'cairo');
      expect(provider.unlockedGovernorateIds, contains('cairo'));
    },
  );

  test(
    'western Alexandria GPS selects its nearest active governorate',
    () async {
      SharedPreferences.setMockInitialValues({});
      final provider = GovernorateProvider();
      addTearDown(provider.dispose);

      await provider.syncWithCoordinates(
        30.9461,
        29.5186,
        availableGovernorateIds: const {'alexandria', 'cairo', 'luxor'},
      );

      expect(provider.activeGovernorate, 'alexandria');
    },
  );
}

double _distanceToPolygonEdges(List<LatLng> polygon, LatLng point) {
  var minimumDistance = double.infinity;
  for (var index = 0; index < polygon.length; index++) {
    final start = polygon[index];
    final end = polygon[(index + 1) % polygon.length];
    final dx = end.longitude - start.longitude;
    final dy = end.latitude - start.latitude;
    final denominator = dx * dx + dy * dy;
    final t = denominator == 0
        ? 0.0
        : (((point.longitude - start.longitude) * dx +
                      (point.latitude - start.latitude) * dy) /
                  denominator)
              .clamp(0.0, 1.0);
    final nearestLongitude = start.longitude + t * dx;
    final nearestLatitude = start.latitude + t * dy;
    final distance = math.sqrt(
      math.pow(point.longitude - nearestLongitude, 2) +
          math.pow(point.latitude - nearestLatitude, 2),
    );
    minimumDistance = math.min(minimumDistance, distance);
  }
  return minimumDistance;
}

String? _selfIntersectingEdges(List<LatLng> polygon) {
  double orientation(LatLng p, LatLng q, LatLng r) =>
      (q.longitude - p.longitude) * (r.latitude - p.latitude) -
      (q.latitude - p.latitude) * (r.longitude - p.longitude);

  for (var first = 0; first < polygon.length; first++) {
    final firstEnd = (first + 1) % polygon.length;
    for (var second = first + 1; second < polygon.length; second++) {
      final secondEnd = (second + 1) % polygon.length;
      if (firstEnd == second || secondEnd == first) continue;
      final a = orientation(polygon[first], polygon[firstEnd], polygon[second]);
      final b = orientation(
        polygon[first],
        polygon[firstEnd],
        polygon[secondEnd],
      );
      final c = orientation(
        polygon[second],
        polygon[secondEnd],
        polygon[first],
      );
      final d = orientation(
        polygon[second],
        polygon[secondEnd],
        polygon[firstEnd],
      );
      if (a * b < 0 && c * d < 0) {
        return '$first-$firstEnd intersects $second-$secondEnd';
      }
    }
  }
  return null;
}
