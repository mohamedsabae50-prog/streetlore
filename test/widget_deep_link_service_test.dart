import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/core/services/widget_deep_link_service.dart';

void main() {
  group('WidgetDeepLinkService', () {
    test('parses place IDs only from widget place links', () {
      expect(
        WidgetDeepLinkService.placeIdFromUri(
          Uri.parse('streetlore://place/place-123'),
        ),
        'place-123',
      );
      expect(
        WidgetDeepLinkService.placeIdFromUri(
          Uri.parse('https://place/place-123'),
        ),
        isNull,
      );
      expect(
        WidgetDeepLinkService.placeIdFromUri(Uri.parse('streetlore://place')),
        isNull,
      );
    });

    test(
      'consumes malformed place links without treating them as auth links',
      () {
        expect(
          WidgetDeepLinkService.handleUri(Uri.parse('streetlore://place')),
          isTrue,
        );
        expect(
          WidgetDeepLinkService.handleUri(
            Uri.parse('streetlore://auth/callback'),
          ),
          isFalse,
        );
      },
    );
  });
}
