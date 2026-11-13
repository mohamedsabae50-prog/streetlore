import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:streetlore/core/services/governorate_service.dart';
import 'package:streetlore/data/cairo_image_urls.dart';
import 'package:streetlore/data/cairo_seed.dart';
import 'package:streetlore/data/models/egypt_governorate.dart';
import 'package:streetlore/data/models/place_model.dart';

const _userAgent =
    'StreetLore/2.1 (Cairo seed image resolver; https://github.com/mohamedsabae50-prog/streetlore)';
const _wikipediaEndpoints = [
  'https://en.wikipedia.org/w/api.php',
  'https://ar.wikipedia.org/w/api.php',
];
const _commonsEndpoint = 'https://commons.wikimedia.org/w/api.php';
const _categoryFallbackCategories = {
  'Food',
  'Cafes',
  'Shopping',
  'Hotels',
  'ATMs',
  'Nature',
};
const _exactArticleImagePlaceIds = {
  'misr_grand_mosque_capital',
  'nativity_cathedral_new_capital',
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
};
const _ignoredNameTokens = {
  'the',
  'and',
  'for',
  'from',
  'into',
  'with',
  'cairo',
  'egypt',
  'new',
  'city',
  'القاهرة',
  'مصر',
  'الجديدة',
  'مدينة',
};
const _genericPlaceTokens = {
  'museum',
  'mosque',
  'church',
  'cathedral',
  'monastery',
  'park',
  'garden',
  'palace',
  'hotel',
  'mall',
  'cafe',
  'coffee',
  'market',
  'bazaar',
  'memorial',
  'complex',
  'bridge',
  'tower',
  'house',
  'street',
  'road',
  'restaurant',
  'atm',
  'bank',
  'machine',
  'wikala',
  'island',
  'متحف',
  'مسجد',
  'كنيسة',
  'كاتدرائية',
  'دير',
  'حديقة',
  'محمية',
  'قصر',
  'فندق',
  'مول',
  'مقهى',
  'كافيه',
  'مطعم',
  'سوق',
  'بازار',
  'نصب',
  'مجمع',
  'جسر',
  'برج',
  'شارع',
  'طريق',
  'بنك',
  'مصرف',
  'صراف',
  'آلة',
};
Future<void> _apiQueue = Future<void>.value();
DateTime _nextApiRequestAt = DateTime.fromMillisecondsSinceEpoch(0);

Future<void> main(List<String> args) async {
  if (cairoSeedPlaces.length != 140) {
    throw StateError(
      'Expected 140 Cairo places before resolving images, '
      'found ${cairoSeedPlaces.length}.',
    );
  }
  _verifySeedGeography();
  if (args.contains('--check-geography-only')) {
    stdout.writeln(
      '[PASS] All 140 places are in Cairo, outside Giza/Alexandria, '
      'and at least 25m apart.',
    );
    return;
  }

  final client = HttpClient()..userAgent = _userAgent;
  client.connectionTimeout = const Duration(seconds: 20);
  final partialFile = File('.dart_tool/cairo_image_urls.partial.json');
  await partialFile.parent.create(recursive: true);
  final resolved = <String, String>{};
  final usedUrls = <String>{};
  final usedImageFiles = <String>{};
  final unresolvedPlaces = <String>[];
  if (await partialFile.exists() || cairoImageUrls.isNotEmpty) {
    final decoded = await partialFile.exists()
        ? jsonDecode(await partialFile.readAsString())
        : cairoImageUrls;
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Cairo image cache must be a JSON object.');
    }
    for (final place in cairoSeedPlaces) {
      final cachedUrl = decoded[place.id];
      if (cachedUrl is! String) continue;
      final uri = Uri.tryParse(cachedUrl);
      final isExactArticleImage =
          _exactArticleImagePlaceIds.contains(place.id) &&
          cachedUrl == cairoImageUrls[place.id] &&
          const {
            'en.wikipedia.org',
            'ar.wikipedia.org',
          }.contains(uri?.queryParameters['utm_source']) &&
          uri?.queryParameters['utm_campaign'] == 'api';
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host != 'upload.wikimedia.org' ||
          !_isPhotographTitle(place.nameEn, cachedUrl) ||
          (!isExactArticleImage &&
              !_isRelevantTitle(
                place,
                cachedUrl,
                cachedUrl,
                allowCategoryFallback: _categoryFallbackCategories.contains(
                  place.category,
                ),
              ))) {
        continue;
      }
      final imageFile = _imageFileKey(uri);
      if (usedUrls.contains(cachedUrl) || usedImageFiles.contains(imageFile)) {
        continue;
      }
      resolved[place.id] = cachedUrl;
      usedUrls.add(cachedUrl);
      usedImageFiles.add(imageFile);
    }
    stdout.writeln('[CACHE] Restored ${resolved.length}/140 verified images.');
  }
  var persistQueue = Future<void>.value();
  Future<void> persistPartialResults() {
    persistQueue = persistQueue.then(
      (_) => partialFile.writeAsString(jsonEncode(resolved), flush: true),
    );
    return persistQueue;
  }

  var nextIndex = 0;
  final workers = List.generate(5, (_) async {
    while (true) {
      final index = nextIndex++;
      if (index >= cairoSeedPlaces.length) return;
      final place = cairoSeedPlaces[index];
      if (resolved.containsKey(place.id)) continue;
      try {
        final url = await _resolvePlaceImage(
          place,
          client,
          usedUrls,
          usedImageFiles,
        );
        if (url != null) {
          resolved[place.id] = url;
          stdout.writeln(
            '[RESOLVED ${resolved.length}/140] ${place.id} -> $url',
          );
          await persistPartialResults();
        } else {
          unresolvedPlaces.add(place.id);
          stderr.writeln('[UNRESOLVED] ${place.id}: no exact Wikimedia photo.');
        }
      } on SocketException catch (error) {
        unresolvedPlaces.add(place.id);
        stderr.writeln('[SEARCH FAILED] ${place.id}: $error');
      } on HttpException catch (error) {
        unresolvedPlaces.add(place.id);
        stderr.writeln('[SEARCH FAILED] ${place.id}: $error');
      } on TimeoutException catch (error) {
        unresolvedPlaces.add(place.id);
        stderr.writeln('[SEARCH FAILED] ${place.id}: $error');
      }
    }
  });

  try {
    await Future.wait(workers);
    final fallbackPlaces = cairoSeedPlaces
        .where(
          (place) =>
              unresolvedPlaces.contains(place.id) &&
              _categoryFallbackCategories.contains(place.category) &&
              !_exactArticleImagePlaceIds.contains(place.id),
        )
        .toList(growable: false);
    for (final place in fallbackPlaces) {
      String? url;
      try {
        url = await _resolveCategoryFallback(
          place,
          client,
          usedUrls,
          usedImageFiles,
        );
      } on SocketException catch (error) {
        stderr.writeln('[FALLBACK FAILED] ${place.id}: $error');
      } on HttpException catch (error) {
        stderr.writeln('[FALLBACK FAILED] ${place.id}: $error');
      } on TimeoutException catch (error) {
        stderr.writeln('[FALLBACK FAILED] ${place.id}: $error');
      }
      if (url == null) continue;
      resolved[place.id] = url;
      unresolvedPlaces.remove(place.id);
      stdout.writeln(
        '[CATEGORY IMAGE ${resolved.length}/140] ${place.id} -> $url',
      );
      await persistPartialResults();
    }
    if (resolved.length != 140 ||
        usedUrls.length != 140 ||
        usedImageFiles.length != 140 ||
        unresolvedPlaces.isNotEmpty) {
      await persistQueue;
      throw StateError(
        'Could not produce 140 verified unique images. Resolved '
        '${resolved.length}/140; unresolved: ${unresolvedPlaces.join(', ')}.',
      );
    }

    final source = StringBuffer(
      '// Generated by tool/resolve_and_verify_cairo_images.dart.\n'
      'const Map<String, String> cairoImageUrls = {\n',
    );
    for (final place in cairoSeedPlaces) {
      source.writeln(
        '  ${jsonEncode(place.id)}: ${jsonEncode(resolved[place.id])},',
      );
    }
    source.writeln('};');
    await File(
      'lib/data/cairo_image_urls.dart',
    ).writeAsString(source.toString(), flush: true);
    if (await partialFile.exists()) await partialFile.delete();
    stdout.writeln(
      '[PASS] Resolved and HTTP-verified 140 unique Wikimedia image URLs.',
    );
    stdout.writeln(
      '[PASS] Updated lib/data/cairo_image_urls.dart; rerun '
      '`dart run tool/verify_cairo_seed.dart` in a fresh process.',
    );
  } finally {
    client.close(force: true);
  }
}

void _verifySeedGeography() {
  final cairo = EgyptGovernorate.byId['cairo']!;
  final alexandria = EgyptGovernorate.byId['alexandria']!;
  final giza = EgyptGovernorate.byId['giza']!;
  for (var index = 0; index < cairoSeedPlaces.length; index++) {
    final place = cairoSeedPlaces[index];
    if (!GovernorateService.containsCoordinates(cairo, place.lat, place.lng)) {
      throw StateError(
        '${place.id} (${place.lat}, ${place.lng}) is outside Cairo.',
      );
    }
    if (GovernorateService.containsCoordinates(
      alexandria,
      place.lat,
      place.lng,
    )) {
      throw StateError('${place.id} is inside Alexandria.');
    }
    if (GovernorateService.containsCoordinates(giza, place.lat, place.lng)) {
      throw StateError('${place.id} is inside Giza.');
    }
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
          '${distance.toStringAsFixed(1)}m apart.',
        );
      }
    }
  }
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

Future<String?> _resolvePlaceImage(
  PlaceModel place,
  HttpClient client,
  Set<String> usedUrls,
  Set<String> usedImageFiles,
) async {
  final searchTerms = _searchTerms(place);
  for (final endpoint in _wikipediaEndpoints) {
    for (final term in searchTerms) {
      final candidates = await _wikipediaImages(endpoint, term, client);
      final resolved = await _firstReachableUnique(
        place,
        candidates,
        client,
        usedUrls,
        usedImageFiles,
      );
      if (resolved != null) return resolved;
    }

    if (const {'aisha_fahmy_palace', 'umm_kulthum_museum'}.contains(place.id)) {
      for (final term in searchTerms) {
        final candidates = await _commonsImages(term, client);
        final resolved = await _firstReachableUnique(
          place,
          candidates,
          client,
          usedUrls,
          usedImageFiles,
        );
        if (resolved != null) return resolved;
      }
    }
  }

  for (final term in searchTerms) {
    final candidates = await _commonsImages(term, client, exactPhrase: true);
    final resolved = await _firstReachableUnique(
      place,
      candidates,
      client,
      usedUrls,
      usedImageFiles,
    );
    if (resolved != null) return resolved;
  }
  if (place.id == 'nmec_fustat') {
    for (final request in [
      (
        endpoint: _wikipediaEndpoints.first,
        title: 'National Museum of Egyptian Civilization',
      ),
      (
        endpoint: _wikipediaEndpoints.last,
        title: 'المتحف القومي للحضارة المصرية',
      ),
    ]) {
      final candidates = await _wikipediaPageImages(
        request.endpoint,
        request.title,
        client,
      );
      final resolved = await _firstReachableUnique(
        place,
        candidates,
        client,
        usedUrls,
        usedImageFiles,
      );
      if (resolved != null) return resolved;
    }
  }

  return null;
}

Future<String?> _resolveCategoryFallback(
  PlaceModel place,
  HttpClient client,
  Set<String> usedUrls,
  Set<String> usedImageFiles,
) async {
  for (final term in _categoryFallbackTerms(place)) {
    final candidates = await _commonsImages(term, client);
    final resolved = await _firstReachableUnique(
      place,
      candidates,
      client,
      usedUrls,
      usedImageFiles,
      allowCategoryFallback: true,
    );
    if (resolved != null) return resolved;
  }
  return null;
}

List<String> _searchTerms(PlaceModel place) => [
  place.nameEn,
  '${place.nameEn} Cairo Egypt',
  if (place.nameAr != null) place.nameAr!,
  if (place.id == 'nmec_fustat') ...[
    'NMEC building Cairo Egypt',
    'National Museum of Egyptian Civilization exterior',
  ],
  if (place.id == 'aisha_fahmy_palace') ...[
    'Aisha Fahmy Palace Zamalek',
    'Aisha Fahmy Arts Center Cairo',
    'Palace of Aisha Fahmy Cairo',
    'قصر عائشة فهمي الزمالك',
  ],
  if (place.id == 'umm_kulthum_museum') ...[
    'Umm Kulthum Museum Cairo',
    'Cairo Roda Kalthum Museum',
    'Umm Kulthum museum Manasterly Palace',
    'متحف أم كلثوم القاهرة',
  ],
  if (place.id == 'tahya_misr_bridge_walk') ...[
    'Tahya Misr Bridge Cairo',
    'Tahia Misr Bridge Cairo Egypt',
  ],
  if (place.id == 'child_museum_heliopolis') ...[
    'Child Museum Heliopolis Cairo',
    'Children Museum Cairo Egypt',
    'Children Civilization and Creativity Center Cairo',
    'متحف الطفل مصر الجديدة',
  ],
  if (place.id == 'al_fath_mosque_ramses') ...[
    'Al-Fath Mosque Ramses Square Cairo',
    'Fath Mosque Ramses Cairo',
    'مسجد الفتح ميدان رمسيس القاهرة',
  ],
  if (place.id == 'misr_grand_mosque_capital') ...[
    'Egypt Grand Mosque New Administrative Capital',
    'Masjid Misr New Capital Egypt',
    'مسجد مصر العاصمة الإدارية',
  ],
  if (place.id == 'cave_church_st_simon_mokattam') ...[
    'Saint Simon the Tanner Monastery Cairo',
    'Mokattam Cave Church Cairo Egypt',
    'دير سمعان الخراز المقطم القاهرة',
  ],
  if (place.id == 'nativity_cathedral_new_capital') ...[
    'Cathedral of the Nativity New Administrative Capital Egypt',
    'Christ Nativity Cathedral Egypt New Capital',
    'كاتدرائية ميلاد المسيح العاصمة الإدارية',
  ],
  if (place.id == 'iconic_tower_new_capital') ...[
    'Iconic Tower New Administrative Capital Egypt',
    'Iconic Tower Egypt',
  ],
  if (place.id == 'international_park_nasr_city') ...[
    'International Park Nasr City Cairo',
  ],
  if (place.id == 'merryland_park_heliopolis') ...[
    'Merryland Park Heliopolis Cairo',
  ],
  if (place.id == 'family_park_rehab') ...['Family Park Rehab Cairo Egypt'],
];

List<String> _categoryFallbackTerms(PlaceModel place) {
  final placeText = '${place.nameEn} Cairo Egypt';
  return switch (place.category) {
    'Food' => [
      '$placeText Egyptian food',
      'Egyptian food Cairo',
      'Egyptian koshari Cairo',
      'Egyptian cuisine Cairo food',
      'Egyptian street food Cairo',
      'Egyptian grilled food Cairo',
      'Egyptian dishes Cairo restaurant',
      'Cairo restaurant food Egypt',
      'Egyptian restaurant Cairo meal',
      'Cairo street food Egypt',
      'Cairo Egyptian restaurant dishes',
      'Egyptian rice vegetables meat Cairo',
      'Japanese food Cairo Egypt restaurant',
      'Japanese cuisine Cairo Egypt',
      'grilled meat restaurant Cairo Egypt',
      'Middle Eastern food Egypt restaurant',
      'Cairo Egyptian meal dish',
      'Cairo Egypt cooked food plate',
      'Cairo Egyptian street food dish',
      'fruit Cairo Egypt food',
      'vegetables Cairo Egypt food',
    ],
    'Cafes' => [
      '$placeText cafe',
      'Cairo cafe Egypt',
      'Egyptian cafe Cairo',
      'Cairo coffee shop Egypt',
      'Cairo coffeehouse Egypt',
      'Egyptian tea cafe Cairo',
      'Cairo cafe street Egypt',
      'coffee in Cairo Egypt',
      'Cairo espresso cafe Egypt',
      'Egyptian coffee shop Cairo interior',
      'Cairo coffee Egypt cafe table',
      'Cairo coffeehouse interior Egypt',
      'Egyptian tea coffee Cairo cafe',
      'Cairo cafe espresso machine',
      'coffee shop Egypt Cairo coffee beans',
      'Egyptian cafe Cairo coffee',
      'Cairo cafe table coffee',
      'coffee in Cairo Egypt cafe',
      'Egypt coffeehouse Cairo',
    ],
    'ATMs' => [
      '$placeText Egyptian bank ATM',
      if (place.id.contains('_cib_')) 'Commercial International Bank Cairo',
      if (place.id.contains('_nbe_')) ...[
        'National Bank of Egypt-2020 Cairo',
        'National Bank of Egypt Cairo photo',
        'National Bank of Egypt Cairo',
      ],
      if (place.id.contains('_bm_')) 'Banque Misr Cairo',
      'Cairo ATM machine',
      'Egyptian bank ATM',
      'Cairo bank ATM Egypt',
      'Egypt ATM machine bank',
      'Egyptian bank building',
      'Cairo bank branch Egypt',
      'Egyptian bank branch Cairo',
      'Egypt bank building Cairo',
      'Egyptian cash machine Cairo',
      'National Bank of Egypt ATM Cairo',
      'Banque Misr ATM Egypt',
      'CIB ATM Egypt bank',
      'Egyptian cash machine',
      'ATM machine Egypt',
      'bank ATM Cairo Egypt',
      'bank branch Egypt Cairo',
      'Egyptian bank cash machine',
      'Cairo cash point bank machine',
      'Egypt bank cash dispenser',
      'Egyptian bank office Cairo',
      'Banque Misr Cairo branch',
      'National Bank of Egypt Cairo headquarters',
      'Commercial International Bank Cairo building',
      'Egypt bank branch Cairo building',
      'Banque du Caire bank Cairo branch',
      'Egyptian ATM cash machine Cairo photo',
      'Egyptian bank ATM machine Cairo photo',
      'bank building Egypt Cairo exterior',
      'Cairo bank headquarters Egypt',
      'Egyptian bank branch exterior Cairo',
      'cash dispenser bank Cairo Egypt',
      'NBE Cairo branch Egypt',
      'National Bank of Egypt branch Cairo photo',
      'National Bank of Egypt Cairo building photo',
      'NBE bank building Cairo Egypt',
      'Cairo bank headquarters building Egypt',
      'Egypt bank branch facade Cairo',
    ],
    'Shopping' => [
      '$placeText Cairo mall',
      'Cairo shopping mall Egypt',
      'New Cairo mall Egypt',
      'Cairo shopping center Egypt',
      'Cairo market bazaar Egypt',
      'Egyptian shopping center Cairo',
      'Cairo mall interior Egypt',
      'modern mall Cairo Egypt exterior',
      'Cairo retail shopping center',
      'Cairo supermarket Egypt',
      if (place.id == 'genena_mall_nasr_city') ...[
        'Genena Mall Nasr City Cairo Egypt',
        'Genena Mall Cairo shopping',
        'modern shopping mall Cairo Egypt',
        'shopping centre Nasr City Cairo',
      ],
      if (place.id == 'talaat_harb_shopping_corridor') ...[
        'Talaat Harb Street Cairo shops',
        'Talaat Harb Square Cairo street shops',
        'Downtown Cairo shopping street Egypt',
      ],
    ],
    'Hotels' => [
      '$placeText Cairo hotel',
      'Cairo hotel exterior Egypt',
      'Egyptian hotel Cairo',
      'Cairo hotel building Egypt',
      'Cairo hotel Nile Egypt',
    ],
    'Nature' => [
      '$placeText Cairo park Egypt',
      'Cairo park Egypt',
      'Cairo garden Egypt',
      'Egypt park Cairo',
      'Cairo public garden Egypt',
    ],
    'Mosques' => [
      '$placeText Cairo mosque',
      'historic Cairo mosque',
      'Cairo mosque Egypt',
      'Egyptian mosque Cairo',
      'Cairo Islamic architecture mosque',
    ],
    'Churches' => [
      '$placeText Cairo church',
      'Coptic church Cairo Egypt',
      'Cairo church Egypt',
      'Coptic Cairo church Egypt',
    ],
    'Culture' => [
      '$placeText Cairo museum',
      'Cairo museum Egypt',
      'Egypt museum Cairo',
      'Egyptian museum Cairo exterior',
    ],
    _ => [
      '$placeText Cairo historic',
      'Islamic Cairo historic building',
      'historic Cairo building Egypt',
      'Egyptian historic monument Cairo',
      'Cairo historic architecture Egypt',
    ],
  };
}

typedef _ImageCandidate = ({String title, String url});

Future<List<_ImageCandidate>> _wikipediaImages(
  String endpoint,
  String term,
  HttpClient client,
) async {
  final uri = Uri.parse(endpoint).replace(
    queryParameters: {
      'action': 'query',
      'generator': 'search',
      'gsrsearch': term,
      'gsrlimit': '8',
      'prop': 'pageimages',
      'piprop': 'thumbnail',
      'pithumbsize': '1200',
      'format': 'json',
    },
  );
  final json = await _getJson(uri, client);
  final query = json['query'];
  if (query is! Map || query['pages'] is! Map) {
    return const <_ImageCandidate>[];
  }
  final candidates = <_ImageCandidate>[];
  for (final page in (query['pages'] as Map).values) {
    if (page is! Map) continue;
    final thumbnail = page['thumbnail'];
    if (page['title'] is String &&
        thumbnail is Map &&
        thumbnail['source'] is String) {
      candidates.add((
        title: page['title'] as String,
        url: thumbnail['source'] as String,
      ));
    }
  }
  return candidates;
}

Future<List<_ImageCandidate>> _wikipediaPageImages(
  String endpoint,
  String title,
  HttpClient client,
) async {
  final uri = Uri.parse(endpoint).replace(
    queryParameters: {
      'action': 'query',
      'titles': title,
      'prop': 'pageimages',
      'piprop': 'thumbnail',
      'pithumbsize': '1200',
      'format': 'json',
    },
  );
  final json = await _getJson(uri, client);
  final query = json['query'];
  if (query is! Map || query['pages'] is! Map) {
    return const <_ImageCandidate>[];
  }
  final candidates = <_ImageCandidate>[];
  for (final page in (query['pages'] as Map).values) {
    if (page is! Map || page['title'] is! String) continue;
    final thumbnail = page['thumbnail'];
    if (thumbnail is Map && thumbnail['source'] is String) {
      candidates.add((
        title: page['title'] as String,
        url: thumbnail['source'] as String,
      ));
    }
  }
  return candidates;
}

Future<List<_ImageCandidate>> _commonsImages(
  String term,
  HttpClient client, {
  bool exactPhrase = false,
}) async {
  final uri = Uri.parse(_commonsEndpoint).replace(
    queryParameters: {
      'action': 'query',
      'generator': 'search',
      'gsrsearch': exactPhrase ? '"$term"' : term,
      'gsrnamespace': '6',
      'gsrlimit': '30',
      'prop': 'imageinfo',
      'iiprop': 'url|extmetadata',
      'iiurlwidth': '1200',
      'format': 'json',
    },
  );
  final json = await _getJson(uri, client);
  final query = json['query'];
  if (query is! Map || query['pages'] is! Map) {
    return const <_ImageCandidate>[];
  }
  final candidates = <_ImageCandidate>[];
  for (final page in (query['pages'] as Map).values) {
    if (page is! Map || page['imageinfo'] is! List) continue;
    for (final info in page['imageinfo'] as List) {
      if (info is! Map) continue;
      final url = info['url'] ?? info['thumburl'];
      if (url is String && page['title'] is String) {
        candidates.add((
          title: '${page['title']} ${_imageMetadataText(info['extmetadata'])}',
          url: url,
        ));
      }
    }
  }
  return candidates;
}

String _imageMetadataText(Object? raw) {
  if (raw is! Map) return '';
  final values = <String>[];
  for (final key in ['ObjectName', 'ImageDescription', 'Categories']) {
    final entry = raw[key];
    if (entry is Map && entry['value'] is String) {
      values.add(
        (entry['value'] as String).replaceAll(RegExp(r'<[^>]*>'), ' '),
      );
    }
  }
  return values.join(' ');
}

Future<Map<String, dynamic>> _getJson(Uri uri, HttpClient client) async {
  for (var attempt = 0; attempt < 4; attempt++) {
    await _waitForApiSlot();
    HttpClientResponse response;
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      response = await request.close().timeout(const Duration(seconds: 30));
    } on SocketException {
      if (attempt == 3) rethrow;
      await Future<void>.delayed(Duration(seconds: 1 << attempt));
      continue;
    } on HttpException {
      if (attempt == 3) rethrow;
      await Future<void>.delayed(Duration(seconds: 1 << attempt));
      continue;
    } on TimeoutException {
      if (attempt == 3) rethrow;
      await Future<void>.delayed(Duration(seconds: 1 << attempt));
      continue;
    }
    if (response.statusCode == HttpStatus.tooManyRequests ||
        response.statusCode == HttpStatus.serviceUnavailable) {
      final retryAfter = int.tryParse(
        response.headers.value(HttpHeaders.retryAfterHeader) ?? '',
      );
      await response.drain<void>();
      if (attempt == 3) {
        throw HttpException(
          'MediaWiki API rate limit persisted for $uri',
          uri: uri,
        );
      }
      await Future<void>.delayed(
        Duration(seconds: retryAfter ?? (1 << attempt)),
      );
      continue;
    }
    if (response.statusCode != HttpStatus.ok) {
      final status = response.statusCode;
      await response.drain<void>();
      throw HttpException(
        'MediaWiki API returned HTTP $status for $uri',
        uri: uri,
      );
    }
    final decoded = jsonDecode(await utf8.decoder.bind(response).join());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'MediaWiki API response was not a JSON object.',
      );
    }
    final apiError = decoded['error'];
    if (apiError is Map && apiError['code'] == 'cirrussearch-too-busy-error') {
      if (attempt == 3) {
        throw FormatException('MediaWiki search remained busy for $uri');
      }
      await Future<void>.delayed(Duration(seconds: 1 << attempt));
      continue;
    }
    if (apiError != null) {
      throw FormatException('MediaWiki API error for $uri: $apiError');
    }
    return decoded;
  }
  throw StateError('MediaWiki retry loop ended unexpectedly for $uri');
}

Future<void> _waitForApiSlot() {
  final previous = _apiQueue;
  final completer = Completer<void>();
  _apiQueue = completer.future;
  return previous.then((_) async {
    final delay = _nextApiRequestAt.difference(DateTime.now());
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    _nextApiRequestAt = DateTime.now().add(const Duration(milliseconds: 600));
    completer.complete();
  });
}

Future<String?> _firstReachableUnique(
  PlaceModel place,
  List<_ImageCandidate> candidates,
  HttpClient client,
  Set<String> usedUrls,
  Set<String> usedImageFiles, {
  bool allowCategoryFallback = false,
}) async {
  for (final candidate in candidates) {
    if (!_isRelevantTitle(
      place,
      candidate.title,
      candidate.url,
      allowCategoryFallback: allowCategoryFallback,
    )) {
      continue;
    }
    final uri = Uri.tryParse(candidate.url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'upload.wikimedia.org' ||
        !_isPhotographTitle(candidate.title, candidate.url)) {
      continue;
    }
    final imageFile = _imageFileKey(uri);
    if (!usedUrls.add(candidate.url)) continue;
    if (!usedImageFiles.add(imageFile)) {
      usedUrls.remove(candidate.url);
      continue;
    }
    try {
      if (await _returnsHttp200(uri, client)) return candidate.url;
    } on SocketException {
      usedUrls.remove(candidate.url);
      usedImageFiles.remove(imageFile);
    } on HttpException {
      usedUrls.remove(candidate.url);
      usedImageFiles.remove(imageFile);
    } on TimeoutException {
      usedUrls.remove(candidate.url);
      usedImageFiles.remove(imageFile);
    }
    usedUrls.remove(candidate.url);
    usedImageFiles.remove(imageFile);
  }
  return null;
}

String _imageFileKey(Uri uri) {
  final fileName = uri.pathSegments.last.toLowerCase();
  return fileName
      .replaceFirst(RegExp(r'^\d+px-'), '')
      .replaceFirst(RegExp(r'\.(?:jpe?g|png|tiff?|webp)$'), '');
}

bool _isRelevantTitle(
  PlaceModel place,
  String title,
  String url, {
  required bool allowCategoryFallback,
}) {
  final fileName = Uri.parse(url).pathSegments.last;
  final fileTokens = _tokens(fileName);
  final candidateTokens = fileTokens.union(_tokens(title));
  final identityTokens = _tokens(
    '${place.id.replaceAll('_', ' ')} ${place.nameEn} ${place.nameAr ?? ''}',
  )..removeAll({..._ignoredNameTokens, ..._genericPlaceTokens});
  final matchingIdentityTokens = identityTokens.intersection(fileTokens);
  if (place.id == 'amr_ibn_alas_mosque' &&
      !(fileTokens.contains('amr') &&
          fileTokens.contains('ibn') &&
          (fileTokens.contains('aas') || fileTokens.contains('alas')) &&
          fileTokens.contains('mosque'))) {
    return false;
  }
  if (place.id == 'nmec_fustat' &&
      matchingIdentityTokens.intersection({
            'national',
            'egyptian',
            'civilization',
            'nmec',
          }).length <
          2) {
    return false;
  }
  final geographicTokens = {
    'cairo',
    'egypt',
    'egyptian',
    'nile',
    'zamalek',
    'fustat',
    'heliopolis',
    'maadi',
    'helwan',
    'mokattam',
    'nasr',
    'madinaty',
    'rehab',
    'shorouk',
    'capital',
    'mohandessin',
    'مصر',
    'القاهرة',
    'النيل',
    'الزمالك',
    'الفسطاط',
    'مصر الجديدة',
    'المعادي',
    'حلوان',
    'المقطم',
    'مدينة نصر',
    'مدينتي',
    'الرحاب',
    'الشروق',
    'العاصمة',
  };
  final featureTokens = switch (place.category) {
    'Food' => {
      'food',
      'restaurant',
      'cuisine',
      'bread',
      'dish',
      'fruit',
      'vegetable',
      'koshari',
      'ful',
      'falafel',
      'taameya',
      'hawawshi',
      'mahshi',
      'molokhia',
      'طعام',
      'مطبخ',
      'كشري',
      'فول',
      'فلافل',
      'طعمية',
      'مشويات',
    },
    'Cafes' => {
      'cafe',
      'coffee',
      'espresso',
      'tea',
      'patisserie',
      'bakery',
      if (place.id == 'thirty_north_5a_new_cairo') 'thirty',
      if (place.id == 'vasko_rehab_food_court') 'food',
      'قهوة',
      'مقهى',
      'كافيه',
      'مخبز',
      'حلواني',
    },
    'Shopping' => {
      'mall',
      'shopping',
      'market',
      'bazaar',
      'souq',
      'shop',
      'supermarket',
      'carrefour',
      'retail',
      if (place.id == 'talaat_harb_shopping_corridor') 'street',
      if (place.id == 'talaat_harb_shopping_corridor') 'shops',
      'مول',
      'تسوق',
      'سوق',
      'بازار',
    },
    'ATMs' => {
      'atm',
      'cash',
      'automated',
      'machine',
      'teller',
      'bank',
      'branch',
      'nbe',
      'بنك',
      'مصرف',
      'صراف',
    },
    'Hotels' => {'hotel', 'resort', 'inn', 'فندق'},
    'Mosques' => {'mosque', 'masjid', 'islamic', 'minaret', 'مسجد'},
    'Churches' => {
      'church',
      'cathedral',
      'monastery',
      'coptic',
      'كنيسة',
      'كاتدرائية',
      'دير',
    },
    'Nature' => {
      'park',
      'garden',
      'reserve',
      'protectorate',
      'island',
      'حديقة',
      'محمية',
      'جزيرة',
    },
    _ => {
      'historic',
      'heritage',
      'museum',
      'palace',
      'monument',
      'archaeological',
      'islamic',
      'citadel',
      'gate',
      'street',
      'wikala',
      'nilometer',
      'opera',
      'fortress',
      'bayt',
      'gatehouse',
      'tower',
      'متحف',
      'أوبرا',
      'ثقافة',
      'تاريخي',
      'أثري',
      'تراث',
      'قصر',
      'نصب',
      'إسلامي',
      'عمارة',
    },
  };
  final isGeographic = candidateTokens.any(geographicTokens.contains);
  final hasPlaceFeature = fileTokens.any(featureTokens.contains);
  if (place.category == 'Culture' && !hasPlaceFeature) return false;
  if (place.category == 'ATMs' &&
      fileTokens.any(
        {
          'park',
          'hospital',
          'canal',
          'river',
          'nile',
          'scene',
          'landscape',
          'luxor',
          'thebes',
          'west',
          'ostrakon',
          'receipt',
          'payment',
          'artifact',
          'coin',
          'house',
          'nubian',
          'aswan',
        }.contains,
      )) {
    return false;
  }
  final hasForeignContext = candidateTokens.any(
    {
      'alexandria',
      'giza',
      'paris',
      'france',
      'italy',
      'rome',
      'spain',
      'madrid',
      'germany',
      'berlin',
      'netherlands',
      'amsterdam',
      'japan',
      'tokyo',
      'china',
      'beijing',
      'india',
      'delhi',
      'singapore',
      'sydney',
      'australia',
      'newyork',
      'york',
      'canada',
      'toronto',
      'switzerland',
      'geneva',
      'austria',
      'vienna',
      'lisbon',
      'portugal',
      'doha',
      'qatar',
      'dubai',
      'istanbul',
      'kuwait',
      'bahrain',
      'somalia',
      'mogadishu',
      'palm',
      'florida',
      'america',
      'american',
      'london',
      'waterloo',
      'england',
      'britain',
      'united',
      'kingdom',
    }.contains,
  );
  if (!hasForeignContext &&
      (matchingIdentityTokens.length >= 2 ||
          (isGeographic &&
              matchingIdentityTokens.isNotEmpty &&
              hasPlaceFeature))) {
    return true;
  }
  if (place.id == 'cairo_tower' && fileTokens.containsAll({'cairo', 'tower'})) {
    return true;
  }
  if (!allowCategoryFallback) return false;
  if (hasForeignContext) return false;

  bool hasAny(Set<String> values) => fileTokens.any(values.contains);
  final egyptianDishTokens = {
    'koshari',
    'ful',
    'falafel',
    'taameya',
    'hawawshi',
    'mahshi',
    'molokhia',
    'كشري',
    'فول',
    'فلافل',
    'طعمية',
    'ملوخية',
  };
  final hasEgypt =
      candidateTokens.any(
        {'egypt', 'egyptian', 'cairo', 'مصر', 'القاهرة'}.contains,
      ) ||
      (place.category == 'Food' && hasAny(egyptianDishTokens));
  return switch (place.category) {
    'Food' =>
      hasEgypt &&
          hasAny({
            'food',
            'restaurant',
            'cuisine',
            'bread',
            'dish',
            'fruit',
            'vegetable',
            'koshari',
            'ful',
            'falafel',
            'taameya',
            'hawawshi',
            'mahshi',
            'molokhia',
            'طعام',
            'مطبخ',
            'كشري',
            'فول',
            'فلافل',
            'طعمية',
            'مشويات',
          }),
    'Cafes' =>
      hasEgypt &&
          hasAny({
            'cafe',
            'coffee',
            'espresso',
            'tea',
            'patisserie',
            'bakery',
            'قهوة',
            'مقهى',
            'كافيه',
            'مخبز',
            'حلواني',
          }),
    'ATMs' =>
      hasEgypt &&
          hasAny({
            'atm',
            'cash',
            'automated',
            'machine',
            'teller',
            'bank',
            'branch',
            'بنك',
            'مصرف',
            'صراف',
          }),
    'Hotels' => hasEgypt && hasAny({'hotel', 'resort', 'inn', 'فندق', 'منتجع'}),
    'Shopping' =>
      hasEgypt &&
          hasAny({
            'mall',
            'shopping',
            'market',
            'bazaar',
            'souq',
            'shop',
            'مول',
            'تسوق',
            'سوق',
            'بازار',
          }),
    'Mosques' =>
      hasEgypt &&
          hasAny({'mosque', 'masjid', 'islamic', 'minaret', 'مسجد', 'إسلامي'}),
    'Churches' =>
      hasEgypt &&
          hasAny({
            'church',
            'cathedral',
            'monastery',
            'coptic',
            'كنيسة',
            'كاتدرائية',
            'دير',
            'قبطي',
          }),
    'Nature' =>
      hasEgypt &&
          hasAny({
            'park',
            'garden',
            'reserve',
            'protectorate',
            'island',
            'حديقة',
            'محمية',
            'جزيرة',
          }),
    'Culture' =>
      hasEgypt &&
          hasAny({
            'museum',
            'opera',
            'theatre',
            'theater',
            'culture',
            'متحف',
            'أوبرا',
          }),
    _ =>
      hasEgypt &&
          hasAny({
            'historic',
            'heritage',
            'museum',
            'palace',
            'monument',
            'archaeological',
            'islamic',
            'architecture',
            'تاريخي',
            'أثري',
            'تراث',
            'قصر',
            'نصب',
            'إسلامي',
            'عمارة',
          }),
  };
}

bool _isPhotographTitle(String title, String url) {
  final fileName = Uri.parse(url).pathSegments.last;
  final fullTitle = '$title $fileName';
  final titleTokens = _tokens(fullTitle);
  final path = Uri.parse(url).path.toLowerCase();
  return RegExp(r'\.(?:jpe?g|png|tiff?|webp)$').hasMatch(path) &&
      !RegExp(
        r'(?:^|[^a-z])ad(?:[^a-z]|$)',
        caseSensitive: false,
      ).hasMatch(fullTitle) &&
      !titleTokens.any(
        {
          'logo',
          'map',
          'flag',
          'coat',
          'emblem',
          'icon',
          'chart',
          'coin',
          'dinar',
          'portrait',
          'actor',
          'singer',
          'poster',
          'ad',
          'advertisement',
          'autograph',
          'currency',
          'satellite',
          'modis',
          'earth',
          'globe',
          'diagram',
          'statistics',
          'graph',
        }.contains,
      ) &&
      !path.endsWith('.gif') &&
      !path.endsWith('.svg');
}

Set<String> _tokens(String value) => value
    .replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match[1]} ${match[2]}',
    )
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06ff]+'), ' ')
    .split(' ')
    .where((token) => token.length >= 3)
    .toSet();

Future<bool> _returnsHttp200(Uri uri, HttpClient client) async {
  final request = await client.headUrl(uri);
  final response = await request.close();
  await response.drain<void>();
  return response.statusCode == HttpStatus.ok &&
      (response.headers.contentType?.mimeType.startsWith('image/') ?? false);
}
