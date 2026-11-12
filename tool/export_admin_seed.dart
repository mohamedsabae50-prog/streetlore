import 'dart:convert';
import 'dart:io';

import 'package:streetlore/data/cairo_seed.dart';
import 'package:streetlore/data/models/itinerary_model.dart';
import 'package:streetlore/data/models/place_model.dart';

const _placeColumns = [
  'id',
  'name',
  'name_en',
  'name_ar',
  'description',
  'description_en',
  'description_ar',
  'image_url',
  'image_urls',
  'rating',
  'category',
  'category_ar',
  'lat',
  'lng',
  'address',
  'address_ar',
  'open_hours',
  'review_count',
  'price_level',
  'price_note',
  'price_local_egp',
  'price_foreigner_egp',
  'is_hidden_gem',
  'is_featured',
  'display_order',
  'enable_chat',
  'enable_gallery',
  'governorate',
];

const _tourColumns = [
  'id',
  'title',
  'title_ar',
  'description',
  'description_ar',
  'duration',
  'duration_ar',
  'category',
  'category_ar',
  'image_url',
  'status',
  'is_premium',
  'is_hidden_gem',
  'governorate',
];

Future<void> main() async {
  final root = Directory.current;
  final parent = root.parent.path;
  final separator = Platform.pathSeparator;
  final adminAsset = File(
    '$parent${separator}streetlore_admin${separator}assets'
    '${separator}governorate_preview_seed.json',
  );
  final migration = File(
    '${root.path}${separator}supabase${separator}migrations'
    '${separator}draft_cairo_multi_governorate.sql',
  );
  if (!adminAsset.existsSync() || !migration.existsSync()) {
    throw StateError(
      'Run this tool from the streetlore repository beside streetlore_admin.',
    );
  }

  final existing = jsonDecode(await adminAsset.readAsString());
  if (existing is! Map<String, dynamic> ||
      existing['places'] is! List ||
      existing['tours'] is! List) {
    throw const FormatException('Invalid existing admin seed asset.');
  }
  final alexandriaPlaces = (existing['places'] as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .where((place) => place['governorate'] == 'alexandria')
      .toList(growable: false);
  final alexandriaTours = (existing['tours'] as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .where((tour) => tour['governorate'] == 'alexandria')
      .toList(growable: false);

  final cairoPlaces = cairoSeedPlaces.map(_serializePlace).toList();
  final cairoTours = cairoSeedItineraries.map(_serializeTour).toList();
  _verifyCairoSeed(cairoPlaces, cairoTours);

  final placeIds = <String>{
    for (final place in [...alexandriaPlaces, ...cairoPlaces])
      place['id'] as String,
  };
  final tourIds = <String>{
    for (final tour in [...alexandriaTours, ...cairoTours])
      tour['id'] as String,
  };
  if (placeIds.length != alexandriaPlaces.length + cairoPlaces.length ||
      tourIds.length != alexandriaTours.length + cairoTours.length) {
    throw StateError('The combined admin seed contains duplicate IDs.');
  }

  await adminAsset.writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'places': [...alexandriaPlaces, ...cairoPlaces],
      'tours': [...alexandriaTours, ...cairoTours],
    }),
  );
  await migration.writeAsString(await _buildDraftSql(migration));

  stdout.writeln(
    'Exported ${cairoPlaces.length} Cairo places and '
    '${cairoTours.length} Cairo tours; retained '
    '${alexandriaPlaces.length} Alexandria places and '
    '${alexandriaTours.length} Alexandria tours.',
  );
}

Map<String, dynamic> _serializePlace(PlaceModel place) {
  final images = place.officialImages;
  return {
    'id': place.id,
    'name': place.nameEn,
    'name_en': place.nameEn,
    'name_ar': place.nameAr,
    'description': place.descriptionEn,
    'description_en': place.descriptionEn,
    'description_ar': place.descriptionAr,
    'image_url': place.imageUrl,
    'image_urls': images,
    'rating': place.rating,
    'category': place.category,
    'category_ar': place.categoryAr,
    'lat': place.lat,
    'lng': place.lng,
    'address': place.address,
    'address_ar': place.addressAr,
    'governorate': place.governorate,
    'open_hours': place.openHours,
    'review_count': place.reviewCount,
    'price_level': place.priceLevel.name,
    'price_note': place.priceNote,
    'price_local_egp': place.priceLocalEgp,
    'price_foreigner_egp': place.priceForeignerEgp,
    'is_hidden_gem': place.isHiddenGem,
    'is_featured': false,
    'display_order': place.displayOrder,
    'enable_chat': place.enableChat,
    'enable_gallery': place.enableGallery,
  };
}

Map<String, dynamic> _serializeTour(ItineraryModel tour) => {
  'id': tour.id,
  'title': tour.title,
  'title_ar': tour.titleAr,
  'description': tour.description,
  'description_ar': tour.descriptionAr,
  'duration': tour.duration,
  'duration_ar': tour.durationAr,
  'category': 'Heritage',
  'category_ar': 'تراث',
  'image_url': tour.imageUrl,
  'status': tour.status,
  'governorate': tour.governorate,
  'is_premium': tour.isPremium,
  'is_hidden_gem': tour.isHiddenGem,
  'places': tour.places.map(_serializePlace).toList(),
};

void _verifyCairoSeed(
  List<Map<String, dynamic>> places,
  List<Map<String, dynamic>> tours,
) {
  if (places.length != 120 || tours.length != 5) {
    throw StateError(
      'Expected 120 Cairo places and 5 Cairo itineraries; '
      'found ${places.length} and ${tours.length}.',
    );
  }
  final primaryImages = <String>{};
  for (final place in places) {
    final imageUrl = place['image_url'] as String;
    final uri = Uri.tryParse(imageUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'upload.wikimedia.org' ||
        !primaryImages.add(imageUrl)) {
      throw StateError(
        'Invalid or duplicate primary Wikimedia image for ${place['id']}.',
      );
    }
  }
  if (primaryImages.length != places.length) {
    throw StateError('Cairo primary image URLs must be unique.');
  }
  final cairoPlaceIds = places.map((place) => place['id']).toSet();
  for (final tour in tours) {
    final stops = tour['places'] as List<Map<String, dynamic>>;
    if (stops.isEmpty ||
        stops.any((place) => !cairoPlaceIds.contains(place['id']))) {
      throw StateError(
        'Tour ${tour['id']} contains a missing or non-Cairo stop.',
      );
    }
  }
}

Future<String> _buildDraftSql(File migrationFile) async {
  final template = await migrationFile.readAsString();
  const placesMarker = 'INSERT INTO public.places (';
  const viewMarker = 'CREATE OR REPLACE VIEW public.tours_with_places AS';
  final placesStart = template.indexOf(placesMarker);
  final viewStart = template.indexOf(viewMarker);
  if (placesStart < 0 || viewStart <= placesStart) {
    throw const FormatException('Draft migration template is incomplete.');
  }

  final prefix = template
      .substring(0, placesStart)
      .replaceFirst("'Hotels', 'ATM'", "'Hotels', 'ATM', 'Cafes', 'ATMs'");
  final suffix = template.substring(viewStart);
  final places = cairoSeedPlaces.map(_serializePlace).toList();
  final tours = cairoSeedItineraries.map(_serializeTour).toList();
  final placeSql = _placeInsertSql(places);
  final tourSql = _tourInsertSql(tours);
  final waypointSql = _tourPlaceSql(cairoSeedItineraries);
  return '$prefix$placeSql\n$tourSql\n$waypointSql\n$suffix';
}

String _placeInsertSql(List<Map<String, dynamic>> places) {
  final rows = places.map((place) {
    final values = [
      place['id'],
      place['name'],
      place['name_en'],
      place['name_ar'],
      place['description'],
      place['description_en'],
      place['description_ar'],
      place['image_url'],
      place['image_urls'],
      place['rating'],
      place['category'],
      place['category_ar'],
      place['lat'],
      place['lng'],
      place['address'],
      place['address_ar'],
      place['open_hours'],
      place['review_count'],
      place['price_level'],
      place['price_note'],
      place['price_local_egp'],
      place['price_foreigner_egp'],
      place['is_hidden_gem'],
      place['is_featured'],
      place['display_order'],
      place['enable_chat'],
      place['enable_gallery'],
      place['governorate'],
    ];
    return '  (${values.map(_sqlValue).join(', ')})';
  });
  final updates = _placeColumns
      .where((column) => column != 'id')
      .map((column) => '  $column = EXCLUDED.$column')
      .join(',\n');
  return '''
INSERT INTO public.places (
  ${_placeColumns.join(', ')}
)
VALUES
${rows.join(',\n')}
ON CONFLICT (id) DO UPDATE SET
$updates;
''';
}

String _tourInsertSql(List<Map<String, dynamic>> tours) {
  final rows = tours.map((tour) {
    final values = [
      tour['id'],
      tour['title'],
      tour['title_ar'],
      tour['description'],
      tour['description_ar'],
      tour['duration'],
      tour['duration_ar'],
      tour['category'],
      tour['category_ar'],
      tour['image_url'],
      tour['status'],
      tour['is_premium'],
      tour['is_hidden_gem'],
      tour['governorate'],
    ];
    return '  (${values.map(_sqlValue).join(', ')})';
  });
  final updates = _tourColumns
      .where((column) => column != 'id')
      .map((column) => '  $column = EXCLUDED.$column')
      .join(',\n');
  return '''
INSERT INTO public.tours (
  ${_tourColumns.join(', ')}
)
VALUES
${rows.join(',\n')}
ON CONFLICT (id) DO UPDATE SET
$updates;
''';
}

String _tourPlaceSql(List<ItineraryModel> tours) {
  final tourIds = tours.map((tour) => _sqlValue(tour.id)).join(', ');
  final rows = <String>[];
  for (final tour in tours) {
    for (var index = 0; index < tour.places.length; index++) {
      rows.add(
        '  (${_sqlValue(tour.id)}, '
        '${_sqlValue(tour.places[index].id)}, $index)',
      );
    }
  }
  return '''
DELETE FROM public.tour_places
WHERE tour_id IN ($tourIds);
INSERT INTO public.tour_places (tour_id, place_id, position)
VALUES
${rows.join(',\n')}
ON CONFLICT (tour_id, place_id) DO UPDATE
SET position = EXCLUDED.position;
''';
}

String _sqlValue(Object? value) {
  if (value == null) return 'NULL';
  if (value is String) return "'${value.replaceAll("'", "''")}'";
  if (value is bool) return value ? 'TRUE' : 'FALSE';
  if (value is List<String>) {
    return 'ARRAY[${value.map(_sqlValue).join(', ')}]::text[]';
  }
  if (value is num) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'value', 'Must be finite.');
    }
    return value.toString();
  }
  throw ArgumentError.value(value, 'value', 'Unsupported SQL value.');
}
