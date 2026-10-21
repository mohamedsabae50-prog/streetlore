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
        LatLng(31.355, 30.085),
        LatLng(31.320, 30.095),
        LatLng(31.260, 30.055),
        LatLng(31.205, 30.005),
        LatLng(31.145, 29.935),
        LatLng(31.055, 29.835),
        LatLng(30.940, 29.720),
        LatLng(30.825, 29.520),
        LatLng(30.855, 29.455),
        LatLng(31.035, 29.485),
        LatLng(31.145, 29.705),
        LatLng(31.245, 29.855),
        LatLng(31.305, 29.965),
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

  test('western Borg El Arab hotel seed lies outside the supplied outline', () {
    final hotel = getSeedHotelPlaces().singleWhere(
      (place) => place.id == 'hotel-borg-al-arab',
    );
    expect(
      GovernorateService.containsCoordinates(
        EgyptGovernorate.byId['alexandria']!,
        hotel.lat,
        hotel.lng,
      ),
      isFalse,
    );
  });

  test(
    'all Alexandria mock places and terrestrial ATMs resolve to Alexandria',
    () {
      for (final place in fallbackPlaces) {
        expect(
          GovernorateService.containsCoordinates(
            EgyptGovernorate.byId['alexandria']!,
            place.lat,
            place.lng,
          ),
          isTrue,
          reason: '${place.id} must be geometrically inside Alexandria',
        );
        expect(
          GovernorateService.detectFromCoordinates(place.lat, place.lng).id,
          'alexandria',
          reason: '${place.id} should be inside the Alexandria boundary',
        );
      }
      for (final hotel in getSeedHotelPlaces().where(
        (hotel) => hotel.id != 'hotel-borg-al-arab',
      )) {
        expect(
          GovernorateService.containsCoordinates(
            EgyptGovernorate.byId['alexandria']!,
            hotel.lat,
            hotel.lng,
          ),
          isTrue,
          reason: '${hotel.id} must be geometrically inside Alexandria',
        );
        expect(
          GovernorateService.detectFromCoordinates(hotel.lat, hotel.lng).id,
          'alexandria',
          reason: '${hotel.id} should be inside the Alexandria boundary',
        );
      }
      for (final hotel in getSeedHotels().where(
        (hotel) => hotel.id != 'hotel-borg-al-arab',
      )) {
        expect(
          GovernorateService.containsCoordinates(
            EgyptGovernorate.byId['alexandria']!,
            hotel.lat,
            hotel.lng,
          ),
          isTrue,
          reason: '${hotel.id} must be geometrically inside Alexandria',
        );
        expect(
          GovernorateService.detectFromCoordinates(hotel.lat, hotel.lng).id,
          'alexandria',
          reason: '${hotel.id} should be inside the Alexandria boundary',
        );
      }
      expect(AtmService.curatedAlexandriaAtms, hasLength(27));
      for (final atm in AtmService.curatedAlexandriaAtms) {
        expect(
          GovernorateService.containsCoordinates(
            EgyptGovernorate.byId['alexandria']!,
            atm.lat,
            atm.lng,
          ),
          isTrue,
          reason: '${atm.id} must be geometrically inside Alexandria',
        );
        expect(
          GovernorateService.detectFromCoordinates(atm.lat, atm.lng).id,
          'alexandria',
          reason: '${atm.id} should be inside the Alexandria boundary',
        );
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
