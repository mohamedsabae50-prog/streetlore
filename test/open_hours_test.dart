import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/data/mock_data.dart';

void main() {
  group('MockData.isOpenNow', () {
    DateTime at(int hour, [int minute = 0]) =>
        DateTime(2026, 10, 16, hour, minute);

    test('uses the place hours instead of a fixed 9-18 window', () {
      expect(MockData.isOpenNow('8:00 AM - 10:00 PM', now: at(19)), isTrue);
      expect(MockData.isOpenNow('8:00 AM - 10:00 PM', now: at(22, 30)), isFalse);
      expect(MockData.isOpenNow('8:00 AM - 10:00 PM', now: at(7, 59)), isFalse);
    });

    test('handles closing after midnight', () {
      expect(MockData.isOpenNow('6:00 PM - 2:00 AM', now: at(1)), isTrue);
      expect(MockData.isOpenNow('6:00 PM - 2:00 AM', now: at(12)), isFalse);
    });

    test('treats "24 hours" as always open', () {
      expect(MockData.isOpenNow('24 hours', now: at(3)), isTrue);
      expect(MockData.isOpenNow('Open 24 Hours', now: at(15)), isTrue);
    });
  });
}
