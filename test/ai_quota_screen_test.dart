import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetlore/core/services/ai_tour_guide_service.dart';
import 'package:streetlore/data/cairo_seed.dart';
import 'package:streetlore/data/mock_data.dart' show fallbackPlaces;
import 'package:streetlore/data/models/place_model.dart';
import 'package:streetlore/logic/auth_provider.dart';
import 'package:streetlore/logic/governorate_provider.dart';
import 'package:streetlore/logic/locale_provider.dart';
import 'package:streetlore/logic/place_provider.dart';
import 'package:streetlore/logic/tour_provider.dart';
import 'package:streetlore/presentation/screens/ai_tour_guide_screen.dart';
import 'package:streetlore/presentation/screens/general_ai_tour_guide_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FreeAuthProvider extends AuthProvider {
  @override
  bool get isPro => false;

  @override
  bool get isAdmin => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('general guide fallback uses the active governorate landmarks', () {
    final cairoFallback = buildGeneralGuideFallback(
      governorateId: 'cairo',
      locale: 'en',
      places: [...cairoSeedPlaces, ...fallbackPlaces],
    );
    final alexandriaFallback = buildGeneralGuideFallback(
      governorateId: 'alexandria',
      locale: 'ar',
      places: [...cairoSeedPlaces, ...fallbackPlaces],
    );

    expect(cairoFallback, contains('Cairo'));
    expect(cairoFallback, isNot(contains('Alexandria')));
    expect(alexandriaFallback, contains('الإسكندرية'));
    expect(alexandriaFallback, isNot(contains('القاهرة')));
  });

  testWidgets(
    'general guide shows Cairo greeting and refreshes quota after send',
    (tester) async {
      final governorates = GovernorateProvider();
      governorates.unlockAndSelectGovernorate('cairo');
      final places = PlaceProvider(
        watchRemoteUpdates: false,
        governorates: governorates,
        isOnline: () => false,
        initialPlaces: cairoSeedPlaces,
      );
      final tours = TourProvider(
        governorates: governorates,
        isOnline: () => false,
      );
      final auth = _FreeAuthProvider();
      final locale = LocaleProvider();
      var quotaFetches = 0;
      var messagesSent = 0;
      Future<Map<String, dynamic>> fetchStatus() async =>
          _quotaStatus(++quotaFetches);

      addTearDown(governorates.dispose);
      addTearDown(places.dispose);
      addTearDown(tours.dispose);
      addTearDown(auth.dispose);
      addTearDown(locale.dispose);

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
          ],
          child: MaterialApp(
            home: GeneralAITourGuideScreen(
              fetchQuotaStatus: fetchStatus,
              isOfflineOverride: false,
              onSendMessage: (_) async {
                messagesSent++;
                return 'A Cairo reply.';
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Cairo'), findsOneWidget);
      expect(find.text('3 of 3 AI calls remaining'), findsOneWidget);
      final quotaTop = tester.getTopLeft(
        find.byKey(const ValueKey('ai-quota-banner')),
      );
      expect(
        quotaTop.dy,
        lessThan(tester.getTopLeft(find.byType(TextField)).dy),
      );

      await tester.enterText(find.byType(TextField), 'What should I see?');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(messagesSent, 1);
      expect(quotaFetches, 2);
      expect(find.text('2 of 3 AI calls remaining'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('place guide shows and refreshes its quota banner after send', (
    tester,
  ) async {
    const place = PlaceModel(
      id: 'ai-quota-place',
      nameEn: 'Cairo Landmark',
      nameAr: 'معلم في القاهرة',
      descriptionEn: 'A Cairo landmark.',
      imageUrl: '',
      rating: 4.5,
      category: 'Historical',
      lat: 30.0444,
      lng: 31.2357,
      governorate: 'cairo',
    );
    final governorates = GovernorateProvider();
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
    final auth = _FreeAuthProvider();
    final locale = LocaleProvider();
    var quotaFetches = 0;
    var messagesSent = 0;
    Future<Map<String, dynamic>> fetchStatus() async =>
        _quotaStatus(++quotaFetches);

    addTearDown(governorates.dispose);
    addTearDown(places.dispose);
    addTearDown(tours.dispose);
    addTearDown(auth.dispose);
    addTearDown(locale.dispose);

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
        ],
        child: MaterialApp(
          home: AITourGuideScreen(
            place: place,
            fetchQuotaStatus: fetchStatus,
            isOfflineOverride: false,
            onSendMessage: (_) async {
              messagesSent++;
              return 'A helpful reply.';
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 of 3 AI calls remaining'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('ai-quota-banner'))).dy,
      lessThan(tester.getTopLeft(find.byType(TextField)).dy),
    );
    await tester.enterText(find.byType(TextField), 'Tell me more');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(messagesSent, 1);
    expect(quotaFetches, 2);
    expect(find.text('2 of 3 AI calls remaining'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Map<String, dynamic> _quotaStatus(int fetchCount) => {
  'used_today': fetchCount - 1,
  'daily_limit': 3,
  'remaining': fetchCount == 1 ? 3 : 2,
  'next_reset_at': DateTime.now()
      .add(const Duration(days: 1))
      .toIso8601String(),
};
