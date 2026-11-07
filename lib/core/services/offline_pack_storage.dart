import '../../data/models/itinerary_model.dart';
import '../../data/models/offline_pack.dart';
import '../../data/models/place_model.dart';

class ImagePrefetchResult {
  final int ok;
  final int failed;
  final int bytes;

  const ImagePrefetchResult({
    required this.ok,
    required this.failed,
    required this.bytes,
  });
}

typedef OfflineImageProgress =
    void Function({required int bytes, required bool cached});

abstract interface class OfflinePackStorage {
  Future<void> init();
  List<OfflinePack> getAllPacks();
  List<PlaceModel> getCachedPlaces();
  List<ItineraryModel> getDownloadedTours();
  Future<void> cachePlaces(List<PlaceModel> places);
  Future<int> cachePackPayload(
    String packId, {
    required List<PlaceModel> places,
    required List<ItineraryModel> tours,
  });
  Map<String, dynamic>? getPackPayload(String packId);
  Future<void> savePack(OfflinePack pack);
  Future<void> deletePack(String packId);
  Future<ImagePrefetchResult> prefetchImages(
    List<PlaceModel> places, {
    bool primaryOnly = false,
    OfflineImageProgress? onProgress,
  });
  Future<ImagePrefetchResult> prefetchExtraImages(
    String folderId,
    Iterable<String> urls, {
    OfflineImageProgress? onProgress,
  });
}
