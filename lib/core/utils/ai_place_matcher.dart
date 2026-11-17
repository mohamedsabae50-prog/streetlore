import '../../data/models/place_model.dart';
import '../../data/models/egypt_governorate.dart';

class AiPlaceMatcher {
  AiPlaceMatcher._();

  static const Map<String, List<String>> _aliases = {
    'qaitbay citadel': ['citadel of qaitbay', 'qaitbay citadel', 'qaitbay'],
    'قلعة قايتباي': ['citadel of qaitbay', 'qaitbay citadel', 'qaitbay'],
    'anfoushi fish market': ['anfoushi fish market', 'fish market anfoushi'],
    'سوق السمك بالأنفوشي': ['anfoushi fish market', 'fish market anfoushi'],
    'bibliotheca alexandrina': [
      'bibliotheca alexandrina',
      'alexandria library',
    ],
    'مكتبة الإسكندرية': ['bibliotheca alexandrina', 'alexandria library'],
    'egyptian museum': ['egyptian museum tahrir', 'egyptian museum'],
    'المتحف المصري': ['egyptian museum tahrir', 'egyptian museum'],
    'cairo tower': ['cairo tower'],
    'برج القاهرة': ['cairo tower'],
    'karnak temple': ['karnak temple'],
    'معبد الكرنك': ['karnak temple'],
  };

  static const Map<String, String> _governorateTerms = {
    'alexandria': 'alexandria',
    'الإسكندرية': 'alexandria',
    'cairo': 'cairo',
    'القاهرة': 'cairo',
    'giza': 'cairo',
    'الجيزة': 'cairo',
    'luxor': 'luxor',
    'الأقصر': 'luxor',
    'aswan': 'luxor',
    'أسوان': 'luxor',
    'hurghada': 'red_sea',
    'الغردقة': 'red_sea',
    'marsa alam': 'red_sea',
    'مرسى علم': 'red_sea',
  };

  static const List<String> _recommendationTerms = [
    'رشح',
    'رشحلي',
    'اقتراح',
    'اقترح',
    'اقترحلي',
    'عايز اروح',
    'افضل',
    'احسن',
    'مكان',
    'اماكن',
    'recommend',
    'suggest',
    'best',
    'where to go',
    'visit',
  ];

  static const Map<String, List<String>> _categoryTerms = {
    'Food': [
      'مطعم',
      'مطاعم',
      'اكل',
      'أكل',
      'food',
      'restaurant',
      'restaurants',
    ],
    'Cafe': ['كافيه', 'قهوة', 'cafe', 'coffee'],
    'Historical': ['تاريخ', 'أثري', 'اثري', 'historical', 'history', 'ancient'],
    'Nature': ['طبيعة', 'شاطئ', 'حديقة', 'nature', 'beach', 'park'],
    'Culture': ['ثقافة', 'ثقافي', 'culture', 'cultural'],
    'Shopping': ['تسوق', 'مول', 'shopping', 'mall'],
    'Mosques': ['مسجد', 'مساجد', 'mosque', 'mosques'],
    'Churches': ['كنيسة', 'كنائس', 'church', 'churches'],
    'Hotels': ['فندق', 'فنادق', 'hotel', 'hotels'],
  };

  static List<PlaceModel> match({
    required String userPrompt,
    required String assistantReply,
    required Iterable<PlaceModel> places,
    required String activeGovernorateId,
    int limit = 3,
  }) {
    if (limit <= 0) return const [];
    final catalog = places.where((place) => place.isVisitable).toList();
    if (catalog.isEmpty) return const [];
    final prompt = normalize(userPrompt);
    final reply = normalize(assistantReply);
    final searchableText = '$prompt $reply';
    final exactMatches = <PlaceModel>[];

    for (final place in catalog) {
      final names = <String>[
        place.nameEn,
        if (place.nameAr != null) place.nameAr!,
        ..._aliases.entries
            .where(
              (entry) =>
                  entry.value.any(
                    (alias) => _matchesText(searchableText, normalize(alias)),
                  ) ||
                  _matchesText(searchableText, normalize(entry.key)),
            )
            .where((entry) => _placeMatchesAlias(place, entry.key, entry.value))
            .map((entry) => entry.key),
      ];
      if (names.any((name) => _matchesText(searchableText, normalize(name)))) {
        exactMatches.add(place);
      }
    }

    if (exactMatches.isNotEmpty) {
      exactMatches.sort(_comparePlaces);
      return exactMatches.take(limit).toList(growable: false);
    }
    if (!_recommendationTerms.any(
      (term) => _matchesText(prompt, normalize(term)),
    )) {
      return const [];
    }

    final governorateId =
        _mentionedGovernorate(prompt) ??
        EgyptGovernorate.normalizeId(activeGovernorateId);
    final categories = _categoryTerms.entries
        .where(
          (entry) =>
              entry.value.any((term) => _matchesText(prompt, normalize(term))),
        )
        .map((entry) => entry.key)
        .toSet();
    final recommendations = catalog.where((place) {
      if (EgyptGovernorate.normalizeId(place.governorate) != governorateId) {
        return false;
      }
      return categories.isEmpty || categories.contains(place.category);
    }).toList()..sort(_comparePlaces);
    return recommendations.take(limit).toList(growable: false);
  }

  static bool _placeMatchesAlias(
    PlaceModel place,
    String alias,
    List<String> targets,
  ) {
    final identity = normalize('${place.id} ${place.nameEn} ${place.nameAr}');
    if (normalize(alias) == normalize('qaitbay citadel') ||
        normalize(alias) == normalize('قلعة قايتباي')) {
      return identity.contains('qaitbay');
    }
    if (normalize(alias) == normalize('anfoushi fish market') ||
        normalize(alias) == normalize('سوق السمك بالأنفوشي')) {
      return identity.contains('anfoushi') &&
          (identity.contains('fish') ||
              identity.contains('market') ||
              identity.contains('سمك'));
    }
    if (normalize(alias) == normalize('bibliotheca alexandrina') ||
        normalize(alias) == normalize('مكتبة الإسكندرية')) {
      return identity.contains('biblio') ||
          identity.contains('alexandria library');
    }
    return targets.any((target) => identity.contains(normalize(target)));
  }

  static String? _mentionedGovernorate(String prompt) {
    for (final entry in _governorateTerms.entries) {
      if (_matchesText(prompt, normalize(entry.key))) return entry.value;
    }
    return null;
  }

  static int _comparePlaces(PlaceModel a, PlaceModel b) {
    final byRating = b.rating.compareTo(a.rating);
    if (byRating != 0) return byRating;
    final byReviews = b.reviewCount.compareTo(a.reviewCount);
    if (byReviews != 0) return byReviews;
    return a.id.compareTo(b.id);
  }

  static bool _matchesText(String text, String candidate) {
    if (text.isEmpty || candidate.isEmpty) return false;
    return RegExp('(^| )${RegExp.escape(candidate)}( |\$)').hasMatch(' $text ');
  }

  static String normalize(String value) {
    final normalizedRunes = <int>[];
    for (final rune in value.toLowerCase().runes) {
      if ((rune >= 0x064B && rune <= 0x065F) ||
          rune == 0x0670 ||
          rune == 0x0640) {
        continue;
      }
      normalizedRunes.add(switch (rune) {
        0x0622 || 0x0623 || 0x0625 => 0x0627,
        0x0629 => 0x0647,
        0x0649 => 0x064A,
        _ => rune,
      });
    }
    final text = String.fromCharCodes(
      normalizedRunes,
    ).replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), ' ').trim();
    return text
        .split(RegExp(r'\s+'))
        .map((token) {
          if (token.startsWith('ال') && token.length > 2) {
            return token.substring(2);
          }
          if (token == 'the' || token == 'a' || token == 'an') return '';
          return token;
        })
        .where((token) => token.isNotEmpty)
        .join(' ');
  }
}
