import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetlore/logic/locale_provider.dart';
import 'package:streetlore/presentation/widgets/report_content_sheet.dart';

void main() {
  late LocaleProvider localeProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    localeProvider = LocaleProvider();
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() {
    localeProvider.dispose();
  });

  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<LocaleProvider>.value(
        value: localeProvider,
        child: const MaterialApp(
          home: Scaffold(
            body: ReportContentSheet(
              targetId: 'target-user',
              targetType: 'user',
              authorName: 'Explorer',
              targetAvatarUrl: 'builtin:avatar',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('account reports show localized reasons in English', (
    tester,
  ) async {
    await localeProvider.setLocale(const Locale('en'));
    await pumpSheet(tester);

    expect(find.text('Report account'), findsOneWidget);
    expect(find.text('Why are you reporting this?'), findsOneWidget);
    expect(find.text('Inappropriate profile picture'), findsOneWidget);
    expect(find.text('Offensive username or profile'), findsOneWidget);
    expect(find.text('Spam or fake account'), findsOneWidget);
  });

  testWidgets('account reports show localized reasons in Arabic', (
    tester,
  ) async {
    await localeProvider.setLocale(const Locale('ar'));
    await pumpSheet(tester);

    expect(find.text('الإبلاغ عن الحساب'), findsOneWidget);
    expect(find.text('صورة شخصية غير لائقة'), findsOneWidget);
    expect(find.text('اسم مستخدم أو حساب مسيء'), findsOneWidget);
    expect(find.text('حساب مزيف أو إعلاني'), findsOneWidget);
  });
}
