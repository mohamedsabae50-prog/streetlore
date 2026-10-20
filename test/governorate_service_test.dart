import 'package:flutter_test/flutter_test.dart';
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
    },
  );

  test(
    'all Alexandria mock places and terrestrial ATMs resolve to Alexandria',
    () {
      for (final place in fallbackPlaces) {
        expect(
          GovernorateService.detectFromCoordinates(place.lat, place.lng).id,
          'alexandria',
          reason: '${place.id} should be inside the Alexandria boundary',
        );
      }
      for (final hotel in getSeedHotelPlaces()) {
        expect(
          GovernorateService.detectFromCoordinates(hotel.lat, hotel.lng).id,
          'alexandria',
          reason: '${hotel.id} should be inside the Alexandria boundary',
        );
      }
      for (final hotel in getSeedHotels()) {
        expect(
          GovernorateService.detectFromCoordinates(hotel.lat, hotel.lng).id,
          'alexandria',
          reason: '${hotel.id} should be inside the Alexandria boundary',
        );
      }
      expect(AtmService.curatedAlexandriaAtms, hasLength(27));
      for (final atm in AtmService.curatedAlexandriaAtms) {
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
