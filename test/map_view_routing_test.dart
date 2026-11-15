import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetlore/core/services/map_route_service.dart';
import 'package:streetlore/data/aswan_seed.dart';
import 'package:streetlore/data/luxor_seed.dart';
import 'package:streetlore/data/models/map_poi.dart';
import 'package:streetlore/data/models/place_model.dart';
import 'package:streetlore/logic/governorate_provider.dart';
import 'package:streetlore/logic/locale_provider.dart';
import 'package:streetlore/logic/place_provider.dart';
import 'package:streetlore/logic/trip_provider.dart';
import 'package:streetlore/presentation/screens/_atm_sheet.dart';
import 'package:streetlore/presentation/screens/map_view_screen.dart';
import 'package:streetlore/presentation/widgets/map_route_hud.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('map place starts a live route and reduces remaining distance', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final governorates = GovernorateProvider();
    const place = PlaceModel(
      id: 'route-destination',
      nameEn: 'Route Destination',
      nameAr: 'وجهة المسار',
      descriptionEn: 'A place for route testing.',
      imageUrl: '',
      rating: 4.5,
      category: 'Historical',
      lat: 31.2001,
      lng: 29.925,
    );
    const nearbyPlace = PlaceModel(
      id: 'nearby-place',
      nameEn: 'Nearby Place',
      nameAr: 'مكان قريب',
      descriptionEn: 'A non-destination marker for route testing.',
      imageUrl: '',
      rating: 4.0,
      category: 'Food',
      lat: 31.201,
      lng: 29.926,
    );
    final places = PlaceProvider(
      watchRemoteUpdates: false,
      governorates: governorates,
      isOnline: () => false,
      initialPlaces: const [place, nearbyPlace],
    );
    final trips = TripProvider();
    final locale = LocaleProvider();
    final locationController = StreamController<LatLng>.broadcast(sync: true);
    LatLng? routeOrigin;
    final routeService = MapRouteService(
      routeFetcher: (origin, destination) async {
        routeOrigin = origin;
        return [origin, destination];
      },
    );
    addTearDown(() async {
      await locationController.close();
      routeService.close();
      governorates.dispose();
      places.dispose();
      trips.dispose();
      locale.dispose();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: governorates),
          ChangeNotifierProvider.value(value: places),
          ChangeNotifierProvider.value(value: trips),
          ChangeNotifierProvider.value(value: locale),
        ],
        child: MaterialApp(
          home: MapViewScreen(
            autoLocate: false,
            routeLocationUpdates: locationController.stream,
            routeService: routeService,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('map-place-marker-nearby-place')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('map-place-marker-route-destination')),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('route-on-map-button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('map-selected-place-card')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('route-on-map-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('map-route-hud')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-view-header-bar')), findsNothing);
    expect(find.byKey(const ValueKey('map-category-filter-bar')), findsNothing);
    expect(find.byKey(const ValueKey('map-selected-place-card')), findsNothing);
    expect(
      find.byKey(const ValueKey('map-place-marker-nearby-place')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('map-route-user-location')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('map-route-destination-marker')),
      findsOneWidget,
    );
    final activeMarkerLayers = tester.widgetList<MarkerLayer>(
      find.byType(MarkerLayer),
    );
    expect(activeMarkerLayers, hasLength(1));
    expect(activeMarkerLayers.single.markers, hasLength(2));
    final routeLayer = tester.widget<PolylineLayer>(
      find.byKey(const ValueKey('map-route-polyline-layer')),
    );
    expect(routeLayer.polylines, hasLength(1));
    expect(routeLayer.polylines.single.color, const Color(0xFF00D9FF));
    expect(routeLayer.polylines.single.borderColor, const Color(0xFF10243A));
    expect(routeLayer.polylines.single.borderStrokeWidth, greaterThan(0));
    final routeCamera = MapCamera.of(
      tester.element(find.byKey(const ValueKey('map-route-polyline-layer'))),
    );
    expect(routeCamera.visibleBounds.contains(routeOrigin!), isTrue);
    expect(
      routeCamera.visibleBounds.contains(LatLng(place.lat, place.lng)),
      isTrue,
    );
    final initialDistance = tester
        .widget<MapRouteHud>(find.byType(MapRouteHud))
        .distance;

    final origin = routeOrigin!;
    locationController.add(
      LatLng(origin.latitude, (origin.longitude + place.lng) / 2),
    );
    await tester.pump();

    final updatedDistance = tester
        .widget<MapRouteHud>(find.byType(MapRouteHud))
        .distance;
    expect(
      _distanceFromLabel(updatedDistance),
      lessThan(_distanceFromLabel(initialDistance)),
    );
    expect(
      MapRouteService.progressAlongRoute(
        route: [origin, LatLng(place.lat, place.lng)],
        currentLocation: LatLng(
          origin.latitude,
          (origin.longitude + place.lng) / 2,
        ),
      ).remainingDistanceMeters,
      lessThan(
        MapRouteService.distanceMeters(origin, LatLng(place.lat, place.lng)),
      ),
    );

    locationController.add(LatLng(place.lat, place.lng));
    await tester.pump();
    expect(
      tester.widget<MapRouteHud>(find.byType(MapRouteHud)).isArrived,
      isTrue,
    );
    expect(find.byKey(const ValueKey('map-view-header-bar')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('map-category-filter-bar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('map-place-marker-nearby-place')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('end-route-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('map-route-hud')), findsNothing);
    expect(find.byKey(const ValueKey('map-view-header-bar')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('map-category-filter-bar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('map-place-marker-route-destination')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('map-place-marker-nearby-place')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('map-route-destination-marker')),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('ATM sheet offers in-app routing without a visit action', (
    tester,
  ) async {
    var startedRoute = false;
    final openedUrls = <Uri>[];
    final locale = LocaleProvider();
    addTearDown(locale.dispose);
    final atm = MapPoi(
      id: 'atm_test',
      name: 'Test ATM',
      address: 'Aswan Governorate, Egypt',
      governorate: 'Aswan',
      lat: 24.0955,
      lng: 32.9008,
      category: 'ATM',
      icon: Icons.atm_rounded,
      color: Colors.blue,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<LocaleProvider>.value(
          value: locale,
          child: Scaffold(
            body: AtmSheet(
              atm: atm,
              onRoute: (_) => startedRoute = true,
              launchMapUrl: (uri) async {
                openedUrls.add(uri);
                return openedUrls.length == 2;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Open in Google Maps'), findsOneWidget);
    expect(find.text('Route on Map'), findsOneWidget);
    expect(find.textContaining('Check In'), findsNothing);
    expect(find.textContaining('Visit'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('atm-open-google-maps-button')));
    await tester.pump();
    expect(openedUrls, hasLength(2));
    expect(openedUrls.first.path, '/maps/dir/');
    expect(
      openedUrls.first.queryParameters['destination'],
      'Test ATM, Aswan Governorate, Egypt, Aswan',
    );
    expect(openedUrls.first.queryParameters['travelmode'], 'walking');
    expect(openedUrls.last.path, '/maps/search/');
    expect(
      openedUrls.last.queryParameters['query'],
      'Test ATM 24.0955,32.9008',
    );
    await tester.tap(find.byKey(const ValueKey('atm-route-on-map-button')));
    expect(startedRoute, isTrue);
  });

  testWidgets('map category chips show the union of Churches and Hotels', (
    tester,
  ) async {
    final harness = await _pumpLuxorMap(tester);
    addTearDown(harness.dispose);

    await _tapMapFilter(tester, 'churches');
    await _tapMapFilter(tester, 'hotels');

    expect(
      find.byKey(
        const ValueKey('map-place-marker-luxor_virgin_mary_cathedral'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('map-place-marker-luxor_sofitel_winter_palace'),
      ),
      findsOneWidget,
    );

    await _tapMapFilter(tester, 'churches');
    expect(
      find.byKey(
        const ValueKey('map-place-marker-luxor_virgin_mary_cathedral'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey('map-place-marker-luxor_sofitel_winter_palace'),
      ),
      findsOneWidget,
    );
    await _tapMapFilter(tester, 'hotels');
    expect(
      tester
          .widget<FilterChip>(find.byKey(const ValueKey('map-filter-chip-all')))
          .selected,
      isTrue,
    );
  });

  testWidgets('Luxor ATMs combine with selected Hotels on the map', (
    tester,
  ) async {
    final harness = await _pumpLuxorMap(tester);
    addTearDown(harness.dispose);

    await _tapMapFilter(tester, 'hotels');
    await _tapMapFilter(tester, 'atms');

    expect(
      find.byKey(
        const ValueKey('map-place-marker-luxor_sofitel_winter_palace'),
      ),
      findsOneWidget,
    );
    const luxorAtmIds = [
      'atm_nbe_luxor_temple_corniche',
      'atm_banque_misr_karnak_plaza',
      'atm_cib_winter_palace_luxor',
      'atm_qnb_luxor_station_square',
      'atm_nbe_west_bank_ferry_qurna',
      'atm_banque_misr_steigenberger_luxor',
    ];
    for (final id in luxorAtmIds) {
      expect(find.byKey(ValueKey('map-atm-marker-$id')), findsOneWidget);
    }
    expect(harness.places.places.where((place) => place.isAtm), isEmpty);
  });

  testWidgets('Aswan map shows all six ATMs only under the ATMs filter', (
    tester,
  ) async {
    final harness = await _pumpAswanMap(tester);
    addTearDown(harness.dispose);

    expect(harness.places.places.where((place) => place.isAtm), isEmpty);
    expect(
      harness.places.allPlaces.where(
        (place) => place.governorate == 'aswan' && place.isAtm,
      ),
      hasLength(6),
    );
    expect(
      find.byKey(
        const ValueKey('map-atm-marker-atm_nbe_aswan_corniche_station'),
      ),
      findsNothing,
    );

    await _tapMapFilter(tester, 'hotels');
    await _tapMapFilter(tester, 'atms');
    expect(
      find.byKey(
        const ValueKey('map-place-marker-aswan_sofitel_legend_old_cataract'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('map-atm-marker-atm_nbe_aswan_corniche_station'),
      ),
      findsOneWidget,
    );
    final map = find.byType(FlutterMap);
    for (var zoomOut = 0; zoomOut < 3; zoomOut++) {
      await _pinchMapOut(tester, map);
    }
    for (final id in [
      'atm_nbe_aswan_corniche_station',
      'atm_banque_misr_old_cataract_aswan',
      'atm_cib_aswan_tourist_souq',
      'atm_qnb_nubian_museum_aswan',
      'atm_nbe_kom_ombo_temple_plaza',
      'atm_banque_misr_edfu_temple_square',
    ]) {
      expect(find.byKey(ValueKey('map-atm-marker-$id')), findsOneWidget);
    }
  });

  testWidgets('map category matching normalizes singular and plural labels', (
    tester,
  ) async {
    final harness = await _pumpLuxorMap(
      tester,
      extraPlaces: [
        _aliasPlace('singular-cafe', 'Cafe', 25.7000, 32.6370),
        _aliasPlace('singular-mosque', 'Mosque', 25.7020, 32.6370),
        _aliasPlace('singular-church', 'Church', 25.7040, 32.6370),
        _aliasPlace('singular-hotel', 'Hotel', 25.7060, 32.6370),
        _aliasPlace('singular-museum', 'Museum', 25.7080, 32.6370),
        _aliasPlace('singular-park', 'Park', 25.7100, 32.6370),
        _aliasPlace('atm_singular_test', 'ATM', 25.7120, 32.6370),
      ],
    );
    addTearDown(harness.dispose);

    expect(
      harness.places.allPlaces.any(
        (place) => place.id == 'singular-mosque' && place.category == 'Mosque',
      ),
      isTrue,
    );
    for (final category in ['cafes', 'mosques', 'churches', 'hotels']) {
      await _tapMapFilter(tester, category);
    }
    await _tapMapFilter(tester, 'culture');
    await _tapMapFilter(tester, 'nature');
    await _tapMapFilter(tester, 'atms');

    for (final id in [
      'singular-cafe',
      'singular-mosque',
      'singular-church',
      'singular-hotel',
      'singular-museum',
      'singular-park',
    ]) {
      expect(find.byKey(ValueKey('map-place-marker-$id')), findsOneWidget);
    }
    expect(
      find.byKey(const ValueKey('map-atm-marker-atm_singular_test')),
      findsOneWidget,
    );
    expect(harness.places.places.any((place) => place.isAtm), isFalse);
  });
}

double _distanceFromLabel(String label) {
  final value = double.parse(label.split(' ').first);
  return label.endsWith('km') ? value * 1000 : value;
}

Future<_LuxorMapHarness> _pumpLuxorMap(
  WidgetTester tester, {
  Iterable<PlaceModel> extraPlaces = const [],
}) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final governorates = GovernorateProvider();
  governorates.unlockAndSelectGovernorate('luxor');
  final places = PlaceProvider(
    watchRemoteUpdates: false,
    governorates: governorates,
    isOnline: () => false,
    initialPlaces: [...luxorSeedPlaces, ...extraPlaces],
  );
  final trips = TripProvider();
  final locale = LocaleProvider();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: governorates),
        ChangeNotifierProvider.value(value: places),
        ChangeNotifierProvider.value(value: trips),
        ChangeNotifierProvider.value(value: locale),
      ],
      child: const MaterialApp(home: MapViewScreen(autoLocate: false)),
    ),
  );
  await tester.pump();
  return _LuxorMapHarness(
    governorates: governorates,
    places: places,
    trips: trips,
    locale: locale,
  );
}

Future<_LuxorMapHarness> _pumpAswanMap(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final governorates = GovernorateProvider();
  governorates.unlockAndSelectGovernorate('aswan');
  final places = PlaceProvider(
    watchRemoteUpdates: false,
    governorates: governorates,
    isOnline: () => false,
    initialPlaces: aswanSeedPlaces,
  );
  final trips = TripProvider();
  final locale = LocaleProvider();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: governorates),
        ChangeNotifierProvider.value(value: places),
        ChangeNotifierProvider.value(value: trips),
        ChangeNotifierProvider.value(value: locale),
      ],
      child: const MaterialApp(home: MapViewScreen(autoLocate: false)),
    ),
  );
  await tester.pump();
  return _LuxorMapHarness(
    governorates: governorates,
    places: places,
    trips: trips,
    locale: locale,
  );
}

PlaceModel _aliasPlace(String id, String category, double lat, double lng) =>
    PlaceModel(
      id: id,
      nameEn: id,
      descriptionEn: 'A category alias map test place.',
      imageUrl: '',
      rating: 4.0,
      category: category,
      lat: lat,
      lng: lng,
      governorate: 'luxor',
    );

Future<void> _pinchMapOut(WidgetTester tester, Finder map) async {
  final center = tester.getCenter(map);
  final firstFinger = await tester.startGesture(
    center.translate(-120, 0),
    pointer: 1,
  );
  final secondFinger = await tester.startGesture(
    center.translate(120, 0),
    pointer: 2,
  );
  await tester.pump();
  await firstFinger.moveTo(center.translate(-30, 0));
  await secondFinger.moveTo(center.translate(30, 0));
  await tester.pumpAndSettle();
  await firstFinger.up();
  await secondFinger.up();
  await tester.pumpAndSettle();
}

Future<void> _tapMapFilter(WidgetTester tester, String category) async {
  final chip = find.byKey(ValueKey('map-filter-chip-$category'));
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await tester.pump();
}

class _LuxorMapHarness {
  final GovernorateProvider governorates;
  final PlaceProvider places;
  final TripProvider trips;
  final LocaleProvider locale;

  const _LuxorMapHarness({
    required this.governorates,
    required this.places,
    required this.trips,
    required this.locale,
  });

  void dispose() {
    governorates.dispose();
    places.dispose();
    trips.dispose();
    locale.dispose();
  }
}
