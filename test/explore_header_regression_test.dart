import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetlore/core/services/compass_service.dart';
import 'package:streetlore/data/models/place_model.dart';
import 'package:streetlore/logic/auth_provider.dart';
import 'package:streetlore/logic/governorate_provider.dart';
import 'package:streetlore/logic/place_provider.dart';
import 'package:streetlore/logic/tour_provider.dart';
import 'package:streetlore/logic/trip_provider.dart';
import 'package:streetlore/logic/locale_provider.dart';
import 'package:streetlore/presentation/screens/home_screen.dart';

class _ExploreTestAuth extends ChangeNotifier implements AuthProvider {
  @override
  bool get isPro => true;
  @override
  bool get isLoggedIn => false;
  @override
  bool get isGuest => false;
  @override
  String get userId => '';
  @override
  String get userName => '';
  @override
  String get username => '';
  @override
  String get avatarUrl => '';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Explore title gradient and quick actions stay below search', (
    tester,
  ) async {
    addTearDown(CompassService.instance.stop);
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final governorates = GovernorateProvider();
    final places = PlaceProvider(
      watchRemoteUpdates: false,
      governorates: governorates,
      initialPlaces: const [
        PlaceModel(
          id: 'test-place',
          nameEn: 'Test Place',
          descriptionEn: 'A test landmark',
          imageUrl: '',
          rating: 4.5,
          lat: 31.2,
          lng: 29.9,
        ),
      ],
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => _ExploreTestAuth(),
          ),
          ChangeNotifierProvider<PlaceProvider>.value(value: places),
          ChangeNotifierProvider<TourProvider>(
            create: (_) => TourProvider(governorates: governorates),
          ),
          ChangeNotifierProvider<TripProvider>(create: (_) => TripProvider()),
          ChangeNotifierProvider<GovernorateProvider>.value(
            value: governorates,
          ),
          ChangeNotifierProvider<LocaleProvider>(
            create: (_) => LocaleProvider(),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump();
    CompassService.instance.stop();

    expect(find.text('EgyptLore'), findsOneWidget);
    final selectorBox = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('home-governorate-selector')),
    );
    final titleBox = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('explore-title')),
    );
    final selectorTop = selectorBox.localToGlobal(Offset.zero).dy;
    final titleTop = titleBox.localToGlobal(Offset.zero).dy;
    expect((selectorTop - titleTop).abs(), lessThan(10));

    final titleGradient = tester.widget<ShaderMask>(
      find.byKey(const ValueKey('explore-title-gradient')),
    );
    expect(titleGradient, isNotNull);
    expect(kExploreTitleGradientColors.first, const Color(0xFF34D399));
    expect(
      kExploreTitleGradientColors.first.computeLuminance(),
      greaterThan(0.3),
    );
    expect(kExploreTitleGradientColors[1], const Color(0xFFF5C45E));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('quick-quick_ranking')),
        matching: find.byIcon(Icons.leaderboard_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('quick-quick_badges')),
        matching: find.byIcon(Icons.workspace_premium_rounded),
      ),
      findsOneWidget,
    );

    final searchBox = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('explore-search-field')),
    );
    final quickCircleBox = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey('quick-quick_map')),
    );
    final searchBottom =
        searchBox.localToGlobal(Offset.zero).dy + searchBox.size.height;
    final selectorBottom = selectorTop + selectorBox.size.height;
    expect(selectorBottom, lessThan(searchBox.localToGlobal(Offset.zero).dy));
    final circleTop = quickCircleBox.localToGlobal(Offset.zero).dy;
    expect(circleTop, greaterThanOrEqualTo(searchBottom));
  });
}
