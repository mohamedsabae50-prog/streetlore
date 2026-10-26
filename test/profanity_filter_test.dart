import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/core/utils/profanity_filter.dart';

void main() {
  test('detects common English profanity regardless of case/punctuation', () {
    expect(ProfanityFilter.containsProfanity('That is SHIT!'), isTrue);
  });

  test('detects Arabic profanity with diacritics and normalized alef', () {
    expect(ProfanityFilter.containsProfanity('أَحَا'), isTrue);
  });

  test('allows ordinary text', () {
    expect(ProfanityFilter.containsProfanity('Welcome to Alexandria'), isFalse);
  });
}
