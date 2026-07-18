import 'dart:convert';
import 'package:flutter/foundation.dart';
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
      
      debugPrint('OfflineStorageService: native init failed ($e), trying fallback');
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
        .map((e) => OfflinePack.fromJson(
            Map<String, dynamic>.from(jsonDecode(e as String) as Map)))
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

  List<PlaceModel> getCachedPlaces() {
    if (!_ready) return const [];
    final box = Hive.box(_placesBox);
    return box.values
        .map((e) => PlaceModel.fromJson(
            Map<String, dynamic>.from(jsonDecode(e as String) as Map)))
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
        .map((e) => ReviewModel.fromMap(
            Map<String, dynamic>.from(jsonDecode(e as String) as Map)))
        .toList();
  }
}
