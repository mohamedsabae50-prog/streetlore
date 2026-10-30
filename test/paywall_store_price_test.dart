import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetlore/logic/auth_provider.dart';
import 'package:streetlore/logic/locale_provider.dart';
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
  });

  testWidgets('uses only the fallback local price when no store product is '
      'available', (tester) async {
    await tester.pumpWidget(buildPrice());
    await tester.pumpAndSettle();

    expect(find.text('49 EGP / week'), findsOneWidget);
    expect(find.textContaining(r'$'), findsNothing);
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

    for (final title in [
      'Explorer Pass',
      'Monthly Pro Plan',
      'Annual Pro Plan',
    ]) {
      await tester.scrollUntilVisible(
        find.text(title),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final subscribeButton = find
          .widgetWithText(FilledButton, 'Subscribe Now')
          .last;
      await tester.ensureVisible(subscribeButton);
      await tester.pump();
      expect(tester.widget<FilledButton>(subscribeButton).onPressed, isNotNull);
    }
    expect(find.text('Coming soon'), findsNothing);
  });
}
