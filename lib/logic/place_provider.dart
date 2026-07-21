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
      debugPrint('PlaceProvider: loaded ${list.length} places from Supabase');
      if (list.isEmpty) {
        _places = List<PlaceModel>.from(fallbackPlaces);
        _error = null;
      } else {
        _places = list;
        _error = null;
      }
    } catch (e, st) {
      debugPrint('PlaceProvider: loadPlaces failed, using fallback: $e\n$st');
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
      result = result.where((p) {
        final now = DateTime.now();
        final hour = now.hour;
        return hour >= 9 && hour < 18;
      }).toList();
    }
    if (_isFilterCheapest) {
      result.sort((a, b) => a.reviewCount.compareTo(b.reviewCount));
    }
    return result;
  }
}
