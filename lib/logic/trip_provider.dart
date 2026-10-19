import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/supabase_service.dart';
import '../data/models/place_model.dart';

class TripProvider extends ChangeNotifier {
  List<PlaceModel> _tripPlaces = [];
  List<PlaceModel> get tripPlaces => _tripPlaces;

  /// Set of place ids the current user has already checked in at.
  /// Refreshed on login + every check-in via [markVisited].
  final Set<String> _visitedPlaceIds = <String>{};
  Set<String> get visitedPlaceIds => Set.unmodifiable(_visitedPlaceIds);
  String? _visitedUserId;
  int _visitedRefreshGeneration = 0;
  Future<void> _visitCacheWrites = Future<void>.value();

  TripProvider() {
    _loadTrip();
    _loadVisitedFromSupabase();
  }

  Future<void> _loadTrip() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('my_trip_data') ?? [];
    _tripPlaces = data
        .map((jsonStr) => PlaceModel.fromJson(jsonDecode(jsonStr)))
        .toList();
    notifyListeners();
  }

  /// Reconcile checked-in place IDs from the current user's server records.
  Future<void> _loadVisitedFromSupabase() async {
    final client = SupabaseService.instance.clientOrNull;
    if (client == null) {
      _replaceVisitedPlaces('', const <String>{});
      return;
    }
    final userId = client.auth.currentUser?.id ?? '';
    if (userId.isEmpty) {
      _replaceVisitedPlaces('', const <String>{});
      return;
    }
    final generation = ++_visitedRefreshGeneration;
    if (_visitedUserId != userId) {
      _replaceVisitedPlaces(userId, const <String>{});
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (generation != _visitedRefreshGeneration ||
          client.auth.currentUser?.id != userId) {
        return;
      }
      final cachedIds = prefs.getStringList(_visitedCacheKey(userId));
      if (cachedIds != null) {
        _replaceVisitedPlaces(userId, cachedIds.toSet());
      }
    } catch (e, stackTrace) {
      debugPrint(
        'TripProvider: failed to read cached visits for $userId: '
        '$e\n$stackTrace',
      );
    }

    try {
      final rows = await client
          .from('place_checkins')
          .select('place_id')
          .eq('user_id', userId);
      if (generation != _visitedRefreshGeneration ||
          client.auth.currentUser?.id != userId) {
        return;
      }
      final remoteIds = rows
          .map((row) => (row['place_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();
      _replaceVisitedPlaces(userId, remoteIds);
      await _persistVisitedPlaces(userId, remoteIds);
    } catch (e) {
      debugPrint('TripProvider._loadVisitedFromSupabase: $e');
    }
  }

  String _visitedCacheKey(String userId) => 'visited_place_ids_$userId';

  Future<void> _persistVisitedPlaces(
    String userId,
    Set<String> placeIds,
  ) async {
    _visitCacheWrites = _visitCacheWrites.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(
          _visitedCacheKey(userId),
          placeIds.toList(growable: false),
        );
      } catch (e, stackTrace) {
        debugPrint(
          'TripProvider: failed to cache visits for $userId: $e\n$stackTrace',
        );
      }
    });
    await _visitCacheWrites;
  }

  String _currentUserId() =>
      SupabaseService.instance.clientOrNull?.auth.currentUser?.id ?? '';

  void _replaceVisitedPlaces(String userId, Set<String> placeIds) {
    final changed =
        _visitedUserId != userId ||
        _visitedPlaceIds.length != placeIds.length ||
        !_visitedPlaceIds.containsAll(placeIds);
    _visitedUserId = userId;
    _visitedPlaceIds
      ..clear()
      ..addAll(placeIds);
    if (changed) notifyListeners();
  }

  /// Public refresh — call after sign-in / sign-out or when syncing visits.
  Future<void> refreshVisited() => _loadVisitedFromSupabase();

  /// Add a freshly-checked-in place id so the trip planner can show the badge
  /// immediately (don't wait for the next refresh).
  void markVisited(String placeId) {
    if (placeId.isEmpty) return;
    final userId = _currentUserId();
    if (userId.isNotEmpty && _visitedUserId != userId) {
      _replaceVisitedPlaces(userId, const <String>{});
    }
    if (_visitedPlaceIds.add(placeId)) {
      _visitedRefreshGeneration++;
      notifyListeners();
      if (userId.isNotEmpty) {
        unawaited(_persistVisitedPlaces(userId, Set.of(_visitedPlaceIds)));
      }
    }
  }

  /// v1.0.63: drop the visited marker (called from PlaceDetails when the
  /// user un-visits a place so the Trip Planner badge disappears
  /// immediately, without waiting for a Supabase round-trip).
  void unmarkVisited(String placeId) {
    if (placeId.isEmpty) return;
    if (_visitedPlaceIds.remove(placeId)) {
      _visitedRefreshGeneration++;
      notifyListeners();
      final userId = _currentUserId();
      if (userId.isNotEmpty) {
        unawaited(_persistVisitedPlaces(userId, Set.of(_visitedPlaceIds)));
      }
    }
  }

  bool isInTrip(String id) {
    return _tripPlaces.any((place) => place.id == id);
  }

  bool isVisited(String id) => _visitedPlaceIds.contains(id);

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
