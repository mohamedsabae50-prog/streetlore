import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/mock_data.dart' show fallbackPlaces;
import '../data/models/place_model.dart';

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

  bool get isFilterOpenNow => _isFilterOpenNow;
  bool get isFilterCheapest => _isFilterCheapest;
  bool get isFilterNearest => _isFilterNearest;

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
      _places = List<PlaceModel>.from(fallbackPlaces);
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
      description: json['description'] as String,
      imageUrl: json['image_url'] as String,
      rating: (json['rating'] as num).toDouble(),
      category: json['category'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      address: (json['address'] as String?) ?? 'Alexandria, Egypt',
      openHours: (json['open_hours'] as String?) ?? '9:00 AM - 6:00 PM',
      reviewCount: (json['review_count'] as int?) ?? 0,
      priceLevel: _priceLevelFromString(json['price_level'] as String?),
      priceNote: (json['price_note'] as String?) ?? '',
      isHiddenGem: (json['is_hidden_gem'] as bool?) ?? false,
      priceLocalEgp: json['price_local_egp'] as int?,
      priceForeignerEgp: json['price_foreigner_egp'] as int?,
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
    notifyListeners();
  }

  void toggleFilterNearest() {
    _isFilterNearest = !_isFilterNearest;
    notifyListeners();
  }

  void clearFilters() {
    _isFilterOpenNow = false;
    _isFilterCheapest = false;
    _isFilterNearest = false;
    notifyListeners();
  }

  List<PlaceModel> applyFilters(List<PlaceModel> initialPlaces) {
    List<PlaceModel> result = List<PlaceModel>.from(initialPlaces);
    if (_isFilterOpenNow) {
      result = result.where((p) => _isPlaceOpenNow(p.openHours)).toList();
    }
    if (_isFilterCheapest) {
      result.sort((a, b) => a.priceLevel.index.compareTo(b.priceLevel.index));
    }
    if (_isFilterNearest) {
      // Sort by proximity to Alexandria city center as default
      const refLat = 31.2001;
      const refLng = 29.9187;
      result.sort((a, b) {
        final da = (a.lat - refLat) * (a.lat - refLat) +
            (a.lng - refLng) * (a.lng - refLng);
        final db = (b.lat - refLat) * (b.lat - refLat) +
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
    // Try to parse "H:MM AM/PM - H:MM AM/PM" or "HH:MM - HH:MM"
    final parts = clean.split('-');
    if (parts.length < 2) return true; // can't parse → assume open
    final open = _parseHourMin(parts[0].trim());
    final close = _parseHourMin(parts[1].trim());
    if (open == null || close == null) return true;
    final now = DateTime.now();
    final nowMins = now.hour * 60 + now.minute;
    if (close > open) {
      return nowMins >= open && nowMins < close;
    } else {
      // Wraps past midnight (e.g. 10 PM – 2 AM)
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
