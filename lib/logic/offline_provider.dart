import 'package:flutter/foundation.dart';

import '../core/services/offline_storage_service.dart';
import '../data/models/offline_pack.dart';
import '../data/models/place_model.dart';

sealed class DownloadResult {
  const DownloadResult();
}

class DownloadOk extends DownloadResult {
  final int cachedCount;
  const DownloadOk(this.cachedCount);
}

class DownloadEmpty extends DownloadResult {
  final OfflinePack pack;
  const DownloadEmpty(this.pack);
}

class OfflineProvider extends ChangeNotifier {
  final OfflineStorageService _storage = OfflineStorageService.instance;
  List<OfflinePack> _packs = const [];
  List<PlaceModel> _cachedPlaces = const [];

  List<OfflinePack> get packs => List.unmodifiable(_packs);
  List<PlaceModel> get cachedPlaces => List.unmodifiable(_cachedPlaces);

  static final List<OfflinePack> catalog = [
    OfflinePack(
      id: 'all_alexandria',
      name: 'All Alexandria',
      description: 'Every place, every description, every photo URL.',
      placeIds: const [
        'fallback_qaitbay',
        'fallback_biblio',
        'fallback_pompey',
        'fallback_catacombs',
        'fallback_corniche',
        'fallback_montaza',
        'fallback_attarine',
        'fallback_stmark',
      ],
      sizeMb: 24,
      coverEmoji: 'book',
    ),
    OfflinePack(
      id: 'historical',
      name: 'Historical Alexandria',
      description: 'Citadels, catacombs, pillars, museums.',
      placeIds: const [
        'fallback_qaitbay',
        'fallback_pompey',
        'fallback_catacombs',
      ],
      sizeMb: 9,
      coverEmoji: 'museum',
    ),
    OfflinePack(
      id: 'culture',
      name: 'Culture & Museums',
      description: 'Libraries, museums and cultural landmarks.',
      placeIds: const [
        'fallback_biblio',
        'fallback_stmark',
        'fallback_attarine',
      ],
      sizeMb: 8,
      coverEmoji: 'museum',
    ),
    OfflinePack(
      id: 'nature_sea',
      name: 'Nature & Sea Breeze',
      description: 'Gardens, corniche, and the Mediterranean breeze.',
      placeIds: const [
        'fallback_montaza',
        'fallback_corniche',
      ],
      sizeMb: 6,
      coverEmoji: 'beach',
    ),
  ];

  Future<void> init() async {
    await _storage.init();
    _packs = _storage.getAllPacks();
    _cachedPlaces = _storage.getCachedPlaces();
    notifyListeners();
  }

  Future<DownloadResult> download(
    OfflinePack pack, {
    required List<PlaceModel> availablePlaces,
  }) async {
    final places = availablePlaces
        .where((p) => pack.placeIds.contains(p.id))
        .toList();
    if (places.isEmpty) {
      debugPrint(
        'OfflineProvider: no places matched pack "${pack.id}"',
      );
      return DownloadEmpty(pack);
    }
    await _storage.cachePlaces(places);
    final updated = pack.copyWith(downloadedAt: DateTime.now());
    await _storage.savePack(updated);
    _packs = _storage.getAllPacks();
    _cachedPlaces = _storage.getCachedPlaces();
    notifyListeners();
    return DownloadOk(places.length);
  }

  Future<void> remove(OfflinePack pack) async {
    await _storage.deletePack(pack.id);
    _packs = _storage.getAllPacks();
    notifyListeners();
  }

  bool isDownloaded(String packId) => _packs.any((p) => p.id == packId);

  int get totalDownloadedMb => _packs.fold(0, (s, p) => s + p.sizeMb);
}
