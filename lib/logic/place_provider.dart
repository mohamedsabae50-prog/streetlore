import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/mock_data.dart' show fallbackPlaces;
import '../data/models/place_model.dart';
import 'offline_provider.dart';

class PlaceProvider extends ChangeNotifier {
  SupabaseClient get _client => Supabase.instance.client;

  List<PlaceModel> _places = [];
  List<PlaceModel> get places => List.unmodifiable(_places);

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  List<PlaceModel> _savedPlaces = [];
  List<PlaceModel> get savedPlaces => _savedPlaces;

  bool _isFilterOpenNow = false;
  bool _isFilterCheapest = false;
  bool _isFilterNearest = false;
  /// Max price level the user wants to see (null = any).
  PriceLevel? _maxPriceLevel;
  /// Show only free places when true (overrides _maxPriceLevel).
  bool _onlyFree = false;

  bool get isFilterOpenNow => _isFilterOpenNow;
  bool get isFilterCheapest => _isFilterCheapest;
  bool get isFilterNearest => _isFilterNearest;
  PriceLevel? get maxPriceLevel => _maxPriceLevel;
  bool get onlyFree => _onlyFree;

  PlaceProvider() {
    _loadSavedPlaces();
  }

  Future<void> loadPlaces({bool force = false}) async {
    if (_loading) return;
    if (!force && _places.isNotEmpty) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _client
          .from('places')
          .select()
          .order('id')
          .timeout(const Duration(seconds: 10));
      final list = (res as List<dynamic>)
          .map((e) => _placeFromSupabase(e as Map<String, dynamic>))
          .toList();
      if (list.isEmpty) {
        _places = List<PlaceModel>.from(fallbackPlaces);
        _error = null;
      } else {
        _places = list;
        _error = null;
      }
    } catch (e) {
      _error = 'Failed to load places: $e';
      // Prefer real cached places over mock data when offline.
      final cached = OfflineProvider.cachedFallback;
      if (cached.isNotEmpty) {
        _places = cached;
      } else {
        _places = List<PlaceModel>.from(fallbackPlaces);
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> ensureLoaded() async {
    if (_places.isEmpty) {
      await loadPlaces(force: true);
    }
  }

  Future<void> refresh() => loadPlaces(force: true);

  PlaceModel? findById(String id) {
    for (final p in _places) {
      if (p.id == id) return p;
    }
    return null;
  }

  PlaceModel _placeFromSupabase(Map<String, dynamic> json) {
    return PlaceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      nameAr: json['name_ar'] as String?,
      description: json['description'] as String,
      descriptionAr: json['description_ar'] as String?,
      imageUrl: json['image_url'] as String,
      rating: (json['rating'] as num).toDouble(),
      category: json['category'] as String,
      categoryAr: json['category_ar'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      address: (json['address'] as String?) ?? 'Alexandria, Egypt',
      addressAr: json['address_ar'] as String?,
      openHours: (json['open_hours'] as String?) ?? '9:00 AM - 6:00 PM',
      reviewCount: (json['review_count'] as int?) ?? 0,
      priceLevel: _priceLevelFromString(json['price_level'] as String?),
      priceNote: (json['price_note'] as String?) ?? '',
      priceNoteAr: json['price_note_ar'] as String?,
      isHiddenGem: (json['is_hidden_gem'] as bool?) ?? false,
      priceLocalEgp: json['price_local_egp'] as int?,
      priceForeignerEgp: json['price_foreigner_egp'] as int?,
      bestTimeNote: json['best_time_note'] as String?,
      bestTimeToVisit: json['best_time_to_visit'] as String?,
      isIndoor: (json['is_indoor'] as bool?) ?? false,
    );
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

  Future<void> _loadSavedPlaces() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getStringList('saved_places_data') ?? [];
    _savedPlaces = savedData
        .map((jsonStr) => PlaceModel.fromJson(jsonDecode(jsonStr)))
        .toList();
    notifyListeners();
  }

  bool isSaved(String id) {
    return _savedPlaces.any((place) => place.id == id);
  }

  Future<void> toggleSave(PlaceModel place) async {
    final prefs = await SharedPreferences.getInstance();
    if (isSaved(place.id)) {
      _savedPlaces.removeWhere((p) => p.id == place.id);
    } else {
      _savedPlaces.add(place);
    }
    final savedData = _savedPlaces.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList('saved_places_data', savedData);
    notifyListeners();
  }

  Future<void> clearAllSaved() async {
    final prefs = await SharedPreferences.getInstance();
    _savedPlaces = [];
    await prefs.setStringList('saved_places_data', []);
    notifyListeners();
  }

  void toggleFilterOpenNow() {
    _isFilterOpenNow = !_isFilterOpenNow;
    notifyListeners();
  }

  void toggleFilterCheapest() {
    _isFilterCheapest = !_isFilterCheapest;
    if (!_isFilterCheapest) {
      _maxPriceLevel = null;
      _onlyFree = false;
    }
    notifyListeners();
  }

  void toggleFilterNearest() {
    _isFilterNearest = !_isFilterNearest;
    notifyListeners();
  }

  /// Set the maximum price level (Free, Cheap, Moderate, Expensive).
  /// Pass null to clear.
  void setMaxPriceLevel(PriceLevel? level) {
    _maxPriceLevel = level;
    _isFilterCheapest = level != null;
    notifyListeners();
  }

  /// Toggle "only free places" filter.
  void toggleOnlyFree() {
    _onlyFree = !_onlyFree;
    _isFilterCheapest = _onlyFree || _maxPriceLevel != null;
    notifyListeners();
  }

  void clearFilters() {
    _isFilterOpenNow = false;
    _isFilterCheapest = false;
    _isFilterNearest = false;
    _maxPriceLevel = null;
    _onlyFree = false;
    notifyListeners();
  }

  List<PlaceModel> applyFilters(List<PlaceModel> initialPlaces) {
    List<PlaceModel> result = List<PlaceModel>.from(initialPlaces);
    if (_isFilterOpenNow) {
      result = result.where((p) => _isPlaceOpenNow(p.openHours)).toList();
    }
    if (_onlyFree) {
      result = result.where((p) => p.priceLevel == PriceLevel.free).toList();
    } else if (_maxPriceLevel != null) {
      result = result
          .where((p) => p.priceLevel.index <= _maxPriceLevel!.index)
          .toList();
    }
    if (_isFilterCheapest) {
      result.sort((a, b) => a.priceLevel.index.compareTo(b.priceLevel.index));
    }
    if (_isFilterNearest) {
      const refLat = 31.2001;
      const refLng = 29.9187;
      result.sort((a, b) {
        final da =
            (a.lat - refLat) * (a.lat - refLat) +
            (a.lng - refLng) * (a.lng - refLng);
        final db =
            (b.lat - refLat) * (b.lat - refLat) +
            (b.lng - refLng) * (b.lng - refLng);
        return da.compareTo(db);
      });
    }
    return result;
  }

  /// Parses the openHours string (e.g. "9:00 AM - 5:00 PM" or "Open 24 hours")
  /// and returns true if the current time falls within the range.
  bool _isPlaceOpenNow(String openHours) {
    final clean = openHours.trim();
    if (clean.toLowerCase() == 'open 24 hours') return true;

    final parts = clean.split('-');
    if (parts.length < 2) return true;
    final open = _parseHourMin(parts[0].trim());
    final close = _parseHourMin(parts[1].trim());
    if (open == null || close == null) return true;
    final now = DateTime.now();
    final nowMins = now.hour * 60 + now.minute;
    if (close > open) {
      return nowMins >= open && nowMins < close;
    } else {
      return nowMins >= open || nowMins < close;
    }
  }

  /// Returns total minutes since midnight for strings like "9:00 AM", "5:30 PM", "17:00"
  int? _parseHourMin(String s) {
    final upper = s.toUpperCase();
    final isPm = upper.contains('PM');
    final isAm = upper.contains('AM');
    final cleaned = upper.replaceAll('AM', '').replaceAll('PM', '').trim();
    final colonIdx = cleaned.indexOf(':');
    if (colonIdx < 0) return null;
    final h = int.tryParse(cleaned.substring(0, colonIdx).trim());
    final m = int.tryParse(cleaned.substring(colonIdx + 1).trim());
    if (h == null || m == null) return null;
    var hour = h;
    if (isPm && hour < 12) hour += 12;
    if (isAm && hour == 12) hour = 0;
    return hour * 60 + m;
  }
}
