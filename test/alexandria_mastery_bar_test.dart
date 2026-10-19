import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/data/models/place_model.dart';
import 'package:streetlore/presentation/widgets/alexandria_mastery_bar.dart';

PlaceModel _place(String id) => PlaceModel(
  id: id,
  nameEn: 'Place $id',
  descriptionEn: 'Story $id',
  imageUrl: '',
  rating: 4.0,
  lat: 31.2,
  lng: 29.9,
);

void main() {
  testWidgets('calculates progress from catalog and visited IDs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AlexandriaMasteryBar(
            places: [_place('one'), _place('two')],
            visitedPlaceIds: const {'one', 'not-in-catalog'},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Visited 1 / 2 Places — 50% of Alexandria Explored'),
      findsOneWidget,
    );
  });

  testWidgets('shows zero safely and localizes progress in Arabic', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const Scaffold(
          body: AlexandriaMasteryBar(places: [], visitedPlaceIds: {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('إتقان الإسكندرية'), findsOneWidget);
    expect(find.textContaining('0 من أصل 0'), findsOneWidget);
    expect(find.text('0٪'), findsOneWidget);
  });
}
