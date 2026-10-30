import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/presentation/screens/splash_screen.dart';

void main() {
  testWidgets('transitions from radar entrance to pyramids splash', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.byKey(const ValueKey('radar-stage')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 3400));

    expect(find.byKey(const ValueKey('pyramids-stage')), findsOneWidget);
    expect(find.byKey(const ValueKey('pyramids-progress')), findsOneWidget);
    final background = tester.widget<Image>(
      find.byKey(const ValueKey('pyramids-background-image')),
    );
    expect(background.image, isA<AssetImage>());
    expect(
      (background.image as AssetImage).assetName,
      'assets/images/splash_bg.png',
    );
    final compass = tester.widget<Image>(
      find.byKey(const ValueKey('pyramids-compass-image')),
    );
    expect(compass.image, isA<AssetImage>());
    expect(
      (compass.image as AssetImage).assetName,
      'assets/images/compass_only.png',
    );
    expect(
      find.bySemanticsLabel(
        'EgyptLore. Egypt Unseen — Discover Egypt’s Hidden Stories. اكتشف حكايات وكنوز مصر المخفية',
      ),
      findsOneWidget,
    );
  });
}
