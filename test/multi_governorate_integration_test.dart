import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetlore/core/services/ai_tour_guide_service.dart';
import 'package:streetlore/data/cairo_seed.dart';
import 'package:streetlore/data/luxor_seed.dart';
import 'package:streetlore/data/aswan_seed.dart';
import 'package:streetlore/data/mock_data.dart'
    show MockData, fallbackPlaces, fallbackTours;
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

      expect(places.availableGovernorateIds, {'alexandria', 'cairo', 'luxor'});
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
      expect(places.places, hasLength(174));
      expect(
        places.places.every((place) => place.governorate == 'cairo'),
        isTrue,
      );
      expect(places.places.where((place) => place.isAtm), isEmpty);
      expect(
        MockData.getByCategory(
          'ATMs',
          places.allPlaces,
          governorateId: 'cairo',
        ),
        isEmpty,
      );
      expect(
        MockData.getFeatured(
          governorateId: 'cairo',
        ).every((place) => place.isVisitable),
        isTrue,
      );
      expect(
        places.places.where((place) => place.category == 'Hotels'),
        hasLength(16),
      );
      expect(places.places.where((place) => !place.isVisitable), isEmpty);
      expect(
        places.allPlaces.where(
          (place) => place.governorate == 'cairo' && place.isAtm,
        ),
        hasLength(20),
      );
      expect(tours.tours, hasLength(15));
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

      expect(governorates.unlockAndSelectGovernorate('luxor'), isTrue);
      expect(places.places, hasLength(112));
      expect(
        places.places.every((place) => place.governorate == 'luxor'),
        isTrue,
      );
      expect(places.places.where((place) => place.isAtm), isEmpty);
      expect(
        places.places.where((place) => place.category == 'Hotels'),
        hasLength(12),
      );
      expect(places.places.where((place) => !place.isVisitable), isEmpty);
      expect(
        places.allPlaces.where(
          (place) => place.governorate == 'luxor' && place.isAtm,
        ),
        hasLength(12),
      );
      expect(tours.tours, hasLength(12));
      expect(tours.tours.every((tour) => tour.governorate == 'luxor'), isTrue);

      expect(governorates.unlockAndSelectGovernorate('aswan'), isTrue);
      expect(governorates.activeGovernorate, 'luxor');
      expect(places.places, hasLength(112));
      expect(
        places.places.every((place) => place.governorate == 'luxor'),
        isTrue,
      );
      expect(places.places.where((place) => place.isAtm), isEmpty);
      expect(
        places.places.where((place) => place.category == 'Hotels'),
        hasLength(12),
      );
      expect(
        places.allPlaces.where(
          (place) => place.governorate == 'luxor' && place.isAtm,
        ),
        hasLength(12),
      );
      expect(
        MockData.getByCategory(
          'ATMs',
          places.allPlaces,
          governorateId: 'aswan',
        ),
        isEmpty,
      );
      expect(
        MockData.getFeatured(
          governorateId: 'aswan',
        ).every((place) => place.isVisitable),
        isTrue,
      );
      expect(tours.tours, hasLength(12));
      expect(tours.tours.every((tour) => tour.governorate == 'luxor'), isTrue);
      expect(
        tours.tours
            .expand((tour) => tour.places)
            .every((place) => place.governorate == 'luxor' && !place.isAtm),
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
    expect(cairoContext, contains('Cairo & Giza / القاهرة والجيزة'));
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

    final luxorContext = buildGovernorateGuideContext(
      governorateId: 'luxor',
      places: [...luxorSeedPlaces, ...aswanSeedPlaces, ...cairoSeedPlaces],
      itineraries: [
        ...luxorSeedItineraries,
        ...aswanSeedItineraries,
        ...cairoSeedItineraries,
      ],
      locale: 'en',
    );
    expect(luxorContext, contains('Luxor & Aswan / الأقصر وأسوان'));
    expect(luxorContext, contains('East Bank Royal Temples Trail'));
    expect(
      luxorContext,
      contains('Philae, High Dam, and Unfinished Obelisk Trail'),
    );
    expect(
      luxorContext,
      isNot(contains('Fatimid Cairo & Al-Muizz Heritage Walk')),
    );

    final aswanContext = buildGovernorateGuideContext(
      governorateId: 'aswan',
      places: [...aswanSeedPlaces, ...cairoSeedPlaces],
      itineraries: [...aswanSeedItineraries, ...cairoSeedItineraries],
      locale: 'en',
    );
    expect(aswanContext, contains('Luxor & Aswan / الأقصر وأسوان'));
    expect(aswanContext, contains('Local expertise: Luxor, Aswan, Nubia'));
    expect(
      aswanContext,
      contains('Nubia, Philae, Kom Ombo, Edfu, and Abu Simbel'),
    );
    expect(
      aswanContext,
      contains('Philae, High Dam, and Unfinished Obelisk Trail'),
    );
    expect(
      aswanContext,
      isNot(contains('Fatimid Cairo & Al-Muizz Heritage Walk')),
    );
  });

  testWidgets('fog layer survives repeated governorate switches', (
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

    for (final id in ['cairo', 'luxor', 'aswan', 'alexandria', 'luxor']) {
      governorates.unlockAndSelectGovernorate(id);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('governorate-cloud-fog')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'map selector exposes three unified regions and fits Cairo and Luxor',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final governorates = GovernorateProvider();
      final places = PlaceProvider(
        watchRemoteUpdates: false,
        governorates: governorates,
        initialPlaces: [
          ...fallbackPlaces,
          ...cairoSeedPlaces,
          ...luxorSeedPlaces,
          ...aswanSeedPlaces,
        ],
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
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('map-view-header-bar')),
          matching: selector,
        ),
        findsOneWidget,
      );
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cairo & Giza'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(governorates.activeGovernorate, 'cairo');
      final fogLayer = find.byKey(const ValueKey('governorate-cloud-fog'));
      final camera = MapCamera.of(tester.element(fogLayer));
      expect(camera.center.latitude, closeTo(30.0444, 0.001));
      expect(camera.center.longitude, closeTo(31.2357, 0.001));

      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Luxor & Aswan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(governorates.activeGovernorate, 'luxor');
      final luxorCamera = MapCamera.of(tester.element(fogLayer));
      expect(luxorCamera.center.latitude, closeTo(24.9500, 0.001));
      expect(luxorCamera.center.longitude, closeTo(32.7600, 0.001));

      await tester.tap(selector);
      await tester.pumpAndSettle();
      expect(find.text('Aswan'), findsNothing);
      expect(find.text('Luxor & Aswan'), findsNWidgets(2));
    },
  );
}
