import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetlore/logic/auth_provider.dart';
import 'package:streetlore/logic/locale_provider.dart';
import 'package:streetlore/core/config/app_config.dart';
import 'package:streetlore/core/services/revenuecat_service.dart';
import 'package:streetlore/presentation/screens/paywall_screen.dart';
import 'package:streetlore/presentation/widgets/paywall_store_price.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
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

  Widget buildPrice({
    StoreProduct? product,
    String fallbackPrice = '49 EGP / week',
    PackageType packageType = PackageType.weekly,
  }) {
    return ChangeNotifierProvider(
      create: (_) => LocaleProvider(),
      child: MaterialApp(
        home: Scaffold(
          body: PaywallStorePrice(
            product: product,
            fallbackPrice: fallbackPrice,
            packageType: packageType,
            usdEquivalent: '~\$0.99 USD',
          ),
        ),
      ),
    );
  }

  testWidgets('renders the store formatted price and subscription period', (
    tester,
  ) async {
    const product = StoreProduct(
      'pro_quarterly',
      'Quarterly Pro',
      'Quarterly Pro',
      12.99,
      '€12.99',
      'EUR',
      subscriptionPeriod: 'P3M',
    );

    await tester.pumpWidget(buildPrice(product: product));
    await tester.pumpAndSettle();

    expect(find.text('€12.99'), findsOneWidget);
    expect(find.text('Billed every 3 months'), findsOneWidget);
    expect(find.text('~\$0.99 USD'), findsOneWidget);
  });

  testWidgets('uses fallback price and USD equivalent without store product', (
    tester,
  ) async {
    await tester.pumpWidget(buildPrice());
    await tester.pumpAndSettle();

    expect(find.text('49 EGP / week'), findsOneWidget);
    expect(find.text('~\$0.99 USD'), findsOneWidget);
  });

  testWidgets('all plan cards show an enabled subscribe action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: const MaterialApp(home: PaywallScreen()),
      ),
    );
    await tester.pump();

    for (final plan in [
      ('Explorer Pass', 'weekly'),
      ('Monthly Plan', 'monthly'),
      ('Annual Plan', 'annual'),
    ]) {
      await tester.scrollUntilVisible(
        find.text(plan.$1),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final subscribeButton = find.byKey(
        ValueKey('paywall-subscribe-${plan.$2}'),
      );
      await tester.ensureVisible(subscribeButton);
      await tester.pump();
      expect(tester.widget<InkWell>(subscribeButton).onTap, isNotNull);
    }
    expect(find.text('Coming soon'), findsNothing);
  });

  test('uses the active Google Play subscription product IDs', () {
    expect(AppConfig.weeklyProductId, 'pro_weekly');
    expect(AppConfig.monthlyProductId, 'pro_monthly_base');
    expect(AppConfig.annualProductId, 'pro_yearly');
    expect(RevenueCatService.weeklyProductId, 'pro_weekly');
    expect(RevenueCatService.monthlyProductId, 'pro_monthly_base');
    expect(RevenueCatService.annualProductId, 'pro_yearly');
    expect(
      RevenueCatService.matchesProductId('pro_weekly', PackageType.weekly),
      isTrue,
    );
    expect(
      RevenueCatService.matchesProductId(
        'pro_monthly_base:monthly-base-plan',
        PackageType.monthly,
      ),
      isTrue,
    );
    expect(
      RevenueCatService.matchesProductId('pro_yearly', PackageType.annual),
      isTrue,
    );
  });

  testWidgets('renders Pharaonic hero, gold plan badges and USD price labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: const MaterialApp(home: PaywallScreen()),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('paywall-hero-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('paywall-wedjat-emblem')), findsOneWidget);
    expect(find.text('EgyptLore'), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
    final heroTop = tester.getTopLeft(
      find.byKey(const ValueKey('paywall-hero-card')),
    );
    final appBarBottom = tester.getBottomLeft(find.byType(AppBar));
    expect(heroTop.dy, greaterThanOrEqualTo(appBarBottom.dy));

    await tester.scrollUntilVisible(
      find.text('WEEKLY PLAN'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('29 EGP / week'), findsNothing);
    expect(find.text('49 EGP / week'), findsOneWidget);
    expect(find.text('~\$0.99 USD'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('MONTHLY'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('MONTHLY'), findsOneWidget);
    expect(find.text('49 EGP / month'), findsOneWidget);
    expect(find.text('~\$0.99 USD'), findsAtLeastNWidgets(1));
    await tester.scrollUntilVisible(
      find.text('ANNUAL'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('ANNUAL'), findsOneWidget);
    expect(find.text('199 EGP / year'), findsOneWidget);
    expect(find.text('~\$4.99 USD'), findsOneWidget);
  });
}
