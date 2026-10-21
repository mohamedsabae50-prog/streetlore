import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetlore/data/models/egypt_governorate.dart';
import 'package:streetlore/logic/governorate_provider.dart';
import 'package:streetlore/logic/locale_provider.dart';
import 'package:streetlore/logic/place_provider.dart';
import 'package:streetlore/logic/trip_provider.dart';
import 'package:streetlore/presentation/screens/map_view_screen.dart';
import 'package:streetlore/presentation/widgets/governorate_explorer_sheet.dart';
import 'package:streetlore/presentation/widgets/governorate_fog_layer.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('screen-space fog path fills the exterior and cuts out Alexandria', () {
    const size = Size(100, 100);
    final path = buildGovernorateFogCutoutPath(size, const [
      Offset(30, 30),
      Offset(70, 30),
      Offset(70, 70),
      Offset(30, 70),
    ]);

    expect(path.fillType, PathFillType.evenOdd);
    expect(path.contains(const Offset(10, 10)), isTrue);
    expect(path.contains(const Offset(50, 50)), isFalse);
  });

  test('smooth governorate path makes curved cutout edges', () {
    final points = const [
      Offset(20, 20),
      Offset(80, 20),
      Offset(80, 80),
      Offset(20, 80),
    ];
    final smooth = buildSmoothGovernoratePath(points);
    final sharp = Path()
      ..moveTo(points.first.dx, points.first.dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..lineTo(points[2].dx, points[2].dy)
      ..lineTo(points[3].dx, points[3].dy)
      ..close();

    expect(smooth.computeMetrics().single.length, greaterThan(200));
    expect(
      smooth.computeMetrics().single.length,
      isNot(closeTo(sharp.computeMetrics().single.length, 0.01)),
    );
    expect(smooth.contains(const Offset(50, 50)), isTrue);
    expect(smooth.contains(const Offset(5, 50)), isFalse);
  });

  testWidgets('fog layer paints a camera-synced cloud overlay', (tester) async {
    final provider = GovernorateProvider();
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(
            body: FlutterMap(
              options: MapOptions(initialCenter: LatLng(31.2, 29.9)),
              children: [GovernorateFogLayer(places: [])],
            ),
          ),
        ),
      ),
    );

    final customPaint = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('governorate-cloud-fog')),
    );
    expect(customPaint.painter, isA<CustomPainter>());
    expect(find.byType(IgnorePointer), findsWidgets);
    expect(find.byType(MarkerLayer), findsOneWidget);
    expect(EgyptGovernorate.byId['alexandria']!.boundaryPolygon, isNotEmpty);
  });

  testWidgets('governorate badge bounds do not overlap at zoom six', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = GovernorateProvider();
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(
            body: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(30.8, 30.5),
                initialZoom: 6,
              ),
              children: [GovernorateFogLayer(places: [])],
            ),
          ),
        ),
      ),
    );

    final paint = find.byKey(const ValueKey('governorate-cloud-fog'));
    final camera = MapCamera.of(tester.element(paint));
    expect(camera.zoom, 6);
    final layer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
    final alexandria = EgyptGovernorate.byId['alexandria']!;
    final projectedBoundary = alexandria.boundaryPolygon.map((point) {
      final screen = camera.latLngToScreenPoint(point);
      return Offset(screen.x, screen.y);
    });
    final activeBounds = _boundsOf(projectedBoundary);
    final centers = layer.markers.map((marker) {
      final screen = camera.latLngToScreenPoint(marker.point);
      return Offset(screen.x, screen.y);
    }).toList();

    for (var i = 0; i < centers.length; i++) {
      final first = Rect.fromCenter(center: centers[i], width: 96, height: 32);
      final nearest = Offset(
        centers[i].dx.clamp(activeBounds.left, activeBounds.right).toDouble(),
        centers[i].dy.clamp(activeBounds.top, activeBounds.bottom).toDouble(),
      );
      expect((centers[i] - nearest).distance, greaterThan(64));
      for (var j = i + 1; j < centers.length; j++) {
        final second = Rect.fromCenter(
          center: centers[j],
          width: 96,
          height: 32,
        );
        expect(first.inflate(10).overlaps(second), isFalse);
      }
    }
  });

  testWidgets('map header keeps the governorate pill clear of back button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final governorates = GovernorateProvider();
    final places = PlaceProvider(
      watchRemoteUpdates: false,
      governorates: governorates,
    );
    final trips = TripProvider();
    final locale = LocaleProvider();
    addTearDown(governorates.dispose);
    addTearDown(places.dispose);
    addTearDown(trips.dispose);
    addTearDown(locale.dispose);

    for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: governorates),
            ChangeNotifierProvider.value(value: places),
            ChangeNotifierProvider.value(value: trips),
            ChangeNotifierProvider.value(value: locale),
          ],
          child: MaterialApp(
            home: Directionality(
              textDirection: direction,
              child: const MapViewScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      final pill = find.byKey(const ValueKey('map-view-governorate-pill'));
      final header = find.byKey(const ValueKey('map-view-header-bar'));
      final backButton = find.byKey(const ValueKey('map-view-back-button'));
      expect(pill, findsOneWidget);
      expect(find.ancestor(of: pill, matching: header), findsOneWidget);
      expect(
        tester.getRect(backButton).overlaps(tester.getRect(pill)),
        isFalse,
      );
    }
  });

  testWidgets('governorate explorer lists all 27 governorates', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = GovernorateProvider();
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(body: GovernorateExplorerSheet(places: [])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final governorate in EgyptGovernorate.all) {
      expect(find.text(governorate.nameEn), findsOneWidget);
    }
    expect(find.text('1 / 27 Governorates Unlocked'), findsOneWidget);
  });
}

Rect _boundsOf(Iterable<Offset> points) {
  var left = double.infinity;
  var top = double.infinity;
  var right = double.negativeInfinity;
  var bottom = double.negativeInfinity;
  for (final point in points) {
    if (point.dx < left) left = point.dx;
    if (point.dy < top) top = point.dy;
    if (point.dx > right) right = point.dx;
    if (point.dy > bottom) bottom = point.dy;
  }
  return Rect.fromLTRB(left, top, right, bottom);
}
