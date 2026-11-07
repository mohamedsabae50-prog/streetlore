import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/l10n/generated/app_localizations.dart';

void main() {
  test('Activity badges tab label is concise in English and Arabic', () async {
    final english = await AppLocalizations.delegate.load(const Locale('en'));
    final arabic = await AppLocalizations.delegate.load(const Locale('ar'));

    expect(english.hub_badges, 'Badges');
    expect(arabic.hub_badges, 'الشارات');
  });
}
