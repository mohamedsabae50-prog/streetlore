enum PriceLevel {
  free,
  cheap,
  moderate,
  expensive;

  String get label {
    switch (this) {
      case PriceLevel.free:
        return 'Free';
      case PriceLevel.cheap:
        return 'EGP 25-50';
      case PriceLevel.moderate:
        return 'EGP 50-150';
      case PriceLevel.expensive:
        return 'EGP 150+';
    }
  }

  static PriceLevel fromName(String? name) {
    switch (name) {
      case 'cheap':
        return PriceLevel.cheap;
      case 'moderate':
        return PriceLevel.moderate;
      case 'expensive':
        return PriceLevel.expensive;
      case 'free':
      default:
        return PriceLevel.free;
    }
  }
}

class PlaceModel {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final double rating;
  final String category;
  final double lat;
  final double lng;
  final String address;
  final String openHours;
  final int reviewCount;
  final PriceLevel priceLevel;
  final String priceNote;
  final bool isHiddenGem;
  final int? priceLocalEgp;
  final int? priceForeignerEgp;

  const PlaceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.rating,
    this.category = 'General',
    required this.lat,
    required this.lng,
    this.address = 'Alexandria, Egypt',
    this.openHours = '9:00 AM - 6:00 PM',
    this.reviewCount = 0,
    this.priceLevel = PriceLevel.free,
    this.priceNote = '',
    this.isHiddenGem = false,
    this.priceLocalEgp,
    this.priceForeignerEgp,
  });

  bool get isFree => priceLevel == PriceLevel.free;

  bool get hasDualPrice =>
      priceLocalEgp != null && priceForeignerEgp != null;

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    return PlaceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String,
      rating: (json['rating'] as num).toDouble(),
      category: json['category'] as String? ?? 'General',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      address: json['address'] as String? ?? 'Alexandria, Egypt',
      openHours: json['openHours'] as String? ?? '9:00 AM - 6:00 PM',
      reviewCount: json['reviewCount'] as int? ?? 0,
      priceLevel: PriceLevel.fromName(json['priceLevel'] as String?),
      priceNote: json['priceNote'] as String? ?? '',
      isHiddenGem: json['isHiddenGem'] as bool? ?? false,
      priceLocalEgp: json['priceLocalEgp'] as int?,
      priceForeignerEgp: json['priceForeignerEgp'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'rating': rating,
      'category': category,
      'lat': lat,
      'lng': lng,
      'address': address,
      'openHours': openHours,
      'reviewCount': reviewCount,
      'priceLevel': priceLevel.name,
      'priceNote': priceNote,
      'isHiddenGem': isHiddenGem,
      'priceLocalEgp': priceLocalEgp,
      'priceForeignerEgp': priceForeignerEgp,
    };
  }
}
