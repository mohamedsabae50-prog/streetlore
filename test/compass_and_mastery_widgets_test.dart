import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:math' as math;
import 'package:streetlore/data/models/place_model.dart';
import 'package:streetlore/presentation/widgets/alexandria_mastery_bar.dart';
import 'package:streetlore/presentation/widgets/compass_card.dart';
import 'package:streetlore/presentation/widgets/head_to_head_comparison_card.dart';
import 'package:streetlore/presentation/widgets/social_user_widgets.dart';
import 'package:streetlore/logic/locale_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

PlaceModel _place(String id, String name) => PlaceModel(
  id: id,
  nameEn: name,
  descriptionEn: '',
  imageUrl: '',
  rating: 4,
  lat: 31.2,
  lng: 29.9,
);

void main() {
  testWidgets('compact mastery pill is single-line and reports progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CompactAlexandriaMasteryPill(
            places: [_place('a', 'A'), _place('b', 'B')],
            visitedPlaceIds: const {'a'},
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('1/2 · 50%'), findsOneWidget);
    expect(
      tester.getSize(find.byType(CompactAlexandriaMasteryPill)).height,
      lessThanOrEqualTo(36),
    );
  });

  testWidgets('compass dial shows North and Qibla markers together', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CompassDialIndicators(qiblaAvailable: true)),
      ),
    );

    expect(find.byKey(const ValueKey('compass-north-marker')), findsOneWidget);
    expect(find.byKey(const ValueKey('compass-qibla-marker')), findsOneWidget);
    final north = tester.getCenter(
      find.byKey(const ValueKey('compass-north-marker')),
    );
    final qibla = tester.getCenter(
      find.byKey(const ValueKey('compass-qibla-marker')),
    );
    expect((north - qibla).distance, greaterThan(18));
  });

  testWidgets(
    'compass face keeps the box and markers fixed while pointer rotates',
    (tester) async {
      Future<void> pumpFace(double heading) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompassCardFace(
              headingDegrees: heading,
              qiblaBearingDegrees: 120,
              qiblaAvailable: true,
              compassWorking: true,
              fallbackAngle: 0,
            ),
          ),
        ),
      );

      await pumpFace(0);
      final backgroundCenter = tester.getCenter(
        find.byKey(const ValueKey('compass-square-background')),
      );
      final northCenter = tester.getCenter(
        find.byKey(const ValueKey('compass-north-marker')),
      );
      final qiblaCenter = tester.getCenter(
        find.byKey(const ValueKey('compass-qibla-marker')),
      );
      final pointerTransform = tester.widget<Transform>(
        find.byKey(const ValueKey('compass-pointer-rotation')),
      );
      final initialAngle = math.atan2(
        pointerTransform.transform.storage[1],
        pointerTransform.transform.storage[0],
      );

      await pumpFace(90);
      await tester.pumpAndSettle();
      final movedBackgroundCenter = tester.getCenter(
        find.byKey(const ValueKey('compass-square-background')),
      );
      final movedNorthCenter = tester.getCenter(
        find.byKey(const ValueKey('compass-north-marker')),
      );
      final movedQiblaCenter = tester.getCenter(
        find.byKey(const ValueKey('compass-qibla-marker')),
      );
      final movedTransform = tester.widget<Transform>(
        find.byKey(const ValueKey('compass-pointer-rotation')),
      );
      final movedAngle = math.atan2(
        movedTransform.transform.storage[1],
        movedTransform.transform.storage[0],
      );

      expect(movedBackgroundCenter, backgroundCenter);
      expect(movedNorthCenter, northCenter);
      expect(movedQiblaCenter, qiblaCenter);
      expect(movedAngle, isNot(closeTo(initialAngle, 0.01)));
      expect(
        find.byKey(const ValueKey('compass-pointer-rotation')),
        findsOneWidget,
      );
    },
  );

  testWidgets('head-to-head compares active catalog and shared places', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LocaleProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: HeadToHeadComparisonCard(
              places: [
                _place('one', 'One'),
                _place('two', 'Two'),
                _place('three', 'Three'),
              ],
              myVisitedIds: const {'one', 'two'},
              theirVisitedIds: const {'one', 'three'},
              otherUsername: 'explorer',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Head-to-Head'), findsOneWidget);
    expect(find.text('67% · 2 places'), findsNWidgets(2));
    expect(find.text('🤝 Tied!'), findsOneWidget);
    expect(find.text('1 shared place'), findsOneWidget);
    expect(find.text('One'), findsOneWidget);
  });

  testWidgets('friend badge shows three avatars and localized count', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LocaleProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: FriendsVisitBadge(
              friends: [
                {'username': 'sara', 'full_name': 'Sara'},
                {'username': 'omar', 'full_name': 'Omar'},
                {'username': 'lina', 'full_name': 'Lina'},
                {'username': 'nour', 'full_name': 'Nour'},
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Visited by @sara +3 others'), findsOneWidget);
    expect(find.byType(ExplorerAvatar), findsNWidgets(3));
  });

  testWidgets('friend badge localizes the visit label in Arabic', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'app_locale_v1': 'ar'});
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LocaleProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: FriendsVisitBadge(
              friends: [
                {'username': 'sara', 'full_name': 'Sara'},
                {'username': 'omar', 'full_name': 'Omar'},
                {'username': 'lina', 'full_name': 'Lina'},
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('زاره @sara و 2 آخرين'), findsOneWidget);
  });
}
