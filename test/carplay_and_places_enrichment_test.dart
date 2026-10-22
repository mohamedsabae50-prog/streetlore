import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/core/services/carplay_service.dart';
import 'package:streetlore/data/mock_data.dart';
import 'package:streetlore/data/models/place_model.dart';

void main() {
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
        'alex_kebdet_el_fallah',
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

      expect(appleMaps.toString(), 'maps://?daddr=${place.lat},${place.lng}');
      expect(
        googleMaps.toString(),
        'google.navigation:q=${place.lat},${place.lng}',
      );
      expect(appleMaps.scheme, 'maps');
      expect(googleMaps.scheme, 'google.navigation');
      expect(webFallback.scheme, 'https');
      expect(
        webFallback.queryParameters['destination'],
        '${place.lat},${place.lng}',
      );
    });

    test('rejects invalid coordinates before building a navigation URI', () {
      const invalidPlace = PlaceModel(
        id: 'invalid',
        nameEn: 'Invalid',
        descriptionEn: '',
        imageUrl: '',
        rating: 4.5,
        lat: 95,
        lng: 29.9,
      );

      expect(
        () => CarPlayService.instance.navigationUri(invalidPlace),
        throwsArgumentError,
      );
    });
  });
}
