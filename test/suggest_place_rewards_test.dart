import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:streetlore/logic/auth_provider.dart';
import 'package:streetlore/logic/locale_provider.dart';
import 'package:streetlore/presentation/screens/suggest_place_screen.dart';

void main() {
  testWidgets('shows both rewards and lets users select a hidden gem', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ],
        child: const MaterialApp(home: SuggestPlaceScreen()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Regular Place Approved'), findsOneWidget);
    expect(find.textContaining('1 Week Free Pro (7 Days)'), findsOneWidget);
    expect(find.textContaining('Hidden Gem Approved'), findsOneWidget);
    expect(find.textContaining('1 Month Free Pro (30 Days)'), findsOneWidget);

    var selector = tester.widget<SegmentedButton<String>>(
      find.byType(SegmentedButton<String>),
    );
    expect(selector.selected, {'regular'});

    await tester.tap(find.text('Hidden Gem'));
    await tester.pump();

    selector = tester.widget<SegmentedButton<String>>(
      find.byType(SegmentedButton<String>),
    );
    expect(selector.selected, {'hidden_gem'});
    expect(tester.takeException(), isNull);
  });
}
