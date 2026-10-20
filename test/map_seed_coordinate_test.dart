import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/data/models/map_seed.dart';

void main() {
  test('Plaza Hotel seed uses the verified San Stefano location', () {
    final plaza = getSeedHotels().singleWhere(
      (hotel) => hotel.id == 'hotel-plaza-alex',
    );

    expect(plaza.lat, 31.2448);
    expect(plaza.lng, 29.9647);
    expect(plaza.address, '394 El-Gaish Rd, Zizinia, San Stefano');
  });
}
