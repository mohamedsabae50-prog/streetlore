import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetlore/core/animations/app_animations.dart';
import 'package:streetlore/core/services/remote_config_service.dart';
import 'package:streetlore/logic/auth_provider.dart';
import 'package:streetlore/logic/locale_provider.dart';
import 'package:streetlore/presentation/screens/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _AppleAuthProvider extends AuthProvider {
  int signInCalls = 0;

  @override
  Future<String?> signInWithApple() async {
    signInCalls++;
    return 'apple_error';
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
    );
  });

  test('compiled defaults match the release configuration', () {
    const config = RemoteConfigData();

    expect(config.appleSignInEnabled, isFalse);
    expect(config.weeklyPriceEn, '49 EGP / week');
    expect(config.weeklyPriceAr, '49 ج.م / أسبوع');
    expect(config.weeklyUsdLabel, '~\$0.99 USD');
    expect(config.monthlyPriceEn, '49 EGP / month');
    expect(config.monthlyPriceAr, '49 ج.م / شهر');
    expect(config.monthlyUsdLabel, '~\$0.99 USD');
    expect(config.annualPriceEn, '199 EGP / year');
    expect(config.annualPriceAr, '199 ج.م / سنة');
    expect(config.annualUsdLabel, '~\$4.99 USD');
    expect(config.promoBannerEnabled, isFalse);
    expect(config.latestAppVersion, '2.1.40');
    expect(config.latestBuildNumber, 243);
    expect(
      config.directApkUrl,
      'https://github.com/mohamedsabae50-prog/streetlore/releases/latest/download/app-release.apk',
    );
  });

  test('parses remote JSON while retaining defaults for absent values', () {
    final config = RemoteConfigData.fromJson({
      'apple_sign_in_enabled': true,
      'weekly_price_en': '59 EGP / week',
      'latest_app_version': '2.2.0',
      'latest_build_number': 260.0,
      'promo_banner_enabled': true,
      'updated_at': '2026-11-03T17:00:00Z',
    });

    expect(config.appleSignInEnabled, isTrue);
    expect(config.weeklyPriceEn, '59 EGP / week');
    expect(config.weeklyPriceAr, '49 ج.م / أسبوع');
    expect(config.latestAppVersion, '2.2.0');
    expect(config.latestBuildNumber, 260);
    expect(config.promoBannerEnabled, isTrue);
    expect(config.updatedAt, DateTime.utc(2026, 11, 3, 17));
  });

  test('compares semantic versions and build numbers', () {
    final config = RemoteConfigService(
      initialConfig: const RemoteConfigData(
        latestAppVersion: '2.1.40',
        latestBuildNumber: 243,
      ),
    );

    expect(config.isUpdateAvailable('2.1.40', 242), isTrue);
    expect(config.isUpdateAvailable('2.1.39', 243), isTrue);
    expect(config.isUpdateAvailable('2.1.40', 243), isFalse);
    expect(config.isUpdateAvailable('2.1.41', 244), isFalse);
    expect(config.isUpdateAvailable('2.1.40-rc.1', 243), isTrue);
    config.dispose();
  });

  testWidgets('LoginScreen reacts to remote Apple sign-in configuration', (
    tester,
  ) async {
    final auth = _AppleAuthProvider();
    final config = RemoteConfigService(initialConfig: const RemoteConfigData());
    addTearDown(config.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
        child: MaterialApp(home: LoginScreen(remoteConfigService: config)),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    final button = find.byKey(const ValueKey('login-apple-button'));
    expect(find.text('Continue with Apple (Coming soon)'), findsOneWidget);
    config.applyRemoteConfig(const RemoteConfigData(appleSignInEnabled: true));
    await tester.pump();
    expect(find.text('Continue with Apple'), findsOneWidget);
    final pressScale = find.descendant(
      of: button,
      matching: find.byType(PressScale),
    );
    tester.widget<PressScale>(pressScale).onTap!.call();
    await tester.pump(const Duration(milliseconds: 500));

    expect(auth.signInCalls, 1);
    expect(tester.takeException(), isNull);
  });
}
