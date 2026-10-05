import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hive_flutter/hive_flutter.dart';
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

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    if (kIsWeb) {
      try {
        await Hive.initFlutter();
        await Hive.openBox(_packsBox);
        await Hive.openBox(_placesBox);
        await Hive.openBox(_reviewsBox);
        _ready = true;
        debugPrint('OfflineStorageService: Hive ready (web / IndexedDB)');
      } catch (e) {
        debugPrint('OfflineStorageService: web init failed: $e');
      }
      return;
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      Hive.init(dir.path);
      await Hive.openBox(_packsBox);
      await Hive.openBox(_placesBox);
      await Hive.openBox(_reviewsBox);
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
        _ready = true;
      } catch (e2) {
        debugPrint('OfflineStorageService: fallback also failed: $e2');
      }
    }
  }

  bool get isReady => _ready;

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
    if (!_ready) return;
    final box = Hive.box(_placesBox);
    for (final p in places) {
      await box.put(p.id, jsonEncode(p.toJson()));
    }
  }

  
  
  Future<Box<dynamic>> get boxForPlaces async {
    if (!_ready) {
      await init();
    }
    return Hive.box(_placesBox);
  }

  
  
  
  
  Future<({int ok, int failed})> prefetchImages(
    List<PlaceModel> places,
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
      final url = p.imageUrl.trim();
      if (url.isEmpty) continue;
      try {
        final dir = Directory(
          '${docs.path}/offline_images/${_safeSegment(p.id)}',
        );
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        final ext = _extForUrl(url);
        final target = File('${dir.path}/image$ext');
        // v1.0.78 — DefaultCacheManager (used just for the actual
        // download + ETag handling) is copied into our PERMANENT
        // directory so the file survives the OS cache wipe and
        // app reinstalls that preserve the ApplicationDocumentsDirectory.
        final info = await manager.downloadFile(url);
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
          '${p.id} -> $url: $e',
        );
        failed++;
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
      final ext = _extForUrl(imageUrl);
      final f = File('${dir.path}/image$ext');
      return await f.exists() ? f : null;
    } catch (_) {
      return null;
    }
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
