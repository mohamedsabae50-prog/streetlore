import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/data/models/itinerary_model.dart';
import 'package:streetlore/data/models/place_model.dart';
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
}
