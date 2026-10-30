import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/presentation/screens/splash_screen.dart';

void main() {
  testWidgets('transitions from radar entrance to pyramids splash', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.byKey(const ValueKey('radar-stage')), findsOneWidget);
    expect(find.text('EgyptLore'), findsOneWidget);
    expect(find.byKey(const ValueKey('splash-progress')), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('pyramids-stage')), findsNothing);

    await tester.pump(const Duration(milliseconds: 799));
    expect(find.byKey(const ValueKey('radar-stage')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byKey(const ValueKey('radar-stage')), findsOneWidget);
    expect(find.byKey(const ValueKey('pyramids-stage')), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 249));
    expect(find.byKey(const ValueKey('radar-stage')), findsOneWidget);
    expect(find.byKey(const ValueKey('pyramids-stage')), findsNothing);

    await tester.pump(const Duration(milliseconds: 5));
    expect(find.byKey(const ValueKey('radar-stage')), findsNothing);

    expect(find.byKey(const ValueKey('pyramids-stage')), findsOneWidget);
    expect(find.text('EgyptLore'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('pyramids-compass-image')), findsNothing);
    await tester.pump(const Duration(milliseconds: 250));
    final background = tester.widget<Image>(
      find.byKey(const ValueKey('pyramids-background-image')),
    );
    expect(background.image, isA<AssetImage>());
    expect(
      (background.image as AssetImage).assetName,
      'assets/images/splash_bg.png',
    );
    expect(
      find.bySemanticsLabel(
        'EgyptLore. Egypt Unseen — Discover Egypt’s Hidden Stories. اكتشف حكايات وكنوز مصر المخفية',
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 1590));
    expect(find.byKey(const ValueKey('pyramids-stage')), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
