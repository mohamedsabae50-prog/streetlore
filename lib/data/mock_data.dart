import 'models/place_model.dart';
import 'models/itinerary_model.dart';

class MockData {
  MockData._();

  static const List<MockReview> _reviewPool = [
    MockReview(
      name: 'Sarah Mitchell',
      rating: 5.0,
      comment:
          'Absolutely breathtaking! The view of the Mediterranean from the top is unlike anything I have ever seen. A true hidden gem of history.',
      date: '2 days ago',
      avatarColor: 0xFFE11D48,
    ),
    MockReview(
      name: 'Ahmed Khalil',
      rating: 4.5,
      comment:
          'A must-visit landmark in Alexandria. Rich history and beautiful architecture. I recommend visiting early morning to avoid crowds.',
      date: '1 week ago',
      avatarColor: 0xFF0F172A,
    ),
    MockReview(
      name: 'Emma Rossi',
      rating: 4.0,
      comment:
          'Beautiful place with a lot of character. Slightly crowded on weekends. The sunset view is absolutely magical.',
      date: '2 weeks ago',
      avatarColor: 0xFF10B981,
    ),
    MockReview(
      name: 'Omar Hassan',
      rating: 5.0,
      comment:
          'One of Alexandria finest gems. Every Egyptian and tourist should visit. The history here is incredible!',
      date: '1 month ago',
      avatarColor: 0xFFF59E0B,
    ),
    MockReview(
      name: 'Layla Nour',
      rating: 4.5,
      comment:
          'Stunning architecture and amazing stories to discover. The guide was very knowledgeable and passionate.',
      date: '3 weeks ago',
      avatarColor: 0xFF6366F1,
    ),
    MockReview(
      name: 'James Wilson',
      rating: 3.5,
      comment:
          'Great experience overall. Could use better signage in English but the place itself is magnificent.',
      date: '2 months ago',
      avatarColor: 0xFF0EA5E9,
    ),
    MockReview(
      name: 'Nadia Farouk',
      rating: 5.0,
      comment:
          'Truly one of those places that stays with you forever. The atmosphere is unique and unlike anywhere else in Egypt.',
      date: '5 days ago',
      avatarColor: 0xFF7C3AED,
    ),
    MockReview(
      name: 'Carlos Martinez',
      rating: 4.5,
      comment:
          'I traveled all the way from Spain to see this. Worth every bit of it. Alexandria keeps surprising me.',
      date: '10 days ago',
      avatarColor: 0xFFEA580C,
    ),
  ];

  static List<MockReview> getReviews(String placeId) {
    final seed = placeId.hashCode.abs() % _reviewPool.length;
    final List<MockReview> result = [];
    for (var i = 0; i < 5; i++) {
      result.add(_reviewPool[(seed + i) % _reviewPool.length]);
    }
    return result;
  }

  static List<PlaceModel> getFeatured() => fallbackPlaces.take(5).toList();

  static List<PlaceModel> getNearby(PlaceModel current) {
    return fallbackPlaces
        .where((p) =>
            p.id != current.id &&
            (p.lat - current.lat).abs() < 0.05 &&
            (p.lng - current.lng).abs() < 0.05)
        .take(4)
        .toList();
  }

  static List<PlaceModel> getByCategory(
      String category, List<PlaceModel> source) {
    if (category == 'All') return source;
    return source.where((p) => p.category == category).toList();
  }

  static bool isOpenNow(String openHours) {
    if (openHours.trim() == 'Open 24 hours') return true;
    final now = DateTime.now();
    final hour = now.hour;
    return hour >= 9 && hour < 18;
  }

  static List<PlaceModel> get places => fallbackPlaces;

  static List<ItineraryModel> get tours => _seedTours;
}

class MockReview {
  final String name;
  final double rating;
  final String comment;
  final String date;
  final int avatarColor;
  const MockReview({
    required this.name,
    required this.rating,
    required this.comment,
    required this.date,
    required this.avatarColor,
  });
}

const List<PlaceModel> fallbackPlaces = [
  PlaceModel(
    id: 'fallback_qaitbay',
    name: 'Citadel of Qaitbay',
    description:
        'A 15th-century defensive fortress located on the Mediterranean sea coast. Built upon the ruins of the ancient Lighthouse of Alexandria.',
    imageUrl:
        'https://images.unsplash.com/photo-1604608672516-f1b9b1d1d1b1?w=900',
    rating: 4.7,
    category: 'Historical',
    lat: 31.2141,
    lng: 29.8856,
    address: 'Asafra, Alexandria',
    openHours: '9:00 AM - 5:00 PM',
    reviewCount: 1240,
    priceLevel: PriceLevel.cheap,
    priceNote: 'Adults',
    priceLocalEgp: 20,
    priceForeignerEgp: 80,
    isHiddenGem: false,
  ),
  PlaceModel(
    id: 'fallback_biblio',
    name: 'Bibliotheca Alexandrina',
    description:
        'A major library and cultural center on the shore of the Mediterranean. A revival of the ancient Library of Alexandria.',
    imageUrl:
        'https://images.unsplash.com/photo-1572252009286-268acec5ca0a?w=900',
    rating: 4.8,
    category: 'Culture',
    lat: 31.2092,
    lng: 29.9085,
    address: 'El Shatby, Alexandria',
    openHours: '10:00 AM - 7:00 PM',
    reviewCount: 2890,
    priceLevel: PriceLevel.free,
    priceNote: 'Free entry',
    priceLocalEgp: 0,
    priceForeignerEgp: 0,
    isHiddenGem: false,
  ),
  PlaceModel(
    id: 'fallback_pompey',
    name: 'Pompey Pillar',
    description:
        'A Roman triumphal column in Alexandria. The largest of its kind constructed outside of Rome and the imperial capitals.',
    imageUrl:
        'https://images.unsplash.com/photo-1553913861-c0fddf2619ee?w=900',
    rating: 4.5,
    category: 'Historical',
    lat: 31.1825,
    lng: 29.8967,
    address: 'Carmous, Alexandria',
    openHours: '9:00 AM - 5:00 PM',
    reviewCount: 980,
    priceLevel: PriceLevel.cheap,
    priceNote: 'Adults',
    priceLocalEgp: 15,
    priceForeignerEgp: 60,
    isHiddenGem: false,
  ),
  PlaceModel(
    id: 'fallback_catacombs',
    name: 'Catacombs of Kom El Shoqafa',
    description:
        'A historical archaeological site considered one of the Seven Wonders of the Middle Ages. Multi-level labyrinth with chambers.',
    imageUrl:
        'https://images.unsplash.com/photo-1568322445389-f64ac2515020?w=900',
    rating: 4.6,
    category: 'Historical',
    lat: 31.1789,
    lng: 29.8922,
    address: 'Carmous, Alexandria',
    openHours: '9:00 AM - 4:00 PM',
    reviewCount: 1450,
    priceLevel: PriceLevel.cheap,
    priceNote: 'Adults',
    priceLocalEgp: 20,
    priceForeignerEgp: 80,
    isHiddenGem: false,
  ),
  PlaceModel(
    id: 'fallback_corniche',
    name: 'Alexandria Corniche',
    description:
        'A scenic waterfront promenade along the Mediterranean Sea. Perfect for sunset walks with stunning views.',
    imageUrl:
        'https://images.unsplash.com/photo-1591202913800-b4eddb931f06?w=900',
    rating: 4.7,
    category: 'Streets',
    lat: 31.2460,
    lng: 29.9660,
    address: 'Corniche, Alexandria',
    openHours: 'Open 24 hours',
    reviewCount: 3200,
    priceLevel: PriceLevel.free,
    priceNote: 'Free',
    priceLocalEgp: 0,
    priceForeignerEgp: 0,
    isHiddenGem: false,
  ),
  PlaceModel(
    id: 'fallback_montaza',
    name: 'Montaza Palace Gardens',
    description:
        'Beautiful royal gardens with the Khedive Ismail palace. Green oasis by the sea with stunning views.',
    imageUrl:
        'https://images.unsplash.com/photo-1604999333679-b86d54738315?w=900',
    rating: 4.5,
    category: 'Nature',
    lat: 31.2890,
    lng: 30.0160,
    address: 'Montaza, Alexandria',
    openHours: '8:00 AM - 10:00 PM',
    reviewCount: 1850,
    priceLevel: PriceLevel.free,
    priceNote: 'Garden free, palace 25 EGP',
    priceLocalEgp: 0,
    priceForeignerEgp: 25,
    isHiddenGem: false,
  ),
  PlaceModel(
    id: 'fallback_attarine',
    name: 'Attarine Mosque',
    description:
        'A historic mosque in the old heart of Alexandria. Beautiful Mamluk-era architecture with intricate details.',
    imageUrl:
        'https://images.unsplash.com/photo-1542816417-0983c9c9ad53?w=900',
    rating: 4.3,
    category: 'Mosques',
    lat: 31.1990,
    lng: 29.8970,
    address: 'Attarine, Alexandria',
    openHours: '9:00 AM - 9:00 PM',
    reviewCount: 420,
    priceLevel: PriceLevel.free,
    priceNote: 'Free',
    priceLocalEgp: 0,
    priceForeignerEgp: 0,
    isHiddenGem: true,
  ),
  PlaceModel(
    id: 'fallback_stmark',
    name: 'St. Mark Coptic Cathedral',
    description:
        'The historic seat of the Coptic Pope in Alexandria. Beautiful modern architecture with ancient Coptic heritage.',
    imageUrl:
        'https://images.unsplash.com/photo-1545987796-200677ee1011?w=900',
    rating: 4.6,
    category: 'Churches',
    lat: 31.2056,
    lng: 29.9110,
    address: 'Raml Station, Alexandria',
    openHours: '8:00 AM - 8:00 PM',
    reviewCount: 380,
    priceLevel: PriceLevel.free,
    priceNote: 'Free',
    priceLocalEgp: 0,
    priceForeignerEgp: 0,
    isHiddenGem: false,
  ),
];

const List<ItineraryModel> _seedTours = [];
