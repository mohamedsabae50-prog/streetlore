import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/core/services/carplay_service.dart';
import 'package:streetlore/data/mock_data.dart';
import 'package:streetlore/data/models/map_seed.dart';
import 'package:streetlore/data/models/place_model.dart';
import 'package:streetlore/logic/place_provider.dart';

void main() {
  group('Alexandria place data integrity', () {
    test('fallback and seeded places have unique IDs and normalized names', () {
      _expectUniquePlaces('fallback places', fallbackPlaces);
      _expectUniquePlaces('curated places', curatedAlexandriaPlaces);
      _expectUniquePlaces('seeded places', getSeedAlexandriaPlaces());
      _expectUniquePlaces('seeded hotels', getSeedHotelPlaces());
    });

    test('fallback place images and bilingual metadata are complete', () {
      final imageUrls = <String>{};
      for (final place in fallbackPlaces) {
        final baseImageUrl = place.imageUrl.split('?').first.trim();
        expect(baseImageUrl, isNotEmpty, reason: '${place.id} has no image');
        expect(
          imageUrls.add(baseImageUrl),
          isTrue,
          reason: 'fallback places share image URL $baseImageUrl',
        );
        expect(
          place.nameEn.trim(),
          isNotEmpty,
          reason: '${place.id} lacks EN name',
        );
        expect(
          place.nameAr?.trim(),
          isNotEmpty,
          reason: '${place.id} lacks AR name',
        );
        expect(
          place.descriptionEn.trim(),
          isNotEmpty,
          reason: '${place.id} lacks EN description',
        );
        expect(
          place.descriptionAr?.trim(),
          isNotEmpty,
          reason: '${place.id} lacks AR description',
        );
      }
      expect(imageUrls, hasLength(fallbackPlaces.length));
    });

    test(
      'provider merge collapses ID, bilingual-name, and nearby duplicates',
      () {
        final original = PlaceModel(
          id: 'remote-delices',
          nameEn: 'Delices Cafe',
          nameAr: 'ديليس',
          descriptionEn: 'A short description.',
          imageUrl: 'image.jpg',
          rating: 4.0,
          lat: 31.2000,
          lng: 29.8990,
        );
        final nearby = PlaceModel(
          id: 'seed-delices',
          nameEn: 'Delices Patisserie & Cafe',
          nameAr: 'حلويات ديليس',
          descriptionEn:
              'A detailed description of the same patisserie and cafe.',
          descriptionAr: 'وصف تفصيلي للحلواني والمقهى.',
          imageUrl: 'better-image.jpg',
          rating: 4.7,
          lat: 31.2001,
          lng: 29.8990,
        );
        final sameId = PlaceModel(
          id: original.id,
          nameEn: 'Different display name',
          nameAr: null,
          descriptionEn: 'A description.',
          imageUrl: '',
          rating: 3.0,
          lat: 31.21,
          lng: 29.91,
        );
        final sameEnglishName = PlaceModel(
          id: 'another-delices',
          nameEn: 'DELICES — CAFE',
          nameAr: 'اسم مختلف',
          descriptionEn: 'A separate database spelling of the same place.',
          imageUrl: '',
          rating: 3.5,
          lat: 31.22,
          lng: 29.92,
        );

        final merged = PlaceProvider.deduplicatePlaces([
          original,
          nearby,
          sameId,
          sameEnglishName,
        ]);

        expect(merged, hasLength(1));
        expect(merged.single.id, nearby.id);
        expect(
          PlaceProvider.deduplicatePlaces([
            ...fallbackPlaces,
            ...getSeedAlexandriaPlaces(),
          ]).length,
          lessThanOrEqualTo(
            fallbackPlaces.length + getSeedAlexandriaPlaces().length,
          ),
        );
      },
    );
  });

  group('CarPlayService', () {
    test('builds Nearby, Food & Cafes, Shopping, and Saved sections', () {
      final service = CarPlayService.instance;
      final sections = service.buildSections(
        places: curatedAlexandriaPlaces,
        savedPlaces: [curatedAlexandriaPlaces.first],
        latitude: 31.2,
        longitude: 29.9,
      );

      expect(sections.map((section) => section.id), [
        'nearby',
        'food_cafes',
        'shopping',
        'saved',
      ]);
      expect(sections[0].places, isNotEmpty);
      expect(sections[1].places, hasLength(19));
      expect(sections[2].places, hasLength(8));
      expect(sections[3].places, [curatedAlexandriaPlaces.first]);
      expect(
        sections[0].places.first.id,
        'alex_gad_fouad_street',
        reason: 'Nearby results should be sorted by distance from the user.',
      );
    });

    test('creates valid native navigation URIs without invoking plugins', () {
      final service = CarPlayService.instance;
      final place = curatedAlexandriaPlaces.first;
      final appleMaps = service.navigationUri(
        place,
        platform: TargetPlatform.iOS,
      );
      final googleMaps = service.navigationUri(
        place,
        platform: TargetPlatform.android,
      );
      final webFallback = service.navigationUri(
        place,
        platform: TargetPlatform.windows,
      );

      expect(appleMaps.host, 'maps.apple.com');
      expect(appleMaps.queryParameters['q'], contains(place.nameEn));
      expect(appleMaps.queryParameters['q'], isNot(contains('${place.lat}')));
      expect(googleMaps.host, 'www.google.com');
      expect(googleMaps.path, '/maps/search/');
      expect(googleMaps.queryParameters['query'], contains(place.nameEn));
      expect(
        googleMaps.queryParameters['query'],
        isNot(contains('${place.lng}')),
      );
      expect(webFallback.scheme, 'https');
      expect(webFallback, googleMaps);
    });

    test('navigation search does not depend on raw coordinates', () {
      const invalidPlace = PlaceModel(
        id: 'invalid',
        nameEn: 'Invalid',
        descriptionEn: '',
        imageUrl: '',
        rating: 4.5,
        lat: 95,
        lng: 29.9,
      );

      final uri = CarPlayService.instance.navigationUri(
        invalidPlace,
        platform: TargetPlatform.android,
      );
      expect(uri.queryParameters['query'], contains('Invalid'));
      expect(uri.queryParameters['query'], isNot(contains('95')));
      expect(uri.queryParameters['query'], isNot(contains('29.9')));
    });
  });
}

void _expectUniquePlaces(String label, List<PlaceModel> places) {
  final ids = <String>{};
  final englishNames = <String>{};
  final arabicNames = <String>{};

  for (final place in places) {
    expect(
      ids.add(place.id.trim().toLowerCase()),
      isTrue,
      reason: '$label contains duplicate ID ${place.id}',
    );
    expect(
      englishNames.add(_normalize(place.nameEn)),
      isTrue,
      reason: '$label contains duplicate English name ${place.nameEn}',
    );
    final arabicName = _normalize(place.nameAr ?? '');
    if (arabicName.isNotEmpty) {
      expect(
        arabicNames.add(arabicName),
        isTrue,
        reason: '$label contains duplicate Arabic name ${place.nameAr}',
      );
    }
  }

  for (var first = 0; first < places.length; first++) {
    for (var second = first + 1; second < places.length; second++) {
      final a = places[first];
      final b = places[second];
      final distance = _distanceMeters(a, b);
      final similarName =
          _similarName(a.nameEn, b.nameEn) ||
          (a.nameAr != null &&
              b.nameAr != null &&
              _similarName(a.nameAr!, b.nameAr!));
      expect(
        distance < 25 && similarName,
        isFalse,
        reason:
            '$label contains places within 25 m with similar names: '
            '${a.nameEn} (${a.id}) and ${b.nameEn} (${b.id})',
      );
      expect(
        distance < 45 && similarName,
        isFalse,
        reason:
            '$label contains venues within 45 m with similar names: '
            '${a.nameEn} (${a.id}) and ${b.nameEn} (${b.id})',
      );
    }
  }
}

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
    .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), '');

bool _similarName(String a, String b) {
  const genericWords = {
    'alexandria',
    'cafe',
    'coffee',
    'hotel',
    'mall',
    'restaurant',
    'seafood',
    'كافيه',
    'مقهى',
    'فندق',
    'مطعم',
    'مول',
  };
  final wordsA = _normalizeWords(a)..removeAll(genericWords);
  final wordsB = _normalizeWords(b)..removeAll(genericWords);
  if (wordsA.isEmpty || wordsB.isEmpty) return false;
  if (wordsA.containsAll(wordsB) || wordsB.containsAll(wordsA)) return true;
  return wordsA.intersection(wordsB).length / wordsA.union(wordsB).length >=
      0.5;
}

Set<String> _normalizeWords(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
    .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), ' ')
    .trim()
    .split(RegExp(r'\s+'))
    .where((word) => word.isNotEmpty)
    .toSet();

double _distanceMeters(PlaceModel a, PlaceModel b) {
  const earthRadiusMeters = 6371000.0;
  final latitudeA = a.lat * math.pi / 180;
  final latitudeB = b.lat * math.pi / 180;
  final latitudeDelta = (b.lat - a.lat) * math.pi / 180;
  final longitudeDelta = (b.lng - a.lng) * math.pi / 180;
  final haversine =
      math.pow(math.sin(latitudeDelta / 2), 2) +
      math.cos(latitudeA) *
          math.cos(latitudeB) *
          math.pow(math.sin(longitudeDelta / 2), 2);
  return 2 * earthRadiusMeters * math.asin(math.sqrt(haversine));
}
