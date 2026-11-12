import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/core/services/governorate_service.dart';
import 'package:streetlore/core/services/atm_service.dart';
import 'package:streetlore/core/widgets/image_defaults.dart';
import 'package:streetlore/data/cairo_seed.dart';
import 'package:streetlore/data/mock_data.dart';
import 'package:streetlore/data/models/egypt_governorate.dart';
import 'package:streetlore/data/models/itinerary_model.dart';
import 'package:streetlore/data/models/place_model.dart';
import 'package:streetlore/data/models/map_seed.dart';

const _expectedCairoPlaceIds = [
  'cairo_citadel',
  'khan_el_khalili',
  'al_muizz_street',
  'egyptian_museum_tahrir',
  'nmec_fustat',
  'cairo_tower',
  'sultan_hassan_mosque',
  'ibn_tulun_mosque',
  'al_azhar_mosque',
  'hanging_church',
  'coptic_museum',
  'amr_ibn_alas_mosque',
  'baron_empain_palace',
  'abdeen_palace',
  'al_azhar_park',
  'islamic_art_museum',
  'gayer_anderson_museum',
  'manial_palace',
  'nile_ritz_carlton_cairo',
  'marriott_zamalek_cairo',
  'steigenberger_tahrir_cairo',
  'kempinski_nile_garden_city',
  'four_seasons_nile_plaza',
  'waldorf_astoria_heliopolis',
  'atm_nbe_tahrir',
  'atm_cib_zamalek',
  'atm_bm_hussein_khan',
  'atm_nbe_korba',
  'atm_cib_talaat_harb',
  'atm_nbe_citadel',
  'atm_bm_mar_girgis',
  'atm_cib_maadi_road9',
  'atm_qnb_garden_city',
  'atm_nbe_abdeen',
];

const _expectedCairoItineraryStops = {
  'cairo_islamic_fatimid_walk': [
    'al_muizz_street',
    'khan_el_khalili',
    'al_azhar_mosque',
    'al_azhar_park',
  ],
  'cairo_citadel_fustat_trail': [
    'cairo_citadel',
    'sultan_hassan_mosque',
    'hanging_church',
    'coptic_museum',
    'nmec_fustat',
  ],
  'cairo_khedivial_zamalek_nile_tour': [
    'cairo_opera_house',
    'aquarium_grotto_garden',
    'aisha_fahmy_palace',
    'cairo_tower',
  ],
  'cairo_heliopolis_nasr_new_cairo_tour': [
    'baron_empain_palace',
    'merryland_park_heliopolis',
    'international_park_nasr_city',
    'citystars_mall_nasr_city',
    'cairo_festival_city_mall',
  ],
  'cairo_new_capital_mokattam_wadi_degla': [
    'iconic_tower_new_capital',
    'al_fattah_al_aleem_mosque',
    'nativity_cathedral_new_capital',
    'cave_church_st_simon_mokattam',
    'wadi_degla_protectorate',
  ],
};

const _validCategories = {
  'Historical',
  'Shopping',
  'Culture',
  'Mosques',
  'Churches',
  'Nature',
  'Hotels',
  'ATMs',
  'Food',
  'Cafes',
};

void main() {
  final cairo = EgyptGovernorate.byId['cairo']!;

  test('Cairo seed has exactly the requested places and stable order', () {
    expect(cairoSeedPlaces, hasLength(120));
    expect(
      cairoSeedPlaces
          .take(_expectedCairoPlaceIds.length)
          .map((place) => place.id)
          .toList(),
      _expectedCairoPlaceIds,
    );
    expect(cairoSeedItineraries, hasLength(5));
    expect(
      MockData.places.where((place) => place.governorate == 'cairo'),
      hasLength(120),
    );
    expect(
      MockData.tours.where((tour) => tour.governorate == 'cairo'),
      hasLength(5),
    );
  });

  test('all Cairo map filter categories are populated with unique images', () {
    const filterCategories = {
      'Food',
      'Cafes',
      'Shopping',
      'Mosques',
      'Churches',
      'Hotels',
      'ATMs',
      'Historical',
      'Culture',
      'Nature',
    };
    final cairoCategories = cairoSeedPlaces
        .map((place) => place.category)
        .toSet();
    expect(cairoCategories, containsAll(filterCategories));
    expect(
      cairoSeedPlaces.map((place) => place.imageUrl).toSet(),
      hasLength(cairoSeedPlaces.length),
    );
  });

  for (final place in cairoSeedPlaces) {
    test('validates Cairo place ${place.id} individually', () {
      _verifyCairoPlace(place, cairo);
    });
  }

  test('Cairo IDs are unique across local Alexandria and Cairo records', () {
    final alexandriaHotels = getSeedHotelPlaces();
    expect(
      alexandriaHotels.every((place) => place.governorate == 'alexandria'),
      isTrue,
    );
    final allPlaceIds = [
      ...MockData.places.map((place) => place.id),
      ...alexandriaHotels.map((place) => place.id),
      ...AtmService.curatedAlexandriaAtms.map((atm) => atm.id),
    ];
    expect(allPlaceIds.toSet(), hasLength(allPlaceIds.length));
    expect(
      MockData.places.where((place) => place.governorate == 'alexandria'),
      isNotEmpty,
    );
    for (final place in MockData.places.where(
      (place) => place.governorate == 'alexandria',
    )) {
      expect(place.governorate, 'alexandria', reason: place.id);
    }

    final allIds = {...allPlaceIds, ...MockData.tours.map((tour) => tour.id)};
    expect(
      allIds.length,
      allPlaceIds.length + MockData.tours.length,
      reason: 'Place and itinerary IDs must not collide',
    );
  });

  test('Cairo negative boundary controls remain outside Cairo', () {
    for (final point in const [
      (name: 'Giza Pyramids', lat: 29.9792, lng: 31.1342),
      (name: 'Dokki West Bank', lat: 30.0385, lng: 31.2118),
      (name: 'Qaitbay Citadel', lat: 31.2140, lng: 29.8856),
    ]) {
      expect(
        GovernorateService.containsCoordinates(cairo, point.lat, point.lng),
        isFalse,
        reason: '${point.name} must be outside Cairo',
      );
    }
  });

  test('Cairo places have at least 25 metres between every marker pair', () {
    for (var first = 0; first < cairoSeedPlaces.length; first++) {
      for (var second = first + 1; second < cairoSeedPlaces.length; second++) {
        final a = cairoSeedPlaces[first];
        final b = cairoSeedPlaces[second];
        expect(
          _haversineMeters(a.lat, a.lng, b.lat, b.lng),
          greaterThanOrEqualTo(25),
          reason: '${a.id} and ${b.id} must not overlap',
        );
      }
    }
  });

  test('legacy places and itineraries still default to Alexandria', () {
    final place = PlaceModel.fromJson({'id': 'legacy'});
    final itinerary = ItineraryModel.fromJson({
      'id': 'legacy-tour',
      'title': 'Legacy tour',
      'description': 'Legacy description',
      'duration': '2 hours',
      'imageUrl': 'https://images.unsplash.com/legacy',
    });

    expect(place.governorate, 'alexandria');
    expect(place.toJson()['governorate'], 'alexandria');
    expect(itinerary.governorate, 'alexandria');
    expect(itinerary.toJson()['governorate'], 'alexandria');
  });

  test('Cairo seed JSON preserves its governorate and image data', () {
    for (final place in cairoSeedPlaces) {
      final restored = PlaceModel.fromJson(place.toJson());
      expect(restored.governorate, 'cairo', reason: place.id);
      expect(restored.primaryImage, place.primaryImage, reason: place.id);
    }
  });

  for (final itinerary in cairoSeedItineraries) {
    test('validates Cairo itinerary ${itinerary.id} and its stops', () {
      final cairoIds = cairoSeedPlaces.map((place) => place.id).toSet();
      expect(itinerary.governorate, 'cairo');
      expect(itinerary.title.trim(), isNotEmpty);
      expect(itinerary.titleAr?.trim(), isNotEmpty);
      expect(itinerary.description.trim(), isNotEmpty);
      expect(itinerary.descriptionAr?.trim(), isNotEmpty);
      expect(itinerary.coverImageUrl, isNotNull);
      final image = Uri.tryParse(itinerary.imageUrl);
      expect(image, isNotNull);
      expect(image!.scheme, 'https');
      expect(image.host, 'upload.wikimedia.org');
      expect(itinerary.places, isNotEmpty);
      expect(
        itinerary.places.map((place) => place.id).toList(),
        _expectedCairoItineraryStops[itinerary.id],
      );
      expect(
        itinerary.places.every(
          (place) =>
              cairoIds.contains(place.id) && place.governorate == 'cairo',
        ),
        isTrue,
      );
    });
  }
}

void _verifyCairoPlace(PlaceModel place, EgyptGovernorate cairo) {
  expect(place.governorate, 'cairo', reason: place.id);
  expect(
    GovernorateService.containsCoordinates(cairo, place.lat, place.lng),
    isTrue,
    reason: '${place.id} must be strictly inside Cairo',
  );
  expect(
    GovernorateService.containsCoordinates(
      EgyptGovernorate.byId['alexandria']!,
      place.lat,
      place.lng,
    ),
    isFalse,
    reason: '${place.id} must be outside Alexandria',
  );
  expect(
    GovernorateService.containsCoordinates(
      EgyptGovernorate.byId['giza']!,
      place.lat,
      place.lng,
    ),
    isFalse,
    reason: '${place.id} must be outside Giza',
  );
  expect(place.nameAr?.trim(), isNotEmpty, reason: place.id);
  expect(place.nameEn.trim(), isNotEmpty, reason: place.id);
  expect(place.descriptionAr?.trim(), isNotEmpty, reason: place.id);
  expect(place.descriptionEn.trim(), isNotEmpty, reason: place.id);
  expect(_validCategories, contains(place.category), reason: place.id);
  expect(imageFallbackIconForCategory(place.category), isNotNull);
  expect(place.openHours.trim(), isNotEmpty, reason: place.id);
  expect(place.rating, inInclusiveRange(0, 5), reason: place.id);
  expect(place.priceNote.trim(), isNotEmpty, reason: place.id);
  final image = Uri.tryParse(place.primaryImage);
  expect(image, isNotNull, reason: place.id);
  expect(image!.scheme, 'https', reason: place.id);
  expect(image.host, 'upload.wikimedia.org', reason: place.id);
  expect(
    place.imageUrls.every((url) {
      final parsed = Uri.tryParse(url);
      return parsed != null &&
          parsed.scheme == 'https' &&
          parsed.host == 'upload.wikimedia.org';
    }),
    isTrue,
    reason: place.id,
  );
  expect(place.officialImages, isNotEmpty, reason: place.id);
  expect(place.lat.isFinite && place.lng.isFinite, isTrue, reason: place.id);
}

double _haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusMeters = 6371000.0;
  final firstLat = lat1 * math.pi / 180;
  final secondLat = lat2 * math.pi / 180;
  final deltaLat = (lat2 - lat1) * math.pi / 180;
  final deltaLng = (lng2 - lng1) * math.pi / 180;
  final haversine =
      math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
      math.cos(firstLat) *
          math.cos(secondLat) *
          math.sin(deltaLng / 2) *
          math.sin(deltaLng / 2);
  return earthRadiusMeters *
      2 *
      math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
}
