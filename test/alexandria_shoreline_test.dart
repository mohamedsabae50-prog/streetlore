import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/presentation/widgets/alexandria_shoreline.dart';

void main() {
  test('waveY oscillates around the baseline within the amplitude', () {
    for (var x = 0.0; x <= 400; x += 7) {
      final y = ShorelinePainter.waveY(
        x: x,
        width: 400,
        baseline: 80,
        amplitude: 6,
        wavelengths: 2,
        phase: 1.3,
      );
      expect(y, inInclusiveRange(74, 86));
    }
  });

  test('repaints only when the animation progresses', () {
    final a = ShorelinePainter(progress: 0.2);
    expect(a.shouldRepaint(ShorelinePainter(progress: 0.2)), isFalse);
    expect(a.shouldRepaint(ShorelinePainter(progress: 0.3)), isTrue);
  });

  testWidgets('animates and paints without errors', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AlexandriaShoreline())),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(AlexandriaShoreline), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stays still when the platform asks to reduce motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: Scaffold(body: AlexandriaShoreline())),
      ),
    );
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
