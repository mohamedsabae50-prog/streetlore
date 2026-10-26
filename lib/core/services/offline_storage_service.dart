import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/models/offline_pack.dart';
import '../../data/models/place_model.dart';
import '../../data/models/review_model.dart';

class OfflineStorageService {
  OfflineStorageService._();
  static final OfflineStorageService instance = OfflineStorageService._();

  static const _packsBox = 'offline_packs';
  static const _placesBox = 'offline_places';
  static const _reviewsBox = 'offline_reviews';
  static const _apiResponsesBox = 'offline_api_responses';
  static const syncQueueBox = 'sync_queue';
  static const _tileTemplates = [
    'https://a.tile.openstreetmap.fr/hot',
    'https://tile.openstreetmap.org',
  ];
  static const _tileUserAgent =
      'EgyptLoreApp/2.1 (https://github.com/mohamedsabae50-prog/streetlore)';
  static const _routeEndpoints = [
    'https://routing.openstreetmap.de/routed-foot/route/v1/driving/',
    'https://routing.openstreetmap.de/routed-car/route/v1/driving/',
    'https://router.project-osrm.org/route/v1/driving/',
  ];
  static const _alexandriaRoadSpines = <List<LatLng>>[
    [
      LatLng(31.2135, 29.8750),
      LatLng(31.2150, 29.8900),
      LatLng(31.2160, 29.9050),
      LatLng(31.2155, 29.9200),
      LatLng(31.2145, 29.9350),
      LatLng(31.2130, 29.9500),
      LatLng(31.2110, 29.9650),
      LatLng(31.2085, 29.9800),
    ],
    [
      LatLng(31.1970, 29.8750),
      LatLng(31.1980, 29.8900),
      LatLng(31.1985, 29.9050),
      LatLng(31.1980, 29.9200),
      LatLng(31.1970, 29.9350),
      LatLng(31.1955, 29.9500),
      LatLng(31.1935, 29.9650),
      LatLng(31.1910, 29.9800),
    ],
  ];

  bool _ready = false;
  String? _tileDirectoryPath;
  String? _legacyTileDirectoryPath;
  String? _routeDirectoryPath;

  Future<void> init() async {
    if (_ready) return;
    if (kIsWeb) {
      try {
        await Hive.initFlutter();
        await Hive.openBox(_packsBox);
        await Hive.openBox(_placesBox);
        await Hive.openBox(_reviewsBox);
        await Hive.openBox(_apiResponsesBox);
        await Hive.openBox(syncQueueBox);
        _ready = true;
        debugPrint('OfflineStorageService: Hive ready (web / IndexedDB)');
      } catch (e) {
        debugPrint('OfflineStorageService: web init failed: $e');
      }
      return;
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      await _initializeTileDirectory(dir);
      Hive.init(dir.path);
      await Hive.openBox(_packsBox);
      await Hive.openBox(_placesBox);
      await Hive.openBox(_reviewsBox);
      await Hive.openBox(_apiResponsesBox);
      await Hive.openBox(syncQueueBox);
      _ready = true;
      debugPrint('OfflineStorageService: Hive ready at ${dir.path}');
    } catch (e) {
      debugPrint(
        'OfflineStorageService: native init failed ($e), trying fallback',
      );
      try {
        await Hive.initFlutter();
        await Hive.openBox(_packsBox);
        await Hive.openBox(_placesBox);
        await Hive.openBox(_reviewsBox);
        await Hive.openBox(_apiResponsesBox);
        await Hive.openBox(syncQueueBox);
        _ready = true;
      } catch (e2) {
        debugPrint('OfflineStorageService: fallback also failed: $e2');
      }
    }
  }

  bool get isReady => _ready;

  Future<void> _initializeTileDirectory(Directory documentsDirectory) async {
    final directory = Directory(
      '${documentsDirectory.path}/offline_map_tiles_v3',
    );
    await directory.create(recursive: true);
    _tileDirectoryPath = directory.path;
    final legacyDirectory = Directory(
      '${documentsDirectory.path}/offline_map_tiles_v2',
    );
    _legacyTileDirectoryPath = legacyDirectory.path;
    final routeDirectory = Directory(
      '${documentsDirectory.path}/offline_map_routes_v1',
    );
    await routeDirectory.create(recursive: true);
    _routeDirectoryPath = routeDirectory.path;
  }

  File? getTileFile(int zoom, int x, int y) {
    final path = _tileDirectoryPath;
    if (path == null || kIsWeb) return null;
    return File('$path${Platform.pathSeparator}${zoom}_${x}_$y.png');
  }

  File? getLegacyTileFile(int zoom, int x, int y) {
    final path = _legacyTileDirectoryPath;
    if (path == null || kIsWeb) return null;
    return File(
      '$path${Platform.pathSeparator}$zoom'
      '${Platform.pathSeparator}$x${Platform.pathSeparator}$y.png',
    );
  }

  Future<LatLng?> getCurrentLocationForOfflineRoute() async {
    if (kIsWeb) return null;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return null;
      }
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        return LatLng(lastKnown.latitude, lastKnown.longitude);
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 3),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (error) {
      debugPrint('OfflineStorageService: could not read route origin: $error');
      return null;
    }
  }

  String entityRouteCacheKey(String entityType, String entityId) =>
      'cached_${entityType}_route_${_safeSegment(entityId)}';

  Future<({int cached, int failed})> prefetchMapTiles(
    Iterable<LatLng> locations, {
    double radiusMeters = 1500,
    int minZoom = 12,
    int maxZoom = 16,
  }) async {
    if (kIsWeb) return (cached: 0, failed: 0);
    if (_tileDirectoryPath == null) await init();
    if (_tileDirectoryPath == null) {
      throw StateError('Map tile storage is not available');
    }

    final tiles = <String, (int zoom, int x, int y)>{};
    for (final location in locations) {
      if (!location.latitude.isFinite ||
          !location.longitude.isFinite ||
          location.latitude < -85.0511 ||
          location.latitude > 85.0511) {
        continue;
      }
      for (var zoom = minZoom; zoom <= maxZoom; zoom++) {
        final tileCount = 1 << zoom;
        final latitudeDelta = radiusMeters / 111320;
        final longitudeDelta =
            radiusMeters /
            (111320 * math.cos(location.latitude * 0.017453292519943295).abs());
        final minX = _longitudeToTileX(
          location.longitude - longitudeDelta,
          tileCount,
        );
        final maxX = _longitudeToTileX(
          location.longitude + longitudeDelta,
          tileCount,
        );
        final minY = _latitudeToTileY(
          location.latitude + latitudeDelta,
          tileCount,
        );
        final maxY = _latitudeToTileY(
          location.latitude - latitudeDelta,
          tileCount,
        );
        for (var x = minX; x <= maxX; x++) {
          for (var y = minY; y <= maxY; y++) {
            if (x < 0 || x >= tileCount || y < 0 || y >= tileCount) {
              continue;
            }
            tiles['$zoom/$x/$y'] = (zoom, x, y);
          }
        }
      }
    }

    return _downloadTiles(tiles.values);
  }

  Future<({int cached, int failed})> prefetchAlexandriaOverview() async {
    if (kIsWeb) return (cached: 0, failed: 0);
    if (_tileDirectoryPath == null) await init();
    if (_tileDirectoryPath == null) {
      throw StateError('Map tile storage is not available');
    }
    const minLatitude = 31.11;
    const maxLatitude = 31.30;
    const minLongitude = 29.82;
    const maxLongitude = 30.08;
    final tiles = <String, (int zoom, int x, int y)>{};
    for (var zoom = 11; zoom <= 13; zoom++) {
      final tileCount = 1 << zoom;
      final minX = _longitudeToTileX(minLongitude, tileCount);
      final maxX = _longitudeToTileX(maxLongitude, tileCount);
      final minY = _latitudeToTileY(maxLatitude, tileCount);
      final maxY = _latitudeToTileY(minLatitude, tileCount);
      for (var x = minX; x <= maxX; x++) {
        for (var y = minY; y <= maxY; y++) {
          tiles['$zoom/$x/$y'] = (zoom, x, y);
        }
      }
    }
    return _downloadTiles(tiles.values);
  }

  Future<({int cached, int failed})> prefetchOfflineRouteCoverage(
    String routeKey,
    List<LatLng> routeLocations,
  ) async {
    await prefetchAlexandriaOverview();
    await prefetchRouteGeometry(routeKey, routeLocations);
    final roadGeometry = await getCachedRouteGeometry(routeKey);
    final route = roadGeometry ?? routeLocations;
    final stride = math.max(1, (route.length / 50).ceil());
    final sampledPoints = <LatLng>[];
    for (var index = 0; index < route.length; index += stride) {
      sampledPoints.add(route[index]);
    }
    if (route.isNotEmpty && sampledPoints.last != route.last) {
      sampledPoints.add(route.last);
    }
    final corridor = await prefetchMapTiles(
      sampledPoints,
      radiusMeters: 300,
      minZoom: 13,
      maxZoom: 15,
    );
    final endpoints = route.isEmpty
        ? routeLocations
        : <LatLng>[route.first, route.last];
    final closeUps = await prefetchMapTiles(
      endpoints,
      radiusMeters: 300,
      minZoom: 16,
      maxZoom: 16,
    );
    return (
      cached: corridor.cached + closeUps.cached,
      failed: corridor.failed + closeUps.failed,
    );
  }

  Future<({int cached, int failed})> _downloadTiles(
    Iterable<(int, int, int)> requestedTiles,
  ) async {
    final tiles = requestedTiles.toList(growable: false);
    final pending = <(int, int, int)>[];
    for (final tile in tiles) {
      final file = getTileFile(tile.$1, tile.$2, tile.$3)!;
      if (!await file.exists() || await file.length() <= 100) {
        pending.add(tile);
      }
    }

    var cached = 0;
    var failed = 0;
    final client = http.Client();
    try {
      for (var index = 0; index < pending.length; index++) {
        final tile = pending[index];
        final file = getTileFile(tile.$1, tile.$2, tile.$3)!;
        var downloaded = false;
        for (final template in _tileTemplates) {
          try {
            final response = await client
                .get(
                  Uri.parse('$template/${tile.$1}/${tile.$2}/${tile.$3}.png'),
                  headers: const {if (!kIsWeb) 'User-Agent': _tileUserAgent},
                )
                .timeout(const Duration(seconds: 5));
            if (!_isPngTile(response)) {
              throw HttpException(
                'Map tile request returned ${response.statusCode}',
              );
            }
            await file.parent.create(recursive: true);
            await file.writeAsBytes(response.bodyBytes, flush: true);
            downloaded = true;
            break;
          } on Exception catch (error) {
            debugPrint(
              'OfflineStorageService.prefetchMapTiles '
              '$template ${tile.$1}/${tile.$2}/${tile.$3} failed: $error',
            );
          }
        }
        if (downloaded) {
          cached++;
        } else {
          failed++;
        }
        if (index + 1 < pending.length) {
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
      }
    } finally {
      client.close();
    }
    debugPrint(
      'OfflineStorageService.prefetchMapTiles: '
      '$cached cached, $failed failed, ${tiles.length} total tiles',
    );
    return (cached: cached, failed: failed);
  }

  int _longitudeToTileX(double longitude, int tileCount) =>
      ((longitude + 180) / 360 * tileCount).floor();

  bool _isPngTile(http.Response response) {
    final bytes = response.bodyBytes;
    return response.statusCode == 200 &&
        bytes.length >= 24 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a &&
        bytes[12] == 0x49 &&
        bytes[13] == 0x48 &&
        bytes[14] == 0x44 &&
        bytes[15] == 0x52 &&
        bytes[16] == 0 &&
        bytes[17] == 0 &&
        bytes[18] == 1 &&
        bytes[19] == 0 &&
        bytes[20] == 0 &&
        bytes[21] == 1 &&
        bytes[22] == 0 &&
        bytes[23] == 0;
  }

  String routeCacheKey(Iterable<LatLng> locations) {
    final coordinates = locations
        .map(
          (point) =>
              '${point.longitude.toStringAsFixed(6)},'
              '${point.latitude.toStringAsFixed(6)}',
        )
        .join(';');
    return 'route_${_stableHash(coordinates)}';
  }

  Future<bool> prefetchRouteGeometry(
    String routeKey,
    List<LatLng> locations,
  ) async {
    if (kIsWeb || locations.length < 2) return false;
    if (_routeDirectoryPath == null) await init();
    final directory = _routeDirectoryPath;
    if (directory == null) {
      throw StateError('Offline route storage is not available');
    }
    final file = File('$directory/${_safeSegment(routeKey)}.json');
    if (await file.exists()) return true;

    try {
      final geometry = await fetchAndCacheRouteGeometry(routeKey, locations);
      return geometry != null;
    } catch (error, stackTrace) {
      debugPrint(
        'OfflineStorageService.prefetchRouteGeometry($routeKey) '
        'failed: $error\n$stackTrace',
      );
      return false;
    }
  }

  Future<List<LatLng>?> fetchAndCacheRouteGeometry(
    String routeKey,
    List<LatLng> locations,
  ) async {
    if (locations.length < 2) return null;
    final points = await _fetchStreetRouteGeometry(locations);
    if (points == null) return null;
    if (!kIsWeb) {
      try {
        if (_routeDirectoryPath == null) await init();
        final directory = _routeDirectoryPath;
        if (directory == null) {
          throw StateError('Offline route storage is not available');
        }
        final file = File('$directory/${_safeSegment(routeKey)}.json');
        await file.writeAsString(
          jsonEncode({
            'coordinates': points
                .map((point) => [point.longitude, point.latitude])
                .toList(growable: false),
          }),
          flush: true,
        );
      } catch (error, stackTrace) {
        debugPrint(
          'OfflineStorageService: could not cache a live route: '
          '$error\n$stackTrace',
        );
      }
    }
    return points;
  }

  Future<List<LatLng>?> _fetchStreetRouteGeometry(
    List<LatLng> locations,
  ) async {
    final coordinates = locations
        .map((point) => '${point.longitude},${point.latitude}')
        .join(';');
    for (final endpoint in _routeEndpoints) {
      final uri = Uri.parse(
        '$endpoint$coordinates?geometries=geojson&overview=full',
      );
      try {
        final response = await http
            .get(
              uri,
              headers: const {if (!kIsWeb) 'User-Agent': _tileUserAgent},
            )
            .timeout(const Duration(seconds: 4));
        if (response.statusCode != 200) {
          debugPrint(
            'OfflineStorageService: route endpoint returned '
            '${response.statusCode}: $endpoint',
          );
          continue;
        }
        final decoded = jsonDecode(response.body);
        if (decoded is! Map ||
            decoded['routes'] is! List ||
            (decoded['routes'] as List).isEmpty) {
          debugPrint(
            'OfflineStorageService: route endpoint returned no route: '
            '$endpoint',
          );
          continue;
        }
        final route = (decoded['routes'] as List).first;
        final geometry = route is Map ? route['geometry'] : null;
        final coordinatesJson = geometry is Map
            ? geometry['coordinates']
            : null;
        if (coordinatesJson is! List) {
          debugPrint(
            'OfflineStorageService: route endpoint returned invalid '
            'geometry: $endpoint',
          );
          continue;
        }
        final points = coordinatesJson
            .whereType<List>()
            .where(
              (coordinate) =>
                  coordinate.length >= 2 &&
                  coordinate[0] is num &&
                  coordinate[1] is num,
            )
            .map(
              (coordinate) => LatLng(
                (coordinate[1] as num).toDouble(),
                (coordinate[0] as num).toDouble(),
              ),
            )
            .toList(growable: false);
        if (points.length >= 2) return points;
        debugPrint(
          'OfflineStorageService: route endpoint returned too few points: '
          '$endpoint',
        );
      } catch (error, stackTrace) {
        debugPrint(
          'OfflineStorageService: route request failed at $endpoint: '
          '$error\n$stackTrace',
        );
      }
    }
    return null;
  }

  List<LatLng> buildOfflineRoadCorridor(
    LatLng origin,
    Iterable<LatLng> destinations,
  ) {
    final route = <LatLng>[origin];
    var start = origin;
    for (final destination in destinations) {
      route.addAll(_buildOfflineRoadSegment(start, destination).skip(1));
      start = destination;
    }
    return route;
  }

  List<LatLng> _buildOfflineRoadSegment(LatLng origin, LatLng destination) {
    final inAlexandria = [origin, destination].every(
      (point) =>
          point.latitude >= 31.12 &&
          point.latitude <= 31.30 &&
          point.longitude >= 29.65 &&
          point.longitude <= 30.15,
    );
    if (!inAlexandria) {
      return [
        origin,
        LatLng(
          origin.latitude + (destination.latitude - origin.latitude) * 0.25,
          origin.longitude + (destination.longitude - origin.longitude) * 0.25,
        ),
        LatLng(
          origin.latitude + (destination.latitude - origin.latitude) * 0.5,
          origin.longitude + (destination.longitude - origin.longitude) * 0.5,
        ),
        LatLng(
          origin.latitude + (destination.latitude - origin.latitude) * 0.75,
          origin.longitude + (destination.longitude - origin.longitude) * 0.75,
        ),
        destination,
      ];
    }

    List<LatLng>? bestSpine;
    var nearestOrigin = 0;
    var nearestDestination = 0;
    var bestDistance = double.infinity;
    for (final spine in _alexandriaRoadSpines) {
      var originIndex = 0;
      var destinationIndex = 0;
      var originDistance = double.infinity;
      var destinationDistance = double.infinity;
      for (var index = 0; index < spine.length; index++) {
        final fromOrigin = _routeDistanceMeters(origin, spine[index]);
        final fromDestination = _routeDistanceMeters(destination, spine[index]);
        if (fromOrigin < originDistance) {
          originDistance = fromOrigin;
          originIndex = index;
        }
        if (fromDestination < destinationDistance) {
          destinationDistance = fromDestination;
          destinationIndex = index;
        }
      }
      final totalDistance = originDistance + destinationDistance;
      if (totalDistance < bestDistance) {
        bestDistance = totalDistance;
        bestSpine = spine;
        nearestOrigin = originIndex;
        nearestDestination = destinationIndex;
      }
    }
    final spine = bestSpine!;
    final step = nearestOrigin <= nearestDestination ? 1 : -1;
    return [
      origin,
      spine[nearestOrigin],
      for (
        var index = nearestOrigin + step;
        step > 0 ? index <= nearestDestination : index >= nearestDestination;
        index += step
      )
        spine[index],
      destination,
    ];
  }

  double _routeDistanceMeters(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * earthRadius * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  Future<List<LatLng>?> getCachedRouteGeometry(String routeKey) async {
    if (kIsWeb) return null;
    if (_routeDirectoryPath == null) await init();
    final directory = _routeDirectoryPath;
    if (directory == null) return null;
    try {
      final file = File('$directory/${_safeSegment(routeKey)}.json');
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map || decoded['coordinates'] is! List) {
        throw const FormatException('Cached OSRM geometry was invalid');
      }
      final points = (decoded['coordinates'] as List)
          .whereType<List>()
          .where((coordinate) => coordinate.length >= 2)
          .where((coordinate) => coordinate[0] is num && coordinate[1] is num)
          .map(
            (coordinate) => LatLng(
              (coordinate[1] as num).toDouble(),
              (coordinate[0] as num).toDouble(),
            ),
          )
          .toList(growable: false);
      return points.isEmpty ? null : points;
    } catch (error, stackTrace) {
      debugPrint(
        'OfflineStorageService.getCachedRouteGeometry($routeKey) '
        'failed: $error\n$stackTrace',
      );
      return null;
    }
  }

  int _latitudeToTileY(double latitude, int tileCount) {
    final radians = latitude * 0.017453292519943295;
    final mercator =
        (1 - math.log(math.tan(radians) + 1 / math.cos(radians)) / math.pi) / 2;
    return (mercator * tileCount).floor();
  }

  Future<void> cacheApiRows(String key, List<dynamic> rows) async {
    if (!_ready) return;
    try {
      await Hive.box(_apiResponsesBox).put(key, jsonEncode(rows));
    } catch (e) {
      debugPrint('OfflineStorageService.cacheApiRows($key) failed: $e');
    }
  }

  List<Map<String, dynamic>>? getCachedApiRows(String key) {
    if (!_ready) return null;
    try {
      final encoded = Hive.box(_apiResponsesBox).get(key);
      if (encoded is! String) return null;
      final decoded = jsonDecode(encoded);
      if (decoded is! List) {
        throw const FormatException('Cached API response was not a list');
      }
      return decoded
          .map((row) {
            if (row is! Map) {
              throw const FormatException(
                'Cached API response contained a non-object row',
              );
            }
            return Map<String, dynamic>.from(row);
          })
          .toList(growable: false);
    } catch (e) {
      debugPrint('OfflineStorageService.getCachedApiRows($key) failed: $e');
      return null;
    }
  }

  List<OfflinePack> getAllPacks() {
    if (!_ready) return const [];
    final box = Hive.box(_packsBox);
    return box.values
        .map(
          (e) => OfflinePack.fromJson(
            Map<String, dynamic>.from(jsonDecode(e as String) as Map),
          ),
        )
        .toList();
  }

  Future<void> savePack(OfflinePack pack) async {
    if (!_ready) return;
    final box = Hive.box(_packsBox);
    await box.put(pack.id, jsonEncode(pack.toJson()));
  }

  Future<void> deletePack(String packId) async {
    if (!_ready) return;
    final box = Hive.box(_packsBox);
    await box.delete(packId);
  }

  Future<void> cachePlaces(List<PlaceModel> places) async {
    if (!_ready) await init();
    if (!_ready) {
      throw StateError('Offline storage is not available');
    }
    final box = Hive.box(_placesBox);
    for (final p in places) {
      await box.put(p.id, jsonEncode(p.toJson()));
    }
    await box.flush();
  }

  /// Permanently stores arbitrary image URLs (e.g. a tour cover) under
  /// `offline_images/<folderId>`, and warms the shared image cache used by
  /// CachedNetworkImage so the image renders while offline.
  Future<({int ok, int failed})> prefetchExtraImages(
    String folderId,
    Iterable<String> urls,
  ) async {
    int ok = 0;
    int failed = 0;
    if (kIsWeb) return (ok: 0, failed: 0);
    final Directory docs;
    try {
      docs = await getApplicationDocumentsDirectory();
    } catch (e) {
      debugPrint('OfflineStorageService.prefetchExtraImages: $e');
      return (ok: 0, failed: urls.length);
    }
    final manager = DefaultCacheManager();
    for (final url in urls.toSet()) {
      final cleanUrl = url.trim();
      if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
        continue;
      }
      try {
        final dir = Directory(
          '${docs.path}/offline_images/${_safeSegment(folderId)}',
        );
        if (!await dir.exists()) await dir.create(recursive: true);
        final info = await manager.downloadFile(cleanUrl);
        if (await info.file.exists()) {
          await File(
            '${dir.path}/${_imageFileName(cleanUrl)}',
          ).writeAsBytes(await info.file.readAsBytes(), flush: true);
          ok++;
        } else {
          failed++;
        }
      } catch (e) {
        debugPrint('OfflineStorageService.prefetchExtraImages: $cleanUrl: $e');
        failed++;
      }
    }
    return (ok: ok, failed: failed);
  }

  Future<Box<dynamic>> get boxForPlaces async {
    if (!_ready) {
      await init();
    }
    return Hive.box(_placesBox);
  }

  Future<({int ok, int failed})> prefetchImages(
    List<PlaceModel> places, {
    Map<String, List<String>> additionalImageUrls = const {},
  }) async {
    int ok = 0;
    int failed = 0;
    if (kIsWeb) {
      return (ok: places.length, failed: 0);
    }
    Directory? docs;
    try {
      docs = await getApplicationDocumentsDirectory();
    } catch (e) {
      debugPrint('OfflineStorageService.prefetchImages: docs dir failed: $e');
    }
    if (docs == null) {
      return (ok: 0, failed: places.length);
    }
    final manager = DefaultCacheManager();
    for (final p in places) {
      final imageUrls = {...p.officialImages, ...?additionalImageUrls[p.id]};
      for (final url in imageUrls) {
        final cleanUrl = url.trim();
        if (cleanUrl.isEmpty ||
            (!cleanUrl.startsWith('http://') &&
                !cleanUrl.startsWith('https://'))) {
          continue;
        }
        try {
          final dir = Directory(
            '${docs.path}/offline_images/${_safeSegment(p.id)}',
          );
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          final target = File('${dir.path}/${_imageFileName(cleanUrl)}');
          // Keep permanent copies outside the evictable image cache.
          final info = await manager.downloadFile(cleanUrl);
          if (await info.file.exists()) {
            final bytes = await info.file.readAsBytes();
            await target.writeAsBytes(bytes, flush: true);
            ok++;
          } else {
            failed++;
          }
        } catch (e) {
          debugPrint(
            'OfflineStorageService.prefetchImages: failed for '
            '${p.id} -> $cleanUrl: $e',
          );
          failed++;
        }
      }
    }
    return (ok: ok, failed: failed);
  }

  /// v1.0.78 — look up the permanent copy of an image that
  /// [prefetchImages] wrote. Returns `null` if the file isn't there
  /// yet. Survives app restarts and OS cache wipes.
  Future<File?> getCachedImageFile(String placeId, String imageUrl) async {
    if (kIsWeb) return null;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(
        '${docs.path}/offline_images/${_safeSegment(placeId)}',
      );
      if (!await dir.exists()) return null;
      final f = File('${dir.path}/${_imageFileName(imageUrl)}');
      if (await f.exists()) return f;

      // Backward compatibility for images cached by earlier app versions.
      final legacyFile = File('${dir.path}/image${_extForUrl(imageUrl)}');
      return await legacyFile.exists() ? legacyFile : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> removeCachedPlace(String placeId) async {
    if (!_ready) return;
    await Hive.box(_placesBox).delete(placeId);
    if (kIsWeb) return;
    final docs = await getApplicationDocumentsDirectory();
    final imageDir = Directory(
      '${docs.path}/offline_images/${_safeSegment(placeId)}',
    );
    if (await imageDir.exists()) {
      await imageDir.delete(recursive: true);
    }
  }

  String _imageFileName(String url) {
    final normalizedUrl = url.trim();
    return 'image_${_stableHash(normalizedUrl)}${_extForUrl(normalizedUrl)}';
  }

  String _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(value)) {
      hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// v1.0.78 — strip characters that would break a filesystem path.
  /// Hive keys are often plain integers like "10" / "11" but defensively
  /// normalize anything that could be hostile.
  String _safeSegment(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return cleaned.isEmpty ? 'unknown' : cleaned;
  }

  /// v1.0.78 — file extension for a remote URL. Defaults to `.jpg`.
  String _extForUrl(String url) {
    final lower = url.toLowerCase().split('?').first;
    if (lower.endsWith('.png')) return '.png';
    if (lower.endsWith('.webp')) return '.webp';
    if (lower.endsWith('.gif')) return '.gif';
    if (lower.endsWith('.webm')) return '.webm';
    return '.jpg';
  }

  List<PlaceModel> getCachedPlaces() {
    if (!_ready) return const [];
    final box = Hive.box(_placesBox);
    return box.values
        .map(
          (e) => PlaceModel.fromJson(
            Map<String, dynamic>.from(jsonDecode(e as String) as Map),
          ),
        )
        .toList();
  }

  Future<void> queueReview(ReviewModel review) async {
    if (!_ready) return;
    final box = Hive.box(_reviewsBox);
    await box.put(review.id, jsonEncode(review.toMap()));
  }

  List<ReviewModel> getQueuedReviews() {
    if (!_ready) return const [];
    final box = Hive.box(_reviewsBox);
    return box.values
        .map(
          (e) => ReviewModel.fromMap(
            Map<String, dynamic>.from(jsonDecode(e as String) as Map),
          ),
        )
        .toList();
  }
}
