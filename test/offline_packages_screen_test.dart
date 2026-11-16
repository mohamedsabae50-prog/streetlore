import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetlore/core/services/offline_pack_storage.dart';
import 'package:streetlore/data/cairo_seed.dart';
import 'package:streetlore/data/luxor_seed.dart';
import 'package:streetlore/data/aswan_seed.dart';
import 'package:streetlore/data/mock_data.dart' show fallbackPlaces;
import 'package:streetlore/data/red_sea_seed.dart';
import 'package:streetlore/data/models/itinerary_model.dart';
import 'package:streetlore/data/models/offline_pack.dart';
import 'package:streetlore/data/models/place_model.dart';
import 'package:streetlore/logic/auth_provider.dart';
import 'package:streetlore/logic/governorate_provider.dart';
import 'package:streetlore/logic/locale_provider.dart';
import 'package:streetlore/logic/offline_provider.dart';
import 'package:streetlore/logic/place_provider.dart';
import 'package:streetlore/logic/tour_provider.dart';
import 'package:streetlore/presentation/screens/offline_packages_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final payload = <String, dynamic>{
      'places': places.map((place) => place.toJson()).toList(),
      'tours': tours.map((tour) => tour.toJson()).toList(),
    };
    payloads[packId] = payload;
    for (final tour in tours) {
      this.tours['${tour.governorate}::${tour.id}'] = tour;
    }
    return utf8.encode(jsonEncode(payload)).length;
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
    for (final place in values) {
      if (!place.primaryImage.startsWith('http')) continue;
      count++;
      onProgress?.call(bytes: 2048, cached: true);
    }
    return ImagePrefetchResult(ok: count, failed: 0, bytes: count * 2048);
  }

  @override
  Future<ImagePrefetchResult> prefetchExtraImages(
    String folderId,
    Iterable<String> urls, {
    OfflineImageProgress? onProgress,
  }) async {
    var count = 0;
    for (final url in urls) {
      if (!url.startsWith('http')) continue;
      count++;
      onProgress?.call(bytes: 1024, cached: true);
    }
    return ImagePrefetchResult(ok: count, failed: 0, bytes: count * 1024);
  }
}

class _ProAuthProvider extends AuthProvider {
  @override
  bool get isPro => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
    );
  });

  testWidgets('profile entry opens and manages city-wide offline packs', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final governorates = GovernorateProvider();
    final places = PlaceProvider(
      watchRemoteUpdates: false,
      governorates: governorates,
      isOnline: () => false,
      initialPlaces: [
        ...fallbackPlaces,
        ...cairoSeedPlaces,
        ...luxorSeedPlaces,
        ...aswanSeedPlaces,
        ...redSeaSeedPlaces,
      ],
    );
    final tours = TourProvider(
      governorates: governorates,
      isOnline: () => false,
    );
    final storage = _MemoryOfflineStorage();
    final offline = OfflineProvider(storage: storage);
    final auth = _ProAuthProvider();
    final locale = LocaleProvider();
    await offline.init();

    addTearDown(governorates.dispose);
    addTearDown(places.dispose);
    addTearDown(tours.dispose);
    addTearDown(offline.dispose);
    addTearDown(auth.dispose);
    addTearDown(locale.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<LocaleProvider>.value(value: locale),
          ChangeNotifierProvider<GovernorateProvider>.value(
            value: governorates,
          ),
          ChangeNotifierProvider<PlaceProvider>.value(value: places),
          ChangeNotifierProvider<TourProvider>.value(value: tours),
          ChangeNotifierProvider<OfflineProvider>.value(value: offline),
        ],
        child: const MaterialApp(
          home: Scaffold(body: OfflinePackagesEntryTile()),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Download Packages'), findsOneWidget);
    expect(find.text('0 city packs downloaded'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('profile-offline-packages')));
    await tester.pumpAndSettle();
    expect(find.byType(OfflinePackagesScreen), findsOneWidget);
    expect(find.text('All Alexandria'), findsOneWidget);
    expect(find.text('All Cairo & Giza'), findsOneWidget);
    expect(find.text('All Luxor & Aswan'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('All Hurghada & Marsa Alam'), findsOneWidget);
    expect(find.text('54 places · 6 tours'), findsOneWidget);
    expect(find.text('194 places · 15 tours'), findsOneWidget);
    expect(find.text('112 places · 12 tours'), findsOneWidget);

    final downloadButton = find.byKey(
      const ValueKey('download-pack-all_cairo'),
    );
    await tester.ensureVisible(downloadButton);
    await tester.tap(downloadButton);
    await tester.pumpAndSettle();

    expect(offline.isDownloaded('all_cairo', governorateId: 'cairo'), isTrue);
    expect(find.byKey(const ValueKey('update-pack-all_cairo')), findsOneWidget);
    expect(find.byKey(const ValueKey('remove-pack-all_cairo')), findsOneWidget);

    final luxorDownloadButton = find.byKey(
      const ValueKey('download-pack-all_luxor'),
    );
    await tester.ensureVisible(luxorDownloadButton);
    await tester.tap(luxorDownloadButton);
    await tester.pumpAndSettle();
    expect(offline.isDownloaded('all_luxor', governorateId: 'aswan'), isTrue);
    expect(
      storage.places.values.where(
        (place) => place.governorate == 'luxor' && place.isVisitable,
      ),
      hasLength(112),
    );
    expect(
      storage.places.values.where(
        (place) => place.governorate == 'luxor' && place.isAtm,
      ),
      isEmpty,
    );

    final redSeaDownloadButton = find.byKey(
      const ValueKey('download-pack-all_red_sea'),
    );
    await tester.ensureVisible(redSeaDownloadButton);
    await tester.tap(redSeaDownloadButton);
    await tester.pumpAndSettle();
    expect(
      offline.isDownloaded('all_red_sea', governorateId: 'red_sea'),
      isTrue,
    );
    expect(
      storage.places.values.where(
        (place) => place.governorate == 'red_sea' && place.isVisitable,
      ),
      hasLength(54),
    );
    expect(
      storage.places.values.where(
        (place) => place.governorate == 'red_sea' && place.isAtm,
      ),
      isEmpty,
    );

    final removeButton = find.byKey(const ValueKey('remove-pack-all_cairo'));
    await tester.ensureVisible(removeButton);
    await tester.tap(removeButton);
    await tester.pumpAndSettle();
    expect(offline.isDownloaded('all_cairo', governorateId: 'cairo'), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
