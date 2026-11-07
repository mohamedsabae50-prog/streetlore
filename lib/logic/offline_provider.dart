import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../core/services/offline_storage_service.dart';
import '../core/services/offline_pack_storage.dart';
import '../data/models/offline_pack.dart';
import '../data/models/itinerary_model.dart';
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

class OfflineDownloadProgress {
  final double progress;
  final int itemsDone;
  final int totalItems;
  final int placesCount;
  final int toursCount;
  final int cachedImagesCount;
  final int sizeBytes;

  const OfflineDownloadProgress({
    required this.progress,
    required this.itemsDone,
    required this.totalItems,
    required this.placesCount,
    required this.toursCount,
    required this.cachedImagesCount,
    required this.sizeBytes,
  });

  double get sizeMb => sizeBytes / (1024 * 1024);
}

typedef DownloadProgress = void Function(OfflineDownloadProgress progress);

class OfflineProvider extends ChangeNotifier {
  final OfflineStorageService _storage = OfflineStorageService.instance;
  final OfflinePackStorage _packStorage;
  List<OfflinePack> _packs = const [];
  List<PlaceModel> _cachedPlaces = const [];
  List<ItineraryModel> _cachedTours = const [];

  List<OfflinePack> get packs => List.unmodifiable(_packs);
  List<PlaceModel> get cachedPlaces => List.unmodifiable(_cachedPlaces);
  List<ItineraryModel> get cachedTours => List.unmodifiable(_cachedTours);

  bool _downloading = false;
  bool get isDownloading => _downloading;
  String? _downloadingPackId;
  String? get downloadingPackId => _downloadingPackId;
  OfflineDownloadProgress _downloadProgress = const OfflineDownloadProgress(
    progress: 0,
    itemsDone: 0,
    totalItems: 0,
    placesCount: 0,
    toursCount: 0,
    cachedImagesCount: 0,
    sizeBytes: 0,
  );
  OfflineDownloadProgress get downloadProgress => _downloadProgress;
  final Set<String> _downloadingPlaceIds = <String>{};

  bool isDownloadingPlace(String placeId) =>
      _downloadingPlaceIds.contains(placeId);

  static List<PlaceModel> get cachedFallback {
    final i = _instance;
    return i == null ? const [] : List.unmodifiable(i._cachedPlaces);
  }

  static OfflineProvider? _instance;
  OfflineProvider({OfflinePackStorage? storage})
    : _packStorage = storage ?? OfflineStorageService.instance {
    _instance = this;
    // Storage is initialised in main() before providers are created, so the
    // downloaded places are available immediately on an offline cold start.
    if (_storage.isReady) {
      try {
        _packs = _packStorage.getAllPacks();
        _cachedPlaces = _packStorage.getCachedPlaces();
        _cachedTours = _packStorage.getDownloadedTours();
      } catch (e) {
        debugPrint('OfflineProvider: hydrate failed: $e');
      }
    } else {
      init();
    }
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
    await _packStorage.init();
    _packs = _packStorage.getAllPacks();
    _cachedPlaces = _packStorage.getCachedPlaces();
    _cachedTours = _packStorage.getDownloadedTours();
    _instance = this;
    notifyListeners();
  }

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
      debugPrint('OfflineProvider.pullAllPlacesFromSupabase: failed: $e\n$st');
      return const [];
    }
  }

  static PlaceModel? findCachedPlace(String id) {
    final i = _instance;
    if (i == null) return null;
    for (final p in i._cachedPlaces) {
      if (p.id == id) return p;
    }
    return null;
  }

  bool isCached(String placeId) => _cachedPlaces.any((p) => p.id == placeId);

  Future<DownloadResult> downloadSinglePlace(
    PlaceModel place, {
    List<String> additionalImageUrls = const [],
  }) async {
    if (!_downloadingPlaceIds.add(place.id)) {
      return DownloadEmpty(
        OfflinePack(
          id: 'single_${place.id}',
          name: place.nameEn,
          description: 'A download for this place is already in progress.',
          placeIds: const [],
          categories: const [],
          sizeMb: 0,
          coverEmoji: '📥',
        ),
      );
    }
    notifyListeners();
    try {
      await _storage.cachePlaces([place]);
      final routeOrigin =
          await _storage.getCurrentLocationForOfflineRoute() ??
          const LatLng(31.2001, 29.9187);
      final routeKey = _storage.entityRouteCacheKey('place', place.id);
      final routePoints = [routeOrigin, LatLng(place.lat, place.lng)];
      await _storage.fetchAndCacheRouteGeometry(routeKey, routePoints);
      await _storage.prefetchOfflineRouteCoverage(routeKey, routePoints);
      await _storage.prefetchMapTiles([LatLng(place.lat, place.lng)]);
      final imgResult = await _storage.prefetchImages(
        [place],
        additionalImageUrls: {place.id: additionalImageUrls},
      );
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
          name: place.nameEn,
          description: 'Single-place offline download',
          placeIds: const [],
          categories: const [],
          sizeMb: 0,
          downloadedAt: null,
          coverEmoji: '📥',
        ),
      );
    } finally {
      _downloadingPlaceIds.remove(place.id);
      notifyListeners();
    }
  }

  Future<void> removeCachedPlace(String placeId) async {
    final i = _instance;
    if (i == null) return;

    await i._storage.removeCachedPlace(placeId);
    _cachedPlaces = _storage.getCachedPlaces();
    notifyListeners();
  }

  Future<DownloadResult> download(
    OfflinePack pack, {
    required List<PlaceModel> availablePlaces,
    List<ItineraryModel> availableTours = const [],
    required bool isPro,
    DownloadProgress? onProgress,
  }) async {
    if (!isPro) {
      return DownloadEmpty(
        OfflinePack(
          id: pack.id,
          name: pack.name,
          description: 'EgyptLore Pro is required to download offline packs.',
        ),
      );
    }
    if (_downloading) {
      return DownloadEmpty(pack);
    }
    _downloading = true;
    _downloadingPackId = pack.id;
    notifyListeners();
    try {
      final selectedPlaces = availablePlaces.where((p) {
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
      final selectedIds = selectedPlaces.map((place) => place.id).toSet();
      final tours = availableTours
          .where((tour) {
            if (pack.id == 'tour_${tour.id}') return true;
            if (pack.placeIds.contains('__all__')) return true;
            if (pack.categories.isEmpty && pack.placeIds.isEmpty) return false;
            return tour.places.any((stop) => selectedIds.contains(stop.id));
          })
          .toList(growable: false);
      final placesById = <String, PlaceModel>{
        for (final place in selectedPlaces) place.id: place,
      };
      for (final tour in tours) {
        for (final stop in tour.places) {
          if (stop.id.isNotEmpty) placesById.putIfAbsent(stop.id, () => stop);
        }
      }
      final places = placesById.values.toList(growable: false);
      if (places.isEmpty && tours.isEmpty) {
        debugPrint('OfflineProvider: no places matched pack "${pack.id}"');
        return DownloadEmpty(pack);
      }

      final imageJobs = <({String id, String? url})>[
        for (final place in places)
          if (place.primaryImage.startsWith('http'))
            (id: place.id, url: place.primaryImage),
        for (final tour in tours)
          if ((tour.coverImageUrl ?? '').startsWith('http'))
            (id: 'tour_${tour.id}', url: tour.coverImageUrl),
      ];
      final totalItems = places.length + tours.length + imageJobs.length;
      var itemsDone = 0;
      var cachedImagesCount = 0;
      var imageBytes = 0;
      var jsonBytes = 0;
      void emitProgress() {
        final progress = OfflineDownloadProgress(
          progress: totalItems == 0 ? 1 : itemsDone / totalItems,
          itemsDone: itemsDone,
          totalItems: totalItems,
          placesCount: places.length,
          toursCount: tours.length,
          cachedImagesCount: cachedImagesCount,
          sizeBytes: jsonBytes + imageBytes,
        );
        _downloadProgress = progress;
        onProgress?.call(progress);
        notifyListeners();
      }

      emitProgress();
      for (final place in places) {
        await _packStorage.cachePlaces([place]);
        itemsDone++;
        emitProgress();
      }
      jsonBytes = await _packStorage.cachePackPayload(
        pack.id,
        places: places,
        tours: tours,
      );
      emitProgress();
      for (var i = 0; i < tours.length; i++) {
        itemsDone++;
        emitProgress();
      }

      int imageOk = 0;
      int imageFail = 0;
      for (final place in places.where(
        (place) => place.primaryImage.startsWith('http'),
      )) {
        await _packStorage.prefetchImages(
          [place],
          primaryOnly: true,
          onProgress: ({required bytes, required cached}) {
            imageBytes += bytes;
            if (cached) {
              cachedImagesCount++;
              imageOk++;
            } else {
              imageFail++;
            }
            itemsDone++;
            emitProgress();
          },
        );
      }
      for (final tour in tours) {
        final url = tour.coverImageUrl;
        if (url == null || !url.startsWith('http')) continue;
        await _packStorage.prefetchExtraImages(
          'tour_${tour.id}',
          [url],
          onProgress: ({required bytes, required cached}) {
            imageBytes += bytes;
            if (cached) {
              cachedImagesCount++;
              imageOk++;
            } else {
              imageFail++;
            }
            itemsDone++;
            emitProgress();
          },
        );
      }

      final updated = pack.copyWith(
        downloadedAt: DateTime.now(),
        downloadedCount: places.length,
        placesCount: places.length,
        toursCount: tours.length,
        cachedImagesCount: cachedImagesCount,
        sizeMb: (jsonBytes + imageBytes) / (1024 * 1024),
      );
      await _packStorage.savePack(updated);
      _packs = _packStorage.getAllPacks();
      _cachedPlaces = _packStorage.getCachedPlaces();
      _cachedTours = _packStorage.getDownloadedTours();
      itemsDone = totalItems;
      emitProgress();
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

  Future<DownloadResult> downloadTour(
    ItineraryModel tour, {
    required List<PlaceModel> availablePlaces,
    required bool isPro,
    DownloadProgress? onProgress,
  }) {
    return download(
      OfflinePack(
        id: 'tour_${tour.id}',
        name: tour.title,
        description: tour.description,
        placeIds: tour.places.map((place) => place.id).toList(growable: false),
      ),
      availablePlaces: availablePlaces,
      availableTours: [tour],
      isPro: isPro,
      onProgress: onProgress,
    );
  }

  Future<void> remove(OfflinePack pack) async {
    await _packStorage.deletePack(pack.id);
    _packs = _packStorage.getAllPacks();
    _cachedPlaces = _packStorage.getCachedPlaces();
    _cachedTours = _packStorage.getDownloadedTours();
    notifyListeners();
  }

  bool isDownloaded(String packId) => _packs.any((p) => p.id == packId);

  double get totalDownloadedMb => _packs.fold(0, (s, p) => s + p.sizeMb);
}
