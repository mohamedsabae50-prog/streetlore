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
        .where(
          (p) =>
              p.id != current.id &&
              (p.lat - current.lat).abs() < 0.05 &&
              (p.lng - current.lng).abs() < 0.05,
        )
        .take(4)
        .toList();
  }

  static List<PlaceModel> getByCategory(
    String category,
    List<PlaceModel> source,
  ) {
    if (category == 'All') return source;
    return source.where((p) => p.category == category).toList();
  }

  static bool isOpenNow(String openHours, {DateTime? now}) {
    final clean = openHours.trim();
    if (RegExp(
      r'^(?:open\s*)?24\s*hours?$',
      caseSensitive: false,
    ).hasMatch(clean)) {
      return true;
    }

    final parts = clean.split(RegExp(r'\s*[-\u2013\u2014]\s*'));
    if (parts.length != 2) return false;

    final open = _parseHourMin(parts[0]);
    final close = _parseHourMin(parts[1]);
    if (open == null || close == null || open == close) return false;

    final current = now ?? DateTime.now();
    final nowMinutes = current.hour * 60 + current.minute;
    if (close > open) {
      return nowMinutes >= open && nowMinutes < close;
    }
    return nowMinutes >= open || nowMinutes < close;
  }

  static int? _parseHourMin(String value) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return null;

    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour < 1 || hour > 12 || minute > 59) return null;

    final period = match.group(3)!.toUpperCase();
    return (hour % 12 + (period == 'PM' ? 12 : 0)) * 60 + minute;
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

const PlaceModel _fallbackNationalMuseum = PlaceModel(
  id: 'fallback_national_museum',
  nameEn: 'Alexandria National Museum',
  nameAr: 'المتحف الوطني بالإسكندرية',
  descriptionEn:
      'An Italianate palace built in 1926, displaying artifacts from the Pharaonic, Greek, Roman, Coptic, and Islamic eras.',
  descriptionAr:
      'قصر إيطالي الطراز شُيّد عام 1926، ويضم آثاراً من العصور الفرعونية واليونانية والرومانية والقبطية والإسلامية.',
  imageUrl:
      'https://images.unsplash.com/photo-1564399579883-451a5d44ec08?auto=format&fit=crop&w=1000&q=80',
  rating: 4.6,
  category: 'Culture',
  categoryAr: 'ثقافة',
  lat: 31.1989,
  lng: 29.9065,
  address: 'Latin Quarter, Alexandria',
  addressAr: 'الحي اللاتيني، الإسكندرية',
  openHours: '9:00 AM - 4:30 PM',
  reviewCount: 850,
  priceLevel: PriceLevel.cheap,
  priceNote: 'Adults',
  priceNoteAr: 'للكبار',
  priceLocalEgp: 20,
  priceForeignerEgp: 100,
);

const PlaceModel _fallbackGraecoRomanMuseum = PlaceModel(
  id: 'fallback_graeco_roman_museum',
  nameEn: 'Graeco-Roman Museum',
  nameAr: 'المتحف اليوناني الروماني',
  descriptionEn:
      'A recently renovated museum showcasing thousands of artifacts from Alexandria’s Ptolemaic and Roman eras.',
  descriptionAr:
      'متحف مُجدّد يضم آلاف القطع الأثرية من العصرين البطلمي والروماني في الإسكندرية.',
  imageUrl:
      'https://images.unsplash.com/photo-1564399579883-451a5d44ec08?auto=format&fit=crop&w=1000&q=80',
  rating: 4.7,
  category: 'Culture',
  categoryAr: 'ثقافة',
  lat: 31.1982,
  lng: 29.9027,
  address: 'Kom El-Dikka, Alexandria',
  addressAr: 'كوم الدكة، الإسكندرية',
  openHours: '9:00 AM - 5:00 PM',
  reviewCount: 620,
  priceLevel: PriceLevel.cheap,
  priceNote: 'Adults',
  priceNoteAr: 'للكبار',
  priceLocalEgp: 20,
  priceForeignerEgp: 100,
);

const _romanAmphitheatreImageUrl =
    'https://images.unsplash.com/photo-1511818966892-d7d671e672a2?auto=format&fit=crop&w=1000&q=80';

const PlaceModel _fallbackRomanAmphitheatre = PlaceModel(
  id: 'fallback_roman_amphitheatre',
  nameEn: 'Roman Amphitheatre (Kom el-Dikka)',
  nameAr: 'المسرح الروماني (كوم الدكة)',
  descriptionEn:
      'A Roman theatre with thirteen tiers of marble seating, discovered during excavations in central Alexandria.',
  descriptionAr:
      'مسرح روماني يضم ثلاثة عشر صفاً من المدرجات الرخامية، اكتُشف خلال أعمال التنقيب في وسط الإسكندرية.',
  imageUrl: _romanAmphitheatreImageUrl,
  imageUrls: [
    'https://images.unsplash.com/photo-1511818966892-d7d671e672a2?auto=format&fit=crop&w=1000&q=80',
  ],
  rating: 4.5,
  category: 'Historical',
  categoryAr: 'تاريخي',
  lat: 31.1925,
  lng: 29.9045,
  address: 'Kom El-Dikka, Alexandria',
  addressAr: 'كوم الدكة، الإسكندرية',
  openHours: '9:00 AM - 5:00 PM',
  reviewCount: 760,
  priceLevel: PriceLevel.cheap,
  priceNote: 'Adults',
  priceNoteAr: 'للكبار',
  priceLocalEgp: 20,
  priceForeignerEgp: 80,
);

const _stanleyBridgeImageUrl =
    'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1000&q=80';

const PlaceModel _fallbackStanleyBridge = PlaceModel(
  id: 'fallback_stanley_bridge',
  nameEn: 'Stanley Bridge & Corniche',
  nameAr: 'كوبري ستانلي والكورنيش',
  descriptionEn:
      'Alexandria’s landmark bridge, with its white arches spanning Stanley Bay along the Mediterranean Corniche.',
  descriptionAr:
      'جسر الإسكندرية الشهير بأقواسه البيضاء الممتدة فوق خليج ستانلي على كورنيش البحر المتوسط.',
  imageUrl: _stanleyBridgeImageUrl,
  rating: 4.6,
  category: 'Nature',
  categoryAr: 'طبيعة',
  lat: 31.2389,
  lng: 29.9553,
  address: 'Stanley, Alexandria',
  addressAr: 'ستانلي، الإسكندرية',
  openHours: 'Open 24 hours',
  reviewCount: 2100,
  priceLevel: PriceLevel.free,
  priceNote: 'Free',
  priceNoteAr: 'مجاني',
  priceLocalEgp: 0,
  priceForeignerEgp: 0,
);

const List<PlaceModel> fallbackPlaces = [
  PlaceModel(
    id: 'fallback_qaitbay',
    nameEn: 'Citadel of Qaitbay',
    nameAr: 'قلعة قايتباي',
    descriptionEn:
        'A 15th-century defensive fortress on the Mediterranean sea coast. Built upon the ruins of the ancient Lighthouse of Alexandria — one of the Seven Wonders of the ancient world.',
    descriptionAr:
        'قلعة قايتباي هي حصن دفاعي يعود للقرن الخامس عشر الميلادي، مبني على أنقاض منارة الإسكندرية القديمة، إحدى عجائب الدنيا السبع. تقع على شاطئ البحر المتوسط وتتميز بمعمارها الأيوبي الرائع.',
    imageUrl:
        'https://images.unsplash.com/photo-1511818966892-d7d671e672a2?auto=format&fit=crop&w=1000&q=80',
    imageUrls: [
      'https://images.unsplash.com/photo-1511818966892-d7d671e672a2?auto=format&fit=crop&w=1000&q=80',
    ],
    rating: 4.7,
    category: 'Historical',
    categoryAr: 'تاريخي',
    lat: 31.2141,
    lng: 29.8856,
    address: 'Eastern Harbor, Anfushi, Alexandria',
    addressAr: 'الميناء الشرقي، الأنفوشي، الإسكندرية',
    openHours: '9:00 AM - 5:00 PM',
    reviewCount: 1240,
    priceLevel: PriceLevel.cheap,
    priceNote: 'Adults',
    priceNoteAr: 'للكبار',
    priceLocalEgp: 20,
    priceForeignerEgp: 80,
    isHiddenGem: false,
  ),
  PlaceModel(
    id: 'fallback_biblio',
    nameEn: 'Bibliotheca Alexandrina',
    nameAr: 'مكتبة الإسكندرية',
    descriptionEn:
        'A modern library and cultural center opened in 2002 on the Mediterranean shore. Inspired by the ancient Library of Alexandria, it holds over 2 million books and hosts museums, exhibitions, and a planetarium.',
    descriptionAr:
        'مكتبة الإسكندرية الجديدة صرح ثقافي ضخم على شاطئ البحر المتوسط، تجسيد معاصر للمكتبة الأسطورية التي كانت مركزاً للعلوم والمعرفة في العالم القديم. تضم مليوني كتاب ومتاحف وقاعات عروض.',
    imageUrl:
        'https://images.unsplash.com/photo-1564399579883-451a5d44ec08?auto=format&fit=crop&w=1000&q=80',
    imageUrls: [
      'https://images.unsplash.com/photo-1564399579883-451a5d44ec08?auto=format&fit=crop&w=1000&q=80',
    ],
    rating: 4.8,
    category: 'Culture',
    categoryAr: 'ثقافة',
    lat: 31.2092,
    lng: 29.9085,
    address: 'El Shatby, Alexandria',
    addressAr: 'الشاطبي، الإسكندرية',
    openHours: '10:00 AM - 7:00 PM',
    reviewCount: 2890,
    priceLevel: PriceLevel.free,
    priceNote: 'Free entry',
    priceNoteAr: 'دخول مجاني',
    priceLocalEgp: 0,
    priceForeignerEgp: 0,
    isHiddenGem: false,
  ),
  PlaceModel(
    id: 'fallback_pompey',
    nameEn: "Pompey's Pillar",
    nameAr: 'عمود السواري',
    descriptionEn:
        'A 30-meter Roman triumphal column in Alexandria, erected in 297 AD in honor of Emperor Diocletian. The largest of its kind constructed outside of Rome and the imperial capitals.',
    descriptionAr:
        'عمود بومبي عمود ضخم من الجرانيت يعود للعصر الروماني، يبلغ ارتفاعه 30 متراً، وهو أعلى عمود انتصار خارج روما. أُقيم عام 297 م تكريماً للإمبراطور دقلديانوس.',
    imageUrl:
        'https://images.unsplash.com/photo-1511818966892-d7d671e672a2?auto=format&fit=crop&w=1000&q=80',
    rating: 4.5,
    category: 'Historical',
    categoryAr: 'تاريخي',
    lat: 31.1825,
    lng: 29.8967,
    address: 'Carmous, Alexandria',
    addressAr: 'كرموز، الإسكندرية',
    openHours: '9:00 AM - 5:00 PM',
    reviewCount: 980,
    priceLevel: PriceLevel.cheap,
    priceNote: 'Adults',
    priceNoteAr: 'للكبار',
    priceLocalEgp: 20,
    priceForeignerEgp: 80,
    isHiddenGem: false,
  ),
  PlaceModel(
    id: 'fallback_catacombs',
    nameEn: 'Catacombs of Kom El Shoqafa',
    nameAr: 'مقابر كوم الشقافة',
    descriptionEn:
        'A historical archaeological site considered one of the Seven Wonders of the Middle Ages. A multi-level labyrinth with chambers blending Roman, Greek, and ancient Egyptian art.',
    descriptionAr:
        'مقابر كوم الشقافة من أبرز المواقع الأثرية في الإسكندرية، تُعد إحدى عجائب الدنيا السبع في العصر الوسيط. متاهة متعددة الطوابق تمزج بين الفن الروماني والمصري القديم.',
    imageUrl:
        'https://images.unsplash.com/photo-1511818966892-d7d671e672a2?auto=format&fit=crop&w=1000&q=80',
    rating: 4.6,
    category: 'Historical',
    categoryAr: 'تاريخي',
    lat: 31.1789,
    lng: 29.8922,
    address: 'Carmous, Alexandria',
    addressAr: 'كرموز، الإسكندرية',
    openHours: '9:00 AM - 4:00 PM',
    reviewCount: 1450,
    priceLevel: PriceLevel.cheap,
    priceNote: 'Adults',
    priceNoteAr: 'للكبار',
    priceLocalEgp: 20,
    priceForeignerEgp: 80,
    isHiddenGem: false,
  ),
  PlaceModel(
    id: 'fallback_montaza',
    nameEn: 'Montaza Palace Gardens',
    nameAr: 'حدائق المنتزه',
    descriptionEn:
        'Royal gardens surrounding the Khedive Abbas palace — a 150-acre green oasis by the Mediterranean. One of Egypt\'s favourite summer retreats for over a century.',
    descriptionAr:
        'حدائق المنتزه الملكية خضراء غناء تحيط بقصر المنتزه التاريخي الذي بناه الخديوي عباس. واحة طبيعية خلابة تطل على البحر المتوسط وتجمع بين الجمال والتاريخ.',
    imageUrl:
        'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1000&q=80',
    imageUrls: [
      'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1000&q=80',
    ],
    rating: 4.5,
    category: 'Nature',
    categoryAr: 'طبيعة',
    lat: 31.2890,
    lng: 30.0160,
    address: 'Montaza, Alexandria',
    addressAr: 'المنتزه، الإسكندرية',
    openHours: '8:00 AM - 10:00 PM',
    reviewCount: 1850,
    priceLevel: PriceLevel.free,
    priceNote: 'Garden free, palace 25 EGP',
    priceNoteAr: 'الحديقة مجانية، القصر 25 جنيه',
    priceLocalEgp: 0,
    priceForeignerEgp: 25,
    isHiddenGem: false,
  ),
  PlaceModel(
    id: 'fallback_attarine',
    nameEn: 'El-Attarine Mosque',
    nameAr: 'مسجد العطارين',
    descriptionEn:
        'A historic mosque in the old heart of Alexandria. Built on the ruins of the Church of St. Athanasius and still preserving its ancient granite columns.',
    descriptionAr:
        'مسجد العطارين أحد المساجد التاريخية العريقة في قلب الإسكندرية القديمة. يعود تاريخه للعصر المملوكي ويتميز بزخارفه الإسلامية الرائعة وروحانيته العالية.',
    imageUrl:
        'https://images.unsplash.com/photo-1519817650390-64a93db51149?auto=format&fit=crop&w=1000&q=80',
    rating: 4.3,
    category: 'Mosques',
    categoryAr: 'مساجد',
    lat: 31.1990,
    lng: 29.8970,
    address: 'Attarine, Alexandria',
    addressAr: 'العطارين، الإسكندرية',
    openHours: '9:00 AM - 9:00 PM',
    reviewCount: 420,
    priceLevel: PriceLevel.free,
    priceNote: 'Free',
    priceNoteAr: 'مجاني',
    priceLocalEgp: 0,
    priceForeignerEgp: 0,
    isHiddenGem: true,
  ),
  PlaceModel(
    id: 'fallback_stmark',
    nameEn: 'St. Mark Coptic Orthodox Cathedral',
    nameAr: 'كاتدرائية القديس مرقس القبطية',
    descriptionEn:
        'The historic seat of the Coptic Pope in Alexandria — the oldest Coptic Orthodox church in Africa and the second papal residence in Egypt after Cairo.',
    descriptionAr:
        'كاتدرائية القديس مرقس الأرثوذكسية مقر البابا الكوبي التاريخي في الإسكندرية. تجمع بين الإرث الكنسي الأصيل والعمارة الحديثة في قلب مدينة الإسكندرية.',
    imageUrl:
        'https://images.unsplash.com/photo-1438032005730-c779502df39b?auto=format&fit=crop&w=1000&q=80',
    rating: 4.6,
    category: 'Churches',
    categoryAr: 'كنائس',
    lat: 31.2056,
    lng: 29.9110,
    address: 'Raml Station, Alexandria',
    addressAr: 'محطة الرمل، الإسكندرية',
    openHours: '8:00 AM - 8:00 PM',
    reviewCount: 380,
    priceLevel: PriceLevel.free,
    priceNote: 'Free',
    priceNoteAr: 'مجاني',
    priceLocalEgp: 0,
    priceForeignerEgp: 0,
    isHiddenGem: false,
  ),
  _fallbackNationalMuseum,
  _fallbackGraecoRomanMuseum,
  _fallbackRomanAmphitheatre,
  _fallbackStanleyBridge,
  PlaceModel(
    id: 'alex_royal_jewelry_museum',
    nameEn: 'Royal Jewelry Museum',
    nameAr: 'متحف المجوهرات الملكية',
    descriptionEn:
        'A former royal palace in Zizinia displaying the jewelry, ceremonial objects and personal collections of Egypt’s Muhammad Ali dynasty.',
    descriptionAr:
        'قصر ملكي سابق في زيزينيا يعرض مجوهرات ومقتنيات أسرة محمد علي، إلى جانب القاعات المزخرفة التي تشكل جزءاً من تجربة الزيارة.',
    imageUrl:
        'https://images.unsplash.com/photo-1564399579883-451a5d44ec08?auto=format&fit=crop&w=1000&q=80',
    rating: 4.6,
    category: 'Culture',
    categoryAr: 'ثقافة',
    lat: 31.2494,
    lng: 29.9665,
    address: '27 Ahmed Yehia Pasha Street, Zizinia, Alexandria',
    addressAr: '٢٧ شارع أحمد يحيى باشا، زيزينيا، الإسكندرية',
    openHours: '9:00 AM - 5:00 PM',
    priceLevel: PriceLevel.cheap,
    priceNote: 'Paid museum admission; verify current ticket prices',
    priceNoteAr: 'دخول بتذكرة؛ يُرجى التحقق من الأسعار الحالية',
  ),
  PlaceModel(
    id: 'alex_cavafy_museum',
    nameEn: 'Cavafy Museum',
    nameAr: 'متحف كفافيس',
    descriptionEn:
        'The preserved Alexandria apartment of Greek poet Constantine P. Cavafy, presented with archival material and objects tracing his life and literary work in the city.',
    descriptionAr:
        'شقة الشاعر اليوناني قسطنطين كفافيس المحفوظة في الإسكندرية، وتضم مقتنيات ووثائق تستعرض حياته وأعماله الأدبية وصلته بالمدينة.',
    imageUrl:
        'https://images.unsplash.com/photo-1564399579883-451a5d44ec08?auto=format&fit=crop&w=1000&q=80',
    imageUrls: [
      'https://images.unsplash.com/photo-1564399579883-451a5d44ec08?auto=format&fit=crop&w=1000&q=80',
      'https://images.unsplash.com/photo-1564399579883-451a5d44ec08?auto=format&fit=crop&w=1000&q=80',
    ],
    rating: 4.5,
    category: 'Culture',
    categoryAr: 'ثقافة',
    lat: 31.1984,
    lng: 29.9018,
    address: '4 Sharm El Sheikh Street, Alexandria',
    addressAr: '٤ شارع شرم الشيخ، الإسكندرية',
    openHours: 'Check current visiting hours before visiting',
    priceLevel: PriceLevel.cheap,
    priceNote: 'Paid admission; verify current visiting details',
    priceNoteAr: 'دخول بتذكرة؛ يُرجى التحقق من مواعيد الزيارة',
  ),
  PlaceModel(
    id: 'alex_nabi_daniel_mosque',
    nameEn: 'Nabi Daniel Mosque',
    nameAr: 'مسجد النبي دانيال',
    descriptionEn:
        'A landmark historic mosque in central Alexandria, known for its distinctive Ottoman-era architecture and long-standing place in the city’s religious and urban history.',
    descriptionAr:
        'مسجد تاريخي بارز في وسط الإسكندرية، يشتهر بعمارة تعود إلى العصر العثماني ومكانته الراسخة في التاريخ الديني والعمراني للمدينة.',
    imageUrl:
        'https://images.unsplash.com/photo-1519817650390-64a93db51149?auto=format&fit=crop&w=1000&q=80',
    rating: 4.5,
    category: 'Mosques',
    categoryAr: 'مساجد',
    lat: 31.1981,
    lng: 29.9017,
    address: 'Nabi Daniel Street, central Alexandria',
    addressAr: 'شارع النبي دانيال، وسط الإسكندرية',
    openHours: '9:00 AM - 5:00 PM',
    priceLevel: PriceLevel.free,
    priceNote: 'Free entry; respect prayer times',
    priceNoteAr: 'الدخول مجاني؛ يُرجى مراعاة أوقات الصلاة',
  ),
  PlaceModel(
    id: 'alex_sayed_darwish_theatre',
    nameEn: 'Sayed Darwish Theatre (Alexandria Opera House)',
    nameAr: 'مسرح سيد درويش (دار أوبرا الإسكندرية)',
    descriptionEn:
        'Alexandria’s historic opera house, opened in 1921 and named for Egyptian composer Sayed Darwish. The restored Italianate theatre remains an active venue for opera, concerts and cultural performances.',
    descriptionAr:
        'دار أوبرا الإسكندرية التاريخية، افتُتحت عام ١٩٢١ وسُمّيت باسم الموسيقار المصري سيد درويش. لا يزال المسرح الإيطالي الطراز يستضيف الأوبرا والحفلات والعروض الثقافية.',
    imageUrl:
        'https://images.unsplash.com/photo-1564399579883-451a5d44ec08?auto=format&fit=crop&w=1000&q=80',
    rating: 4.6,
    category: 'Culture',
    categoryAr: 'ثقافة',
    lat: 31.1995,
    lng: 29.9038,
    address: 'Fouad Street, Alexandria',
    addressAr: 'شارع فؤاد، الإسكندرية',
    openHours: 'Performance schedule varies; check the theatre programme',
    priceLevel: PriceLevel.moderate,
    priceNote: 'Ticketed performances; prices and schedule vary',
    priceNoteAr: 'العروض بتذاكر؛ تختلف الأسعار والمواعيد',
  ),
];

const List<ItineraryModel> _seedTours = fallbackTours;

const List<ItineraryModel> fallbackTours = [
  ItineraryModel(
    id: 'tour_historical',
    title: 'Historical Alexandria',
    titleAr: 'الإسكندرية التاريخية',
    description:
        'Walk through the ancient glories of Alexandria — from Roman columns to Ptolemaic tombs and the iconic Qaitbay Citadel.',
    descriptionAr:
        'تجوّل في أمجاد الإسكندرية القديمة — من الأعمدة الرومانية إلى مقابر البطالمة وقلعة قايتباي الأيقونية.',
    duration: 'Full Day',
    durationAr: 'يوم كامل',
    imageUrl:
        'https://images.unsplash.com/photo-1511818966892-d7d671e672a2?auto=format&fit=crop&w=1000&q=80',
    places: [
      PlaceModel(
        id: 'fallback_qaitbay',
        nameEn: 'Citadel of Qaitbay',
        nameAr: 'قلعة قايتباي',
        descriptionEn:
            'A 15th-century fortress built on the ruins of the ancient Lighthouse of Alexandria.',
        descriptionAr:
            'قلعة قايتباي هي حصن دفاعي يعود للقرن الخامس عشر الميلادي، مبني على أنقاض منارة الإسكندرية القديمة، إحدى عجائب الدنيا السبع. تقع على شاطئ البحر المتوسط وتتميز بمعمارها الأيوبي الرائع.',
        imageUrl:
            'https://images.unsplash.com/photo-1511818966892-d7d671e672a2?auto=format&fit=crop&w=1000&q=80',
        rating: 4.7,
        category: 'Historical',
        categoryAr: 'تاريخي',
        lat: 31.2141,
        lng: 29.8856,
        address: 'Eastern Harbor, Alexandria',
        addressAr: 'الميناء الشرقي، الإسكندرية',
        openHours: '9:00 AM - 5:00 PM',
        reviewCount: 1240,
        priceLevel: PriceLevel.cheap,
        priceNote: 'Adults',
        priceNoteAr: 'للكبار',
        priceLocalEgp: 20,
        priceForeignerEgp: 80,
      ),
      PlaceModel(
        id: 'fallback_pompey',
        nameEn: "Pompey's Pillar",
        nameAr: 'عمود السواري',
        descriptionEn:
            'The tallest ancient monument in Alexandria, a Roman triumphal column from 297 AD.',
        descriptionAr:
            'عمود بومبي عمود ضخم من الجرانيت يعود للعصر الروماني، يبلغ ارتفاعه 30 متراً، وهو أعلى عمود انتصار خارج روما. أُقيم عام 297 م تكريماً للإمبراطور دقلديانوس.',
        imageUrl:
            'https://images.unsplash.com/photo-1511818966892-d7d671e672a2?auto=format&fit=crop&w=1000&q=80',
        rating: 4.5,
        category: 'Historical',
        categoryAr: 'تاريخي',
        lat: 31.1825,
        lng: 29.8967,
        address: 'Carmous, Alexandria',
        addressAr: 'كرموز، الإسكندرية',
        openHours: '9:00 AM - 5:00 PM',
        reviewCount: 980,
        priceLevel: PriceLevel.cheap,
        priceNote: 'Adults',
        priceNoteAr: 'للكبار',
        priceLocalEgp: 20,
        priceForeignerEgp: 80,
      ),
      PlaceModel(
        id: 'fallback_catacombs',
        nameEn: 'Catacombs of Kom El Shoqafa',
        nameAr: 'مقابر كوم الشقافة',
        descriptionEn:
            'A multi-level labyrinth considered one of the Seven Wonders of the Middle Ages.',
        descriptionAr:
            'مقابر كوم الشقافة من أبرز المواقع الأثرية في الإسكندرية، تُعد إحدى عجائب الدنيا السبع في العصر الوسيط. متاهة متعددة الطوابق تمزج بين الفن الروماني والمصري القديم.',
        imageUrl:
            'https://images.unsplash.com/photo-1511818966892-d7d671e672a2?auto=format&fit=crop&w=1000&q=80',
        rating: 4.6,
        category: 'Historical',
        categoryAr: 'تاريخي',
        lat: 31.1789,
        lng: 29.8922,
        address: 'Carmous, Alexandria',
        addressAr: 'كرموز، الإسكندرية',
        openHours: '9:00 AM - 4:00 PM',
        reviewCount: 1450,
        priceLevel: PriceLevel.cheap,
        priceNote: 'Adults',
        priceNoteAr: 'للكبار',
        priceLocalEgp: 20,
        priceForeignerEgp: 80,
      ),
      PlaceModel(
        id: 'fallback_biblio',
        nameEn: 'Bibliotheca Alexandrina',
        nameAr: 'مكتبة الإسكندرية',
        descriptionEn:
            'A modern library opened in 2002, inspired by the ancient Library of Alexandria.',
        descriptionAr:
            'مكتبة الإسكندرية الجديدة صرح ثقافي ضخم على شاطئ البحر المتوسط، تجسيد معاصر للمكتبة الأسطورية التي كانت مركزاً للعلوم والمعرفة في العالم القديم. تضم مليوني كتاب ومتاحف وقاعات عروض.',
        imageUrl:
            'https://images.unsplash.com/photo-1564399579883-451a5d44ec08?auto=format&fit=crop&w=1000&q=80',
        rating: 4.8,
        category: 'Culture',
        categoryAr: 'ثقافة',
        lat: 31.2092,
        lng: 29.9085,
        address: 'El Shatby, Alexandria',
        addressAr: 'الشاطبي، الإسكندرية',
        openHours: '10:00 AM - 7:00 PM',
        reviewCount: 2890,
        priceLevel: PriceLevel.free,
        priceNote: 'Free entry',
        priceNoteAr: 'دخول مجاني',
        priceLocalEgp: 0,
        priceForeignerEgp: 0,
      ),
    ],
  ),
  ItineraryModel(
    id: 'tour_coastal',
    title: 'Coastal Alexandria',
    titleAr: 'إسكندرية الساحل',
    description:
        'Explore the royal gardens and historic palaces on Alexandria’s Mediterranean coast.',
    descriptionAr:
        'استكشف الحدائق الملكية والقصور التاريخية على ساحل الإسكندرية.',
    duration: '4 Hours',
    durationAr: '4 ساعات',
    imageUrl:
        'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1000&q=80',
    places: [
      PlaceModel(
        id: 'fallback_montaza',
        nameEn: 'Montaza Palace Gardens',
        nameAr: 'حدائق المنتزه',
        descriptionEn:
            'Beautiful royal gardens surrounding the Khedive Abbas palace — a green oasis by the sea.',
        descriptionAr:
            'حدائق المنتزه الملكية خضراء غناء تحيط بقصر المنتزه التاريخي الذي بناه الخديوي عباس. واحة طبيعية خلابة تطل على البحر المتوسط وتجمع بين الجمال والتاريخ.',
        imageUrl:
            'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1000&q=80',
        rating: 4.5,
        category: 'Nature',
        categoryAr: 'طبيعة',
        lat: 31.2890,
        lng: 30.0160,
        address: 'Montaza, Alexandria',
        addressAr: 'المنتزه، الإسكندرية',
        openHours: '8:00 AM - 10:00 PM',
        reviewCount: 1850,
        priceLevel: PriceLevel.free,
        priceNote: 'Garden free, palace 25 EGP',
        priceNoteAr: 'الحديقة مجانية، القصر 25 جنيه',
        priceLocalEgp: 0,
        priceForeignerEgp: 25,
      ),
    ],
  ),
  ItineraryModel(
    id: 'tour_spiritual',
    title: 'Sacred Landmarks',
    titleAr: 'الأماكن المقدسة',
    description:
        'Explore the spiritual heart of Alexandria — historic mosques and ancient Coptic cathedrals side by side.',
    descriptionAr:
        'استكشف قلب الإسكندرية الروحي — مساجد تاريخية وكنائس قبطية عريقة جنباً إلى جنب.',
    duration: '3 Hours',
    durationAr: '3 ساعات',
    imageUrl:
        'https://images.unsplash.com/photo-1519817650390-64a93db51149?auto=format&fit=crop&w=1000&q=80',
    places: [
      PlaceModel(
        id: 'fallback_attarine',
        nameEn: 'El-Attarine Mosque',
        nameAr: 'مسجد العطارين',
        descriptionEn:
            'A historic Mamluk-era mosque in the old heart of Alexandria with intricate architectural details.',
        descriptionAr:
            'مسجد العطارين أحد المساجد التاريخية العريقة في قلب الإسكندرية القديمة. يعود تاريخه للعصر المملوكي ويتميز بزخارفه الإسلامية الرائعة وروحانيته العالية.',
        imageUrl:
            'https://images.unsplash.com/photo-1519817650390-64a93db51149?auto=format&fit=crop&w=1000&q=80',
        rating: 4.3,
        category: 'Mosques',
        categoryAr: 'مساجد',
        lat: 31.1990,
        lng: 29.8970,
        address: 'Attarine, Alexandria',
        addressAr: 'العطارين، الإسكندرية',
        openHours: '9:00 AM - 9:00 PM',
        reviewCount: 420,
        priceLevel: PriceLevel.free,
        priceNote: 'Free',
        priceNoteAr: 'مجاني',
        priceLocalEgp: 0,
        priceForeignerEgp: 0,
        isHiddenGem: true,
      ),
      PlaceModel(
        id: 'fallback_stmark',
        nameEn: 'St. Mark Coptic Orthodox Cathedral',
        nameAr: 'كاتدرائية القديس مرقس القبطية',
        descriptionEn:
            'The historic seat of the Coptic Pope in Alexandria — blending ancient heritage and modern architecture.',
        descriptionAr:
            'كاتدرائية القديس مرقس الأرثوذكسية مقر البابا الكوبي التاريخي في الإسكندرية. تجمع بين الإرث الكنسي الأصيل والعمارة الحديثة في قلب مدينة الإسكندرية.',
        imageUrl:
            'https://images.unsplash.com/photo-1438032005730-c779502df39b?auto=format&fit=crop&w=1000&q=80',
        rating: 4.6,
        category: 'Churches',
        categoryAr: 'كنائس',
        lat: 31.2056,
        lng: 29.9110,
        address: 'Raml Station, Alexandria',
        addressAr: 'محطة الرمل، الإسكندرية',
        openHours: '8:00 AM - 8:00 PM',
        reviewCount: 380,
        priceLevel: PriceLevel.free,
        priceNote: 'Free',
        priceNoteAr: 'مجاني',
        priceLocalEgp: 0,
        priceForeignerEgp: 0,
      ),
    ],
  ),
  ItineraryModel(
    id: 'tour_roman_alexandria',
    title: 'Roman Alexandria',
    titleAr: 'الإسكندرية الرومانية',
    description:
        'Explore the city’s Roman past through its museum collections, theatre, monumental column, and ancient underground tombs.',
    descriptionAr:
        'اكتشف تاريخ الإسكندرية الروماني من خلال مقتنيات المتاحف والمسرح الروماني والعمود الأثري والمقابر القديمة.',
    duration: '4 Hours',
    durationAr: '4 ساعات',
    imageUrl: _romanAmphitheatreImageUrl,
    places: [
      _fallbackGraecoRomanMuseum,
      _fallbackRomanAmphitheatre,
      PlaceModel(
        id: 'fallback_pompey',
        nameEn: "Pompey's Pillar",
        nameAr: 'عمود السواري',
        descriptionEn:
            'A monumental red-granite Roman column erected in 297 AD at the Serapeum.',
        descriptionAr:
            'عمود روماني ضخم من الجرانيت الأحمر أُقيم عام 297م في منطقة السيرابيوم.',
        imageUrl:
            'https://images.unsplash.com/photo-1511818966892-d7d671e672a2?auto=format&fit=crop&w=1000&q=80',
        rating: 4.5,
        category: 'Historical',
        categoryAr: 'تاريخي',
        lat: 31.1825,
        lng: 29.8967,
        address: 'Carmous, Alexandria',
        addressAr: 'كرموز، الإسكندرية',
        openHours: '9:00 AM - 5:00 PM',
        reviewCount: 980,
        priceLevel: PriceLevel.cheap,
        priceNote: 'Adults',
        priceNoteAr: 'للكبار',
        priceLocalEgp: 20,
        priceForeignerEgp: 80,
      ),
    ],
  ),
  ItineraryModel(
    id: 'tour_city_highlights',
    title: 'Alexandria City Highlights',
    titleAr: 'أبرز معالم الإسكندرية',
    description:
        'Visit Alexandria’s museums, library and cultural landmarks.',
    descriptionAr:
        'زر متاحف الإسكندرية ومكتبتها ومعالمها الثقافية.',
    duration: '5 Hours',
    durationAr: '5 ساعات',
    imageUrl: _stanleyBridgeImageUrl,
    places: [
      _fallbackNationalMuseum,
      _fallbackStanleyBridge,
      PlaceModel(
        id: 'fallback_biblio',
        nameEn: 'Bibliotheca Alexandrina',
        nameAr: 'مكتبة الإسكندرية',
        descriptionEn:
            'A modern library and cultural center on Alexandria’s Mediterranean shore.',
        descriptionAr:
            'مكتبة ومركز ثقافي حديث على ساحل البحر المتوسط في الإسكندرية.',
        imageUrl:
            'https://images.unsplash.com/photo-1564399579883-451a5d44ec08?auto=format&fit=crop&w=1000&q=80',
        rating: 4.8,
        category: 'Culture',
        categoryAr: 'ثقافة',
        lat: 31.2092,
        lng: 29.9085,
        address: 'El Shatby, Alexandria',
        addressAr: 'الشاطبي، الإسكندرية',
        openHours: '10:00 AM - 7:00 PM',
        reviewCount: 2890,
        priceLevel: PriceLevel.free,
        priceNote: 'Free entry',
        priceNoteAr: 'دخول مجاني',
        priceLocalEgp: 0,
        priceForeignerEgp: 0,
      ),
    ],
  ),
];
