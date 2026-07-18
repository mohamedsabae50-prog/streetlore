import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/place_model.dart';

class TripProvider extends ChangeNotifier {
  List<PlaceModel> _tripPlaces = [];
  List<PlaceModel> get tripPlaces => _tripPlaces;

  TripProvider() {
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('my_trip_data') ?? [];
    _tripPlaces = data
        .map((jsonStr) => PlaceModel.fromJson(jsonDecode(jsonStr)))
        .toList();
    notifyListeners();
  }

  bool isInTrip(String id) {
    return _tripPlaces.any((place) => place.id == id);
  }

  Future<void> togglePlaceInTrip(PlaceModel place) async {
    if (isInTrip(place.id)) {
      _tripPlaces.removeWhere((p) => p.id == place.id);
    } else {
      _tripPlaces.add(place);
    }
    await _saveTrip();
  }

  
  
  
  Future<void> reorderTrip(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _tripPlaces.length) return;
    if (newIndex < 0 || newIndex > _tripPlaces.length) return;
    final place = _tripPlaces.removeAt(oldIndex);
    _tripPlaces.insert(newIndex, place);
    await _saveTrip();
  }

  Future<void> _saveTrip() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _tripPlaces.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList('my_trip_data', data);
    notifyListeners();
  }

  Future<void> clearTrip() async {
    _tripPlaces = [];
    await _saveTrip();
  }
}
