import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetlore/core/services/map_route_service.dart';
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
    final places = PlaceProvider(
      watchRemoteUpdates: false,
      governorates: governorates,
      isOnline: () => false,
      initialPlaces: const [place],
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

    await tester.tap(
      find.byKey(const ValueKey('map-place-marker-route-destination')),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('route-on-map-button')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('route-on-map-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('map-route-hud')), findsOneWidget);
    expect(find.byType(PolylineLayer), findsOneWidget);
    expect(
      find.byKey(const ValueKey('map-route-user-location')),
      findsOneWidget,
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
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('ATM sheet offers in-app routing without a visit action', (
    tester,
  ) async {
    var startedRoute = false;
    final locale = LocaleProvider();
    addTearDown(locale.dispose);
    final atm = MapPoi(
      id: 'atm_test',
      name: 'Test ATM',
      address: 'Cairo',
      lat: 30.0444,
      lng: 31.2357,
      category: 'ATM',
      icon: Icons.atm_rounded,
      color: Colors.blue,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<LocaleProvider>.value(
          value: locale,
          child: Scaffold(
            body: AtmSheet(atm: atm, onRoute: (_) => startedRoute = true),
          ),
        ),
      ),
    );

    expect(find.text('Route on Map'), findsOneWidget);
    expect(find.textContaining('Check In'), findsNothing);
    expect(find.textContaining('Visit'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('atm-route-on-map-button')));
    expect(startedRoute, isTrue);
  });
}

double _distanceFromLabel(String label) {
  final value = double.parse(label.split(' ').first);
  return label.endsWith('km') ? value * 1000 : value;
}
