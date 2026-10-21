import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
