import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetlore/core/widgets/ai_quota_banner.dart';
import 'package:streetlore/logic/auth_provider.dart';
import 'package:streetlore/logic/locale_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FreeAuthProvider extends AuthProvider {
  @override
  bool get isPro => false;

  @override
  bool get isAdmin => false;
}

class _ProAuthProvider extends AuthProvider {
  @override
  bool get isPro => true;

  @override
  bool get isAdmin => false;

  @override
  String get currentUserId => 'pro-quota-banner-test';
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
    );
  });

  testWidgets('free users see the initial three-call quota immediately', (
    tester,
  ) async {
    final auth = _FreeAuthProvider();
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AiQuotaBanner(fetchQuotaStatus: _initialQuotaStatus),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('ai-quota-remaining-banner')), findsOneWidget);
    expect(find.text('Remaining AI uses today: 3 / 3'), findsOneWidget);
    expect(find.text('Resets at midnight UTC'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Pro users get a finite 50-message quota that decrements', (
    tester,
  ) async {
    final auth = _ProAuthProvider();
    AiQuotaSnapshot? snapshot;
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AiQuotaBanner(
              fetchQuotaStatus: _misreportedProQuotaStatus,
              onStatusChanged: (value) => snapshot = value,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Remaining AI uses today: 50 / 50 (Pro)'), findsOneWidget);
    expect(snapshot?.unlimited, isFalse);
    expect(snapshot?.limit, 50);

    final state = tester.state<AiQuotaBannerState>(find.byType(AiQuotaBanner));
    expect(await state.consumeOne(), isTrue);
    await tester.pump();

    expect(find.text('Remaining AI uses today: 49 / 50 (Pro)'), findsOneWidget);
    expect(snapshot?.unlimited, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<Map<String, dynamic>> _initialQuotaStatus() async => {
  'used_today': 0,
  'daily_limit': 3,
  'remaining': 3,
  'next_reset_at': DateTime.now()
      .add(const Duration(days: 1))
      .toIso8601String(),
};

Future<Map<String, dynamic>> _misreportedProQuotaStatus() async => {
  'used_today': 0,
  'daily_limit': 3,
  'remaining': 3,
  'is_unlimited': true,
  'next_reset_at': DateTime.now()
      .add(const Duration(days: 1))
      .toIso8601String(),
};
