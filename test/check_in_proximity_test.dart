import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetlore/core/services/checkin_location_service.dart';
import 'package:streetlore/data/models/place_model.dart';
import 'package:streetlore/logic/place_provider.dart';

PlaceModel _place({
  required String id,
  required String name,
  String category = 'Food',
  double lat = 31.2,
  double lng = 29.9,
}) {
  return PlaceModel(
    id: id,
    nameEn: name,
    descriptionEn: '',
    imageUrl: '',
    rating: 4,
    category: category,
    lat: lat,
    lng: lng,
  );
}

double _latitudeOffset(double meters) => meters / 111320;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'auto check-in applies GPS accuracy, visits once, and ignores far places',
    () async {
      final nearby = _place(
        id: 'nearby',
        name: 'Nearby place',
        lat: 31.2 + _latitudeOffset(85),
      );
      final alreadyVisited = _place(
        id: 'visited',
        name: 'Already visited',
        lat: 31.2 + _latitudeOffset(10),
      );
      final far = _place(
        id: 'far',
        name: 'Far place',
        lat: 31.2 + _latitudeOffset(160),
      );
      final provider = PlaceProvider(
        watchRemoteUpdates: false,
        initialPlaces: [nearby, alreadyVisited, far],
      );
      addTearDown(provider.dispose);
      final visitedIds = <String>{alreadyVisited.id};
      final savedIds = <String>[];
      provider.configureAutoCheckIn(
        isPlaceVisited: visitedIds.contains,
        recordCheckIn: (place) async {
          savedIds.add(place.id);
          visitedIds.add(place.id);
        },
      );

      final first = await provider.evaluateAutoCheckInForPosition(
        lat: 31.2,
        lng: 29.9,
        accuracy: 40,
      );
      final second = await provider.evaluateAutoCheckInForPosition(
        lat: 31.2,
        lng: 29.9,
        accuracy: 40,
      );

      expect(first, [nearby]);
      expect(second, isEmpty);
      expect(savedIds, [nearby.id]);
      expect(visitedIds, containsAll([alreadyVisited.id, nearby.id]));
      expect(savedIds, isNot(contains(far.id)));
    },
  );

  test(
    'mega parks receive the additional auto-check-in zone allowance',
    () async {
      final montaza = _place(
        id: 'montaza_palace_gardens',
        name: 'Montaza Palace Gardens',
        lat: 31.2 + _latitudeOffset(90),
      );
      final provider = PlaceProvider(
        watchRemoteUpdates: false,
        initialPlaces: [montaza],
      );
      addTearDown(provider.dispose);
      var checkedIn = false;
      provider.configureAutoCheckIn(
        isPlaceVisited: (_) => checkedIn,
        recordCheckIn: (_) async {
          checkedIn = true;
        },
      );

      final checkedInPlaces = await provider.evaluateAutoCheckInForPosition(
        lat: 31.2,
        lng: 29.9,
      );

      expect(checkedInPlaces, [montaza]);
    },
  );

  test(
    'manual proximity uses adaptive radii and GPS accuracy compensation',
    () {
      const montaza = PlaceModel(
        id: 'montaza',
        nameEn: 'Montaza Palace Gardens',
        descriptionEn: '',
        imageUrl: '',
        rating: 4,
        category: 'Historical',
        lat: 31.2,
        lng: 29.9,
      );
      const nature = PlaceModel(
        id: 'nature',
        nameEn: 'Nature area',
        descriptionEn: '',
        imageUrl: '',
        rating: 4,
        category: 'Nature',
        lat: 31.2,
        lng: 29.9,
      );
      const standard = PlaceModel(
        id: 'standard',
        nameEn: 'Standard cafe',
        descriptionEn: '',
        imageUrl: '',
        rating: 4,
        category: 'Cafe',
        lat: 31.2,
        lng: 29.9,
      );

      expect(getEffectiveCheckInRadiusMeters(montaza), 1250);
      expect(getEffectiveCheckInRadiusMeters(nature), 550);
      expect(getEffectiveCheckInRadiusMeters(standard), 300);
      for (final distance in [600.0, 1100.0]) {
        expect(
          CheckInLocationService.isWithinRadius(
            rawDistanceMeters: distance,
            accuracyMeters: 0,
            allowedDistanceMeters: getEffectiveCheckInRadiusMeters(montaza),
          ),
          isTrue,
        );
      }
      expect(
        CheckInLocationService.isWithinRadius(
          rawDistanceMeters: 299,
          accuracyMeters: 80,
          allowedDistanceMeters: getEffectiveCheckInRadiusMeters(standard),
        ),
        isTrue,
      );
      expect(
        CheckInLocationService.isWithinRadius(
          rawDistanceMeters: 301,
          accuracyMeters: 0,
          allowedDistanceMeters: getEffectiveCheckInRadiusMeters(standard),
        ),
        isFalse,
      );
    },
  );
}
