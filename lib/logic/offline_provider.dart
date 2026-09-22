import 'package:flutter/foundation.dart';

import '../core/services/offline_storage_service.dart';
import '../data/models/offline_pack.dart';
import '../data/models/place_model.dart';

sealed class DownloadResult {
  const DownloadResult();
}

class DownloadOk extends DownloadResult {
  final int cachedCount;
  final int imagesOk;
  final int imagesFailed;
  const DownloadOk({
    required this.cachedCount,
    required this.imagesOk,
    required this.imagesFailed,
  });
}

class DownloadEmpty extends DownloadResult {
  final OfflinePack pack;
  const DownloadEmpty(this.pack);
}

/// Optional progress callback fired by [OfflineProvider.download].
///
/// - [done] is the number of places whose JSON has been written.
/// - [total] is the total number of places in the pack.
/// - [imageOk] / [imageFail] are running counts of the image prefetch.
typedef DownloadProgress = void Function(
  int done,
  int total, {
  int imageOk,
  int imageFail,
});

class OfflineProvider extends ChangeNotifier {
  final OfflineStorageService _storage = OfflineStorageService.instance;
  List<OfflinePack> _packs = const [];
  List<PlaceModel> _cachedPlaces = const [];

  List<OfflinePack> get packs => List.unmodifiable(_packs);
  List<PlaceModel> get cachedPlaces => List.unmodifiable(_cachedPlaces);

  /// True when at least one pack is currently downloading.
  bool _downloading = false;
  bool get isDownloading => _downloading;
  String? _downloadingPackId;
  String? get downloadingPackId => _downloadingPackId;

  /// Static fallback exposed to [PlaceProvider] so that when the
  /// network is down the app still has real data to show instead of
  /// silently falling back to mock data.
  static List<PlaceModel> get cachedFallback {
    final i = _instance;
    return i == null ? const [] : List.unmodifiable(i._cachedPlaces);
  }

  static OfflineProvider? _instance;
  OfflineProvider() {
    _instance = this;
  }

  static final List<OfflinePack> catalog = [
    OfflinePack(
      id: 'all_alexandria',
      name: 'All Alexandria',
      description: 'Every place, every description, every photo URL.',
      placeIds: const ['__all__'],
      categories: const [],
      sizeMb: 24,
      coverEmoji: 'book',
    ),
    OfflinePack(
      id: 'historical',
      name: 'Historical Alexandria',
      description: 'Citadels, catacombs, pillars, museums.',
      placeIds: const [],
      categories: const ['Historical'],
      sizeMb: 9,
      coverEmoji: 'museum',
    ),
    OfflinePack(
      id: 'culture',
      name: 'Culture & Museums',
      description: 'Libraries, museums and cultural landmarks.',
      placeIds: const [],
      categories: const ['Culture', 'Museums'],
      sizeMb: 8,
      coverEmoji: 'museum',
    ),
    OfflinePack(
      id: 'nature_sea',
      name: 'Nature & Sea Breeze',
      description: 'Gardens, corniche, and the Mediterranean breeze.',
      placeIds: const [],
      categories: const ['Nature', 'Beach'],
      sizeMb: 6,
      coverEmoji: 'beach',
    ),
  ];

  Future<void> init() async {
    await _storage.init();
    _packs = _storage.getAllPacks();
    _cachedPlaces = _storage.getCachedPlaces();
    _instance = this;
    notifyListeners();
  }

  Future<DownloadResult> download(
    OfflinePack pack, {
    required List<PlaceModel> availablePlaces,
    DownloadProgress? onProgress,
  }) async {
    if (_downloading) {
      // Already downloading a different pack — refuse rather than
      // corrupting progress state.
      return DownloadEmpty(pack);
    }
    _downloading = true;
    _downloadingPackId = pack.id;
    notifyListeners();
    try {
      final places = availablePlaces.where((p) {
        final matchesAll = pack.placeIds.contains('__all__');
        if (matchesAll) return true;
        if (pack.placeIds.contains(p.id)) return true;
        if (pack.categories.isNotEmpty &&
            pack.categories
                .map((c) => c.toLowerCase())
                .contains(p.category.toLowerCase())) {
          return true;
        }
        return false;
      }).toList();
      if (places.isEmpty) {
        debugPrint('OfflineProvider: no places matched pack "${pack.id}"');
        return DownloadEmpty(pack);
      }

      // Phase 1: persist the JSON blobs so the place model is
      // available even if image prefetch fails partway through.
      onProgress?.call(0, places.length, imageOk: 0, imageFail: 0);
      for (var i = 0; i < places.length; i++) {
        await _storage.cachePlaces([places[i]]);
        onProgress?.call(
          i + 1,
          places.length,
          imageOk: 0,
          imageFail: 0,
        );
      }

      // Phase 2: prefetch every place's hero image into the disk
      // cache used by CachedNetworkImage.
      int imageOk = 0;
      int imageFail = 0;
      final total = places.length;
      for (var i = 0; i < places.length; i++) {
        final result = await _storage.prefetchImages([places[i]]);
        imageOk += result.ok;
        imageFail += result.failed;
        onProgress?.call(
          total,
          total,
          imageOk: imageOk,
          imageFail: imageFail,
        );
      }

      final updated = pack.copyWith(downloadedAt: DateTime.now());
      await _storage.savePack(updated);
      _packs = _storage.getAllPacks();
      _cachedPlaces = _storage.getCachedPlaces();
      notifyListeners();
      return DownloadOk(
        cachedCount: places.length,
        imagesOk: imageOk,
        imagesFailed: imageFail,
      );
    } finally {
      _downloading = false;
      _downloadingPackId = null;
      notifyListeners();
    }
  }

  Future<void> remove(OfflinePack pack) async {
    await _storage.deletePack(pack.id);
    _packs = _storage.getAllPacks();
    _cachedPlaces = _storage.getCachedPlaces();
    notifyListeners();
  }

  bool isDownloaded(String packId) => _packs.any((p) => p.id == packId);

  int get totalDownloadedMb => _packs.fold(0, (s, p) => s + p.sizeMb);
}
