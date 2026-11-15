import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/core/services/governorate_service.dart';
import 'package:streetlore/core/services/atm_service.dart';
import 'package:streetlore/core/widgets/image_defaults.dart';
import 'package:streetlore/data/alexandria_image_urls.dart';
import 'package:streetlore/data/cairo_seed.dart';
import 'package:streetlore/data/luxor_image_urls.dart';
import 'package:streetlore/data/luxor_seed.dart';
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

const _newCairoArticleImageIds = [
  'mosque_of_muhammad_ali',
  'al_ghuri_complex',
  'sabil_kuttab_katkhuda',
  'mosque_of_suleiman_pasha',
  'qasr_el_nil_bridge',
  'tahrir_square_obelisk',
  'amir_beshtak_palace',
  'mosque_of_al_maridani',
  'mosque_of_sultan_qaytbay',
  'khanqah_faraj_ibn_barquq',
  'saint_barbara_church_cairo',
  'ben_ezra_synagogue_cairo',
  'babylon_fortress_cairo',
  'egyptian_geological_museum',
  'egyptian_postal_museum',
  'egyptian_railways_museum',
  'beit_el_umma_museum',
  'mahmoud_mukhtar_museum',
  'modern_egyptian_art_museum',
  'al_gawhara_palace_citadel',
  'great_pyramid_of_giza',
  'pyramid_of_khafre',
  'pyramid_of_menkaure',
  'great_sphinx_of_giza',
  'grand_egyptian_museum_gem',
  'saqqara_step_pyramid',
  'serapeum_of_saqqara',
  'pyramid_of_unas_saqqara',
  'imhotep_museum_saqqara',
  'bent_pyramid_dahshur',
  'red_pyramid_dahshur',
  'memphis_museum_mit_rahina',
  'pharaonic_village_giza',
  'cairo_university_dome_giza',
  'orman_botanical_garden_giza',
  'giza_zoo_garden',
  'taha_hussein_museum_giza',
  'ahmed_shawki_museum_giza',
  'mahmoud_khalil_museum_giza',
  'zed_park_sheikh_zayed',
  'al_hosary_mosque_october',
  'mustafa_mahmoud_mosque_giza',
  'al_shorta_mosque_zayed',
  'archangel_michael_cathedral_giza',
  'nine_pyramid_lounge_giza',
  'andrea_el_mariouteya_giza',
  'kebdet_el_prince_imbaba',
  'abou_shakra_mohandessin',
  'arkan_plaza_cafe_zayed',
  'mall_of_egypt_october',
  'mall_of_arabia_october',
  'arkan_plaza_sheikh_zayed',
  'first_mall_giza',
  'marriott_mena_house_giza',
  'four_seasons_first_residence_giza',
  'sheraton_cairo_hotel_dokki',
  'hyatt_regency_west_cairo',
  'atm_nbe_dokki_giza',
  'atm_cib_mall_of_egypt',
  'atm_nbe_arkan_zayed',
  'egyptian_textile_museum',
  'sabil_umm_abbas',
  'wakala_of_qaytbay_cairo',
  'hammam_inal_muizz',
  'cairo_opera_house_museum',
  'al_horreya_garden_zamalek',
  'azbakeya_book_market_cairo',
  'korba_heritage_walk_heliopolis',
  'new_capital_arts_culture_city',
  'maadi_nile_felucca_pier',
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
  'cairo_citadel_royal_mosques_tour': [
    'mosque_of_muhammad_ali',
    'mosque_of_suleiman_pasha',
    'al_gawhara_palace_citadel',
    'cairo_citadel',
    'sultan_hassan_mosque',
  ],
  'cairo_zamalek_art_museums_walk': [
    'mahmoud_mukhtar_museum',
    'aisha_fahmy_palace',
    'cairo_opera_house',
    'modern_egyptian_art_museum',
    'qasr_el_nil_bridge',
  ],
  'cairo_mamluk_gems_architecture_tour': [
    'al_ghuri_complex',
    'sabil_kuttab_katkhuda',
    'amir_beshtak_palace',
    'mosque_of_al_maridani',
    'mosque_of_sultan_qaytbay',
    'khanqah_faraj_ibn_barquq',
  ],
  'cairo_museums_palaces_heritage_trail': [
    'abdeen_palace',
    'beit_el_umma_museum',
    'egyptian_geological_museum',
    'egyptian_postal_museum',
    'egyptian_railways_museum',
  ],
  'cairo_culinary_historic_cafes_walk': [
    'koshary_abou_tarek',
    'felfela_downtown',
    'cafe_riche_downtown',
    'groppi_talaat_harb',
    'el_fishawy_cafe_khan',
  ],
  'giza_pyramids_sphinx_gem_trail': [
    'great_pyramid_of_giza',
    'pyramid_of_khafre',
    'great_sphinx_of_giza',
    'grand_egyptian_museum_gem',
  ],
  'saqqara_memphis_dahshur_necropolis': [
    'saqqara_step_pyramid',
    'serapeum_of_saqqara',
    'memphis_museum_mit_rahina',
    'bent_pyramid_dahshur',
    'red_pyramid_dahshur',
  ],
  'giza_dokki_nile_museums_gardens': [
    'cairo_university_dome_giza',
    'taha_hussein_museum_giza',
    'orman_botanical_garden_giza',
    'giza_zoo_garden',
    'ahmed_shawki_museum_giza',
    'mahmoud_khalil_museum_giza',
  ],
  'sheikh_zayed_october_modern_walk': [
    'zed_park_sheikh_zayed',
    'arkan_plaza_sheikh_zayed',
    'mall_of_arabia_october',
    'mall_of_egypt_october',
    'al_hosary_mosque_october',
  ],
  'greater_cairo_east_to_west_grand_tour': [
    'cairo_citadel',
    'al_muizz_street',
    'egyptian_museum_tahrir',
    'nmec_fustat',
    'great_pyramid_of_giza',
    'great_sphinx_of_giza',
    'grand_egyptian_museum_gem',
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
  final luxor = EgyptGovernorate.byId['luxor']!;

  test('Cairo & Giza seed has 190 places and stable core order', () {
    expect(cairoSeedPlaces, hasLength(190));
    expect(
      cairoSeedPlaces
          .take(_expectedCairoPlaceIds.length)
          .map((place) => place.id)
          .toList(),
      _expectedCairoPlaceIds,
    );
    expect(
      cairoSeedPlaces.map((place) => place.id),
      containsAll(_newCairoArticleImageIds),
    );
    expect(cairoSeedItineraries, hasLength(15));
    expect(
      MockData.places.where((place) => place.governorate == 'cairo'),
      hasLength(190),
    );
    expect(
      MockData.tours.where((tour) => tour.governorate == 'cairo'),
      hasLength(15),
    );
  });

  test('Luxor seed has 60 places, six tours, and unique offline URLs', () {
    expect(luxor.id, 'luxor');
    expect(luxor.nameEn, 'Luxor');
    expect(luxor.nameAr, 'الأقصر');
    expect(luxor.centerLat, 25.7050);
    expect(luxor.centerLng, 32.6391);
    expect(luxor.defaultZoom, 12.2);
    expect(
      luxor.boundaryPolygon
          .map((point) => (point.latitude, point.longitude))
          .toList(),
      [
        (25.8200, 32.5200),
        (25.8300, 32.7200),
        (25.7500, 32.7800),
        (25.6200, 32.7600),
        (25.5200, 32.6800),
        (25.5000, 32.5000),
        (25.6000, 32.4500),
        (25.7400, 32.5000),
      ],
    );
    expect(luxorSeedPlaces, hasLength(60));
    expect(luxorSeedItineraries, hasLength(6));
    expect(
      MockData.places.where((place) => place.governorate == 'luxor'),
      hasLength(60),
    );
    expect(MockData.places, hasLength(299));
    expect(luxorImageUrls, hasLength(60));
    expect(luxorImageUrls.values.toSet(), hasLength(60));
    expect(
      luxorSeedPlaces.map((place) => place.id).toSet(),
      luxorImageUrls.keys.toSet(),
    );
    for (final place in luxorSeedPlaces) {
      expect(place.governorate, 'luxor', reason: place.id);
      expect(place.descriptionEn.trim().length, greaterThanOrEqualTo(95));
      expect(place.descriptionAr!.trim().length, greaterThanOrEqualTo(65));
      expect(
        RegExp(r'[.!?](?:\s|$)').allMatches(place.descriptionEn).length,
        greaterThanOrEqualTo(2),
        reason: place.id,
      );
      expect(
        RegExp(r'[.!?؟](?:\s|$)').allMatches(place.descriptionAr!).length,
        greaterThanOrEqualTo(2),
        reason: place.id,
      );
      final image = Uri.parse(place.imageUrl);
      expect(image.scheme, 'https', reason: place.id);
      expect(image.host, 'upload.wikimedia.org', reason: place.id);
      expect(
        image.path.startsWith('/wikipedia/commons/'),
        isTrue,
        reason: place.id,
      );
    }

    final placesById = {for (final place in luxorSeedPlaces) place.id: place};
    const paidTickets = <String, (int, int)>{
      'luxor_karnak_temple': (80, 600),
      'luxor_temple': (80, 500),
      'luxor_avenue_of_sphinxes': (80, 500),
      'luxor_museum': (50, 400),
      'luxor_mummification_museum': (40, 300),
      'luxor_valley_of_the_kings': (100, 750),
      'luxor_tomb_of_tutankhamun': (80, 700),
      'luxor_tomb_of_ramesses_vi': (60, 220),
      'luxor_valley_of_the_queens': (60, 220),
      'luxor_tomb_of_nefertari': (600, 2000),
      'luxor_hatshepsut_temple': (80, 440),
      'luxor_medinet_habu': (60, 220),
      'luxor_ramesseum': (60, 220),
      'luxor_deir_el_medina': (60, 220),
      'luxor_tombs_of_the_nobles': (60, 200),
      'luxor_ramose_tomb': (40, 160),
      'luxor_sennedjem_tomb': (40, 160),
      'luxor_howard_carter_house': (60, 220),
      'luxor_temple_of_seti_i_qurna': (40, 160),
      'luxor_merenptah_mortuary_temple': (40, 140),
      'luxor_assasif_necropolis': (40, 160),
      'luxor_deir_el_shelwit': (30, 100),
      'luxor_medamud_temple': (30, 100),
      'luxor_tod_temple': (30, 100),
      'luxor_armant_temple': (30, 100),
    };
    for (final entry in paidTickets.entries) {
      final place = placesById[entry.key]!;
      expect(
        (place.priceLocalEgp, place.priceForeignerEgp),
        entry.value,
        reason: entry.key,
      );
      expect(place.isFree, isFalse, reason: entry.key);
    }
    final colossi = placesById['luxor_colossi_of_memnon']!;
    expect(colossi.openHours, '24 hours');
    expect((colossi.priceLocalEgp, colossi.priceForeignerEgp), (0, 0));
    expect(colossi.isFree, isTrue);
    const naturePrices = <String, (int, int)>{
      'luxor_banana_island': (50, 150),
      'luxor_nile_corniche': (0, 0),
      'luxor_west_bank_balloon_field': (800, 3500),
      'luxor_felucca_sail_dock': (100, 300),
      'luxor_crocodile_island_park': (40, 120),
    };
    for (final entry in naturePrices.entries) {
      final place = placesById[entry.key]!;
      expect(
        (place.priceLocalEgp, place.priceForeignerEgp),
        entry.value,
        reason: entry.key,
      );
    }
    final religiousPlaces = placesById.values.where(
      (place) => place.category == 'Mosques' || place.category == 'Churches',
    );
    expect(religiousPlaces, hasLength(5));
    expect(religiousPlaces.every((place) => place.isFree), isTrue);
    final foodAndCafes = placesById.values.where(
      (place) => place.category == 'Food' || place.category == 'Cafes',
    );
    expect(foodAndCafes, hasLength(8));
    expect(
      foodAndCafes.every(
        (place) =>
            (place.priceLevel == PriceLevel.moderate ||
                place.priceLevel == PriceLevel.expensive) &&
            place.openHours == '10:00 AM - 01:00 AM',
      ),
      isTrue,
    );
    final shopping = placesById.values.where(
      (place) => place.category == 'Shopping',
    );
    expect(shopping, hasLength(4));
    expect(
      shopping.every((place) => place.openHours == '10:00 AM - 11:00 PM'),
      isTrue,
    );
    final hotels = placesById.values.where(
      (place) => place.category == 'Hotels',
    );
    expect(hotels, hasLength(6));
    expect(
      hotels.every(
        (place) =>
            place.priceLevel == PriceLevel.expensive &&
            place.openHours == '24 hours',
      ),
      isTrue,
    );
    expect(
      placesById.values.where((place) => place.category == 'ATMs'),
      hasLength(6),
    );
    expect(
      placesById.values
          .where((place) => place.category == 'ATMs')
          .every(
            (place) => !place.isVisitable && place.openHours == '24 hours',
          ),
      isTrue,
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
    expect(
      cairoSeedPlaces
          .where((place) => place.category == 'ATMs')
          .every((place) => !place.isVisitable),
      isTrue,
    );
  });

  test('new Cairo landmarks use HTTPS Wikimedia image URLs', () {
    final placesById = {for (final place in cairoSeedPlaces) place.id: place};
    for (final id in _newCairoArticleImageIds) {
      final url = Uri.parse(placesById[id]!.imageUrl);
      expect(url.scheme, 'https', reason: id);
      expect(url.host, 'upload.wikimedia.org', reason: id);
    }
  });

  test('the complete catalog contains no boilerplate descriptions', () {
    const boilerplate = [
      'Confirm current visitor information',
      'is a culture destination in',
      'a place to explore in',
      'a landmark of the history and culture of',
    ];
    for (final place in MockData.places) {
      final descriptions =
          '${place.descriptionEn}\n${place.descriptionAr ?? ''}'.toLowerCase();
      for (final phrase in boilerplate) {
        expect(
          descriptions,
          isNot(contains(phrase.toLowerCase())),
          reason: place.id,
        );
      }
    }
  });

  test('catalog descriptions are long, contextual, and sentence-complete', () {
    for (final place in MockData.places) {
      final english = place.descriptionEn.trim();
      final arabic = place.descriptionAr?.trim() ?? '';
      expect(english.length, greaterThanOrEqualTo(95), reason: place.id);
      expect(arabic.length, greaterThanOrEqualTo(65), reason: place.id);
      expect(
        english.toLowerCase(),
        contains(place.nameEn.toLowerCase()),
        reason: place.id,
      );
      expect(arabic, contains(place.nameAr ?? place.nameEn), reason: place.id);
      expect(_sentenceCount(english), inInclusiveRange(2, 3), reason: place.id);
      expect(_sentenceCount(arabic), inInclusiveRange(2, 3), reason: place.id);
    }
  });

  test('ticketed attractions in every city have positive dual prices', () {
    for (final place in MockData.places.where(_requiresPaidAdmission)) {
      expect(place.priceLocalEgp, greaterThan(0), reason: place.id);
      expect(place.priceForeignerEgp, greaterThan(0), reason: place.id);
      expect(place.isFree, isFalse, reason: place.id);
    }
  });

  test('dining and hotels are never marked as free entry', () {
    for (final place in MockData.places) {
      final category = place.category.toLowerCase();
      if (category == 'food' ||
          category == 'cafe' ||
          category == 'cafes' ||
          category == 'hotels') {
        expect(place.isFree, isFalse, reason: place.id);
      }
      if (category == 'atms' || category == 'atm') {
        expect(place.isVisitable, isFalse, reason: place.id);
      }
    }
  });

  test('catalog image URLs have no known bad placeholders or duplicates', () {
    const forbiddenImageTerms = [
      'Construction',
      'BritishMuseum',
      'Turin_Album',
      'LOC_matpc',
      'Sheikh_Zayed_Road',
      'City_stars',
      'Omar_Afandi',
    ];
    final imageOwners = <String, String>{};
    for (final place in MockData.places) {
      for (final imageUrl in place.officialImages) {
        for (final term in forbiddenImageTerms) {
          expect(
            imageUrl.toLowerCase(),
            isNot(contains(term.toLowerCase())),
            reason: '${place.id}: $imageUrl',
          );
        }
        final previousOwner = imageOwners.putIfAbsent(imageUrl, () => place.id);
        expect(
          previousOwner,
          place.id,
          reason: '$imageUrl is shared by $previousOwner and ${place.id}',
        );
        final uri = Uri.tryParse(imageUrl);
        expect(uri?.scheme, 'https', reason: '${place.id}: $imageUrl');
        expect(
          uri?.host == 'upload.wikimedia.org' ||
              (place.governorate == 'alexandria' &&
                  const {
                    'images.unsplash.com',
                    'tbivoxyxclwjjspwsgvc.supabase.co',
                  }.contains(uri?.host)),
          isTrue,
          reason: '${place.id}: $imageUrl',
        );
      }
    }
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

  test('negative boundary controls remain outside Greater Cairo', () {
    for (final point in const [
      (name: 'Banha', lat: 30.4660, lng: 31.1840),
      (name: 'Fayoum', lat: 29.3084, lng: 30.8428),
    ]) {
      expect(
        GovernorateService.containsCoordinates(cairo, point.lat, point.lng),
        isFalse,
        reason: '${point.name} must be outside Cairo & Giza',
      );
      expect(
        GovernorateService.containsCoordinates(
          EgyptGovernorate.byId['alexandria']!,
          point.lat,
          point.lng,
        ),
        isFalse,
        reason: '${point.name} must be outside Alexandria',
      );
    }
  });

  test('Giza landmarks resolve to Cairo & Giza, not a separate region', () {
    expect(EgyptGovernorate.byId['giza']!.id, 'cairo');
    expect(
      EgyptGovernorate.all.where((region) => region.id == 'giza'),
      isEmpty,
    );
    for (final place in cairoSeedPlaces.where(
      (place) => place.id.startsWith('great_') || place.id.contains('pyramid'),
    )) {
      expect(
        GovernorateService.containsCoordinates(cairo, place.lat, place.lng),
        isTrue,
        reason: place.id,
      );
    }
  });

  test('the ten requested Alexandria image places stay in Alexandria', () {
    final alexandriaPlaces = MockData.places
        .where((place) => alexandriaImageUrls.containsKey(place.id))
        .toList(growable: false);
    expect(alexandriaPlaces, hasLength(10));
    expect(
      alexandriaPlaces.map((place) => place.imageUrl).toSet(),
      hasLength(10),
    );
    for (final place in alexandriaPlaces) {
      expect(
        place.imageUrl,
        startsWith('https://upload.wikimedia.org/'),
        reason: place.id,
      );
      expect(place.governorate, 'alexandria', reason: place.id);
      expect(
        GovernorateService.containsCoordinates(
          EgyptGovernorate.byId['alexandria']!,
          place.lat,
          place.lng,
        ),
        isTrue,
        reason: place.id,
      );
      expect(
        GovernorateService.containsCoordinates(cairo, place.lat, place.lng),
        isFalse,
        reason: place.id,
      );
    }
  });

  test(
    'Cairo & Giza places have at least 25 metres between every marker pair',
    () {
      for (var first = 0; first < cairoSeedPlaces.length; first++) {
        for (
          var second = first + 1;
          second < cairoSeedPlaces.length;
          second++
        ) {
          final a = cairoSeedPlaces[first];
          final b = cairoSeedPlaces[second];
          expect(
            _haversineMeters(a.lat, a.lng, b.lat, b.lng),
            greaterThanOrEqualTo(25),
            reason: '${a.id} and ${b.id} must not overlap',
          );
        }
      }
    },
  );

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
      expect(restored.imageUrls, place.imageUrls, reason: place.id);
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

bool _requiresPaidAdmission(PlaceModel place) {
  final category = place.category.trim().toLowerCase();
  if (category == 'atms' ||
      category == 'atm' ||
      category == 'food' ||
      category == 'cafe' ||
      category == 'cafes' ||
      category == 'hotels' ||
      category == 'shopping' ||
      category == 'mosques' ||
      category == 'churches') {
    return false;
  }
  final searchable = '${place.id} ${place.nameEn}'.toLowerCase();
  if (searchable.contains('street') ||
      searchable.contains('square') ||
      searchable.contains('bridge') ||
      searchable.contains('corniche') ||
      searchable.contains('promenade') ||
      searchable.contains('mall') ||
      searchable.contains('synagogue')) {
    return false;
  }
  const paidTerms = [
    'museum',
    'pyramid',
    'citadel',
    'palace',
    'archaeological',
    'tomb',
    'necropolis',
    'serapeum',
    'protectorate',
    'zoo',
    'tower',
    'grotto',
    'aquarium',
    'sabil',
    'wakala',
    'wikala',
    'hammam',
    'bayt ',
    'beit ',
  ];
  const paidIds = {
    'fallback_qaitbay',
    'fallback_biblio',
    'fallback_catacombs',
    'fallback_pompey',
    'fallback_graeco_roman_museum',
    'fallback_roman_amphitheatre',
    'fallback_national_museum',
    'pharaonic_village_giza',
  };
  const ticketedParks = {
    'al_azhar_park',
    'orman_botanical_garden_giza',
    'giza_zoo_garden',
    'zed_park_sheikh_zayed',
    'wadi_degla_protectorate',
    'aquarium_grotto_garden',
  };
  return paidIds.contains(place.id) ||
      ticketedParks.contains(place.id) ||
      paidTerms.any(searchable.contains);
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

int _sentenceCount(String value) => RegExp(
  r'[.!?؟](?:\s|$)',
).allMatches(value.replaceAll('St. ', 'St ').trim()).length;
