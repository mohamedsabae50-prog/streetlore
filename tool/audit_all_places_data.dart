import 'dart:io';

import 'package:streetlore/data/alexandria_image_urls.dart';
import 'package:streetlore/data/cairo_image_urls.dart';
import 'package:streetlore/data/mock_data.dart';
import 'package:streetlore/data/models/place_model.dart';

const _boilerplate = [
  'confirm current visitor information',
  'is a culture destination in',
  'a place to explore in',
  'a landmark of the history and culture of',
  'check current opening hours',
  'check current prices and fees',
];

const _legacyAlexandriaImageHosts = {
  'images.unsplash.com',
  'tbivoxyxclwjjspwsgvc.supabase.co',
};

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
      final validLegacyAlexandriaUrl =
          place.governorate == 'alexandria' &&
          uri != null &&
          uri.scheme == 'https' &&
          _legacyAlexandriaImageHosts.contains(uri.host) &&
          uri.path.isNotEmpty;
      if (!validWikimediaUrl && !validLegacyAlexandriaUrl) {
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

  final alexandriaCount = places
      .where((place) => place.governorate == 'alexandria')
      .length;
  final cairoCount = places
      .where((place) => place.governorate == 'cairo')
      .length;
  stdout.writeln(
    'Audited $alexandriaCount Alexandria and $cairoCount Cairo/Giza places '
    '(${imageOwners.length} unique place image URLs).',
  );
  stdout.writeln(
    'HTTP status checks are performed by dart run tool/verify_cairo_seed.dart.',
  );
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

bool _isOpenPublicSpace(String idAndName) =>
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
