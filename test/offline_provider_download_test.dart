import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/core/services/offline_pack_storage.dart';
import 'package:streetlore/data/cairo_seed.dart';
import 'package:streetlore/data/models/itinerary_model.dart';
import 'package:streetlore/data/models/offline_pack.dart';
import 'package:streetlore/data/models/place_model.dart';
import 'package:streetlore/logic/offline_provider.dart';

class _MemoryOfflineStorage implements OfflinePackStorage {
  final Map<String, OfflinePack> packs = {};
  final Map<String, Map<String, dynamic>> payloads = {};
  final Map<String, PlaceModel> places = {};
  final Map<String, ItineraryModel> tours = {};

  @override
  Future<void> init() async {}

  @override
  List<OfflinePack> getAllPacks() => packs.values.toList(growable: false);

  @override
  List<PlaceModel> getCachedPlaces() => places.values.toList(growable: false);

  @override
  List<ItineraryModel> getDownloadedTours() =>
      tours.values.toList(growable: false);

  @override
  Future<void> cachePlaces(List<PlaceModel> values) async {
    for (final place in values) {
      places['${place.governorate}::${place.id}'] = place;
    }
  }

  @override
  Future<int> cachePackPayload(
    String packId, {
    required List<PlaceModel> places,
    required List<ItineraryModel> tours,
  }) async {
    final json = <String, dynamic>{
      'places': places.map((place) => place.toJson()).toList(),
      'tours': tours.map((tour) => tour.toJson()).toList(),
    };
    payloads[packId] = json;
    for (final tour in tours) {
      this.tours['${tour.governorate}::${tour.id}'] = tour;
    }
    return utf8.encode(jsonEncode(json)).length;
  }

  @override
  Map<String, dynamic>? getPackPayload(String packId) => payloads[packId];

  @override
  Future<void> savePack(OfflinePack pack) async {
    packs[pack.storageKey] = pack;
  }

  @override
  Future<void> deletePack(String packId) async {
    packs.remove(packId);
    payloads.remove(packId);
  }

  @override
  Future<ImagePrefetchResult> prefetchImages(
    List<PlaceModel> values, {
    bool primaryOnly = false,
    OfflineImageProgress? onProgress,
  }) async {
    var count = 0;
    var bytes = 0;
    for (final place in values) {
      if (!place.primaryImage.startsWith('http')) continue;
      count++;
      bytes += 4096;
      onProgress?.call(bytes: 4096, cached: true);
    }
    return ImagePrefetchResult(ok: count, failed: 0, bytes: bytes);
  }

  @override
  Future<ImagePrefetchResult> prefetchExtraImages(
    String folderId,
    Iterable<String> urls, {
    OfflineImageProgress? onProgress,
  }) async {
    var count = 0;
    var bytes = 0;
    for (final url in urls) {
      if (!url.startsWith('http')) continue;
      count++;
      bytes += 2048;
      onProgress?.call(bytes: 2048, cached: true);
    }
    return ImagePrefetchResult(ok: count, failed: 0, bytes: bytes);
  }
}

void main() {
  test(
    'Pro pack downloads real JSON, images, progress, and restores offline',
    () async {
      final storage = _MemoryOfflineStorage();
      final provider = OfflineProvider(storage: storage);
      await provider.init();

      const place = PlaceModel(
        id: 'citadel',
        nameEn: 'Citadel',
        descriptionEn: 'A complete historical story.',
        imageUrl: 'https://example.test/citadel.jpg',
        rating: 4.8,
        category: 'Historical',
        lat: 31.2,
        lng: 29.9,
      );
      const tour = ItineraryModel(
        id: 'heritage',
        title: 'Heritage Tour',
        description: 'A curated itinerary.',
        duration: '3 hours',
        imageUrl: 'https://example.test/heritage.jpg',
        places: [place],
      );
      final progress = <OfflineDownloadProgress>[];
      final result = await provider.download(
        OfflineProvider.catalog.first,
        availablePlaces: const [place],
        availableTours: const [tour],
        isPro: true,
        onProgress: progress.add,
      );

      expect(result, isA<DownloadOk>());
      expect(progress.first.progress, 0);
      expect(progress.last.progress, 1);
      expect(
        progress.map((entry) => entry.progress),
        orderedEquals(progress.map((entry) => entry.progress).toList()..sort()),
      );
      expect(progress.last.placesCount, 1);
      expect(progress.last.toursCount, 1);
      expect(progress.last.cachedImagesCount, 2);
      expect(progress.last.sizeBytes, greaterThan(0));
      expect(progress.last.sizeMb, greaterThan(0));

      final persisted = storage.packs.values.single;
      expect(persisted.isDownloaded, isTrue);
      expect(persisted.placesCount, 1);
      expect(persisted.toursCount, 1);
      expect(persisted.cachedImagesCount, 2);
      expect(persisted.sizeMb, closeTo(progress.last.sizeMb, 0.000001));
      expect(storage.payloads.values.single['places'], isNotEmpty);
      expect(storage.payloads.values.single['tours'], isNotEmpty);

      final offlineRestore = OfflineProvider(storage: storage);
      await offlineRestore.init();
      expect(
        offlineRestore.cachedPlaces.single.descriptionEn,
        contains('story'),
      );
      expect(offlineRestore.cachedTours.single.title, 'Heritage Tour');
      expect(offlineRestore.packs.single.downloadedAt, isNotNull);
    },
  );

  test('free users cannot download a premium pack', () async {
    final storage = _MemoryOfflineStorage();
    final provider = OfflineProvider(storage: storage);
    await provider.init();
    final result = await provider.download(
      OfflineProvider.catalog.first,
      availablePlaces: const [],
      isPro: false,
    );

    expect(result, isA<DownloadEmpty>());
    expect(storage.packs, isEmpty);
  });

  test(
    'Cairo and Alexandria offline packs use isolated bundles and state',
    () async {
      final storage = _MemoryOfflineStorage();
      final provider = OfflineProvider(storage: storage);
      await provider.init();

      final alexandriaPlace = PlaceModel(
        id: 'alexandria_offline_place',
        nameEn: 'Alexandria landmark',
        descriptionEn: 'Alexandria offline place.',
        imageUrl: 'https://example.test/alexandria.jpg',
        rating: 4.5,
        category: 'Historical',
        lat: 31.2,
        lng: 29.9,
        governorate: 'alexandria',
      );
      final cairoPlace = cairoSeedPlaces.first;
      final alexandriaTour = ItineraryModel(
        id: 'alexandria_offline_tour',
        title: 'Alexandria walk',
        description: 'Alexandria route.',
        duration: '2 hours',
        imageUrl: 'https://example.test/alexandria-tour.jpg',
        places: [alexandriaPlace],
      );
      final cairoTour = cairoSeedItineraries.first;
      final packs = [
        OfflineProvider.catalog.first,
        OfflineProvider.catalog.singleWhere(
          (pack) => pack.governorateId == 'cairo',
        ),
      ];

      expect(packs[0].storageKey, isNot(packs[1].storageKey));
      expect(OfflinePack.fromJson(packs[1].toJson()).governorateId, 'cairo');
      expect(packs[1].localizedName('ar'), contains('القاهرة'));

      for (final pack in packs) {
        final result = await provider.download(
          pack,
          availablePlaces: [alexandriaPlace, cairoPlace],
          availableTours: [alexandriaTour, cairoTour],
          isPro: true,
          onProgress: (_) {
            expect(provider.isDownloadingPack(pack), isTrue);
            final otherPack = packs.firstWhere(
              (candidate) => candidate.storageKey != pack.storageKey,
            );
            expect(provider.isDownloadingPack(otherPack), isFalse);
          },
        );
        expect(result, isA<DownloadOk>());
      }

      final alexandriaPayload = storage.payloads[packs[0].storageKey]!;
      final cairoPayload = storage.payloads[packs[1].storageKey]!;
      expect(
        (alexandriaPayload['places'] as List)
            .map((place) => (place as Map)['governorate'])
            .toSet(),
        {'alexandria'},
      );
      expect(
        (cairoPayload['places'] as List)
            .map((place) => (place as Map)['governorate'])
            .toSet(),
        {'cairo'},
      );
      expect(
        storage.places.keys,
        containsAll([
          'alexandria::${alexandriaPlace.id}',
          'cairo::${cairoPlace.id}',
        ]),
      );
      expect(
        storage.tours.keys,
        containsAll([
          'alexandria::${alexandriaTour.id}',
          'cairo::${cairoTour.id}',
        ]),
      );
      expect(
        storage.packs.keys.toSet(),
        packs.map((pack) => pack.storageKey).toSet(),
      );
      expect(
        provider.isDownloaded(packs[1].id, governorateId: 'cairo'),
        isTrue,
      );

      await provider.remove(packs[1]);
      expect(storage.packs.keys, [packs[0].storageKey]);
      expect(storage.payloads.keys, [packs[0].storageKey]);
    },
  );
}
