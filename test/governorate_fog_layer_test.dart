import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetlore/data/models/egypt_governorate.dart';
import 'package:streetlore/logic/governorate_provider.dart';
import 'package:streetlore/presentation/widgets/governorate_explorer_sheet.dart';
import 'package:streetlore/presentation/widgets/governorate_fog_layer.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('fog polygon leaves active governorate as an inverted hole', (
    tester,
  ) async {
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

    final layer = tester.widget<PolygonLayer>(find.byType(PolygonLayer));
    final fog = layer.polygons.first;
    expect(fog.points, hasLength(4));
    expect(fog.holePointsList, hasLength(1));
    expect(
      fog.holePointsList!.single,
      EgyptGovernorate.byId['alexandria']!.boundaryPolygon,
    );
    expect(fog.color, const Color(0xCC060C18));
    expect(layer.polygons.last.borderColor, const Color(0xFF00E5FF));
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
