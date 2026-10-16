import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/logic/place_photos_provider.dart';

void main() {
  test('community photos are stored under user-photos/<uid>/', () {
    const uid = '9b2c3f6e-1d4a-4c8e-8f21-5a7d0c9e1b34';
    final path = PlacePhotosProvider.storagePathFor(
      userId: uid,
      placeId: 'fallback_qaitbay',
      photoId: 'f47ac10b-58cc-4372-a567-0e02b2c3d479',
    );
    expect(
      path,
      'user-photos/$uid/fallback_qaitbay/f47ac10b-58cc-4372-a567-0e02b2c3d479.jpg',
    );
    // Folder 1 and 2 are what the storage policies check.
    final folders = path.split('/');
    expect(folders[0], 'user-photos');
    expect(folders[1], uid);
  });
}
