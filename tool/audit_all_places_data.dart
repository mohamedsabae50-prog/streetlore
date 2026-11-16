import 'dart:io';
import 'dart:math' as math;

import 'package:streetlore/data/alexandria_image_urls.dart';
import 'package:streetlore/data/cairo_image_urls.dart';
import 'package:streetlore/data/luxor_image_urls.dart';
import 'package:streetlore/data/aswan_image_urls.dart';
import 'package:streetlore/data/red_sea_image_urls.dart';
import 'package:streetlore/data/mock_data.dart';
import 'package:streetlore/data/models/place_model.dart';
import 'package:streetlore/data/models/egypt_governorate.dart';
import 'package:streetlore/core/services/governorate_service.dart';

const _boilerplate = [
  'confirm current visitor information',
  'is a culture destination in',
  'a place to explore in',
  'a landmark of the history and culture of',
  'check current opening hours',
  'check current prices and fees',
];

const _paidAdmissionTerms = [
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

const _ticketedParkIds = {
  'al_azhar_park',
  'orman_botanical_garden_giza',
  'giza_zoo_garden',
  'zed_park_sheikh_zayed',
  'wadi_degla_protectorate',
  'aquarium_grotto_garden',
};

const _paidAdmissionIds = {
  'fallback_qaitbay',
  'fallback_biblio',
  'fallback_catacombs',
  'fallback_pompey',
  'fallback_graeco_roman_museum',
  'fallback_roman_amphitheatre',
  'fallback_national_museum',
  'pharaonic_village_giza',
};

const _specialRestaurantHours = {
  'kebdet_el_prince_imbaba',
  'kebdet_el_prince_korba',
  'gad',
  'abou_shakra_mohandessin',
  'nine_pyramid_lounge_giza',
};

Future<void> main() async {
  final places = MockData.places;
  final issues = <String>[];
  final placeIds = <String>{};
  final imageOwners = <String, String>{};
  final suspiciousImageTerms = [
    'construction',
    'britishmuseum',
    'turin_album',
    'loc_matpc',
    'sheikh_zayed_road',
    'city_stars',
    'omar_afandi',
  ];

  for (final place in places) {
    if (!placeIds.add(place.id)) {
      issues.add('${place.id}: duplicate place ID');
    }
    if (!place.lat.isFinite ||
        !place.lng.isFinite ||
        place.lat < -90 ||
        place.lat > 90 ||
        place.lng < -180 ||
        place.lng > 180) {
      issues.add('${place.id}: invalid Google Maps coordinates');
    }

    final text = '${place.descriptionEn} ${place.descriptionAr}'.toLowerCase();
    if (_boilerplate.any(text.contains)) {
      issues.add('${place.id}: boilerplate description');
    }
    if (_sentenceCount(place.descriptionEn) < 2 ||
        _sentenceCount(place.descriptionAr ?? '') < 2) {
      issues.add(
        '${place.id}: description must contain at least two sentences in both languages',
      );
    }
    if (place.descriptionEn.trim().length < 95 ||
        (place.descriptionAr?.trim().length ?? 0) < 65) {
      issues.add(
        '${place.id}: description must be at least 95 English and 65 Arabic characters',
      );
    }

    if (_requiresPaidAdmission(place) &&
        (place.priceLocalEgp == null ||
            place.priceLocalEgp! <= 0 ||
            place.priceForeignerEgp == null ||
            place.priceForeignerEgp! <= 0 ||
            place.isFree)) {
      issues.add(
        '${place.id}: paid attraction needs positive local/foreign prices and a non-free price level',
      );
    }

    final category = place.category.trim().toLowerCase();
    if ((category == 'food' ||
            category == 'cafe' ||
            category == 'cafes' ||
            category == 'hotels') &&
        place.priceLevel == PriceLevel.free) {
      issues.add('${place.id}: dining/hotel price level is free');
    }

    final expectedHours = _expectedHours(place);
    if (expectedHours != null &&
        _normalizeHours(place.openHours) != _normalizeHours(expectedHours)) {
      issues.add(
        '${place.id}: expected hours "$expectedHours", found "${place.openHours}"',
      );
    }

    final urls = place.officialImages;
    if (urls.isEmpty) {
      issues.add('${place.id}: no image URL');
    }
    for (final url in urls) {
      final normalized = url.toLowerCase();
      if (suspiciousImageTerms.any(normalized.contains)) {
        issues.add('${place.id}: disallowed image URL $url');
      }
      final uri = Uri.tryParse(url);
      final validWikimediaUrl =
          uri != null &&
          uri.scheme == 'https' &&
          uri.host == 'upload.wikimedia.org' &&
          uri.path.isNotEmpty;
      if (!validWikimediaUrl) {
        issues.add('${place.id}: image is not a Wikimedia HTTPS URL: $url');
      }
      final previous = imageOwners.putIfAbsent(url, () => place.id);
      if (previous != place.id) {
        issues.add('${place.id}: image URL is also used by $previous');
      }
    }
  }

  _checkImageMapDuplicates('Cairo', cairoImageUrls, issues);
  _checkImageMapDuplicates('Alexandria', alexandriaImageUrls, issues);
  _checkImageMapDuplicates('Luxor', luxorImageUrls, issues);
  _checkImageMapDuplicates('Aswan', aswanImageUrls, issues);
  _checkImageMapDuplicates('Red Sea', redSeaImageUrls, issues);

  final alexandriaCount = places
      .where((place) => place.governorate == 'alexandria')
      .length;
  final cairoCount = places
      .where((place) => place.governorate == 'cairo')
      .length;
  final luxorPlaces = places
      .where((place) => place.governorate == 'luxor')
      .toList(growable: false);
  final redSeaPlaces = places
      .where((place) => place.governorate == 'red_sea')
      .toList(growable: false);
  final luxorCount = luxorPlaces.length;
  if (alexandriaCount != 53) {
    issues.add('expected 53 Alexandria places, found $alexandriaCount');
  }
  final alexandriaPlaces = places
      .where((place) => place.governorate == 'alexandria')
      .toList(growable: false);
  if (alexandriaPlaces.where((place) => place.isVisitable).length != 53 ||
      alexandriaPlaces.where((place) => place.isAtm).isNotEmpty) {
    issues.add(
      'expected 53 Alexandria visitable places and no Alexandria ATMs',
    );
  }
  if (cairoCount != 194) {
    issues.add('expected 194 Cairo/Giza places, found $cairoCount');
  }
  final cairoPlaces = places
      .where((place) => place.governorate == 'cairo')
      .toList(growable: false);
  if (cairoPlaces.where((place) => place.isVisitable).length != 174 ||
      cairoPlaces.where((place) => place.isAtm).length != 20) {
    issues.add('expected 174 Cairo/Giza visitable places and 20 map ATMs');
  }
  if (luxorCount != 124) {
    issues.add('expected 124 Luxor & Aswan records, found $luxorCount');
  }
  final luxorVisitableCount = luxorPlaces
      .where((place) => place.isVisitable)
      .length;
  final luxorAtmCount = luxorPlaces.where((place) => place.isAtm).length;
  if (luxorVisitableCount != 112 || luxorAtmCount != 12) {
    issues.add(
      'expected 112 Luxor & Aswan visitable places and 12 map ATMs, '
      'found $luxorVisitableCount visitable and $luxorAtmCount ATMs',
    );
  }
  if (redSeaPlaces.length != 60 ||
      redSeaPlaces.where((place) => place.isVisitable).length != 54 ||
      redSeaPlaces.where((place) => place.isAtm).length != 6) {
    issues.add(
      'expected 60 Red Sea records (54 visitable and 6 map ATMs), '
      'found ${redSeaPlaces.length} records '
      '(${redSeaPlaces.where((place) => place.isVisitable).length} visitable, '
      '${redSeaPlaces.where((place) => place.isAtm).length} ATMs)',
    );
  }
  final visitableCount = places.where((place) => place.isVisitable).length;
  final atmCount = places.where((place) => place.isAtm).length;
  if (visitableCount != 393 || atmCount != 38) {
    issues.add(
      'expected 393 visitable places and 38 map ATMs, '
      'found $visitableCount visitable and $atmCount ATMs',
    );
  }
  for (final governorateId in ['alexandria', 'cairo', 'luxor', 'red_sea']) {
    final governorate = EgyptGovernorate.byId[governorateId]!;
    for (final place in places.where(
      (place) => place.governorate == governorateId,
    )) {
      if (!_strictlyInside(governorate, place.lat, place.lng)) {
        issues.add(
          '${place.id}: coordinate is not strictly inside the '
          '$governorateId boundary',
        );
      }
    }
  }
  if (redSeaImageUrls.length != 60 ||
      redSeaImageUrls.values.toSet().length != 60) {
    issues.add('Red Sea image catalog must contain exactly 60 unique URLs');
  }
  final redSeaIds = redSeaPlaces
      .where((place) => redSeaImageUrls.containsKey(place.id))
      .map((place) => place.id)
      .toSet();
  if (redSeaIds.length != 60 ||
      redSeaIds.difference(redSeaImageUrls.keys.toSet()).isNotEmpty ||
      redSeaImageUrls.keys.toSet().difference(redSeaIds).isNotEmpty) {
    issues.add('Red Sea place IDs and image catalog keys must match exactly');
  }
  for (final entry in redSeaImageUrls.entries) {
    final uri = Uri.tryParse(entry.value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'upload.wikimedia.org' ||
        !uri.path.startsWith('/wikipedia/commons/')) {
      issues.add(
        '${entry.key}: malformed Wikimedia Commons URL in local image catalog',
      );
    }
  }
  final activeGovernorateIds = places
      .map((place) => EgyptGovernorate.normalizeId(place.governorate))
      .toSet();
  if (activeGovernorateIds.length != 4 ||
      !activeGovernorateIds.containsAll([
        'alexandria',
        'cairo',
        'luxor',
        'red_sea',
      ]) ||
      EgyptGovernorate.normalizeId('aswan') != 'luxor') {
    issues.add(
      'active governorates must be Alexandria, Cairo & Giza, '
      'Luxor & Aswan, and Red Sea',
    );
  }
  if (places.length != 431) {
    issues.add('expected 431 total places, found ${places.length}');
  }
  final profileScreen = File(
    'lib/presentation/screens/profile_screen.dart',
  ).readAsStringSync();
  if (profileScreen.contains('_BadgesLevelCard') ||
      profileScreen.contains('View All Badges')) {
    issues.add('ProfileScreen must not contain a badges card or button');
  }
  if (luxorImageUrls.length != 61 ||
      luxorImageUrls.values.toSet().length != 61) {
    issues.add('Luxor image catalog must contain exactly 61 unique image URLs');
  }
  final luxorIds = luxorPlaces
      .where((place) => luxorImageUrls.containsKey(place.id))
      .map((place) => place.id)
      .toSet();
  if (luxorIds.length != 61 ||
      luxorIds.difference(luxorImageUrls.keys.toSet()).isNotEmpty ||
      luxorImageUrls.keys.toSet().difference(luxorIds).isNotEmpty) {
    issues.add('Luxor place IDs and image catalog keys must match exactly');
  }
  for (final entry in luxorImageUrls.entries) {
    final uri = Uri.tryParse(entry.value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'upload.wikimedia.org' ||
        !uri.path.startsWith('/wikipedia/commons/')) {
      issues.add(
        '${entry.key}: malformed Wikimedia Commons URL in local image catalog',
      );
    }
  }
  final aswanIds = luxorPlaces
      .where((place) => aswanImageUrls.containsKey(place.id))
      .map((place) => place.id)
      .toSet();
  if (aswanIds.length != 63 ||
      aswanIds.difference(aswanImageUrls.keys.toSet()).isNotEmpty ||
      aswanImageUrls.keys.toSet().difference(aswanIds).isNotEmpty) {
    issues.add('Aswan place IDs and image catalog keys must match exactly');
  }
  if (aswanImageUrls.length != 63 ||
      aswanImageUrls.values.toSet().length != 63) {
    issues.add('Aswan image catalog must contain exactly 63 unique image URLs');
  }
  for (final entry in aswanImageUrls.entries) {
    final uri = Uri.tryParse(entry.value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'upload.wikimedia.org' ||
        !uri.path.startsWith('/wikipedia/commons/')) {
      issues.add(
        '${entry.key}: malformed Wikimedia Commons URL in local image catalog',
      );
    }
  }
  stdout.writeln(
    'Audited $alexandriaCount Alexandria, $cairoCount Cairo/Giza, '
    '$luxorCount Luxor & Aswan, and ${redSeaPlaces.length} Red Sea records '
    '(${imageOwners.length} unique place image URLs).',
  );
  stdout.writeln(
    'Place split: $visitableCount visitable, $atmCount map-only ATMs.',
  );
  stdout.writeln('Image checks are offline URL-format and uniqueness checks.');
  if (issues.isNotEmpty) {
    for (final issue in issues) {
      stderr.writeln('[FAIL] $issue');
    }
    stderr.writeln('Found ${issues.length} catalog quality issue(s).');
    exitCode = 1;
    return;
  }
  stdout.writeln('[PASS] No catalog quality issues found.');
}

bool _requiresPaidAdmission(PlaceModel place) {
  final category = place.category.trim().toLowerCase();
  if (place.governorate == 'luxor' &&
      (category == 'historical' || category == 'culture')) {
    return place.id != 'luxor_colossi_of_memnon';
  }

  if (place.id.startsWith('aswan_')) {
    if (category == 'historical' || category == 'culture') return true;
    if (category == 'nature') {
      return place.id != 'aswan_nile_corniche_promenade';
    }
  }
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
  if (_ticketedParkIds.contains(place.id) ||
      _paidAdmissionIds.contains(place.id)) {
    return true;
  }
  if (place.id == 'khan_el_khalili' ||
      place.id == 'al_muizz_street' ||
      place.id.contains('mall') ||
      place.id.contains('mosque') ||
      place.id.contains('church') ||
      place.id.contains('cathedral') ||
      place.id.contains('synagogue') ||
      place.id.contains('corniche') ||
      place.id.contains('promenade') ||
      place.id.contains('bridge_walk') ||
      place.id.contains('square')) {
    return false;
  }
  final searchable = '${place.id} ${place.nameEn}'.toLowerCase();
  return _paidAdmissionTerms.any(searchable.contains);
}

String? _expectedHours(PlaceModel place) {
  final category = place.category.trim().toLowerCase();
  final idAndName = '${place.id} ${place.nameEn}'.toLowerCase();
  if (place.governorate == 'red_sea') {
    return switch (category) {
      'shopping' => '10:00 AM - 11:00 PM',
      'food' || 'cafe' || 'cafes' => '10:00 AM - 01:00 AM',
      'hotels' || 'atms' || 'atm' => '24 hours',
      _ => null,
    };
  }
  if (place.id.startsWith('aswan_')) {
    return switch (category) {
      'historical' || 'culture' || 'nature' => place.openHours,
      'mosques' => '04:00 AM - 10:00 PM',
      'churches' => '08:00 AM - 08:00 PM',
      'shopping' => '10:00 AM - 11:00 PM',
      'food' || 'cafe' || 'cafes' => '10:00 AM - 01:00 AM',
      'hotels' || 'atms' || 'atm' => '24 hours',
      _ => null,
    };
  }
  if (place.governorate == 'luxor') {
    return switch (category) {
      'historical' => switch (place.id) {
        'luxor_karnak_temple' => '06:00 AM - 05:30 PM',
        'luxor_temple' || 'luxor_avenue_of_sphinxes' => '06:00 AM - 09:00 PM',
        'luxor_colossi_of_memnon' => '24 hours',
        'luxor_esna_khnum_temple' => '07:00 AM - 05:00 PM',
        _ => '06:00 AM - 05:00 PM',
      },
      'culture' =>
        place.id == 'luxor_howard_carter_house'
            ? '08:00 AM - 05:00 PM'
            : '09:00 AM - 08:00 PM',
      'nature' => switch (place.id) {
        'luxor_nile_corniche' => '24 hours',
        'luxor_west_bank_balloon_field' => '04:30 AM - 08:30 AM',
        'luxor_banana_island' ||
        'luxor_crocodile_island_park' => '09:00 AM - 05:00 PM',
        'luxor_felucca_sail_dock' => '06:00 AM - 10:00 PM',
        _ => null,
      },
      'mosques' => '04:00 AM - 10:00 PM',
      'churches' => '08:00 AM - 08:00 PM',
      'shopping' => '10:00 AM - 11:00 PM',
      'food' || 'cafes' => '10:00 AM - 01:00 AM',
      'hotels' || 'atms' || 'atm' => '24 hours',
      _ => null,
    };
  }
  if (category == 'atms' ||
      category == 'atm' ||
      category == 'hotels' ||
      _isOpenPublicSpace(idAndName)) {
    return '24 hours';
  }
  if (category == 'mosques') return '04:00 AM - 10:00 PM';
  if (category == 'churches') return '08:00 AM - 08:00 PM';
  if (category == 'shopping') {
    if (place.id == 'azbakeya_book_market_cairo' ||
        idAndName.contains('bazaar') ||
        idAndName.contains('souq') ||
        idAndName.contains('book market')) {
      return '10:00 AM - 10:00 PM';
    }
    return '10:00 AM - 12:00 AM';
  }
  if (category == 'food' || category == 'cafe' || category == 'cafes') {
    return _specialRestaurantHours.contains(place.id)
        ? '09:00 AM - 05:00 PM'
        : '10:00 AM - 01:00 AM';
  }
  if (category == 'nature') {
    if (place.id == 'cairo_helwan_japanese_garden') {
      return '08:00 AM - 09:00 PM';
    }
    if (place.id == 'zed_park_sheikh_zayed') {
      return '01:00 PM - 11:00 PM';
    }
    if (place.id == 'orman_botanical_garden_giza' ||
        place.id == 'giza_zoo_garden') {
      return '09:00 AM - 05:00 PM';
    }
    if (_isOpenPublicSpace(idAndName)) return '24 hours';
    return '08:00 AM - 10:00 PM';
  }
  return null;
}

bool _strictlyInside(EgyptGovernorate governorate, double lat, double lng) {
  if (!GovernorateService.containsCoordinates(governorate, lat, lng)) {
    return false;
  }
  final polygon = governorate.boundaryPolygon;
  for (var index = 0; index < polygon.length; index++) {
    final start = polygon[index];
    final end = polygon[(index + 1) % polygon.length];
    final cross =
        (lng - start.longitude) * (end.latitude - start.latitude) -
        (lat - start.latitude) * (end.longitude - start.longitude);
    final withinSegment =
        lng >= math.min(start.longitude, end.longitude) - 1e-10 &&
        lng <= math.max(start.longitude, end.longitude) + 1e-10 &&
        lat >= math.min(start.latitude, end.latitude) - 1e-10 &&
        lat <= math.max(start.latitude, end.latitude) + 1e-10;
    if (cross.abs() <= 1e-10 && withinSegment) return false;
  }
  return true;
}

bool _isOpenPublicSpace(String idAndName) =>
    idAndName.contains('alex_el_max_venice_canal') ||
    idAndName.contains('street') ||
    idAndName.contains('square') ||
    idAndName.contains('bridge') ||
    idAndName.contains('corniche') ||
    idAndName.contains('promenade') ||
    idAndName.contains('pier') ||
    idAndName.contains('walk');

int _sentenceCount(String value) =>
    RegExp(r'[.!?؟](?:\s|$)').allMatches(value.trim()).length;

String _normalizeHours(String value) => value
    .toLowerCase()
    .replaceAll('open ', '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

void _checkImageMapDuplicates(
  String region,
  Map<String, String> imageUrls,
  List<String> issues,
) {
  final urls = <String, String>{};
  for (final entry in imageUrls.entries) {
    final previous = urls.putIfAbsent(entry.value, () => entry.key);
    if (previous != entry.key) {
      issues.add('$region image map: ${entry.key} reuses $previous image URL');
    }
  }
}
