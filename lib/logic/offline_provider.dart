import 'package:flutter/foundation.dart';

import '../core/services/offline_storage_service.dart';
import '../data/models/offline_pack.dart';
import '../data/models/place_model.dart';

class OfflineProvider extends ChangeNotifier {
  final OfflineStorageService _storage = OfflineStorageService.instance;
  List<OfflinePack> _packs = const [];
  List<PlaceModel> _cachedPlaces = const [];

  List<OfflinePack> get packs => List.unmodifiable(_packs);
  List<PlaceModel> get cachedPlaces => List.unmodifiable(_cachedPlaces);

  static final List<OfflinePack> catalog = [
    OfflinePack(
      id: 'all_egypt',
      name: 'All Alexandria',
      description: 'Every place, every description, every photo URL.',
      placeIds: List.generate(30, (i) => '${i + 1}'),
      sizeMb: 84,
      coverEmoji: 'book',
    ),
    OfflinePack(
      id: 'historical',
      name: 'Historical Alexandria',
      description: 'Citadels, catacombs, pillars, museums.',
      placeIds: const ['1', '4', '7', '9', '11', '12', '17', '27', '28'],
      sizeMb: 32,
      coverEmoji: 'museum',
    ),
    OfflinePack(
      id: 'food',
      name: 'Tastes of the City',
      description: 'Cafés, seafood markets and legendary restaurants.',
      placeIds: const ['6', '14', '19', '20', '21', '22', '23', '30'],
      sizeMb: 24,
      coverEmoji: 'food',
    ),
    OfflinePack(
      id: 'beach',
      name: 'Coast & Beaches',
      description: 'From Sidi Bishr to Agami - sun, sand and sea.',
      placeIds: const ['8', '15', '24', '25', '26'],
      sizeMb: 18,
      coverEmoji: 'beach',
    ),
  ];

  Future<void> init() async {
    await _storage.init();
    _packs = _storage.getAllPacks();
    _cachedPlaces = _storage.getCachedPlaces();
    notifyListeners();
  }

  Future<void> download(
    OfflinePack pack, {
    required List<PlaceModel> availablePlaces,
  }) async {
    final places = availablePlaces
        .where((p) => pack.placeIds.contains(p.id))
        .toList();
    await _storage.cachePlaces(places);
    final updated = pack.copyWith(downloadedAt: DateTime.now());
    await _storage.savePack(updated);
    _packs = _storage.getAllPacks();
    _cachedPlaces = _storage.getCachedPlaces();
    notifyListeners();
  }

  Future<void> remove(OfflinePack pack) async {
    await _storage.deletePack(pack.id);
    _packs = _storage.getAllPacks();
    notifyListeners();
  }

  bool isDownloaded(String packId) => _packs.any((p) => p.id == packId);

  int get totalDownloadedMb => _packs.fold(0, (s, p) => s + p.sizeMb);
}
