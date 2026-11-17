import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetlore/core/utils/checkin_error_sanitizer.dart';
import 'package:streetlore/data/models/place_model.dart';
import 'package:streetlore/logic/place_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('large complex auto-check-in radius is 250 meters', () async {
    const mall = PlaceModel(
      id: 'san-stefano-mall',
      nameEn: 'San Stefano Mall',
      descriptionEn: '',
      imageUrl: '',
      rating: 4.5,
      category: 'Shopping',
      lat: 31.2,
      lng: 29.9,
    );
    final provider = PlaceProvider(
      watchRemoteUpdates: false,
      initialPlaces: const [mall],
    );
    final checkedIn = <String>[];
    provider.configureAutoCheckIn(
      isPlaceVisited: (_) => false,
      recordCheckIn: (place) async {
        checkedIn.add(place.id);
      },
    );

    final firstPass = await provider.evaluateAutoCheckInForPosition(
      lat: mall.lat + 0.0021,
      lng: mall.lng,
    );
    final secondPass = await provider.evaluateAutoCheckInForPosition(
      lat: mall.lat + 0.0021,
      lng: mall.lng,
    );

    expect(getAutoCheckInRadiusMeters(mall), 250);
    expect(firstPass.map((place) => place.id), ['san-stefano-mall']);
    expect(secondPass, isEmpty);
    expect(checkedIn, ['san-stefano-mall']);
    provider.dispose();
  });

  test('standard places use the 180 meter auto-check-in radius', () {
    const place = PlaceModel(
      id: 'standard-place',
      nameEn: 'Standard Place',
      descriptionEn: '',
      imageUrl: '',
      rating: 4,
      category: 'Historical',
      lat: 31.2,
      lng: 29.9,
    );

    expect(getAutoCheckInRadiusMeters(place), 180);
  });

  test('out-of-range check-in errors are sanitized bilingually', () {
    expect(
      sanitizeCheckInError(Exception('You are too far away'), locale: 'en'),
      'You must be within 200 meters of this place to check in',
    );
    expect(
      sanitizeCheckInError(
        StateError('outside the allowed range'),
        locale: 'ar',
      ),
      'يجب أن تكون داخل نطاق المكان (200 متر) لتسجيل الزيارة',
    );
    expect(
      sanitizeCheckInError(
        Exception('Service temporarily unavailable'),
        locale: 'en',
      ),
      isNot(contains('Exception:')),
    );
  });
}
