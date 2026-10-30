import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:streetlore/core/animations/app_animations.dart';
import 'package:streetlore/core/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetlore/logic/auth_provider.dart';
import 'package:streetlore/logic/locale_provider.dart';
import 'package:streetlore/presentation/screens/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _AppleSignInAuthProvider extends AuthProvider {
  int appleSignInCalls = 0;

  @override
  Future<String?> signInWithApple() async {
    appleSignInCalls++;
    return 'apple_error';
  }
}

void main() {
  test(
    'Apple auth routing selects native Apple platforms and OAuth redirects',
    () {
      expect(
        AuthProvider.usesNativeAppleCredentials(
          isWeb: false,
          targetPlatform: TargetPlatform.iOS,
        ),
        isTrue,
      );
      expect(
        AuthProvider.usesNativeAppleCredentials(
          isWeb: false,
          targetPlatform: TargetPlatform.macOS,
        ),
        isTrue,
      );
      expect(
        AuthProvider.usesNativeAppleCredentials(
          isWeb: false,
          targetPlatform: TargetPlatform.android,
        ),
        isFalse,
      );
      expect(
        AuthProvider.usesNativeAppleCredentials(
          isWeb: true,
          targetPlatform: TargetPlatform.iOS,
        ),
        isFalse,
      );

      expect(
        AuthProvider.appleOAuthRedirectForPlatform(
          isWeb: false,
          isRelease: false,
          webOrigin: Uri.parse('https://localhost:3000/path'),
        ),
        AppConfig.mobileRedirectUrl,
      );
      expect(
        AuthProvider.appleOAuthRedirectForPlatform(
          isWeb: true,
          isRelease: true,
          webOrigin: Uri.parse('http://localhost:3000/path'),
        ),
        AppConfig.webRedirectUrl,
      );
      expect(
        AuthProvider.appleOAuthRedirectForPlatform(
          isWeb: true,
          isRelease: false,
          webOrigin: Uri.parse('http://localhost:3000/path'),
        ),
        'http://localhost:3000',
      );
    },
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
    );
  });

  testWidgets('Apple sign-in is disabled by default with a localized notice', (
    tester,
  ) async {
    final auth = _AppleSignInAuthProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    final button = find.byKey(const ValueKey('login-apple-button'));

    expect(button, findsOneWidget);
    expect(find.text('Continue with Apple (Coming soon)'), findsOneWidget);
    final pressScale = find.descendant(
      of: button,
      matching: find.byType(PressScale),
    );
    tester.widget<PressScale>(pressScale).onTap!.call();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Sign in with Apple is coming soon!'), findsOneWidget);
    expect(auth.appleSignInCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('enabled Apple sign-in calls AuthProvider', (tester) async {
    final auth = _AppleSignInAuthProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
        child: const MaterialApp(home: LoginScreen(appleSignInEnabled: true)),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    final button = find.byKey(const ValueKey('login-apple-button'));
    expect(button, findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    final pressScale = find.descendant(
      of: button,
      matching: find.byType(PressScale),
    );
    tester.widget<PressScale>(pressScale).onTap!.call();
    await tester.pump(const Duration(milliseconds: 500));

    expect(auth.appleSignInCalls, 1);
    expect(tester.takeException(), isNull);
  });
}
