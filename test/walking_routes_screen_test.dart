import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetlore/core/services/map_route_service.dart';
import 'package:streetlore/data/models/egypt_governorate.dart';
import 'package:streetlore/data/models/place_model.dart';
import 'package:streetlore/logic/governorate_provider.dart';
import 'package:streetlore/logic/locale_provider.dart';
import 'package:streetlore/logic/place_provider.dart';
import 'package:streetlore/presentation/screens/walking_routes_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'pins and picker select five nearby stops in order from the live origin',
    (tester) async {
      const liveOrigin = LatLng(31.205, 29.925);
      final alexandriaPlaces = [
        _place('alex-near', 'alexandria', 31.2053, 29.9252),
        _place('alex-next', 'alexandria', 31.2055, 29.9258, 'Food'),
        _place('alex-mid', 'alexandria', 31.204, 29.923, 'Nature'),
        _place('alex-far', 'alexandria', 31.215, 29.950, 'Culture'),
        _place('alex-fourth', 'alexandria', 31.208, 29.920, 'Shopping'),
        _place('alex-fifth', 'alexandria', 31.202, 29.928, 'Hotels'),
        _place('atm-alex', 'alexandria', 31.2045, 29.924, 'ATM'),
        _place('cairo-place', 'cairo', 30.045, 31.236),
        _place('luxor-place', 'luxor', 25.688, 32.640),
      ];
      final calls = <({LatLng origin, LatLng destination})>[];
      final harness = _createHarness(
        places: alexandriaPlaces,
        locationProvider: () async => liveOrigin,
        routeService: MapRouteService(
          routeFetcher: (origin, destination) async {
            calls.add((origin: origin, destination: destination));
            return [origin, destination];
          },
        ),
      );
      addTearDown(() => _disposeHarness(tester, harness));

      await harness.pump(tester);

      expect(
        find.byKey(const ValueKey('walking-route-origin')),
        findsOneWidget,
      );
      expect(find.text('You'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('walking-route-category-alex-near')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('walking-route-place-cairo-place')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('walking-route-place-atm-alex')),
        findsNothing,
      );

      final nearRow = find.byKey(
        const ValueKey('walking-route-picker-alex-near'),
      );
      final nextRow = find.byKey(
        const ValueKey('walking-route-picker-alex-next'),
      );
      expect(
        tester.getTopLeft(nearRow).dy,
        lessThan(tester.getTopLeft(nextRow).dy),
      );
      await tester.tap(nearRow);
      await tester.pumpAndSettle();
      expect(calls.first.origin, liveOrigin);
      expect(calls.first.destination, const LatLng(31.2053, 29.9252));

      await tester.tap(
        find.byKey(const ValueKey('walking-route-place-alex-far')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('walking-route-stop-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('walking-route-stop-2')),
        findsOneWidget,
      );
      expect(calls[calls.length - 2].origin, liveOrigin);
      expect(
        calls[calls.length - 2].destination,
        const LatLng(31.2053, 29.9252),
      );
      expect(calls.last.origin, const LatLng(31.2053, 29.9252));
      expect(calls.last.destination, const LatLng(31.215, 29.950));

      for (final id in ['alex-mid', 'alex-fourth', 'alex-fifth']) {
        final row = find.byKey(ValueKey('walking-route-picker-$id'));
        await tester.scrollUntilVisible(
          row,
          100,
          scrollable: find.descendant(
            of: find.byKey(const ValueKey('walking-route-place-list')),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.tap(row);
        await tester.pumpAndSettle();
      }

      for (var index = 1; index <= 5; index++) {
        expect(
          find.byKey(ValueKey('walking-route-stop-$index')),
          findsOneWidget,
        );
      }
      final route = tester
          .widget<PolylineLayer>(
            find.byKey(const ValueKey('walking-route-polyline-layer')),
          )
          .polylines
          .single
          .points;
      expect(route.first, liveOrigin);
      expect(route[1], const LatLng(31.2053, 29.9252));
      expect(route[2], const LatLng(31.215, 29.950));
      expect(route.last, const LatLng(31.202, 29.928));

      var expectedDistance = 0.0;
      var previous = liveOrigin;
      for (final stop in [
        const LatLng(31.2053, 29.9252),
        const LatLng(31.215, 29.950),
        const LatLng(31.204, 29.923),
        const LatLng(31.208, 29.920),
        const LatLng(31.202, 29.928),
      ]) {
        expectedDistance += MapRouteService.distanceMeters(previous, stop);
        previous = stop;
      }
      final expectedMinutes = MapRouteService.walkingMinutes(expectedDistance);
      final expectedTime = expectedMinutes < 60
          ? '$expectedMinutes min'
          : '${expectedMinutes ~/ 60}h ${expectedMinutes % 60}m';
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('walking-route-distance')))
            .data,
        '${(expectedDistance / 1000).toStringAsFixed(1)} km · $expectedTime',
      );

      await tester.tap(
        find.byKey(const ValueKey('walking-route-place-alex-near')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('walking-route-stop-1')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('walking-route-stop-5')), findsNothing);
    },
  );

  testWidgets(
    'switching governorates clears old stops and anchors remote routes locally',
    (tester) async {
      const alexandriaLocation = LatLng(31.205, 29.925);
      final calls = <({LatLng origin, LatLng destination})>[];
      final harness = _createHarness(
        places: [
          _place('alex-place', 'alexandria', 31.2053, 29.9252),
          _place('cairo-place', 'cairo', 30.045, 31.236),
          _place('luxor-place', 'luxor', 25.688, 32.640),
          _place('red-sea-place', 'red_sea', 26.8525, 33.9925),
        ],
        locationProvider: () async => alexandriaLocation,
        routeService: MapRouteService(
          routeFetcher: (origin, destination) async {
            calls.add((origin: origin, destination: destination));
            return [origin, destination];
          },
        ),
      );
      addTearDown(() => _disposeHarness(tester, harness));

      await harness.pump(tester);
      for (final id in ['alexandria', 'cairo', 'luxor', 'red_sea']) {
        expect(
          find.byKey(ValueKey('walking-routes-governorate-$id')),
          findsOneWidget,
        );
      }
      await tester.tap(
        find.byKey(const ValueKey('walking-route-picker-alex-place')),
      );
      await tester.pumpAndSettle();
      expect(calls.last.origin, alexandriaLocation);

      await tester.tap(
        find.byKey(const ValueKey('walking-routes-governorate-cairo')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('walking-route-stop-1')), findsNothing);
      expect(
        find.byKey(const ValueKey('walking-route-place-alex-place')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('walking-route-place-cairo-place')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('walking-route-picker-cairo-place')),
      );
      await tester.pumpAndSettle();
      final cairoAnchor = LatLng(
        EgyptGovernorate.byId['cairo']!.centerLat,
        EgyptGovernorate.byId['cairo']!.centerLng,
      );
      expect(calls.last.origin, cairoAnchor);

      await tester.tap(
        find.byKey(const ValueKey('walking-routes-governorate-luxor')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('walking-route-stop-1')), findsNothing);
      expect(
        find.byKey(const ValueKey('walking-route-place-cairo-place')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('walking-route-picker-luxor-place')),
      );
      await tester.pumpAndSettle();
      final luxorAnchor = LatLng(
        EgyptGovernorate.byId['luxor']!.centerLat,
        EgyptGovernorate.byId['luxor']!.centerLng,
      );
      expect(calls.last.origin, luxorAnchor);

      await tester.tap(
        find.byKey(const ValueKey('walking-routes-governorate-red_sea')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('walking-route-stop-1')), findsNothing);
      expect(
        find.byKey(const ValueKey('walking-route-place-luxor-place')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('walking-route-place-red-sea-place')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('walking-route-picker-red-sea-place')),
      );
      await tester.pumpAndSettle();
      final redSeaAnchor = LatLng(
        EgyptGovernorate.byId['red_sea']!.centerLat,
        EgyptGovernorate.byId['red_sea']!.centerLng,
      );
      expect(calls.last.origin, redSeaAnchor);
    },
  );
}

PlaceModel _place(
  String id,
  String governorate,
  double latitude,
  double longitude, [
  String category = 'Historical',
]) => PlaceModel(
  id: id,
  nameEn: id,
  descriptionEn: 'Walking route test place.',
  imageUrl: '',
  rating: 4.5,
  category: category,
  lat: latitude,
  lng: longitude,
  governorate: governorate,
);

_WalkingRoutesHarness _createHarness({
  required List<PlaceModel> places,
  required Future<LatLng?> Function() locationProvider,
  required MapRouteService routeService,
}) {
  final governorates = GovernorateProvider();
  final placeProvider = PlaceProvider(
    watchRemoteUpdates: false,
    governorates: governorates,
    isOnline: () => false,
    initialPlaces: places,
  );
  final locale = LocaleProvider();
  return _WalkingRoutesHarness(
    governorates: governorates,
    places: placeProvider,
    locale: locale,
    routeService: routeService,
    locationProvider: locationProvider,
  );
}

Future<void> _disposeHarness(
  WidgetTester tester,
  _WalkingRoutesHarness harness,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  harness.governorates.dispose();
  harness.places.dispose();
  harness.locale.dispose();
  harness.routeService.close();
}

class _WalkingRoutesHarness {
  const _WalkingRoutesHarness({
    required this.governorates,
    required this.places,
    required this.locale,
    required this.routeService,
    required this.locationProvider,
  });

  final GovernorateProvider governorates;
  final PlaceProvider places;
  final LocaleProvider locale;
  final MapRouteService routeService;
  final Future<LatLng?> Function() locationProvider;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: governorates),
          ChangeNotifierProvider.value(value: places),
          ChangeNotifierProvider.value(value: locale),
        ],
        child: MaterialApp(
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: WalkingRoutesScreen(
            routeService: routeService,
            locationProvider: locationProvider,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}
