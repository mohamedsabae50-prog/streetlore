import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/core/services/google_maps_search.dart';
import 'package:streetlore/data/models/place_model.dart';

void main() {
  const place = PlaceModel(
    id: 'seed_14',
    nameEn: '14 Citadel of Qaitbay 123',
    nameAr: 'قلعة قايتباي 14',
    descriptionEn: '',
    imageUrl: '',
    rating: 4.5,
    lat: 31.2139,
    lng: 29.8856,
    governorate: 'alexandria',
  );

  test('Google Maps search contains only cleaned name and governorate', () {
    final uri = googleMapsSearchUri(place);
    expect(
      uri.queryParameters['query'],
      'Citadel of Qaitbay, Alexandria, Egypt',
    );
    expect(uri.queryParameters['query'], isNot(contains('31.2139')));
    expect(uri.queryParameters['query'], isNot(contains('29.8856')));
    expect(uri.queryParameters['query'], isNot(contains('14')));
    expect(uri.queryParameters['query'], isNot(contains('123')));
  });

  test('removes plus codes from the search query', () {
    const plusCodePlace = PlaceModel(
      id: 'plus-code',
      nameEn: '8FVC9G8F+5W Alexandria 14',
      descriptionEn: '',
      imageUrl: '',
      rating: 4,
      lat: 31,
      lng: 29,
      governorate: 'alexandria',
    );
    expect(
      googleMapsSearchUri(plusCodePlace).queryParameters['query'],
      'Alexandria, Alexandria, Egypt',
    );
  });
}
