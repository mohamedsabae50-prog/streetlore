import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetlore/core/services/ai_tour_guide_service.dart';
import 'package:streetlore/data/cairo_seed.dart';
import 'package:streetlore/data/mock_data.dart'
    show fallbackPlaces, fallbackTours;
import 'package:streetlore/data/models/egypt_governorate.dart';
import 'package:streetlore/logic/governorate_provider.dart';
import 'package:streetlore/logic/locale_provider.dart';
import 'package:streetlore/logic/place_provider.dart';
import 'package:streetlore/logic/tour_provider.dart';
import 'package:streetlore/logic/trip_provider.dart';
import 'package:streetlore/presentation/screens/map_view_screen.dart';
import 'package:streetlore/presentation/widgets/governorate_fog_layer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'active governorate filters places, hotels, ATMs, and itineraries',
    () async {
      final governorates = GovernorateProvider();
      final places = PlaceProvider(
        watchRemoteUpdates: false,
        governorates: governorates,
        isOnline: () => false,
      );
      final tours = TourProvider(
        governorates: governorates,
        isOnline: () => false,
      );
      addTearDown(governorates.dispose);
      addTearDown(places.dispose);
      addTearDown(tours.dispose);

      await places.loadPlaces();
      await tours.loadTours();

      expect(
        places.availableGovernorateIds,
        containsAll(['alexandria', 'cairo']),
      );
      expect(places.places, isNotEmpty);
      expect(
        places.places.every((place) => place.governorate == 'alexandria'),
        isTrue,
      );
      expect(tours.tours, isNotEmpty);
      expect(
        tours.tours.every((tour) => tour.governorate == 'alexandria'),
        isTrue,
      );

      expect(governorates.unlockAndSelectGovernorate('cairo'), isTrue);
      expect(places.places, hasLength(120));
      expect(
        places.places.every((place) => place.governorate == 'cairo'),
        isTrue,
      );
      expect(
        places.places.where((place) => place.category == 'Hotels'),
        hasLength(12),
      );
      expect(
        places.places.where((place) => place.category == 'ATMs'),
        hasLength(17),
      );
      expect(tours.tours, hasLength(5));
      expect(tours.tours.every((tour) => tour.governorate == 'cairo'), isTrue);

      expect(governorates.unlockAndSelectGovernorate('alexandria'), isTrue);
      expect(
        places.places.every((place) => place.governorate == 'alexandria'),
        isTrue,
      );
      expect(
        tours.tours.every((tour) => tour.governorate == 'alexandria'),
        isTrue,
      );
    },
  );

  test('AI context uses active-city landmarks and itineraries', () {
    final cairoContext = buildGovernorateGuideContext(
      governorateId: 'cairo',
      places: [...cairoSeedPlaces, fallbackPlaces.first],
      itineraries: [...cairoSeedItineraries, ...fallbackTours],
      locale: 'en',
      referencePlace: cairoSeedPlaces.first,
    );
    expect(cairoContext, contains('Cairo / القاهرة'));
    expect(cairoContext, contains('Fatimid Cairo & Al-Muizz Heritage Walk'));
    expect(cairoContext, isNot(contains(fallbackPlaces.first.nameEn)));

    final alexandriaContext = buildGovernorateGuideContext(
      governorateId: 'alexandria',
      places: [...fallbackPlaces, ...cairoSeedPlaces],
      itineraries: [...fallbackTours, ...cairoSeedItineraries],
      locale: 'ar',
    );
    expect(alexandriaContext, contains('الإسكندرية / Alexandria'));
    expect(alexandriaContext, isNot(contains('جولة القاهرة الفاطمية')));
  });

  testWidgets('fog layer survives repeated Cairo and Alexandria switches', (
    tester,
  ) async {
    final governorates = GovernorateProvider();
    addTearDown(governorates.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: governorates,
        child: const MaterialApp(
          home: Scaffold(
            body: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(31.2001, 29.9187),
                initialZoom: 11,
              ),
              children: [GovernorateFogLayer(places: [])],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(EgyptGovernorate.byId['alexandria']!.boundaryPolygon, isNotEmpty);

    for (final id in ['cairo', 'alexandria', 'cairo']) {
      governorates.unlockAndSelectGovernorate(id);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('governorate-cloud-fog')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('map selector animates the camera to Cairo', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final governorates = GovernorateProvider();
    final places = PlaceProvider(
      watchRemoteUpdates: false,
      governorates: governorates,
      initialPlaces: [...fallbackPlaces, ...cairoSeedPlaces],
    );
    final tours = TourProvider(governorates: governorates);
    final trips = TripProvider();
    final locale = LocaleProvider();
    addTearDown(governorates.dispose);
    addTearDown(places.dispose);
    addTearDown(tours.dispose);
    addTearDown(trips.dispose);
    addTearDown(locale.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: governorates),
          ChangeNotifierProvider.value(value: places),
          ChangeNotifierProvider.value(value: tours),
          ChangeNotifierProvider.value(value: trips),
          ChangeNotifierProvider.value(value: locale),
        ],
        child: const MaterialApp(home: MapViewScreen()),
      ),
    );
    await tester.pump();

    final selector = find.byKey(const ValueKey('map-view-governorate-pill'));
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cairo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(governorates.activeGovernorate, 'cairo');
    final fogLayer = find.byKey(const ValueKey('governorate-cloud-fog'));
    final camera = MapCamera.of(tester.element(fogLayer));
    expect(camera.center.latitude, closeTo(30.0444, 0.001));
    expect(camera.center.longitude, closeTo(31.2357, 0.001));
  });
}
