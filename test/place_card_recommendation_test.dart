import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetlore/data/models/place_model.dart';
import 'package:streetlore/logic/locale_provider.dart';
import 'package:streetlore/presentation/widgets/place_card.dart';

void main() {
  testWidgets('closed beach recommendation is clear and warning-colored', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final localeProvider = LocaleProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider<LocaleProvider>.value(
        value: localeProvider,
        child: MaterialApp(
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: PlaceCard(
              place: const PlaceModel(
                id: 'ajami-beach',
                nameEn: 'Agami Beach',
                nameAr: 'شاطئ عجمي',
                descriptionEn: 'A beach in Alexandria',
                imageUrl: '',
                rating: 4.2,
                category: 'Beaches',
                categoryAr: 'شواطئ',
                lat: 31.12,
                lng: 29.78,
                openHours: '9:00 AM - 5:00 PM',
              ),
              recommendationTime: DateTime(2026, 10, 20, 23),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final recommendation = tester.widget<Text>(
      find.text('Closed at night · Best visited in the morning'),
    );
    expect(recommendation.style?.color, Colors.amberAccent);
    final category = tester.widget<Text>(find.text('BEACHES'));
    expect(category.style?.color, Colors.white);
  });

  testWidgets('open place shows the green great-time message', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final localeProvider = LocaleProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider<LocaleProvider>.value(
        value: localeProvider,
        child: MaterialApp(
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: PlaceCard(
              place: const PlaceModel(
                id: 'open-beach',
                nameEn: 'Open Beach',
                descriptionEn: 'A beach in Alexandria',
                imageUrl: '',
                rating: 4.2,
                category: 'Beaches',
                lat: 31.12,
                lng: 29.78,
                openHours: '9:00 AM - 5:00 PM',
              ),
              recommendationTime: DateTime(2026, 10, 20, 10),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final recommendation = tester.widget<Text>(
      find.text('Open now · Great time to visit'),
    );
    expect(recommendation.style?.color, const Color(0xFF10B981));
  });
}
