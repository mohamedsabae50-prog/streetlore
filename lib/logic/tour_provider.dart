import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/offline_storage_service.dart';
import '../core/services/supabase_service.dart';
import '../data/models/itinerary_model.dart';
import '../data/models/place_model.dart';
import '../data/mock_data.dart' show fallbackTours;
import 'governorate_provider.dart';

int visitedStopsCountForTour(
  Tour tour,
  Set<String> visitedPlaceIds,
  List<PlaceModel> allPlaces,
) {
  final visitedPlaces = allPlaces
      .where((place) => visitedPlaceIds.contains(place.id))
      .toList(growable: false);
  return tour.places.where((stop) {
    if (visitedPlaceIds.contains(stop.id)) return true;
    return visitedPlaces.any((visited) => _placesMatch(stop, visited));
  }).length;
}

bool isTourAutomaticallyVisited(
  Tour tour,
  Set<String> visitedPlaceIds,
  List<PlaceModel> allPlaces,
) {
  final status = tour.status.trim().toLowerCase();
  if (status == 'completed' || status == 'visited') return true;
  return tour.places.isNotEmpty &&
      visitedStopsCountForTour(tour, visitedPlaceIds, allPlaces) ==
          tour.places.length;
}

bool _placesMatch(PlaceModel a, PlaceModel b) {
  if (a.id.isNotEmpty && a.id == b.id) return true;
  final aNames = [a.nameEn, a.nameAr]
      .whereType<String>()
      .map(_normalizePlaceName)
      .where((name) => name.isNotEmpty);
  final bNames = [b.nameEn, b.nameAr]
      .whereType<String>()
      .map(_normalizePlaceName)
      .where((name) => name.isNotEmpty)
      .toSet();
  if (aNames.any(bNames.contains)) return true;
  if (!_hasValidCoordinates(a) || !_hasValidCoordinates(b)) return false;
  return _placeDistanceMeters(a, b) <= 120;
}

bool _hasValidCoordinates(PlaceModel place) =>
    place.lat.isFinite &&
    place.lng.isFinite &&
    place.lat >= -90 &&
    place.lat <= 90 &&
    place.lng >= -180 &&
    place.lng <= 180 &&
    (place.lat != 0 || place.lng != 0);

String _normalizePlaceName(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

double _placeDistanceMeters(PlaceModel a, PlaceModel b) {
  const earthRadius = 6371000.0;
  final lat1 = a.lat * 0.017453292519943295;
  final lat2 = b.lat * 0.017453292519943295;
  final dLat = (b.lat - a.lat) * 0.017453292519943295;
  final dLng = (b.lng - a.lng) * 0.017453292519943295;
  final h =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * earthRadius * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}

class TourProvider extends ChangeNotifier {
  SupabaseClient get _client => Supabase.instance.client;

  List<ItineraryModel> _tours = [];
  final GovernorateProvider? governorates;
  List<ItineraryModel> get tours => List.unmodifiable(
    _tours.where(
      (tour) =>
          tour.governorate == (governorates?.activeGovernorate ?? 'alexandria'),
    ),
  );

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  List<ItineraryModel> _savedTours = [];
  List<ItineraryModel> get savedTours => _savedTours
      .where(
        (tour) =>
            tour.governorate ==
            (governorates?.activeGovernorate ?? 'alexandria'),
      )
      .toList(growable: false);
  final Set<String> _downloadingTourIds = <String>{};

  bool isDownloadingTour(String tourId) => _downloadingTourIds.contains(tourId);

  final Set<String> _checkedInPlaceIds = <String>{};
  final Set<String> _automaticallyVisitedTourIds = <String>{};
  List<PlaceModel> _allPlaces = const [];
  String? _checkInUserId;
  Set<String> get checkedInPlaceIds => Set.unmodifiable(_checkedInPlaceIds);
  bool _checkInsLoaded = false;
  bool get checkInsLoaded => _checkInsLoaded;
  Set<String> get visitedTourIds => Set.unmodifiable(
    _tours.where((tour) => isTourVisited(tour.id)).map((tour) => tour.id),
  );
  int get visitedToursCount => visitedTourIds.length;

  bool isTourVisited(String tourId) {
    final matches = _tours.where((tour) => tour.id == tourId);
    if (matches.isEmpty) return false;
    final tour = matches.first;
    return _automaticallyVisitedTourIds.contains(tourId) ||
        isTourAutomaticallyVisited(tour, _checkedInPlaceIds, _allPlaces);
  }

  int checkedInPlaceCount(ItineraryModel tour) =>
      visitedStopsCountForTour(tour, _checkedInPlaceIds, _allPlaces);

  void markPlaceCheckedIn(String placeId) {
    _checkInsLoaded = true;
    if (placeId.isNotEmpty && _checkedInPlaceIds.add(placeId)) {
      _updateAutomaticallyVisitedTours();
      notifyListeners();
    }
  }

  void unmarkPlaceCheckedIn(String placeId) {
    _checkInsLoaded = true;
    if (placeId.isNotEmpty && _checkedInPlaceIds.remove(placeId)) {
      _updateAutomaticallyVisitedTours();
      notifyListeners();
    }
  }

  void syncVisitedPlaces(
    Set<String> visitedPlaceIds,
    List<PlaceModel> allPlaces,
  ) {
    final changed =
        !_checkedInPlaceIds.containsAll(visitedPlaceIds) ||
        !visitedPlaceIds.containsAll(_checkedInPlaceIds) ||
        !listEquals(_allPlaces, allPlaces);
    _checkedInPlaceIds
      ..clear()
      ..addAll(visitedPlaceIds);
    _allPlaces = List.unmodifiable(allPlaces);
    _checkInsLoaded = true;
    final completionChanged = _updateAutomaticallyVisitedTours();
    if (changed || completionChanged) notifyListeners();
  }

  bool _updateAutomaticallyVisitedTours() {
    final completed = _tours
        .where(
          (tour) =>
              tour.places.isNotEmpty &&
              visitedStopsCountForTour(tour, _checkedInPlaceIds, _allPlaces) ==
                  tour.places.length,
        )
        .map((tour) => tour.id)
        .toSet();
    if (setEquals(_automaticallyVisitedTourIds, completed)) return false;
    _automaticallyVisitedTourIds
      ..clear()
      ..addAll(completed);
    unawaited(_persistAutomaticallyVisitedTours());
    return true;
  }

  Future<void> _persistAutomaticallyVisitedTours() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'automatically_visited_tour_ids',
        _automaticallyVisitedTourIds.toList(growable: false),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'TourProvider: failed to persist completed tours: '
        '$error\n$stackTrace',
      );
    }
  }

  void clearCheckedInPlaces() {
    _checkInUserId = null;
    _checkInsLoaded = false;
    if (_checkedInPlaceIds.isEmpty && _automaticallyVisitedTourIds.isEmpty) {
      return;
    }
    _checkedInPlaceIds.clear();
    _updateAutomaticallyVisitedTours();
    notifyListeners();
  }

  TourProvider({this.governorates}) {
    governorates?.addListener(_onGovernorateChanged);
    _loadSavedTours();
  }

  void _onGovernorateChanged() => notifyListeners();

  @override
  void dispose() {
    governorates?.removeListener(_onGovernorateChanged);
    super.dispose();
  }

  Future<void> loadTours({bool force = false}) async {
    if (_loading) return;
    if (!force && _tours.isNotEmpty) return;
    final storage = OfflineStorageService.instance;
    if (_tours.isEmpty) {
      final cachedRows = storage.getCachedApiRows('supabase_tours');
      if (cachedRows != null && cachedRows.isNotEmpty) {
        try {
          _tours = cachedRows.map(_tourFromSupabase).toList(growable: false);
        } catch (e) {
          debugPrint('TourProvider.loadTours: cached response invalid: $e');
        }
      }
      if (_tours.isEmpty) {
        _tours = List<ItineraryModel>.from(fallbackTours);
      }
      notifyListeners();
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _client
          .from('tours_with_places')
          .select()
          .eq('status', 'published')
          .order('id')
          .timeout(const Duration(seconds: 3));
      final rows = (res as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);
      await storage.cacheApiRows('supabase_tours', rows);
      final loaded = rows.map(_tourFromSupabase).toList();
      if (loaded.isEmpty) {
        _tours = List<ItineraryModel>.from(fallbackTours);
      } else {
        _tours = loaded;
      }
      _updateAutomaticallyVisitedTours();
      _error = null;
    } catch (e) {
      _error = 'Failed to load tours: $e';
      debugPrint('TourProvider: $e');
      if (_tours.isEmpty) {
        _tours = List<ItineraryModel>.from(fallbackTours);
      }
    } finally {
      _loading = false;
      _updateAutomaticallyVisitedTours();
      notifyListeners();
    }
  }

  Future<void> refresh() => loadTours(force: true);

  ItineraryModel _tourFromSupabase(Map<String, dynamic> json) {
    final placesJson = (json['places'] as List<dynamic>?) ?? const [];
    final places = placesJson
        .map((e) => _placeFromSupabaseJson(e as Map<String, dynamic>))
        .toList();
    final governorate = (json['governorate'] as String?)?.trim().toLowerCase();
    return ItineraryModel(
      id: json['id'] as String,
      title: json['title'] as String,
      titleAr: json['title_ar'] as String?,
      description: json['description'] as String,
      descriptionAr: json['description_ar'] as String?,
      duration: json['duration'] as String,
      durationAr: json['duration_ar'] as String?,
      imageUrl: (json['image_url'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'published',
      governorate: governorate == null || governorate.isEmpty
          ? 'alexandria'
          : governorate,
      isPremium: (json['is_premium'] as bool?) ?? false,
      isHiddenGem: (json['is_hidden_gem'] as bool?) ?? false,
      places: places,
    );
  }

  PlaceModel _placeFromSupabaseJson(Map<String, dynamic> json) {
    final governorate = (json['governorate'] as String?)?.trim().toLowerCase();
    return PlaceModel(
      id: (json['id'] as String?) ?? '',
      nameEn:
          (json['name_en'] as String?) ??
          (json['name'] as String?) ??
          'Unknown Place',
      nameAr: json['name_ar'] as String?,
      descriptionEn:
          (json['description_en'] as String?) ??
          (json['description'] as String?) ??
          '',
      descriptionAr: json['description_ar'] as String?,

      imageUrl:
          (json['image_url'] as String?) ?? (json['imageUrl'] as String?) ?? '',
      imageUrls: _imageUrlsFromJson(json['image_urls']),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      category: (json['category'] as String?) ?? 'General',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      address: (json['address'] as String?) ?? 'Alexandria, Egypt',
      governorate: governorate == null || governorate.isEmpty
          ? 'alexandria'
          : governorate,
      openHours:
          (json['open_hours'] as String?) ??
          (json['openHours'] as String?) ??
          '9:00 AM - 6:00 PM',
      reviewCount:
          (json['review_count'] as int?) ?? (json['reviewCount'] as int?) ?? 0,
      priceLevel: _priceLevelFromString(
        (json['price_level'] as String?) ?? (json['priceLevel'] as String?),
      ),
      priceNote:
          (json['price_note'] as String?) ??
          (json['priceNote'] as String?) ??
          '',
      isHiddenGem:
          (json['is_hidden_gem'] as bool?) ??
          (json['isHiddenGem'] as bool?) ??
          false,
      priceLocalEgp:
          (json['price_local_egp'] as int?) ?? (json['priceLocalEgp'] as int?),
      priceForeignerEgp:
          (json['price_foreigner_egp'] as int?) ??
          (json['priceForeignerEgp'] as int?),
    );
  }

  List<String> _imageUrlsFromJson(dynamic value) {
    if (value is! List) return const <String>[];
    return value
        .whereType<Object>()
        .map((url) => url.toString().trim())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
  }

  PriceLevel _priceLevelFromString(String? s) {
    switch (s) {
      case 'cheap':
        return PriceLevel.cheap;
      case 'moderate':
        return PriceLevel.moderate;
      case 'expensive':
        return PriceLevel.expensive;
      default:
        return PriceLevel.free;
    }
  }

  Future<void> _loadSavedTours() async {
    final prefs = await SharedPreferences.getInstance();
    final String? toursJson = prefs.getString('saved_tours_data');
    if (toursJson != null) {
      final List<dynamic> decodedList = json.decode(toursJson);
      _savedTours = decodedList
          .map((item) => ItineraryModel.fromJson(item))
          .toList();
      notifyListeners();
    }
  }

  Future<void> _saveToursToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedList = json.encode(
      _savedTours.map((t) => t.toJson()).toList(),
    );
    await prefs.setString('saved_tours_data', encodedList);
  }

  Future<bool> bootstrapForUser(String userId) async {
    if (userId.isEmpty) return false;
    if (_checkInUserId != userId) {
      _checkInUserId = userId;
      _checkInsLoaded = false;
      _checkedInPlaceIds.clear();
      notifyListeners();
    }
    final remoteMaps = await SupabaseService.instance.pullSavedTours(userId);
    if (remoteMaps.isEmpty) {
      debugPrint(
        'TourProvider: no remote saved tours for $userId, keeping local',
      );
    } else {
      final remote = <ItineraryModel>[];
      for (final m in remoteMaps) {
        try {
          remote.add(ItineraryModel.fromJson(m));
        } catch (_) {}
      }
      final remoteIds = remote.map((t) => t.id).toSet();
      final localOnly = _savedTours
          .where((t) => !remoteIds.contains(t.id))
          .toList();
      final merged = [...remote, ...localOnly];
      _savedTours = merged;
      await _saveToursToStorage();
      notifyListeners();
      debugPrint(
        'TourProvider: pulled ${remote.length} saved tours for $userId '
        '(total now ${merged.length})',
      );
    }

    await _syncVisitedFromCheckins(userId);
    return true;
  }

  Future<void> _syncVisitedFromCheckins(String userId) async {
    if (_tours.isEmpty) {
      try {
        await loadTours();
      } catch (_) {}
    }

    try {
      final res = await _client
          .from('place_checkins')
          .select('place_id')
          .eq('user_id', userId);
      final checkedInPlaceIds = (res as List)
          .map((e) => (e as Map<String, dynamic>)['place_id'] as String?)
          .whereType<String>()
          .toSet();

      final wasLoaded = _checkInsLoaded;
      _checkInsLoaded = true;
      final changed =
          !_checkedInPlaceIds.containsAll(checkedInPlaceIds) ||
          !checkedInPlaceIds.containsAll(_checkedInPlaceIds);
      if (changed) {
        _checkedInPlaceIds
          ..clear()
          ..addAll(checkedInPlaceIds);
      }
      _updateAutomaticallyVisitedTours();
      if (changed || !wasLoaded) {
        notifyListeners();
        debugPrint(
          'TourProvider: synced visited tours from place_checkins -> '
          '$visitedToursCount completed',
        );
      }
    } catch (e) {
      debugPrint('TourProvider._syncVisitedFromCheckins error: $e');
    }
  }

  void toggleTourSaved(ItineraryModel tour) {
    final isExisting = _savedTours.any((t) => t.id == tour.id);
    if (isExisting) {
      _savedTours.removeWhere((t) => t.id == tour.id);
    } else {
      _savedTours.add(tour);
    }
    _saveToursToStorage();
    notifyListeners();
  }

  /// Saves (or removes) a tour for offline use and, when saving, really
  /// downloads its data to disk:
  ///   * tour details + stops JSON  -> SharedPreferences (`saved_tours_data`)
  ///   * every stop PlaceModel      -> Hive `offline_places` box
  ///   * stop images + tour cover   -> `<docs>/offline_images/...` (permanent)
  /// Returns `null` when the tour was removed, otherwise the image result.
  Future<({int ok, int failed})?> toggleTourOffline(ItineraryModel tour) async {
    if (isDownloadingTour(tour.id)) return (ok: 0, failed: 0);
    final isExisting = _savedTours.any((t) => t.id == tour.id);
    if (isExisting) {
      _savedTours.removeWhere((t) => t.id == tour.id);
      await _saveToursToStorage();
      notifyListeners();
      return null;
    }
    _downloadingTourIds.add(tour.id);
    notifyListeners();
    try {
      final result = await downloadTourAssets(tour);
      _savedTours.add(tour);
      await _saveToursToStorage();
      return result;
    } finally {
      _downloadingTourIds.remove(tour.id);
      notifyListeners();
    }
  }

  Future<({int ok, int failed})> downloadTourAssets(ItineraryModel tour) async {
    final storage = OfflineStorageService.instance;
    var ok = 0;
    var failed = 0;
    try {
      final stops = tour.places.where((p) => p.id.isNotEmpty).toList();
      if (stops.isNotEmpty) {
        await storage.cachePlaces(stops);
        final routeOrigin =
            await storage.getCurrentLocationForOfflineRoute() ??
            const LatLng(31.2001, 29.9187);
        final routePoints = <LatLng>[
          routeOrigin,
          ...stops.map((place) => LatLng(place.lat, place.lng)),
        ];
        await storage.fetchAndCacheRouteGeometry(
          storage.entityRouteCacheKey('tour', tour.id),
          routePoints,
        );
        await storage.prefetchOfflineRouteCoverage(
          storage.entityRouteCacheKey('tour', tour.id),
          routePoints,
        );
        await storage.prefetchMapTiles(
          stops.map((place) => LatLng(place.lat, place.lng)),
        );
        final stopRoutePoints = stops
            .map((place) => LatLng(place.lat, place.lng))
            .toList(growable: false);
        if (stopRoutePoints.length > 1) {
          await storage.prefetchRouteGeometry(
            storage.routeCacheKey(stopRoutePoints),
            stopRoutePoints,
          );
        }
        final stopImages = await storage.prefetchImages(stops);
        ok += stopImages.ok;
        failed += stopImages.failed;
      }
      final coverUrls = <String>{
        if (tour.imageUrl.isNotEmpty) tour.imageUrl,
        if ((tour.coverImageUrl ?? '').isNotEmpty) tour.coverImageUrl!,
      };
      if (coverUrls.isNotEmpty) {
        final cover = await storage.prefetchExtraImages(
          'tour_${tour.id}',
          coverUrls,
        );
        ok += cover.ok;
        failed += cover.failed;
      }
      debugPrint(
        'TourProvider: tour ${tour.id} saved offline '
        '(${stops.length} stops, imgOk=$ok, imgFail=$failed)',
      );
    } catch (e, st) {
      debugPrint('TourProvider.downloadTourAssets failed: $e\n$st');
      failed++;
    }
    return (ok: ok, failed: failed);
  }

  bool isSaved(String id) {
    return _savedTours.any((t) => t.id == id);
  }
}
