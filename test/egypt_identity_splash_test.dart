import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/presentation/screens/splash_screen.dart';

void main() {
  testWidgets('mobile compass emblem is centered in its rings', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            padding: EdgeInsets.only(top: 40, bottom: 24),
          ),
          child: SplashScreen(),
        ),
      ),
    );
    await tester.pump();

    final rings = find.byKey(const ValueKey('splash-compass-rings'));
    final compass = find.byKey(const ValueKey('splash-compass-emblem'));
    expect(rings, findsOneWidget);
    expect(compass, findsOneWidget);
    final ringsCenter = tester.getCenter(rings);
    final compassCenter = tester.getCenter(compass);
    expect((ringsCenter.dx - compassCenter.dx).abs(), lessThanOrEqualTo(.01));
    expect((ringsCenter.dy - compassCenter.dy).abs(), lessThanOrEqualTo(.01));
    expect(tester.getSize(rings), const Size(280, 280));
    expect(tester.getSize(rings).width, tester.getSize(rings).height);

    final compassAsset = find.byKey(const ValueKey('splash-compass-asset'));
    final centeringTransform = tester.widget<Transform>(
      find.ancestor(of: compassAsset, matching: find.byType(Transform)).first,
    );
    final imageScale = (280 * (.785 - 2 * .096) - 2) / 713;
    expect(
      centeringTransform.transform.getTranslation().x,
      closeTo(-6 * imageScale, .01),
    );
    expect(
      centeringTransform.transform.getTranslation().y,
      closeTo(-12 * imageScale, .01),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('transitions from radar entrance to pyramids splash', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump();

    expect(find.byKey(const ValueKey('radar-stage')), findsOneWidget);
    expect(find.text('EgyptLore'), findsOneWidget);
    expect(find.byKey(const ValueKey('splash-progress')), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('pyramids-stage')), findsNothing);

    double opacityOfStage(Key key) {
      final stage = find.byKey(key);
      final transition = tester.widget<FadeTransition>(
        find.ancestor(of: stage, matching: find.byType(FadeTransition)).first,
      );
      return transition.opacity.value;
    }

    double progressValue() => tester
        .widget<LinearProgressIndicator>(
          find.byKey(const ValueKey('splash-progress')),
        )
        .value!;

    expect(opacityOfStage(const ValueKey('radar-stage')), 1);
    await tester.pump(const Duration(milliseconds: 1399));
    expect(find.byKey(const ValueKey('radar-stage')), findsOneWidget);
    expect(opacityOfStage(const ValueKey('radar-stage')), 1);
    expect(progressValue(), closeTo(0.5, 0.001));

    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byKey(const ValueKey('radar-stage')), findsOneWidget);
    expect(find.byKey(const ValueKey('pyramids-stage')), findsNothing);
    expect(opacityOfStage(const ValueKey('radar-stage')), 1);
    expect(progressValue(), closeTo(0.5, 0.001));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 249));
    expect(find.byKey(const ValueKey('radar-stage')), findsOneWidget);
    expect(find.byKey(const ValueKey('pyramids-stage')), findsNothing);
    expect(opacityOfStage(const ValueKey('radar-stage')), lessThan(0.01));

    await tester.pump(const Duration(milliseconds: 5));
    expect(find.byKey(const ValueKey('radar-stage')), findsNothing);
    expect(find.byKey(const ValueKey('pyramids-stage')), findsOneWidget);
    expect(opacityOfStage(const ValueKey('pyramids-stage')), 0);
    expect(find.text('EgyptLore'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('pyramids-compass-image')), findsNothing);
    await tester.pump(const Duration(milliseconds: 255));
    expect(opacityOfStage(const ValueKey('pyramids-stage')), greaterThan(0.99));
    expect(progressValue(), closeTo(0.5, 0.005));
    await tester.pump(const Duration(milliseconds: 700));
    expect(progressValue(), closeTo(0.75, 0.005));
    expect(opacityOfStage(const ValueKey('pyramids-stage')), 1);
    await tester.pump(const Duration(milliseconds: 689));
    expect(opacityOfStage(const ValueKey('pyramids-stage')), 1);

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
    expect(find.byKey(const ValueKey('pyramids-stage')), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(opacityOfStage(const ValueKey('pyramids-stage')), 1);
    expect(progressValue(), closeTo(1, 0.001));
  });
}
