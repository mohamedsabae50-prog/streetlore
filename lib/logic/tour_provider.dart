import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/itinerary_model.dart';
import '../data/models/place_model.dart';

class TourProvider extends ChangeNotifier {
  SupabaseClient get _client => Supabase.instance.client;

  List<ItineraryModel> _tours = [];
  List<ItineraryModel> get tours => List.unmodifiable(_tours);

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  List<ItineraryModel> _savedTours = [];
  List<ItineraryModel> get savedTours => _savedTours;

  TourProvider() {
    _loadSavedTours();
  }

  Future<void> loadTours({bool force = false}) async {
    if (_loading) return;
    if (!force && _tours.isNotEmpty) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _client
          .from('tours_with_places')
          .select()
          .order('id');
      _tours = (res as List<dynamic>)
          .map((e) => _tourFromSupabase(e as Map<String, dynamic>))
          .toList();
      _error = null;
    } catch (e) {
      _error = 'Failed to load tours: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadTours(force: true);

  ItineraryModel _tourFromSupabase(Map<String, dynamic> json) {
    final placesJson = (json['places'] as List<dynamic>?) ?? const [];
    final places = placesJson
        .map((e) => _placeFromSupabaseJson(e as Map<String, dynamic>))
        .toList();
    return ItineraryModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      duration: json['duration'] as String,
      imageUrl: json['image_url'] as String,
      places: places,
    );
  }

  PlaceModel _placeFromSupabaseJson(Map<String, dynamic> json) {
    return PlaceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String,
      rating: (json['rating'] as num).toDouble(),
      category: json['category'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      address: (json['address'] as String?) ?? 'Alexandria, Egypt',
      openHours: (json['openHours'] as String?) ?? '9:00 AM - 6:00 PM',
      reviewCount: (json['reviewCount'] as int?) ?? 0,
      priceLevel: _priceLevelFromString(json['priceLevel'] as String?),
      priceNote: (json['priceNote'] as String?) ?? '',
      isHiddenGem: (json['isHiddenGem'] as bool?) ?? false,
      priceLocalEgp: json['priceLocalEgp'] as int?,
      priceForeignerEgp: json['priceForeignerEgp'] as int?,
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

  bool isSaved(String id) {
    return _savedTours.any((t) => t.id == id);
  }
}
