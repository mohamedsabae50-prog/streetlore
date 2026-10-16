import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/presentation/screens/splash_screen.dart';

void main() {
  testWidgets('shows the cinematic EgyptLore splash identity', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump(const Duration(seconds: 2));

    expect(find.byKey(const ValueKey('splash-background')), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'EgyptLore. Egypt Unseen — Discover Egypt’s Hidden Stories. اكتشف حكايات وكنوز مصر المخفية',
      ),
      findsOneWidget,
    );
  });
}
