import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../core/services/offline_storage_service.dart';
import '../data/models/offline_pack.dart';
import '../data/models/place_model.dart';
import 'place_provider.dart' show placeModelFromSupabaseRow;

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

  /// Fetch the full place list directly from Supabase, bypassing the
  /// in-memory `PlaceProvider`. Returns an empty list when offline or
  /// when the Supabase call fails.
  ///
  /// The Offline Download flow uses this when the in-memory place list
  /// looks suspiciously small (less than 5 places), which indicates
  /// `PlaceProvider.loadPlaces()` has not yet finished loading.
  Future<List<PlaceModel>> pullAllPlacesFromSupabase() async {
    if (!AppConfig.supabaseEnabled) {
      debugPrint(
        'OfflineProvider.pullAllPlacesFromSupabase: Supabase disabled in config',
      );
      return const [];
    }
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('places')
          .select()
          .order('id')
          .timeout(const Duration(seconds: 10));
      final list = (res as List<dynamic>)
          .map((row) {
            try {
              final m = Map<String, dynamic>.from(row as Map);
              // Use the snake_case-tolerant parser (NOT PlaceModel.fromJson,
              // which expects camelCase and threw on every Supabase row).
              return placeModelFromSupabaseRow(m);
            } catch (e) {
              debugPrint(
                'OfflineProvider.pullAllPlacesFromSupabase: row parse failed: $e',
              );
              return null;
            }
          })
          .whereType<PlaceModel>()
          .toList();
      debugPrint(
        'OfflineProvider.pullAllPlacesFromSupabase: fetched ${list.length} places',
      );
      return list;
    } catch (e, st) {
      debugPrint(
        'OfflineProvider.pullAllPlacesFromSupabase: failed: $e\n$st',
      );
      return const [];
    }
  }

  /// Look up a place by id from the Hive cache (synchronous, no async
  /// hop). Used by the offline Place Details page when the in-memory
  /// `PlaceProvider` doesn't have the place yet.
  static PlaceModel? findCachedPlace(String id) {
    final i = _instance;
    if (i == null) return null;
    for (final p in i._cachedPlaces) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// True when [place] is already in the local offline cache.
  bool isCached(String placeId) =>
      _cachedPlaces.any((p) => p.id == placeId);

  /// Download a SINGLE place for offline use (one-tap action from the
  /// Place Details screen). Caches the JSON blob AND prefetches the
  /// hero image into the disk cache used by CachedNetworkImage.
  ///
  /// Per the v1.0.22 spec, offline is no longer a global pack-based
  /// action — users grab places one by one from the Place Details page.
  /// Returns a [DownloadOk] with `cachedCount=1` on success.
  Future<DownloadResult> downloadSinglePlace(PlaceModel place) async {
    try {
      // Phase 1: persist the JSON so the model survives a cold start
      // with no network.
      await _storage.cachePlaces([place]);
      // Phase 2: prefetch the hero image.
      final imgResult = await _storage.prefetchImages([place]);
      _cachedPlaces = _storage.getCachedPlaces();
      notifyListeners();
      debugPrint(
        'OfflineProvider: downloaded single place '
        '${place.id} (imgOk=${imgResult.ok}, imgFail=${imgResult.failed})',
      );
      return DownloadOk(
        cachedCount: 1,
        imagesOk: imgResult.ok,
        imagesFailed: imgResult.failed,
      );
    } catch (e) {
      debugPrint('OfflineProvider.downloadSinglePlace error: $e');
      return DownloadEmpty(
        OfflinePack(
          id: 'single_${place.id}',
          name: place.name,
          description: 'Single-place offline download',
          placeIds: const [],
          categories: const [],
          sizeMb: 0,
          downloadedAt: null,
          coverEmoji: '📥',
        ),
      );
    }
  }

  /// Remove a single place from the offline cache (its JSON + image
  /// eviction is handled by Hive's TTL on the cache manager).
  Future<void> removeCachedPlace(String placeId) async {
    final i = _instance;
    if (i == null) return;
    // Hive stores each place under its own key — drop just that one.
    final box = await (i._storage).boxForPlaces;
    await box.delete(placeId);
    _cachedPlaces = _storage.getCachedPlaces();
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
