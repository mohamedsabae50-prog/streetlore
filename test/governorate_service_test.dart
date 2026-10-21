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
    'defines all 27 governorates with unique IDs and valid bilingual data',
    () {
      final governorates = GovernorateService.governorates;
      expect(governorates, hasLength(27));
      expect(
        governorates.map((governorate) => governorate.id).toSet(),
        hasLength(27),
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
        LatLng(31.470, 29.420),
        LatLng(31.485, 29.620),
        LatLng(31.485, 29.850),
        LatLng(31.465, 30.080),
        LatLng(31.425, 30.145),
        LatLng(31.350, 30.165),
        LatLng(31.280, 30.155),
        LatLng(31.210, 30.140),
        LatLng(31.150, 30.120),
        LatLng(31.100, 30.090),
        LatLng(30.980, 29.990),
        LatLng(30.880, 29.840),
        LatLng(30.800, 29.680),
        LatLng(30.735, 29.520),
        LatLng(30.755, 29.435),
        LatLng(30.870, 29.400),
        LatLng(31.000, 29.415),
        LatLng(31.150, 29.455),
        LatLng(31.300, 29.450),
        LatLng(31.410, 29.425),
      ]);
      expect(
        _selfIntersectingEdges(alexandria.boundaryPolygon),
        isNull,
        reason: 'Alexandria boundary must not self-intersect',
      );
      for (final governorate in EgyptGovernorate.all.where(
        (item) => item.id != 'alexandria',
      )) {
        expect(
          GovernorateService.containsCoordinates(
            governorate,
            alexandria.centerLat,
            alexandria.centerLng,
          ),
          isFalse,
          reason: 'Alexandria must not lie inside ${governorate.id}',
        );
        expect(
          GovernorateService.containsCoordinates(
            alexandria,
            governorate.centerLat,
            governorate.centerLng,
          ),
          isFalse,
          reason: '${governorate.id} center must be outside Alexandria',
        );
        for (final point in governorate.boundaryPolygon) {
          expect(
            _strictlyContains(alexandria.boundaryPolygon, point),
            isFalse,
            reason:
                '${governorate.id} boundary point '
                '${point.latitude},${point.longitude} must not lie inside '
                'Alexandria',
          );
        }
        final crossing = _polygonCrossingEdges(
          alexandria.boundaryPolygon,
          governorate.boundaryPolygon,
        );
        expect(
          crossing,
          isNull,
          reason:
              '${governorate.id} boundary must not intersect Alexandria: '
              '$crossing',
        );
      }
    },
  );

  test('Beheira coordinates are outside Alexandria', () {
    final alexandria = EgyptGovernorate.byId['alexandria']!;
    for (final point in const [(31.133, 30.130), (31.0409, 30.4700)]) {
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
    'all Alexandria mock places and terrestrial ATMs resolve to Alexandria',
    () {
      void expectComfortablyInside(String id, double lat, double lng) {
        final boundary = EgyptGovernorate.byId['alexandria']!.boundaryPolygon;
        expect(
          GovernorateService.containsCoordinates(
            EgyptGovernorate.byId['alexandria']!,
            lat,
            lng,
          ),
          isTrue,
          reason: '$id must be geometrically inside Alexandria',
        );
        expect(
          _distanceToPolygonEdges(boundary, LatLng(lat, lng)),
          greaterThan(0.01),
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
        'giza': (30.0131, 31.2089),
        'matrouh': (31.3543, 27.2373),
        'luxor': (25.6872, 32.6396),
        'aswan': (24.0889, 32.8998),
      };

      for (final entry in cases.entries) {
        final (lat, lng) = entry.value;
        expect(
          GovernorateService.detectFromCoordinates(lat, lng).id,
          entry.key,
        );
        await provider.syncWithCoordinates(
          lat,
          lng,
          availableGovernorateIds: const {'alexandria'},
        );
        expect(provider.detectedGovernorate, entry.key);
        expect(provider.activeGovernorate, 'alexandria');
        expect(provider.unlockedGovernorateIds, {'alexandria'});
        expect(
          provider.takeNoticeMessage('en'),
          contains(EgyptGovernorate.byId[entry.key]!.nameEn),
        );
      }
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

bool _strictlyContains(List<LatLng> polygon, LatLng point) {
  if (polygon.contains(point)) return false;
  if (!GovernorateService.containsCoordinates(
    EgyptGovernorate.byId['alexandria']!,
    point.latitude,
    point.longitude,
  )) {
    return false;
  }
  for (var index = 0; index < polygon.length; index++) {
    final start = polygon[index];
    final end = polygon[(index + 1) % polygon.length];
    final cross =
        (point.longitude - start.longitude) * (end.latitude - start.latitude) -
        (point.latitude - start.latitude) * (end.longitude - start.longitude);
    final withinBounds =
        point.latitude >= start.latitude &&
            point.latitude <= end.latitude &&
            point.longitude >= start.longitude &&
            point.longitude <= end.longitude ||
        point.latitude >= end.latitude &&
            point.latitude <= start.latitude &&
            point.longitude >= end.longitude &&
            point.longitude <= start.longitude;
    if (cross.abs() < 1e-9 && withinBounds) return false;
  }
  return true;
}

String? _polygonCrossingEdges(List<LatLng> first, List<LatLng> second) {
  double orientation(LatLng a, LatLng b, LatLng c) =>
      (b.longitude - a.longitude) * (c.latitude - a.latitude) -
      (b.latitude - a.latitude) * (c.longitude - a.longitude);

  for (var firstIndex = 0; firstIndex < first.length; firstIndex++) {
    final a = first[firstIndex];
    final b = first[(firstIndex + 1) % first.length];
    for (var secondIndex = 0; secondIndex < second.length; secondIndex++) {
      final c = second[secondIndex];
      final d = second[(secondIndex + 1) % second.length];
      final firstC = orientation(a, b, c);
      final firstD = orientation(a, b, d);
      final secondA = orientation(c, d, a);
      final secondB = orientation(c, d, b);
      if (firstC * firstD < 0 && secondA * secondB < 0) {
        return 'Alexandria $firstIndex/$a -> $b; '
            'neighbor $secondIndex/$c -> $d';
      }
    }
  }
  return null;
}
