import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/presentation/screens/splash_screen.dart';

void main() {
  testWidgets('shows the EgyptLore identity and Egypt-wide subtitle', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('EgyptLore'), findsOneWidget);
    expect(
      find.text("Egypt Unseen — Discover Egypt's Hidden Stories"),
      findsOneWidget,
    );
    expect(find.text('اكتشف حكايات وكنوز مصر المخفية'), findsOneWidget);
    expect(find.text('Stories of Alexandria'), findsNothing);
  });
}
