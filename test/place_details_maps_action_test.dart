import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetlore/data/models/place_model.dart';
import 'package:streetlore/logic/auth_provider.dart';
import 'package:streetlore/logic/locale_provider.dart';
import 'package:streetlore/logic/place_provider.dart';
import 'package:streetlore/logic/review_provider.dart';
import 'package:streetlore/presentation/screens/place_details_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
    );
  });

  testWidgets('hero actions use Google Maps and keep one Save action', (
    tester,
  ) async {
    final place = const PlaceModel(
      id: 'test-place',
      nameEn: 'Test Place',
      descriptionEn: 'A test place',
      imageUrl: '',
      rating: 4.0,
      lat: 31.2,
      lng: 29.9,
      enableGallery: false,
      enableChat: false,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider(
            create: (_) => PlaceProvider(watchRemoteUpdates: false),
          ),
          ChangeNotifierProvider(create: (_) => ReviewProvider()),
        ],
        child: MaterialApp(
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: PlaceDetailsScreen(place: place),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(find.byTooltip('Google Maps'), findsOneWidget);
    expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
  });
}
