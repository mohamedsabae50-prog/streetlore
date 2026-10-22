import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/data/models/map_seed.dart';

void main() {
  test('Plaza Hotel seed stays on the land side of the San Stefano coast', () {
    final plaza = getSeedHotels().singleWhere(
      (hotel) => hotel.id == 'hotel-plaza-alex',
    );

    expect(plaza.lat, 31.2426);
    expect(plaza.lng, 29.9668);
    expect(plaza.address, '394 El-Gaish Rd, Zizinia, San Stefano');
  });
}
