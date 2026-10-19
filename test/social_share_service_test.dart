import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/core/services/social_share_service.dart';

void main() {
  group('SocialShareService.buildShareText', () {
    test(
      'includes title, concise description, app label, and Play Store URL',
      () {
        final text = SocialShareService.buildShareText(
          title: '  Citadel  ',
          description: '  Historic fortress\n overlooking the harbor. ',
          appName: 'Discover EgyptLore',
        );

        expect(
          text,
          'Citadel\n\nHistoric fortress overlooking the harbor.\n\n'
          'Discover EgyptLore\n\n'
          'https://play.google.com/store/apps/details?id=com.alsaba.egyptlore',
        );
      },
    );

    test('omits empty fields and truncates long descriptions', () {
      final text = SocialShareService.buildShareText(
        title: '',
        description: 'a' * 300,
        appName: '',
      );

      expect(text, startsWith('${'a' * 239}…\n\n'));
      expect(
        text,
        endsWith(
          'https://play.google.com/store/apps/details?id=com.alsaba.egyptlore',
        ),
      );
      expect(text, isNot(contains('\n\n\n')));
    });
  });
}
