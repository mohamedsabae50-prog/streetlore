import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streetlore/data/models/itinerary_model.dart';
import 'package:streetlore/data/models/place_model.dart';
import 'package:streetlore/logic/trip_provider.dart';
import 'package:streetlore/logic/tour_provider.dart';

PlaceModel _place(
  String id,
  String name, {
  double lat = 31.2,
  double lng = 29.9,
}) => PlaceModel(
  id: id,
  nameEn: name,
  descriptionEn: '',
  imageUrl: '',
  rating: 4,
  lat: lat,
  lng: lng,
);

ItineraryModel _tour(List<PlaceModel> places, {String status = 'published'}) =>
    ItineraryModel(
      id: 'alexandria-tour',
      title: 'Alexandria tour',
      description: '',
      duration: 'Half day',
      imageUrl: '',
      status: status,
      places: places,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tour completes when every stop ID is visited', () {
    final tour = _tour([
      _place('one', 'One'),
      _place('two', 'Two', lat: 31.21),
    ]);

    expect(visitedStopsCountForTour(tour, {'one'}, tour.places), 1);
    expect(isTourAutomaticallyVisited(tour, {'one'}, tour.places), isFalse);
    expect(
      isTourAutomaticallyVisited(tour, {'one', 'two'}, tour.places),
      isTrue,
    );
  });

  test('tour stops match visited places by normalized name and proximity', () {
    final tour = _tour([
      _place('tour-stop', 'The Old Lighthouse', lat: 31.2000, lng: 29.9000),
      _place('second-stop', 'Citadel', lat: 31.2100, lng: 29.9000),
    ]);
    final visitedPlaces = [
      _place('db-lighthouse', 'The Old Lighthouse', lat: 31.25, lng: 29.9),
      _place('db-citadel', 'Fort', lat: 31.2105, lng: 29.9000),
    ];

    expect(
      visitedStopsCountForTour(tour, {
        'db-lighthouse',
        'db-citadel',
      }, visitedPlaces),
      2,
    );
    expect(
      isTourAutomaticallyVisited(tour, {
        'db-lighthouse',
        'db-citadel',
      }, visitedPlaces),
      isTrue,
    );
  });

  test(
    'explicitly completed tours count as visited without stops checked in',
    () {
      final tour = _tour([_place('one', 'One')], status: 'completed');

      expect(isTourAutomaticallyVisited(tour, const {}, tour.places), isTrue);
    },
  );

  test('ATM places cannot count toward visits or tour completion', () {
    final atm = PlaceModel(
      id: 'atm_inside_cafe',
      nameEn: 'ATM inside a cafe',
      descriptionEn: '',
      imageUrl: '',
      rating: 4,
      category: 'Cafe',
      lat: 31.2,
      lng: 29.9,
    );
    final tour = _tour([_place('visit', 'Visit'), atm]);

    expect(atm.isVisitable, isFalse);
    expect(visitedStopsCountForTour(tour, {'visit', atm.id}, tour.places), 1);
    expect(
      isTourAutomaticallyVisited(tour, {'visit', atm.id}, tour.places),
      isFalse,
    );
  });

  test('ATM category aliases are not visitable', () {
    for (final category in ['ATM', 'ATMs']) {
      final atm = PlaceModel(
        id: 'cashpoint-${category.toLowerCase()}',
        nameEn: 'Cash point',
        descriptionEn: '',
        imageUrl: '',
        rating: 4,
        category: category,
        lat: 31.2,
        lng: 29.9,
      );
      expect(atm.isVisitable, isFalse);
    }
  });

  test('trip visit state discards current and legacy ATM check-ins', () {
    SharedPreferences.setMockInitialValues({});
    final provider = TripProvider();
    final atm = PlaceModel(
      id: 'legacy-cashpoint',
      nameEn: 'ATM',
      descriptionEn: '',
      imageUrl: '',
      rating: 0,
      category: 'ATM',
      lat: 31.2,
      lng: 29.9,
    );

    provider.markVisited(atm.id);
    provider.syncPlaceCatalog([atm]);
    provider.markVisited('atm_cairo_station');

    expect(provider.visitedPlaceIds, isEmpty);
  });
}
