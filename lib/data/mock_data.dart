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

  static List<PlaceModel> getFeatured() => _seedPlaces.take(5).toList();

  static List<PlaceModel> getNearby(PlaceModel current) {
    return _seedPlaces
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

  static List<PlaceModel> get places => _seedPlaces;

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

const List<PlaceModel> _seedPlaces = [];
const List<ItineraryModel> _seedTours = [];
