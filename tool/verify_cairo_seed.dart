import 'dart:io';
import 'dart:math' as math;

import 'package:streetlore/core/services/governorate_service.dart';
import 'package:streetlore/data/cairo_seed.dart';
import 'package:streetlore/data/mock_data.dart';
import 'package:streetlore/data/models/egypt_governorate.dart';
import 'package:streetlore/data/models/place_model.dart';

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

const _negativeControls = [
  (name: 'Giza Pyramids', lat: 29.9792, lng: 31.1342),
  (name: 'Dokki West Bank', lat: 30.0385, lng: 31.2118),
  (name: 'Qaitbay Citadel', lat: 31.2140, lng: 29.8856),
];

Future<void> main() async {
  final cairo = EgyptGovernorate.byId['cairo']!;
  final client = HttpClient()
    ..userAgent =
        'StreetLore/2.1 (Cairo seed verifier; https://github.com/mohamedsabae50-prog/streetlore)';
  final checkedImageUrls = <String, ({int statusCode, String? contentType})>{};
  final alexandriaPlaces = MockData.places
      .where((place) => place.governorate == 'alexandria')
      .toList(growable: false);
  final alexandriaTours = MockData.tours
      .where((tour) => tour.governorate == 'alexandria')
      .toList(growable: false);
  final allIds = <String>{};

  for (final place in [...alexandriaPlaces, ...cairoSeedPlaces]) {
    if (place.id.trim().isEmpty || !allIds.add(place.id)) {
      throw StateError('Place ID is empty or duplicated: ${place.id}');
    }
  }
  for (final tour in [...alexandriaTours, ...cairoSeedItineraries]) {
    if (tour.id.trim().isEmpty || !allIds.add(tour.id)) {
      throw StateError('Place/tour ID is empty or duplicated: ${tour.id}');
    }
  }
  for (final place in alexandriaPlaces) {
    if (place.governorate != 'alexandria') {
      throw StateError(
        'Alexandria place ${place.id} has governorate ${place.governorate}',
      );
    }
  }
  for (final tour in alexandriaTours) {
    if (tour.governorate != 'alexandria') {
      throw StateError(
        'Alexandria itinerary ${tour.id} has governorate ${tour.governorate}',
      );
    }
  }
  if (cairoSeedPlaces.length != 120) {
    throw StateError(
      'Expected 120 Cairo places, got ${cairoSeedPlaces.length}',
    );
  }
  if (cairoSeedItineraries.length != 5) {
    throw StateError(
      'Expected 5 Cairo itineraries, got ${cairoSeedItineraries.length}',
    );
  }
  final primaryImageUrls = cairoSeedPlaces
      .map((place) => place.imageUrl)
      .toSet();
  if (primaryImageUrls.length != cairoSeedPlaces.length) {
    throw StateError(
      'Cairo primary image URLs are not unique: '
      '${primaryImageUrls.length}/${cairoSeedPlaces.length}.',
    );
  }
  const requiredCategories = {
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
  final seededCategories = cairoSeedPlaces
      .map((place) => place.category)
      .toSet();
  if (!seededCategories.containsAll(requiredCategories)) {
    throw StateError(
      'Missing Cairo map filter categories: '
      '${requiredCategories.difference(seededCategories)}',
    );
  }

  for (final control in _negativeControls) {
    if (GovernorateService.containsCoordinates(
      cairo,
      control.lat,
      control.lng,
    )) {
      throw StateError('${control.name} must be outside Cairo');
    }
    stdout.writeln('[PASS] Negative boundary control: ${control.name}');
  }

  for (var index = 0; index < cairoSeedPlaces.length; index++) {
    final place = cairoSeedPlaces[index];
    await _verifyCairoPlace(place, cairo, client, checkedImageUrls);
    for (var previousIndex = 0; previousIndex < index; previousIndex++) {
      final previous = cairoSeedPlaces[previousIndex];
      final distance = _haversineMeters(
        place.lat,
        place.lng,
        previous.lat,
        previous.lng,
      );
      if (distance < 25) {
        throw StateError(
          '${place.id} and ${previous.id} are only '
          '${distance.toStringAsFixed(1)}m apart',
        );
      }
    }
    stdout.writeln(
      '[PASS] (${index + 1}/${cairoSeedPlaces.length}) '
      '${place.nameAr} | ${place.nameEn}',
    );
  }

  final cairoIds = cairoSeedPlaces.map((place) => place.id).toSet();
  for (var index = 0; index < cairoSeedItineraries.length; index++) {
    final itinerary = cairoSeedItineraries[index];
    if (itinerary.governorate != 'cairo' ||
        itinerary.title.trim().isEmpty ||
        itinerary.titleAr?.trim().isNotEmpty != true ||
        itinerary.description.trim().isEmpty ||
        itinerary.descriptionAr?.trim().isNotEmpty != true ||
        !_isHttpsImage(itinerary.imageUrl) ||
        itinerary.places.isEmpty ||
        itinerary.places.any(
          (place) =>
              !cairoIds.contains(place.id) || place.governorate != 'cairo',
        )) {
      throw StateError('Invalid Cairo itinerary: ${itinerary.id}');
    }
    stdout.writeln(
      '[PASS] (itinerary ${index + 1}/${cairoSeedItineraries.length}) '
      '${itinerary.titleAr} | ${itinerary.title}',
    );
  }
  stdout.writeln(
    '[PASS] ${alexandriaPlaces.length} Alexandria places and '
    '${alexandriaTours.length} Alexandria itineraries retain Alexandria IDs '
    'and governorate values.',
  );
  stdout.writeln(
    '[PASS] ${checkedImageUrls.length} unique Wikimedia image URLs returned HTTP 200.',
  );
  client.close(force: true);
}

Future<void> _verifyCairoPlace(
  PlaceModel place,
  EgyptGovernorate cairo,
  HttpClient client,
  Map<String, ({int statusCode, String? contentType})> checkedImageUrls,
) async {
  if (place.governorate != 'cairo') {
    throw StateError('${place.id} must have governorate cairo');
  }
  if (!GovernorateService.containsCoordinates(cairo, place.lat, place.lng)) {
    throw StateError(
      '${place.id} (${place.lat}, ${place.lng}) is outside Cairo',
    );
  }
  if (GovernorateService.containsCoordinates(
    EgyptGovernorate.byId['alexandria']!,
    place.lat,
    place.lng,
  )) {
    throw StateError('${place.id} is inside Alexandria');
  }
  if (GovernorateService.containsCoordinates(
    EgyptGovernorate.byId['giza']!,
    place.lat,
    place.lng,
  )) {
    throw StateError('${place.id} is inside Giza');
  }
  if (place.nameAr?.trim().isNotEmpty != true ||
      place.nameEn.trim().isEmpty ||
      place.descriptionAr?.trim().isNotEmpty != true ||
      place.descriptionEn.trim().isEmpty) {
    throw StateError('${place.id} needs Arabic and English content');
  }
  if (!_validCategories.contains(place.category)) {
    throw StateError('${place.id} has unsupported category ${place.category}');
  }
  if (place.openHours.trim().isEmpty ||
      !place.rating.isFinite ||
      place.rating < 0 ||
      place.rating > 5 ||
      place.priceNote.trim().isEmpty) {
    throw StateError('${place.id} has incomplete hours, rating, or price data');
  }
  if (!_isHttpsImage(place.imageUrl) ||
      place.imageUrls.isEmpty ||
      !place.imageUrls.every(_isHttpsImage) ||
      place.officialImages.isEmpty) {
    throw StateError('${place.id} has invalid image/fallback configuration');
  }
  for (final url in [place.imageUrl, ...place.imageUrls]) {
    if (checkedImageUrls.containsKey(url)) continue;
    final status = await _imageStatus(url, client);
    checkedImageUrls[url] = status;
    if (status.statusCode != HttpStatus.ok ||
        !(status.contentType?.startsWith('image/') ?? false)) {
      throw StateError(
        '${place.id} image is not an HTTP 200 image '
        '(HTTP ${status.statusCode}, ${status.contentType}): $url',
      );
    }
  }
  if (!place.lat.isFinite || !place.lng.isFinite) {
    throw StateError('${place.id} has invalid coordinates');
  }
}

bool _isHttpsImage(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host == 'upload.wikimedia.org';
}

Future<({int statusCode, String? contentType})> _imageStatus(
  String value,
  HttpClient client,
) async {
  final uri = Uri.parse(value);
  for (var attempt = 0; attempt < 4; attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final request = await client.headUrl(uri);
    var response = await request.close();
    if (response.statusCode == HttpStatus.methodNotAllowed ||
        response.statusCode == HttpStatus.notImplemented) {
      await response.drain<void>();
      response = await (await client.getUrl(uri)).close();
    }
    if (response.statusCode != HttpStatus.tooManyRequests &&
        response.statusCode != HttpStatus.serviceUnavailable) {
      final result = (
        statusCode: response.statusCode,
        contentType: response.headers.contentType?.mimeType,
      );
      await response.drain<void>();
      return result;
    }
    final retryAfter = int.tryParse(
      response.headers.value(HttpHeaders.retryAfterHeader) ?? '',
    );
    await response.drain<void>();
    if (attempt == 3) {
      return (
        statusCode: response.statusCode,
        contentType: response.headers.contentType?.mimeType,
      );
    }
    await Future<void>.delayed(
      Duration(seconds: retryAfter ?? (1 << attempt)),
    );
  }
  throw StateError('Image retry loop ended unexpectedly for $uri');
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
