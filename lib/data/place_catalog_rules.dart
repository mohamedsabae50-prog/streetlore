import 'models/place_model.dart';

const _admissionPrices = <String, (int, int)>{
  'fallback_qaitbay': (60, 200),
  'fallback_biblio': (20, 150),
  'fallback_catacombs': (40, 200),
  'fallback_pompey': (40, 200),
  'fallback_graeco_roman_museum': (80, 400),
  'fallback_roman_amphitheatre': (40, 200),
  'fallback_national_museum': (40, 200),
  'fallback_montaza': (20, 80),
  'alex_royal_jewelry_museum': (40, 200),
  'alex_cavafy_museum': (20, 80),
  'alex_sadat_museum_bibliotheca': (20, 150),
  'alex_ras_el_tin_palace': (40, 200),
  'alex_mahmoud_said_museum': (20, 100),
  'alex_shatby_ancient_tombs': (20, 100),
  'aisha_fahmy_palace': (50, 200),
  'umm_kulthum_museum': (40, 200),
  'bayt_al_suhaymi': (40, 200),
  'wikala_al_ghuri': (40, 200),
  'royal_carriages_museum': (40, 200),
  'sakakini_palace': (40, 200),
  'child_museum_heliopolis': (40, 200),
  'national_military_museum': (40, 200),
  'aquarium_grotto_garden': (20, 100),
  'wadi_degla_protectorate': (25, 200),
  'iconic_tower_new_capital': (100, 350),
  'cairo_tower': (100, 350),
  'sabil_kuttab_katkhuda': (40, 200),
  'amir_beshtak_palace': (40, 200),
  'egyptian_geological_museum': (40, 200),
  'egyptian_postal_museum': (20, 100),
  'egyptian_railways_museum': (20, 100),
  'beit_el_umma_museum': (40, 200),
  'mahmoud_mukhtar_museum': (40, 200),
  'modern_egyptian_art_museum': (40, 200),
  'al_gawhara_palace_citadel': (60, 250),
  'great_pyramid_of_giza': (60, 700),
  'pyramid_of_khafre': (60, 700),
  'pyramid_of_menkaure': (60, 700),
  'grand_egyptian_museum_gem': (200, 1200),
  'pharaonic_village_giza': (250, 600),
  'saqqara_step_pyramid': (100, 600),
  'serapeum_of_saqqara': (100, 600),
  'pyramid_of_unas_saqqara': (100, 600),
  'imhotep_museum_saqqara': (100, 600),
  'bent_pyramid_dahshur': (40, 200),
  'red_pyramid_dahshur': (40, 200),
  'memphis_museum_mit_rahina': (40, 200),
  'orman_botanical_garden_giza': (20, 100),
  'giza_zoo_garden': (20, 100),
  'taha_hussein_museum_giza': (20, 100),
  'ahmed_shawki_museum_giza': (20, 100),
  'mahmoud_khalil_museum_giza': (20, 100),
  'zed_park_sheikh_zayed': (100, 250),
  'egyptian_textile_museum': (40, 200),
  'sabil_umm_abbas': (40, 200),
  'wakala_of_qaytbay_cairo': (40, 200),
  'hammam_inal_muizz': (40, 200),
  'cairo_opera_house_museum': (40, 200),
  'aswan_philae_temple': (80, 550),
  'aswan_abu_simbel_great_temple': (100, 750),
  'aswan_abu_simbel_nefertari_temple': (100, 750),
  'aswan_nubian_museum': (40, 400),
  'aswan_unfinished_obelisk': (40, 220),
  'aswan_high_dam_memorial': (30, 200),
  'aswan_old_low_dam': (20, 100),
  'aswan_kalabsha_temple': (40, 300),
  'aswan_beit_el_wali_temple': (40, 300),
  'aswan_kiosk_of_qertassi': (40, 300),
  'aswan_qubbet_el_hawa_tombs': (40, 200),
  'aswan_st_simeon_monastery': (40, 160),
  'aswan_elephantine_museum_ruins': (40, 200),
  'aswan_elephantine_nilometer': (40, 200),
  'aswan_sehel_island_famine_stele': (40, 160),
  'aswan_aga_khan_mausoleum': (30, 100),
  'aswan_fatimid_cemetery': (30, 100),
  'aswan_kom_ombo_temple': (60, 450),
  'aswan_crocodile_museum_kom_ombo': (40, 200),
  'aswan_edfu_horus_temple': (80, 550),
  'aswan_tell_edfu_archaeological_site': (40, 150),
  'aswan_nile_museum': (35, 150),
  'aswan_cultural_palace_theater': (30, 120),
  'aswan_international_sculpture_park': (30, 120),
  'aswan_botanical_garden_kitchener': (30, 160),
  'aswan_gharb_soheil_nubian_village': (50, 150),
  'aswan_saluga_ghazal_protectorate': (30, 150),
  'aswan_heissa_nubian_island': (50, 150),
  'aswan_faryal_garden_corniche': (20, 60),
  'aswan_west_bank_sand_dunes_viewpoint': (50, 150),
};

PlaceModel applyPlaceCatalogRules(PlaceModel place) {
  final category = place.category.trim().toLowerCase();
  final idAndName = '${place.id} ${place.nameEn}'.toLowerCase();
  final hours = _expectedHours(place, category, idAndName);
  final admissionPrice = _admissionPrices[place.id];
  final descriptionEn = _catalogDescription(
    source: place.descriptionEn,
    place: place,
    neighborhood: _neighborhood(place.address, place.governorate),
    category: category,
  );
  final descriptionAr = _catalogDescription(
    source: place.descriptionAr ?? '',
    place: place,
    neighborhood: _neighborhood(
      place.addressAr ?? '',
      place.governorate,
      arabic: true,
    ),
    category: category,
    arabic: true,
  );
  final isCommercial =
      category == 'food' ||
      category == 'cafe' ||
      category == 'cafes' ||
      category == 'hotels';
  final needsPriceTier = isCommercial && place.priceLevel == PriceLevel.free;

  if (hours == null &&
      admissionPrice == null &&
      !needsPriceTier &&
      descriptionEn == place.descriptionEn &&
      descriptionAr == place.descriptionAr) {
    return place;
  }
  return place.copyWith(
    openHours: hours,
    descriptionEn: descriptionEn,
    descriptionAr: descriptionAr,
    priceLevel: admissionPrice != null
        ? (admissionPrice.$2 > 500 ? PriceLevel.expensive : PriceLevel.moderate)
        : needsPriceTier
        ? PriceLevel.moderate
        : null,
    priceNote: needsPriceTier ? r'Average cost: $$' : null,
    priceNoteAr: needsPriceTier ? r'متوسط التكلفة: $$' : null,
    priceLocalEgp: admissionPrice?.$1,
    priceForeignerEgp: admissionPrice?.$2,
  );
}

String _catalogDescription({
  required String source,
  required PlaceModel place,
  required String neighborhood,
  required String category,
  bool arabic = false,
}) {
  final description = source.trim();
  final lowerDescription = description.toLowerCase();
  const boilerplate = [
    'confirm current visitor information',
    'is a culture destination in',
    'a place to explore in',
    'a landmark of the history and culture of',
  ];
  final usableSource =
      description.isNotEmpty && !boilerplate.any(lowerDescription.contains);
  final sentences = usableSource
      ? _sentences(description).take(2).toList(growable: false)
      : const <String>[];
  final name = arabic ? place.nameAr ?? place.nameEn : place.nameEn;
  final area = neighborhood.trim().isEmpty
      ? (arabic
            ? place.governorate == 'alexandria'
                  ? 'الإسكندرية'
                  : 'القاهرة والجيزة'
            : place.governorate == 'alexandria'
            ? 'Alexandria'
            : 'Cairo and Giza')
      : neighborhood;
  final hasName = lowerDescription.contains(name.toLowerCase());
  final hasArea = lowerDescription.contains(area.toLowerCase());
  final completeSource =
      usableSource &&
      description.length >= (arabic ? 65 : 95) &&
      sentences.length >= 2 &&
      sentences.length <= 3 &&
      (place.governorate == 'luxor' || (hasName && hasArea));
  if (completeSource) return description;

  final firstSentence = sentences.isNotEmpty
      ? sentences.first
      : _descriptionOpening(name, area, category, arabic);
  final detail = _descriptionDetail(name, area, category, arabic);
  final experience = _visitorExperience(category, arabic);
  final contextualSentence = arabic
      ? 'في $area، يبرز $name بتفاصيله المعمارية وصلته بتاريخ المكان، '
            'ويتيح للزوار $experience'
      : 'In $area, $name reflects the area’s architectural and historical '
            'character, and visitors can $experience';
  final result = '$firstSentence $contextualSentence.';
  if (result.length >= (arabic ? 65 : 95)) return result;

  return '${_descriptionOpening(name, area, category, arabic)} '
      '${arabic ? detail : experience}.';
}

String _descriptionOpening(
  String name,
  String neighborhood,
  String category,
  bool arabic,
) {
  if (arabic) {
    return '$name في $neighborhood معلم يرتبط بتاريخ المنطقة ويكشف '
        'عن ملامحها المعمارية والثقافية.';
  }
  final kind = switch (category) {
    'historical' => 'historic landmark',
    'culture' => 'cultural landmark',
    'nature' => 'landscape destination',
    'food' => 'local dining address',
    'cafe' || 'cafes' => 'neighborhood cafe',
    'hotels' => 'hospitality landmark',
    'mosques' => 'place of worship',
    'churches' => 'historic place of worship',
    'shopping' => 'shopping destination',
    'atm' || 'atms' => 'convenient banking stop',
    _ => 'local destination',
  };
  return '$name in $neighborhood is a $kind shaped by the area’s '
      'history, architecture, and everyday character.';
}

String _descriptionDetail(
  String name,
  String neighborhood,
  String category,
  bool arabic,
) {
  if (arabic) {
    return 'ويمنح الزائر فرصة للتعرف إلى $name والاستمتاع بأجواء $neighborhood '
        'ومشاهدة تفاصيل المكان عن قرب';
  }
  return 'the opportunity to explore its setting and notice the local '
      'architectural details';
}

String _visitorExperience(String category, bool arabic) {
  if (arabic) {
    return switch (category) {
      'historical' ||
      'culture' => 'استكشاف معالمه ومجموعاته والتعرف إلى طبقات التاريخ المحلي',
      'nature' => 'التنزه بين المساحات المفتوحة والاستمتاع بالمشهد المحيط',
      'food' ||
      'cafe' ||
      'cafes' => 'تذوق المأكولات أو المشروبات وملاحظة الحياة اليومية في الحي',
      'hotels' => 'الإقامة والاستفادة من خدمات الضيافة في المنطقة',
      'mosques' || 'churches' =>
        'تقدير تفاصيله المعمارية مع احترام أوقات العبادة وخصوصية المكان',
      'shopping' => 'التجول بين المتاجر ومشاهدة النشاط التجاري المحلي',
      'atm' || 'atms' => 'استخدام الخدمات المصرفية وإنجاز المعاملات القريبة',
      _ => 'التعرف إلى المكان والاستمتاع بأجواء الحي المحيط',
    };
  }
  return switch (category) {
    'historical' || 'culture' =>
      'explore its features and collections while tracing the area’s history',
    'nature' =>
      'walk through its open spaces and enjoy the surrounding landscape',
    'food' || 'cafe' || 'cafes' =>
      'sample food or drinks and observe everyday life in the neighborhood',
    'hotels' => 'stay comfortably and make use of local hospitality services',
    'mosques' || 'churches' =>
      'appreciate its architecture while respecting worship and visitor customs',
    'shopping' => 'browse its shops and experience the neighborhood’s commerce',
    'atm' || 'atms' => 'access banking services and complete nearby errands',
    _ => 'explore the site and enjoy the character of its neighborhood',
  };
}

List<String> _sentences(String value) => value
    .replaceAll('St. ', 'St<abbr> ')
    .split(RegExp(r'(?<=[.!?؟])\s+'))
    .map((sentence) => sentence.replaceAll('St<abbr>', 'St.').trim())
    .where((sentence) => sentence.isNotEmpty)
    .toList(growable: false);

String _neighborhood(
  String address,
  String governorate, {
  bool arabic = false,
}) {
  final firstSegment = address.split(',').first.trim();
  if (firstSegment.isNotEmpty) return firstSegment;
  return arabic
      ? governorate == 'alexandria'
            ? 'الإسكندرية'
            : 'القاهرة والجيزة'
      : governorate == 'alexandria'
      ? 'Alexandria'
      : 'Cairo and Giza';
}

String? _expectedHours(PlaceModel place, String category, String idAndName) {
  if (place.id == 'alex_el_max_venice_canal') return '24 hours';
  if (place.id == 'cairo_helwan_japanese_garden') {
    return '08:00 AM - 09:00 PM';
  }
  if (place.id == 'luxor_esna_khnum_temple') {
    return '07:00 AM - 05:00 PM';
  }
  if (place.id.startsWith('aswan_')) {
    return switch (category) {
      'historical' || 'culture' || 'nature' => place.openHours,
      'mosques' => '04:00 AM - 10:00 PM',
      'churches' => '08:00 AM - 08:00 PM',
      'shopping' => '10:00 AM - 11:00 PM',
      'food' || 'cafe' || 'cafes' => '10:00 AM - 01:00 AM',
      'hotels' || 'atms' || 'atm' => '24 hours',
      _ => null,
    };
  }
  if (place.governorate == 'luxor') {
    return switch (category) {
      'historical' => switch (place.id) {
        'luxor_karnak_temple' => '06:00 AM - 05:30 PM',
        'luxor_temple' || 'luxor_avenue_of_sphinxes' => '06:00 AM - 09:00 PM',
        'luxor_colossi_of_memnon' => '24 hours',
        _ => '06:00 AM - 05:00 PM',
      },
      'culture' =>
        place.id == 'luxor_howard_carter_house'
            ? '08:00 AM - 05:00 PM'
            : '09:00 AM - 08:00 PM',
      'nature' => switch (place.id) {
        'luxor_nile_corniche' => '24 hours',
        'luxor_west_bank_balloon_field' => '04:30 AM - 08:30 AM',
        'luxor_banana_island' ||
        'luxor_crocodile_island_park' => '09:00 AM - 05:00 PM',
        'luxor_felucca_sail_dock' => '06:00 AM - 10:00 PM',
        _ => null,
      },
      'mosques' => '04:00 AM - 10:00 PM',
      'churches' => '08:00 AM - 08:00 PM',
      'shopping' => '10:00 AM - 11:00 PM',
      'food' || 'cafes' => '10:00 AM - 01:00 AM',
      'hotels' || 'atms' || 'atm' => '24 hours',
      _ => null,
    };
  }
  if (category == 'atms' ||
      category == 'atm' ||
      category == 'hotels' ||
      _isOpenPublicSpace(idAndName)) {
    return '24 hours';
  }
  if (category == 'mosques') return '04:00 AM - 10:00 PM';
  if (category == 'churches') return '08:00 AM - 08:00 PM';
  if (category == 'shopping') {
    if (place.id == 'azbakeya_book_market_cairo' ||
        idAndName.contains('bazaar') ||
        idAndName.contains('souq') ||
        idAndName.contains('book market')) {
      return '10:00 AM - 10:00 PM';
    }
    return '10:00 AM - 12:00 AM';
  }
  if (category == 'food' || category == 'cafe' || category == 'cafes') {
    if (_isSpecialRestaurant(place.id)) return '09:00 AM - 05:00 PM';
    return '10:00 AM - 01:00 AM';
  }
  if (category == 'nature') {
    if (place.id == 'zed_park_sheikh_zayed') {
      return '01:00 PM - 11:00 PM';
    }
    if (place.id == 'orman_botanical_garden_giza' ||
        place.id == 'giza_zoo_garden') {
      return '09:00 AM - 05:00 PM';
    }
    return '08:00 AM - 10:00 PM';
  }
  return null;
}

bool _isSpecialRestaurant(String id) =>
    id == 'kebdet_el_prince_imbaba' ||
    id == 'kebdet_el_prince_korba' ||
    id == 'gad' ||
    id == 'abou_shakra_mohandessin' ||
    id == 'nine_pyramid_lounge_giza';

bool _isOpenPublicSpace(String idAndName) =>
    idAndName.contains('street') ||
    idAndName.contains('square') ||
    idAndName.contains('bridge') ||
    idAndName.contains('corniche') ||
    idAndName.contains('promenade') ||
    idAndName.contains('pier') ||
    idAndName.contains('walk');
