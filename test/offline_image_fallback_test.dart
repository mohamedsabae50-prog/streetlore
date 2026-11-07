import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/core/widgets/image_defaults.dart';

void main() {
  testWidgets('offline image fallback shows a category icon and place title', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 220,
          height: 180,
          child: CategoryImageFallback(
            category: 'Historical',
            title: 'Citadel of Qaitbay',
          ),
        ),
      ),
    );

    expect(find.text('Citadel of Qaitbay'), findsOneWidget);
    expect(find.byIcon(Icons.account_balance_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
