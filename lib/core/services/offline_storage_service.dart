import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
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
  static const _tileTemplate =
      'https://a.basemaps.cartocdn.com/rastertiles/voyager';

  bool _ready = false;
  String? _tileDirectoryPath;

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
    final directory = Directory('${documentsDirectory.path}/offline_map_tiles');
    await directory.create(recursive: true);
    _tileDirectoryPath = directory.path;
  }

  File? getTileFile(int zoom, int x, int y) {
    final path = _tileDirectoryPath;
    if (path == null || kIsWeb) return null;
    return File('$path/$zoom/$x/$y.png');
  }

  Future<({int cached, int failed})> prefetchMapTiles(
    Iterable<LatLng> locations, {
    double radiusMeters = 1500,
    int minZoom = 13,
    int maxZoom = 17,
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
            (111320 *
                math.cos(location.latitude * 0.017453292519943295).abs());
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

    final pending = <(int, int, int)>[];
    for (final tile in tiles.values) {
      final file = getTileFile(tile.$1, tile.$2, tile.$3)!;
      if (!await file.exists()) pending.add(tile);
    }

    var cached = 0;
    var failed = 0;
    final client = http.Client();
    try {
      for (var offset = 0; offset < pending.length; offset += 8) {
        final batch = pending.skip(offset).take(8);
        final results = await Future.wait(
          batch.map((tile) async {
            final file = getTileFile(tile.$1, tile.$2, tile.$3)!;
            try {
              await file.parent.create(recursive: true);
              final response = await client
                  .get(
                    Uri.parse('$_tileTemplate/${tile.$1}/${tile.$2}/${tile.$3}.png'),
                    headers: const {'User-Agent': 'com.streetlore.app/1.0'},
                  )
                  .timeout(const Duration(seconds: 4));
              if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
                throw HttpException(
                  'Map tile request returned ${response.statusCode}',
                );
              }
              await file.writeAsBytes(response.bodyBytes, flush: true);
              return true;
            } catch (error) {
              debugPrint(
                'OfflineStorageService.prefetchMapTiles '
                '${tile.$1}/${tile.$2}/${tile.$3} failed: $error',
              );
              return false;
            }
          }),
        );
        cached += results.where((result) => result).length;
        failed += results.where((result) => !result).length;
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

  int _latitudeToTileY(double latitude, int tileCount) {
    final radians = latitude * 0.017453292519943295;
    final mercator =
        (1 -
            math.log(
                  math.tan(radians) + 1 / math.cos(radians),
                ) /
                math.pi) /
        2;
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
          await File('${dir.path}/${_imageFileName(cleanUrl)}')
              .writeAsBytes(await info.file.readAsBytes(), flush: true);
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
  }
  ) async {
    int ok = 0;
    int failed = 0;
    if (kIsWeb) {
      return (ok: places.length, failed: 0);
    }
    Directory? docs;
    try {
      docs = await getApplicationDocumentsDirectory();
    } catch (e) {
      debugPrint(
        'OfflineStorageService.prefetchImages: docs dir failed: $e',
      );
    }
    if (docs == null) {
      return (ok: 0, failed: places.length);
    }
    final manager = DefaultCacheManager();
    for (final p in places) {
      final imageUrls = {
        ...p.officialImages,
        ...?additionalImageUrls[p.id],
      };
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
          final target = File(
            '${dir.path}/${_imageFileName(cleanUrl)}',
          );
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
