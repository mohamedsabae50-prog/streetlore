import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/data/models/offline_pack.dart';

void main() {
  test(
    'download metadata survives JSON persistence and app restart parsing',
    () {
      final downloadedAt = DateTime.utc(2026, 11, 7, 18, 30);
      final pack = OfflinePack(
        id: 'all_alexandria',
        name: 'All Alexandria',
        description: 'Every place and story.',
        sizeMb: 24,
        downloadedCount: 68,
        downloadedAt: downloadedAt,
      );

      final restored = OfflinePack.fromJson(pack.toJson());

      expect(restored.isDownloaded, isTrue);
      expect(restored.downloadedAt, downloadedAt);
      expect(restored.downloadedCount, 68);
      expect(restored.sizeMb, 24);
    },
  );
}
