import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetlore/logic/auth_provider.dart';
import 'package:streetlore/logic/locale_provider.dart';
import 'package:streetlore/presentation/screens/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _PasswordResetAuthProvider extends AuthProvider {
  String? requestedEmail;
  String? verifiedEmail;
  String? verifiedToken;
  String? updatedPassword;

  @override
  Future<void> resetPasswordForEmail(String email) async {
    requestedEmail = email;
  }

  @override
  Future<void> verifyPasswordRecoveryOtp({
    required String email,
    required String token,
  }) async {
    verifiedEmail = email;
    verifiedToken = token;
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    updatedPassword = newPassword;
  }
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

  testWidgets(
    'Forgot Password requests a code, verifies it, and updates password',
    (tester) async {
      final auth = _PasswordResetAuthProvider();
      final locale = LocaleProvider();
      addTearDown(auth.dispose);
      addTearDown(locale.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<LocaleProvider>.value(value: locale),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('forgot-password-button')), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('forgot-password-button')),
      );
      await tester.tap(find.byKey(const Key('forgot-password-button')));
      await tester.pump();

      expect(find.text('Reset your password'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('password-reset-email')),
        'traveler@example.com',
      );
      await tester.tap(find.byKey(const Key('password-reset-send-code')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(auth.requestedEmail, 'traveler@example.com');
      expect(
        find.text('Recovery code sent. Check your email.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('password-reset-code')),
        '348921',
      );
      await tester.tap(find.byKey(const Key('password-reset-verify-code')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(auth.verifiedEmail, 'traveler@example.com');
      expect(auth.verifiedToken, '348921');
      expect(
        find.byKey(const Key('password-reset-new-password')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('password-reset-new-password')),
        'new-pass-123',
      );
      await tester.enterText(
        find.byKey(const Key('password-reset-confirm-password')),
        'new-pass-123',
      );
      await tester.tap(find.byKey(const Key('password-reset-update-password')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(auth.updatedPassword, 'new-pass-123');
      expect(find.text('Reset your password'), findsNothing);
    },
  );
}
