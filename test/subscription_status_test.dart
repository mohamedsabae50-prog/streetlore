import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/logic/subscription_status.dart';

void main() {
  group('profileGrantsPro', () {
    final now = DateTime.utc(2026, 10, 16, 12);

    test('is false without a profile or without is_pro', () {
      expect(profileGrantsPro(null, now: now), isFalse);
      expect(profileGrantsPro({'is_pro': false}, now: now), isFalse);
      expect(profileGrantsPro({'subscription_tier': 'monthly'}, now: now),
          isFalse);
    });

    test('lifetime / legacy rows have no end date and stay Pro', () {
      expect(
        profileGrantsPro({
          'is_pro': true,
          'subscription_tier': 'lifetime',
          'subscription_end_date': null,
        }, now: now),
        isTrue,
      );
      expect(profileGrantsPro({'is_pro': true}, now: now), isTrue);
    });

    test('annual / monthly / weekly are Pro only until the end date', () {
      for (final tier in ['weekly', 'monthly', 'annual']) {
        expect(
          profileGrantsPro({
            'is_pro': true,
            'subscription_tier': tier,
            'subscription_end_date': '2026-10-17T00:00:00+00:00',
          }, now: now),
          isTrue,
          reason: '$tier before expiry',
        );
        expect(
          profileGrantsPro({
            'is_pro': true,
            'subscription_tier': tier,
            'subscription_end_date': '2026-10-15T00:00:00+00:00',
          }, now: now),
          isFalse,
          reason: '$tier after a missed expiration event',
        );
      }
    });

    test('an unparseable end date is not treated as Pro', () {
      expect(
        profileGrantsPro({'is_pro': true, 'subscription_end_date': 'soon'},
            now: now),
        isFalse,
      );
    });
  });
}
