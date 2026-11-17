import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetlore/data/models/place_model.dart';
import 'package:streetlore/logic/auth_provider.dart';
import 'package:streetlore/logic/blocked_users_provider.dart';
import 'package:streetlore/logic/governorate_provider.dart';
import 'package:streetlore/logic/locale_provider.dart';
import 'package:streetlore/logic/place_provider.dart';
import 'package:streetlore/logic/place_photos_provider.dart';
import 'package:streetlore/logic/review_provider.dart';
import 'package:streetlore/logic/tour_provider.dart';
import 'package:streetlore/presentation/screens/general_ai_tour_guide_screen.dart';
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

  testWidgets('a Qaitbay request renders a card that opens place details', (
    tester,
  ) async {
    const place = PlaceModel(
      id: 'qaitbay_citadel',
      nameEn: 'Citadel of Qaitbay',
      nameAr: 'قلعة قايتباي',
      descriptionEn: 'A historic Alexandrian fortress.',
      descriptionAr: 'حصن تاريخي في الإسكندرية.',
      imageUrl: '',
      rating: 4.8,
      category: 'Historical',
      lat: 31.2139,
      lng: 29.8857,
      governorate: 'alexandria',
    );
    final governorates = GovernorateProvider();
    governorates.unlockAndSelectGovernorate('alexandria');
    final places = PlaceProvider(
      watchRemoteUpdates: false,
      governorates: governorates,
      isOnline: () => false,
      initialPlaces: const [place],
    );
    final tours = TourProvider(
      governorates: governorates,
      isOnline: () => false,
    );
    final auth = AuthProvider();
    final locale = LocaleProvider();
    final reviews = ReviewProvider();
    final blockedUsers = BlockedUsersProvider();
    final placePhotos = PlacePhotosProvider();

    addTearDown(governorates.dispose);
    addTearDown(places.dispose);
    addTearDown(tours.dispose);
    addTearDown(auth.dispose);
    addTearDown(locale.dispose);
    addTearDown(reviews.dispose);
    addTearDown(blockedUsers.dispose);
    addTearDown(placePhotos.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<LocaleProvider>.value(value: locale),
          ChangeNotifierProvider<GovernorateProvider>.value(
            value: governorates,
          ),
          ChangeNotifierProvider<PlaceProvider>.value(value: places),
          ChangeNotifierProvider<TourProvider>.value(value: tours),
          ChangeNotifierProvider<ReviewProvider>.value(value: reviews),
          ChangeNotifierProvider<BlockedUsersProvider>.value(
            value: blockedUsers,
          ),
          ChangeNotifierProvider<PlacePhotosProvider>.value(value: placePhotos),
        ],
        child: MaterialApp(
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: GeneralAITourGuideScreen(
            isOfflineOverride: false,
            onSendMessage: (_) async =>
                'The Citadel of Qaitbay is a notable place to visit.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'عايز اروح قلعة قايتباي');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    final card = find.byKey(
      const Key('ai-recommended-place-card-qaitbay_citadel'),
    );
    expect(card, findsOneWidget);
    expect(find.text('View Place'), findsOneWidget);

    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.byType(PlaceDetailsScreen), findsOneWidget);
  });
}
