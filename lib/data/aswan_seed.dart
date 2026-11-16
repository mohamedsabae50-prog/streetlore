import 'models/itinerary_model.dart';
import 'models/place_model.dart';
import 'aswan_image_urls.dart';

typedef _AswanPlaceSpec = ({
  String id,
  String nameEn,
  String nameAr,
  String category,
  double lat,
  double lng,
  String areaEn,
  String areaAr,
  String openHours,
  int? priceLocalEgp,
  int? priceForeignerEgp,
  String storyEn,
  String storyAr,
});

String _aswanCategoryAr(String category) => switch (category) {
  'Historical' => 'تاريخي',
  'Culture' => 'ثقافة',
  'Nature' => 'طبيعة',
  'Mosques' => 'مساجد',
  'Churches' => 'كنائس',
  'Food' => 'مطاعم',
  'Cafes' => 'مقاهٍ',
  'Shopping' => 'تسوّق',
  'Hotels' => 'فنادق',
  'ATMs' => 'ماكينات صراف آلي',
  _ => category,
};

PriceLevel _aswanPriceLevel(_AswanPlaceSpec spec) {
  if (spec.category == 'Hotels' ||
      spec.id == 'aswan_1902_restaurant_old_cataract' ||
      spec.id == 'aswan_old_cataract_terrace_cafe') {
    return PriceLevel.expensive;
  }
  if (spec.category == 'Food' ||
      spec.category == 'Cafes' ||
      spec.category == 'Shopping') {
    return PriceLevel.moderate;
  }
  if (spec.category == 'ATMs' ||
      spec.category == 'Mosques' ||
      spec.category == 'Churches' ||
      (spec.priceLocalEgp ?? 0) == 0) {
    return PriceLevel.free;
  }
  return (spec.priceForeignerEgp ?? 0) > 500
      ? PriceLevel.expensive
      : PriceLevel.moderate;
}

String _aswanVisitSentence(_AswanPlaceSpec spec) => switch (spec.category) {
  'Historical' || 'Culture' =>
    'Allow time to read the site\'s inscriptions and architectural details; its ${spec.areaEn} setting connects the monument to the wider history of southern Egypt',
  'Nature' =>
    'The Nile-side setting around ${spec.areaEn} offers a slower counterpoint to temple visits and a close view of Aswan life along the river',
  'Food' =>
    'The menu and setting make ${spec.areaEn} a useful place to pause; confirm reservations and service details on busy evenings',
  'Cafes' =>
    'Settle in at ${spec.areaEn} for tea, coffee, or a light break, and check current service details before making a special trip',
  'Shopping' =>
    'Browse ${spec.areaEn} at an unhurried pace, compare materials and workmanship, and agree on prices before purchasing',
  'Hotels' =>
    'Its ${spec.areaEn} location suits travelers planning Nile views and day trips; room rates and facilities vary by season and room type',
  'Mosques' || 'Churches' =>
    'Visitors are welcome to appreciate ${spec.areaEn} respectfully, observing modest dress and avoiding disruption during worship',
  'ATMs' =>
    'Check cash availability and foreign-card fees with your bank, and keep another payment option for travel beyond central Aswan',
  _ =>
    'Take time to explore ${spec.areaEn} and notice how the site fits the river landscape and the communities around it',
};

String _aswanVisitSentenceAr(_AswanPlaceSpec spec) => switch (spec.category) {
  'Historical' || 'Culture' =>
    'تأمل النقوش والتفاصيل المعمارية على مهل؛ ويربط موقع ${spec.areaAr} المعلم بتاريخ جنوب مصر الأوسع',
  'Nature' =>
    'تمنح أجواء النيل في ${spec.areaAr} استراحة هادئة بين زيارات المعابد وتكشف جانباً من الحياة اليومية في أسوان',
  'Food' =>
    'يجعل الطعام وموقع ${spec.areaAr} المكان مناسباً للاستراحة؛ ويُستحسن التحقق من الحجز والخدمة في الأمسيات المزدحمة',
  'Cafes' =>
    'استمتع بالشاي أو القهوة في ${spec.areaAr}، وتحقق من مواعيد الخدمة قبل تخصيص رحلة للمكان',
  'Shopping' =>
    'تجول في ${spec.areaAr} بهدوء، وقارن الخامات وجودة الصناعة واتفق على السعر قبل الشراء',
  'Hotels' =>
    'يناسب موقعه في ${spec.areaAr} الباحثين عن إطلالة النيل والرحلات اليومية؛ وتتغير الأسعار والخدمات حسب الموسم ونوع الغرفة',
  'Mosques' || 'Churches' =>
    'يمكن للزوار تقدير ${spec.areaAr} مع مراعاة الاحتشام واحترام خصوصية أوقات الصلاة والعبادة',
  'ATMs' =>
    'تحقق من توافر النقد ورسوم البطاقات الأجنبية لدى مصرفك، واحتفظ بوسيلة دفع أخرى عند مغادرة وسط أسوان',
  _ =>
    'خصص وقتاً لاستكشاف ${spec.areaAr} وملاحظة صلة المكان بمشهد النيل والمجتمعات المحيطة',
};

PlaceModel _buildAswanPlace(_AswanPlaceSpec spec) {
  final imageUrl = aswanImageUrls[spec.id]!;
  final hasAdmission =
      spec.priceLocalEgp != null && spec.priceForeignerEgp != null;
  final priceNote = hasAdmission
      ? 'Egyptian ticket EGP ${spec.priceLocalEgp}; foreign visitor ticket EGP ${spec.priceForeignerEgp}.'
      : switch (spec.category) {
          'Hotels' => 'Room rates vary by date and room type.',
          'Food' || 'Cafes' => 'Meal and drink prices vary by order.',
          'Shopping' => 'Prices vary by craft, material, and item.',
          'Mosques' || 'Churches' => 'Worship access has no admission charge.',
          'ATMs' => '',
          _ => 'Public access; no admission ticket is required.',
        };
  final priceNoteAr = hasAdmission
      ? 'تذكرة المصريين ${spec.priceLocalEgp} جنيهاً؛ وتذكرة الزائر الأجنبي ${spec.priceForeignerEgp} جنيهاً.'
      : switch (spec.category) {
          'Hotels' => 'تختلف أسعار الغرف حسب الموعد ونوع الغرفة.',
          'Food' || 'Cafes' => 'تختلف أسعار الطعام والمشروبات حسب الطلب.',
          'Shopping' => 'تختلف الأسعار باختلاف الحرفة والخامة والقطعة.',
          'Mosques' || 'Churches' => 'لا تُفرض رسوم دخول على أماكن العبادة.',
          'ATMs' => '',
          _ => 'المكان مفتوح للزيارة العامة ولا يحتاج إلى تذكرة دخول.',
        };

  return PlaceModel(
    id: spec.id,
    nameEn: spec.nameEn,
    nameAr: spec.nameAr,
    descriptionEn:
        '${spec.nameEn}: ${spec.storyEn}. ${_aswanVisitSentence(spec)}.',
    descriptionAr:
        '${spec.nameAr}: ${spec.storyAr}. ${_aswanVisitSentenceAr(spec)}.',
    imageUrl: imageUrl,
    imageUrls: [imageUrl],
    rating: 4.5,
    category: spec.category,
    categoryAr: _aswanCategoryAr(spec.category),
    lat: spec.lat,
    lng: spec.lng,
    address: '${spec.areaEn}, Aswan Governorate, Egypt',
    addressAr: '${spec.areaAr}، محافظة أسوان، مصر',
    governorate: 'luxor',
    openHours: spec.openHours,
    reviewCount: 350,
    priceLevel: _aswanPriceLevel(spec),
    priceNote: priceNote,
    priceNoteAr: priceNoteAr,
    priceLocalEgp: spec.priceLocalEgp,
    priceForeignerEgp: spec.priceForeignerEgp,
    isIndoor:
        spec.category == 'Culture' ||
        spec.category == 'Hotels' ||
        spec.category == 'Food' ||
        spec.category == 'Cafes',
  );
}

final List<PlaceModel> aswanSeedPlaces = List<PlaceModel>.unmodifiable([
  _buildAswanPlace((
    id: 'aswan_philae_temple',
    nameEn: 'Philae Temple (Temple of Isis on Agilkia Island)',
    nameAr: 'معبد فيلة بجزيرة أجيليكا',
    category: 'Historical',
    lat: 24.0254,
    lng: 32.8842,
    areaEn: 'Agilkia Island',
    areaAr: 'جزيرة أجيليكا',
    openHours: '07:00 AM - 04:00 PM',
    priceLocalEgp: 80,
    priceForeignerEgp: 550,
    storyEn:
        'the Temple of Isis was relocated stone by stone to Agilkia Island after the High Dam threatened the original Philae sanctuary',
    storyAr:
        'نُقل معبد إيزيس حجراً حجراً إلى جزيرة أجيليكا بعدما هدد السد العالي معبد فيلة الأصلي بالغمر',
  )),
  _buildAswanPlace((
    id: 'aswan_abu_simbel_great_temple',
    nameEn: 'Great Temple of Ramesses II at Abu Simbel',
    nameAr: 'معبد أبو سمبل الكبير',
    category: 'Historical',
    lat: 22.3372,
    lng: 31.6258,
    areaEn: 'Abu Simbel, Lake Nasser',
    areaAr: 'أبو سمبل، بحيرة ناصر',
    openHours: '06:00 AM - 05:00 PM',
    priceLocalEgp: 100,
    priceForeignerEgp: 750,
    storyEn:
        'four colossal seated images of Ramesses II guard a rock-cut sanctuary whose alignment and carved halls proclaim royal power in Nubia',
    storyAr:
        'تحرس أربع صور ضخمة جالسة لرمسيس الثاني حرماً منحوتاً في الصخر، وتعلن محاوره وقاعاته المنقوشة سلطة الملك في النوبة',
  )),
  _buildAswanPlace((
    id: 'aswan_abu_simbel_nefertari_temple',
    nameEn: 'Temple of Hathor & Nefertari at Abu Simbel',
    nameAr: 'معبد نفرتاري بأبو سمبل',
    category: 'Historical',
    lat: 22.3381,
    lng: 31.6267,
    areaEn: 'Abu Simbel, Lake Nasser',
    areaAr: 'أبو سمبل، بحيرة ناصر',
    openHours: '06:00 AM - 05:00 PM',
    priceLocalEgp: 100,
    priceForeignerEgp: 750,
    storyEn:
        'the smaller rock-cut temple honors Hathor and Queen Nefertari, with royal statues carved at comparable scale along its facade',
    storyAr:
        'يكرم المعبد الصغير المنحوت في الصخر حتحور والملكة نفرتاري، وتظهر على واجهته تماثيل ملكية متقاربة في أحجامها',
  )),
  _buildAswanPlace((
    id: 'aswan_nubian_museum',
    nameEn: 'Nubian Museum',
    nameAr: 'متحف النوبة بأسوان',
    category: 'Culture',
    lat: 24.0795,
    lng: 32.8891,
    areaEn: 'Nubian Museum Road',
    areaAr: 'طريق متحف النوبة',
    openHours: '09:00 AM - 09:00 PM',
    priceLocalEgp: 40,
    priceForeignerEgp: 400,
    storyEn:
        'galleries trace Nubian communities, archaeology, and everyday traditions, including objects rescued during the UNESCO campaign around Lake Nasser',
    storyAr:
        'تعرض القاعات مجتمعات النوبة وآثارها وتقاليد الحياة اليومية، ومنها مقتنيات أنقذت خلال حملة اليونسكو حول بحيرة ناصر',
  )),
  _buildAswanPlace((
    id: 'aswan_unfinished_obelisk',
    nameEn: 'Unfinished Obelisk Northern Quarry',
    nameAr: 'المسلة الناقصة بأسوان',
    category: 'Historical',
    lat: 24.0769,
    lng: 32.8955,
    areaEn: 'Northern Granite Quarry',
    areaAr: 'المحجر الشمالي للجرانيت',
    openHours: '07:00 AM - 04:00 PM',
    priceLocalEgp: 40,
    priceForeignerEgp: 220,
    storyEn:
        'this enormous granite shaft remains attached to its bedrock, preserving tool marks and a rare view of ancient quarrying methods',
    storyAr:
        'ما زال هذا العمود الضخم من الجرانيت متصلاً بصخره الأم، محتفظاً بآثار الأدوات وكاشفاً أساليب المحاجر القديمة',
  )),
  _buildAswanPlace((
    id: 'aswan_high_dam_memorial',
    nameEn: 'Aswan High Dam & Lotus Monument',
    nameAr: 'السد العالي ورمز الصداقة',
    category: 'Culture',
    lat: 23.9700,
    lng: 32.8772,
    areaEn: 'High Dam and Soviet-Egyptian Friendship Monument',
    areaAr: 'السد العالي ونصب الصداقة المصرية السوفيتية',
    openHours: '07:00 AM - 05:00 PM',
    priceLocalEgp: 30,
    priceForeignerEgp: 200,
    storyEn:
        'the twentieth-century dam reshaped Nile storage and power generation, while the nearby lotus monument commemorates Egyptian-Soviet cooperation',
    storyAr:
        'غيّر السد في القرن العشرين تخزين مياه النيل وتوليد الكهرباء، ويخلد نصب اللوتس القريب التعاون المصري السوفيتي',
  )),
  _buildAswanPlace((
    id: 'aswan_old_low_dam',
    nameEn: 'Old Aswan Dam (First Cataract Dam)',
    nameAr: 'خزان أسوان القديم',
    category: 'Historical',
    lat: 24.0345,
    lng: 32.8705,
    areaEn: 'Old Aswan Dam',
    areaAr: 'خزان أسوان القديم',
    openHours: '07:00 AM - 06:00 PM',
    priceLocalEgp: 20,
    priceForeignerEgp: 100,
    storyEn:
        'completed in 1902 and later heightened, the masonry dam marks an earlier chapter in Nile regulation before the High Dam',
    storyAr:
        'اكتمل الخزان عام ١٩٠٢ ثم رُفع لاحقاً، ويمثل مرحلة مبكرة من تنظيم مياه النيل قبل إنشاء السد العالي',
  )),
  _buildAswanPlace((
    id: 'aswan_kalabsha_temple',
    nameEn: 'Temple of Kalabsha (New Kalabsha Island)',
    nameAr: 'معبد كلابشة الجديد',
    category: 'Historical',
    lat: 23.9614,
    lng: 32.8669,
    areaEn: 'New Kalabsha Island',
    areaAr: 'جزيرة كلابشة الجديدة',
    openHours: '07:00 AM - 04:00 PM',
    priceLocalEgp: 40,
    priceForeignerEgp: 300,
    storyEn:
        'dedicated chiefly to Mandulis, the Nubian temple was dismantled and rebuilt on higher ground to save it from Lake Nasser',
    storyAr:
        'كُرس المعبد أساساً للإله النوبي ماندوليس، وفُكك وأعيد بناؤه في موقع مرتفع لإنقاذه من مياه بحيرة ناصر',
  )),
  _buildAswanPlace((
    id: 'aswan_beit_el_wali_temple',
    nameEn: 'Rock Temple of Beit el-Wali',
    nameAr: 'معبد بيت الوالي',
    category: 'Historical',
    lat: 23.9622,
    lng: 32.8662,
    areaEn: 'New Kalabsha Island',
    areaAr: 'جزيرة كلابشة الجديدة',
    openHours: '07:00 AM - 04:00 PM',
    priceLocalEgp: 40,
    priceForeignerEgp: 300,
    storyEn:
        'Ramesses II dedicated this compact sanctuary to Amun-Re, Khnum, and Anuket; its reliefs depict campaigns and offerings in Nubia',
    storyAr:
        'كرس رمسيس الثاني هذا المعبد الصخري لآمون رع وخنوم وعنقت، وتصور نقوشه الحملات والقرابين في النوبة',
  )),
  _buildAswanPlace((
    id: 'aswan_kiosk_of_qertassi',
    nameEn: 'Kiosk of Qertassi at New Kalabsha',
    nameAr: 'كشك قرطاسي',
    category: 'Historical',
    lat: 23.9608,
    lng: 32.8675,
    areaEn: 'New Kalabsha Island',
    areaAr: 'جزيرة كلابشة الجديدة',
    openHours: '07:00 AM - 04:00 PM',
    priceLocalEgp: 40,
    priceForeignerEgp: 300,
    storyEn:
        'the graceful Roman-period kiosk combines columns and carved capitals, and was moved from the flooded region of ancient Qertassi',
    storyAr:
        'يجمع الكشك الأنيق من العصر الروماني بين الأعمدة والتيجان المنحوتة، ونُقل من منطقة قرطاسي القديمة المهددة بالغمر',
  )),
  _buildAswanPlace((
    id: 'aswan_qubbet_el_hawa_tombs',
    nameEn: 'Qubbet el-Hawa (Tombs of the Nobles)',
    nameAr: 'مقابر النبلاء بقبة الهوا',
    category: 'Historical',
    lat: 24.1018,
    lng: 32.8893,
    areaEn: 'West Bank, Qubbet el-Hawa',
    areaAr: 'البر الغربي، قبة الهوا',
    openHours: '07:00 AM - 04:00 PM',
    priceLocalEgp: 40,
    priceForeignerEgp: 200,
    storyEn:
        'rock-cut tombs above the west bank preserve biographies and scenes commissioned by provincial governors and officials of ancient Elephantine',
    storyAr:
        'تحفظ المقابر المنحوتة فوق البر الغربي سيراً ومشاهد كلف بها حكام وأعيان من جزيرة إلفنتين القديمة',
  )),
  _buildAswanPlace((
    id: 'aswan_st_simeon_monastery',
    nameEn: 'Monastery of St. Simeon (Deir Anba Hadra)',
    nameAr: 'دير الأنبا سمعان',
    category: 'Historical',
    lat: 24.0956,
    lng: 32.8758,
    areaEn: 'West Bank Desert Plateau',
    areaAr: 'هضبة الصحراء بالبر الغربي',
    openHours: '07:00 AM - 04:00 PM',
    priceLocalEgp: 40,
    priceForeignerEgp: 160,
    storyEn:
        'the fortified monastery preserves a church, monks’ cells, and traces of a community that flourished above the Nile from late antiquity',
    storyAr:
        'يضم الدير المحصن كنيسة وقلالي رهبان وآثار مجتمع ازدهر فوق النيل منذ أواخر العصور القديمة',
  )),
  _buildAswanPlace((
    id: 'aswan_elephantine_museum_ruins',
    nameEn: 'Elephantine Island Museum & Temple of Khnum',
    nameAr: 'متحف ومعبد خنوم بجزيرة إلفنتين',
    category: 'Culture',
    lat: 24.0850,
    lng: 32.8865,
    areaEn: 'Elephantine Island',
    areaAr: 'جزيرة إلفنتين',
    openHours: '07:00 AM - 05:00 PM',
    priceLocalEgp: 40,
    priceForeignerEgp: 200,
    storyEn:
        'island excavations reveal successive settlements and sanctuaries, including the cult center of Khnum at Egypt’s historic southern frontier',
    storyAr:
        'تكشف حفائر الجزيرة عن مستوطنات ومعابد متعاقبة، ومنها مركز عبادة خنوم عند الحدود الجنوبية التاريخية لمصر',
  )),
  _buildAswanPlace((
    id: 'aswan_elephantine_nilometer',
    nameEn: 'Ancient Nilometer of Elephantine Island',
    nameAr: 'مقياس النيل بجزيرة إلفنتين',
    category: 'Historical',
    lat: 24.0842,
    lng: 32.8872,
    areaEn: 'Elephantine Island',
    areaAr: 'جزيرة إلفنتين',
    openHours: '07:00 AM - 05:00 PM',
    priceLocalEgp: 40,
    priceForeignerEgp: 200,
    storyEn:
        'a calibrated stairway descends toward the river, where officials once recorded Nile levels to anticipate flood conditions and assess taxation',
    storyAr:
        'يهبط درج مدرج نحو النهر، حيث سجل المسؤولون قديماً منسوب النيل لتقدير الفيضان وتحديد الضرائب',
  )),
  _buildAswanPlace((
    id: 'aswan_sehel_island_famine_stele',
    nameEn: 'Sehel Island & Famine Stele Inscriptions',
    nameAr: 'جزيرة سهيل ولوحة المجاعة',
    category: 'Historical',
    lat: 24.0580,
    lng: 32.8750,
    areaEn: 'Sehel Island, First Cataract',
    areaAr: 'جزيرة سهيل، الشلال الأول',
    openHours: '07:00 AM - 05:00 PM',
    priceLocalEgp: 40,
    priceForeignerEgp: 160,
    storyEn:
        'granite boulders carry hundreds of votive inscriptions, including the famous Famine Stele that recounts a legendary seven-year drought',
    storyAr:
        'تحمل صخور الجرانيت مئات النقوش النذرية، ومنها لوحة المجاعة الشهيرة التي تروي أسطورة جفاف دام سبع سنوات',
  )),
  _buildAswanPlace((
    id: 'aswan_aga_khan_mausoleum',
    nameEn: 'Mausoleum of the Aga Khan (Exterior Viewpoint)',
    nameAr: 'ضريح الآغا خان بالبر الغربي',
    category: 'Historical',
    lat: 24.0884,
    lng: 32.8788,
    areaEn: 'West Bank, above the Nile',
    areaAr: 'البر الغربي، فوق النيل',
    openHours: '08:00 AM - 05:00 PM',
    priceLocalEgp: 30,
    priceForeignerEgp: 100,
    storyEn:
        'the pale-stone mausoleum overlooks the Nile from a desert rise and is associated with Aga Khan III, who chose Aswan for its winter climate',
    storyAr:
        'يشرف الضريح الحجري الفاتح على النيل من ربوة صحراوية، ويرتبط بالآغا خان الثالث الذي اختار أسوان لمناخها الشتوي',
  )),
  _buildAswanPlace((
    id: 'aswan_fatimid_cemetery',
    nameEn: 'Fatimid Cemetery Domes of Aswan',
    nameAr: 'القباب الفاطمية بأسوان',
    category: 'Historical',
    lat: 24.0785,
    lng: 32.8935,
    areaEn: 'Historic Aswan Cemetery',
    areaAr: 'جبانة أسوان التاريخية',
    openHours: '08:00 AM - 05:00 PM',
    priceLocalEgp: 30,
    priceForeignerEgp: 100,
    storyEn:
        'a field of mud-brick domed tombs reflects medieval funerary architecture and the long continuity of Aswan’s Muslim communities',
    storyAr:
        'تعكس مجموعة القباب الجنائزية المبنية بالطوب اللبن عمارة العصور الوسطى واستمرار مجتمعات أسوان المسلمة عبر القرون',
  )),
  _buildAswanPlace((
    id: 'aswan_kom_ombo_temple',
    nameEn: 'Temple of Kom Ombo (Sobek & Haroeris)',
    nameAr: 'معبد كوم أمبو',
    category: 'Historical',
    lat: 24.4520,
    lng: 32.9283,
    areaEn: 'Kom Ombo Nile Terrace',
    areaAr: 'مصطبة كوم أمبو على النيل',
    openHours: '07:00 AM - 08:00 PM',
    priceLocalEgp: 60,
    priceForeignerEgp: 450,
    storyEn:
        'the unusual double temple gives balanced precincts to crocodile god Sobek and falcon god Haroeris, with reliefs of ritual and healing',
    storyAr:
        'يخصص المعبد المزدوج حرمين متوازنين للإله التمساح سوبك والإله الصقر حور وير، وتزينه مناظر الطقوس والشفاء',
  )),
  _buildAswanPlace((
    id: 'aswan_crocodile_museum_kom_ombo',
    nameEn: 'Crocodile Museum at Kom Ombo',
    nameAr: 'متحف التماسيح بكوم أمبو',
    category: 'Culture',
    lat: 24.4515,
    lng: 32.9290,
    areaEn: 'Kom Ombo Temple Precinct',
    areaAr: 'حرم معبد كوم أمبو',
    openHours: '07:00 AM - 08:00 PM',
    priceLocalEgp: 40,
    priceForeignerEgp: 200,
    storyEn:
        'mummified crocodiles and related objects explain the local cult of Sobek and the sacred animals once kept near the twin sanctuary',
    storyAr:
        'تشرح التماسيح المحنطة ومقتنياتها عبادة سوبك المحلية والحيوانات المقدسة التي عاشت قرب المعبد المزدوج',
  )),
  _buildAswanPlace((
    id: 'aswan_edfu_horus_temple',
    nameEn: 'Temple of Horus at Edfu',
    nameAr: 'معبد حورس بإدفو',
    category: 'Historical',
    lat: 24.9780,
    lng: 32.8733,
    areaEn: 'Edfu Temple Precinct',
    areaAr: 'حرم معبد إدفو',
    openHours: '07:00 AM - 05:00 PM',
    priceLocalEgp: 80,
    priceForeignerEgp: 550,
    storyEn:
        'one of Egypt’s best-preserved temples follows a formal route from monumental pylon to sanctuary and records the mythic contest of Horus and Seth',
    storyAr:
        'يعد من أفضل معابد مصر حفظاً، ويمتد محوره من بوابة ضخمة إلى قدس الأقداس ويسجل أسطورة صراع حورس وست',
  )),
  _buildAswanPlace((
    id: 'aswan_tell_edfu_archaeological_site',
    nameEn: 'Tell Edfu Ancient Settlement Mound',
    nameAr: 'تل إدفو الأثري',
    category: 'Historical',
    lat: 24.9772,
    lng: 32.8718,
    areaEn: 'Edfu Archaeological Zone',
    areaAr: 'المنطقة الأثرية بإدفو',
    openHours: '07:00 AM - 04:00 PM',
    priceLocalEgp: 40,
    priceForeignerEgp: 150,
    storyEn:
        'layers of settlement beside the temple preserve evidence of Edfu’s changing urban life from ancient periods into later eras',
    storyAr:
        'تحفظ طبقات الاستيطان بجوار المعبد شواهد على تغير الحياة الحضرية في إدفو من العصور القديمة إلى فترات لاحقة',
  )),
  _buildAswanPlace((
    id: 'aswan_nile_museum',
    nameEn: 'Nile Museum (Grand Irrigation Museum)',
    nameAr: 'متحف النيل الوثائقي بأسوان',
    category: 'Culture',
    lat: 24.0410,
    lng: 32.8775,
    areaEn: 'Nile Museum Road',
    areaAr: 'طريق متحف النيل',
    openHours: '09:00 AM - 05:00 PM',
    priceLocalEgp: 35,
    priceForeignerEgp: 150,
    storyEn:
        'exhibits and documents explore the Nile’s geography, irrigation history, and regional cooperation across the river basin',
    storyAr:
        'تستعرض المعروضات والوثائق جغرافيا النيل وتاريخ الري والتعاون الإقليمي بين بلدان حوض النهر',
  )),
  _buildAswanPlace((
    id: 'aswan_cultural_palace_theater',
    nameEn: 'Aswan Cultural Palace & Folklore Stage',
    nameAr: 'قصر ثقافة أسوان',
    category: 'Culture',
    lat: 24.0898,
    lng: 32.8982,
    areaEn: 'Aswan City Center',
    areaAr: 'وسط مدينة أسوان',
    openHours: '10:00 AM - 09:00 PM',
    priceLocalEgp: 30,
    priceForeignerEgp: 120,
    storyEn:
        'the cultural venue hosts performances and programs that bring Nubian music, folk dance, and local arts to public audiences',
    storyAr:
        'يستضيف المركز الثقافي عروضاً وبرامج تقدم الموسيقى النوبية والرقص الشعبي والفنون المحلية للجمهور',
  )),
  _buildAswanPlace((
    id: 'aswan_international_sculpture_park',
    nameEn: 'Aswan Open-Air Granite Sculpture Symposium Park',
    nameAr: 'سمبوزيوم أسوان الدولي للنحت',
    category: 'Culture',
    lat: 24.0755,
    lng: 32.8895,
    areaEn: 'Granite Sculpture Park',
    areaAr: 'حديقة منحوتات الجرانيت',
    openHours: '08:00 AM - 06:00 PM',
    priceLocalEgp: 30,
    priceForeignerEgp: 120,
    storyEn:
        'works created during the international sculpture symposium place contemporary forms in conversation with Aswan’s celebrated granite landscape',
    storyAr:
        'تتحاور الأعمال المنجزة في ملتقى النحت الدولي مع مشهد الجرانيت الذي تشتهر به أسوان عبر أشكال فنية معاصرة',
  )),
  _buildAswanPlace((
    id: 'aswan_botanical_garden_kitchener',
    nameEn: "Aswan Botanical Garden (Kitchener's Island)",
    nameAr: 'الحديقة النباتية بأسوان',
    category: 'Nature',
    lat: 24.0933,
    lng: 32.8872,
    areaEn: "Kitchener's Island",
    areaAr: 'جزيرة النباتات',
    openHours: '08:00 AM - 05:00 PM',
    priceLocalEgp: 30,
    priceForeignerEgp: 160,
    storyEn:
        'the compact island garden gathers tropical and subtropical plants along shaded paths between the East and West Banks',
    storyAr:
        'تجمع حديقة الجزيرة الصغيرة نباتات استوائية وشبه استوائية على ممرات ظليلة بين البرين الشرقي والغربي',
  )),
  _buildAswanPlace((
    id: 'aswan_gharb_soheil_nubian_village',
    nameEn: 'Gharb Soheil Nubian Village',
    nameAr: 'القرية النوبية بغرب سهيل',
    category: 'Nature',
    lat: 24.0585,
    lng: 32.8695,
    areaEn: 'Gharb Soheil, West Bank',
    areaAr: 'غرب سهيل، البر الغربي',
    openHours: '08:00 AM - 10:00 PM',
    priceLocalEgp: 50,
    priceForeignerEgp: 150,
    storyEn:
        'painted Nubian homes, river landings, and family-run guesthouses frame a living village rather than a museum display',
    storyAr:
        'تؤطر البيوت النوبية الملونة ومراسي النهر وبيوت الضيافة العائلية قرية حية لا معرضاً متحفياً',
  )),
  _buildAswanPlace((
    id: 'aswan_saluga_ghazal_protectorate',
    nameEn: 'Saluga and Ghazal First Cataract Islands Protectorate',
    nameAr: 'محمية سالوجا وغزال',
    category: 'Nature',
    lat: 24.0695,
    lng: 32.8810,
    areaEn: 'First Cataract Islands',
    areaAr: 'جزر الشلال الأول',
    openHours: '08:00 AM - 04:30 PM',
    priceLocalEgp: 30,
    priceForeignerEgp: 150,
    storyEn:
        'the small protected islands shelter riverine plants and birds among the granite channels of the First Cataract',
    storyAr:
        'تحمي الجزر الصغيرة نباتات النهر وطيوره بين قنوات الجرانيت في منطقة الشلال الأول',
  )),
  _buildAswanPlace((
    id: 'aswan_heissa_nubian_island',
    nameEn: 'Heissa Island Nubian Eco-Camp',
    nameAr: 'جزيرة هيسا النوبية',
    category: 'Nature',
    lat: 24.0185,
    lng: 32.8795,
    areaEn: 'Heissa Island',
    areaAr: 'جزيرة هيسا',
    openHours: '08:00 AM - 09:00 PM',
    priceLocalEgp: 50,
    priceForeignerEgp: 150,
    storyEn:
        'the island’s Nubian community and simple river lodges offer a quieter base for walking, boat trips, and sunset over Lake Nasser',
    storyAr:
        'يوفر مجتمع الجزيرة النوبي ونُزلها النهرية البسيطة مكاناً هادئاً للمشي ورحلات القوارب ومشاهدة الغروب فوق بحيرة ناصر',
  )),
  _buildAswanPlace((
    id: 'aswan_nile_corniche_promenade',
    nameEn: 'Aswan Nile Corniche Promenade',
    nameAr: 'ممشى كورنيش النيل بأسوان',
    category: 'Nature',
    lat: 24.0895,
    lng: 32.8985,
    areaEn: 'Aswan Nile Corniche',
    areaAr: 'كورنيش النيل بأسوان',
    openHours: '24 hours',
    priceLocalEgp: 0,
    priceForeignerEgp: 0,
    storyEn:
        'the public riverfront follows boat landings and cafes, with views toward Elephantine Island and the West Bank dunes',
    storyAr:
        'يمتد الممشى العام بمحاذاة مراسي القوارب والمقاهي، ويطل على جزيرة إلفنتين وكثبان البر الغربي',
  )),
  _buildAswanPlace((
    id: 'aswan_faryal_garden_corniche',
    nameEn: 'Faryal Historic Nile View Garden',
    nameAr: 'حديقة فريال التاريخية بأسوان',
    category: 'Nature',
    lat: 24.0802,
    lng: 32.8882,
    areaEn: 'Faryal Garden, East Bank',
    areaAr: 'حديقة فريال، البر الشرقي',
    openHours: '08:00 AM - 10:00 PM',
    priceLocalEgp: 20,
    priceForeignerEgp: 60,
    storyEn:
        'terraced lawns and mature shade trees look across the river toward the Aga Khan Mausoleum and desert slopes',
    storyAr:
        'تطل المساحات المدرجة وأشجار الظل العتيقة عبر النهر نحو ضريح الآغا خان ومنحدرات الصحراء',
  )),
  _buildAswanPlace((
    id: 'aswan_west_bank_sand_dunes_viewpoint',
    nameEn: 'West Bank Golden Dunes & Cataract Felucca Pier',
    nameAr: 'كثبان البر الغربي ومرسى الفلوكة',
    category: 'Nature',
    lat: 24.0890,
    lng: 32.8805,
    areaEn: 'West Bank Ferry and Felucca Landing',
    areaAr: 'مرسى العبّارات والفلوكة بالبر الغربي',
    openHours: '07:00 AM - 08:00 PM',
    priceLocalEgp: 50,
    priceForeignerEgp: 150,
    storyEn:
        'a sandy river landing opens onto golden slopes, felucca crossings, and broad views of the First Cataract at sunset',
    storyAr:
        'يفتح المرسى الرملي على منحدرات ذهبية وعبور الفلوكة ومشهد واسع للشلال الأول عند الغروب',
  )),
  _buildAswanPlace((
    id: 'aswan_el_tabia_mosque',
    nameEn: 'El-Tabia Mosque',
    nameAr: 'مسجد الطابية بأسوان',
    category: 'Mosques',
    lat: 24.0882,
    lng: 32.9025,
    areaEn: 'El-Tabia, Aswan City',
    areaAr: 'الطابية، مدينة أسوان',
    openHours: '04:00 AM - 10:00 PM',
    priceLocalEgp: 0,
    priceForeignerEgp: 0,
    storyEn:
        'the prominent mosque stands on a landscaped rise and is known for its minarets, domes, and views over central Aswan',
    storyAr:
        'يقع المسجد البارز على ربوة منسقة، ويشتهر بمآذنه وقبابه وإطلالته على وسط أسوان',
  )),
  _buildAswanPlace((
    id: 'aswan_el_haj_hassan_mosque',
    nameEn: 'El-Haj Hassan Corniche Mosque',
    nameAr: 'مسجد الحاج حسن على الكورنيش',
    category: 'Mosques',
    lat: 24.0935,
    lng: 32.9002,
    areaEn: 'Nile Corniche, Aswan',
    areaAr: 'كورنيش النيل، أسوان',
    openHours: '04:00 AM - 10:00 PM',
    priceLocalEgp: 0,
    priceForeignerEgp: 0,
    storyEn:
        'this neighborhood mosque serves the busy Corniche and provides a useful example of contemporary religious life beside the Nile',
    storyAr:
        'يخدم المسجد الحي النشط على الكورنيش ويقدم صورة من الحياة الدينية المعاصرة بمحاذاة النيل',
  )),
  _buildAswanPlace((
    id: 'aswan_sayyida_zaynab_mosque_souq',
    nameEn: 'Al-Sayyida Zaynab Mosque Aswan',
    nameAr: 'مسجد السيدة زينب بأسوان',
    category: 'Mosques',
    lat: 24.0875,
    lng: 32.8975,
    areaEn: 'Aswan Souq District',
    areaAr: 'منطقة سوق أسوان',
    openHours: '04:00 AM - 10:00 PM',
    priceLocalEgp: 0,
    priceForeignerEgp: 0,
    storyEn:
        'a local place of prayer within the souq district, closely connected to the daily rhythms of central Aswan’s market streets',
    storyAr:
        'مسجد محلي في منطقة السوق يرتبط بإيقاع الحياة اليومية في شوارع وسط أسوان التجارية',
  )),
  _buildAswanPlace((
    id: 'aswan_archangel_michael_cathedral',
    nameEn: 'Archangel Michael Coptic Orthodox Cathedral',
    nameAr: 'كاتدرائية رئيس الملائكة ميخائيل بأسوان',
    category: 'Churches',
    lat: 24.0815,
    lng: 32.8920,
    areaEn: 'Aswan Cathedral District',
    areaAr: 'منطقة كاتدرائية أسوان',
    openHours: '08:00 AM - 08:00 PM',
    priceLocalEgp: 0,
    priceForeignerEgp: 0,
    storyEn:
        'the cathedral serves Aswan’s Coptic Orthodox community and is an important contemporary landmark near the city center',
    storyAr:
        'تخدم الكاتدرائية مجتمع أسوان القبطي الأرثوذكسي وتمثل معلماً معاصراً مهماً قرب وسط المدينة',
  )),
  _buildAswanPlace((
    id: 'aswan_virgin_mary_church_corniche',
    nameEn: 'Church of the Virgin Mary Aswan',
    nameAr: 'كنيسة السيدة العذراء بأسوان',
    category: 'Churches',
    lat: 24.0912,
    lng: 32.8992,
    areaEn: 'Nile Corniche, Aswan',
    areaAr: 'كورنيش النيل، أسوان',
    openHours: '08:00 AM - 08:00 PM',
    priceLocalEgp: 0,
    priceForeignerEgp: 0,
    storyEn:
        'the church is part of Aswan’s Christian heritage and remains a living place of worship close to the city’s riverfront',
    storyAr:
        'تندرج الكنيسة ضمن تراث أسوان المسيحي وما زالت مكاناً حياً للعبادة قرب واجهة المدينة النهرية',
  )),
  _buildAswanPlace((
    id: 'aswan_1902_restaurant_old_cataract',
    nameEn: '1902 Restaurant at Old Cataract',
    nameAr: 'مطعم 1902 بفندق كتراكت التاريخي',
    category: 'Food',
    lat: 24.0812,
    lng: 32.8885,
    areaEn: 'Sofitel Legend Old Cataract',
    areaAr: 'فندق سوفيتيل ليجند أولد كتراكت',
    openHours: '10:00 AM - 01:00 AM',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    storyEn:
        'the formal dining room occupies the historic Old Cataract hotel, known for its Nile terrace and long association with visiting writers and travelers',
    storyAr:
        'تقع قاعة الطعام الرسمية داخل فندق كتراكت التاريخي المعروف بشرفته على النيل وارتباطه بالكتاب والزوار عبر أجيال',
  )),
  _buildAswanPlace((
    id: 'aswan_al_masry_restaurant',
    nameEn: 'Al-Masry Traditional Grill Restaurant',
    nameAr: 'مطعم المصري بأسوان',
    category: 'Food',
    lat: 24.0908,
    lng: 32.8998,
    areaEn: 'Aswan City Center',
    areaAr: 'وسط مدينة أسوان',
    openHours: '10:00 AM - 01:00 AM',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    storyEn:
        'a popular central dining address for Egyptian grills, rice, and traditional side dishes close to the market and riverfront',
    storyAr:
        'وجهة طعام معروفة في وسط المدينة للمشاوي المصرية والأرز والأطباق الجانبية التقليدية قرب السوق والنيل',
  )),
  _buildAswanPlace((
    id: 'aswan_al_dokkah_nubian_island_restaurant',
    nameEn: 'Al-Dokkah Nubian Island Restaurant',
    nameAr: 'مطعم الدوكة النوبي',
    category: 'Food',
    lat: 24.0862,
    lng: 32.8895,
    areaEn: 'Elephantine Island',
    areaAr: 'جزيرة إلفنتين',
    openHours: '10:00 AM - 01:00 AM',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    storyEn:
        'a river-island restaurant presents Nubian-inspired dishes and broad waterside views reached by a short boat crossing',
    storyAr:
        'يقدم مطعم الجزيرة أطباقاً مستوحاة من المطبخ النوبي وإطلالة واسعة على النهر، ويمكن الوصول إليه برحلة قارب قصيرة',
  )),
  _buildAswanPlace((
    id: 'aswan_makka_corniche_restaurant',
    nameEn: 'Makka Nile View Restaurant',
    nameAr: 'مطعم مكة بأسوان',
    category: 'Food',
    lat: 24.0925,
    lng: 32.9005,
    areaEn: 'Nile Corniche, Aswan',
    areaAr: 'كورنيش النيل، أسوان',
    openHours: '10:00 AM - 01:00 AM',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    storyEn:
        'a relaxed Corniche restaurant serves familiar Egyptian meals beside the river, convenient for a break between the souq and boat piers',
    storyAr:
        'يقدم المطعم الهادئ على الكورنيش وجبات مصرية مألوفة بجوار النهر، ويقع بين السوق ومراسي القوارب',
  )),
  _buildAswanPlace((
    id: 'aswan_ibis_panorama_restaurant',
    nameEn: 'Panorama Nile Terrace Restaurant',
    nameAr: 'مطعم بانوراما النيل بأسوان',
    category: 'Food',
    lat: 24.0965,
    lng: 32.9012,
    areaEn: 'Nile Corniche, Aswan',
    areaAr: 'كورنيش النيل، أسوان',
    openHours: '10:00 AM - 01:00 AM',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    storyEn:
        'the terrace dining room pairs Egyptian and international dishes with a high view over the Nile, islands, and traditional sailboats',
    storyAr:
        'تجمع قاعة الطعام على الشرفة أطباقاً مصرية وعالمية مع إطلالة مرتفعة على النيل والجزر والمراكب الشراعية',
  )),
  _buildAswanPlace((
    id: 'aswan_old_cataract_terrace_cafe',
    nameEn: 'The Terrace Cafe at Old Cataract',
    nameAr: 'شرفة فندق كتراكت على النيل',
    category: 'Cafes',
    lat: 24.0809,
    lng: 32.8884,
    areaEn: 'Sofitel Legend Old Cataract',
    areaAr: 'فندق سوفيتيل ليجند أولد كتراكت',
    openHours: '10:00 AM - 01:00 AM',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    storyEn:
        'the hotel terrace looks over the First Cataract and Elephantine Island, making afternoon tea and sunset a distinctive Nile experience',
    storyAr:
        'تطل شرفة الفندق على الشلال الأول وجزيرة إلفنتين، وتمنح جلسة الشاي والغروب تجربة مميزة على النيل',
  )),
  _buildAswanPlace((
    id: 'aswan_nubian_dreams_cafe_gharb_soheil',
    nameEn: 'Nubian Dreams Rooftop Cafe Gharb Soheil',
    nameAr: 'كافيه أحلام النوبة بغرب سهيل',
    category: 'Cafes',
    lat: 24.0592,
    lng: 32.8698,
    areaEn: 'Gharb Soheil, West Bank',
    areaAr: 'غرب سهيل، البر الغربي',
    openHours: '10:00 AM - 01:00 AM',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    storyEn:
        'rooftop tables overlook the village and river, with Nubian colors and a relaxed menu of tea, coffee, juices, and light meals',
    storyAr:
        'تطل طاولات السطح على القرية والنهر، وتحيط بها الألوان النوبية وقائمة هادئة من الشاي والقهوة والعصائر والوجبات الخفيفة',
  )),
  _buildAswanPlace((
    id: 'aswan_karkadeh_souq_heritage_cafe',
    nameEn: 'Aswan Hibiscus and Spices Heritage Cafe',
    nameAr: 'مقهى الكركديه الأسواني التراثي',
    category: 'Cafes',
    lat: 24.0918,
    lng: 32.8996,
    areaEn: 'Aswan Souq District',
    areaAr: 'منطقة سوق أسوان',
    openHours: '10:00 AM - 01:00 AM',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    storyEn:
        'a traditional-style stop for karkadeh, Nubian tea, and spice aromas within walking distance of the market lanes',
    storyAr:
        'محطة بطابع تراثي للكركديه والشاي النوبي وروائح التوابل على مسافة مشي من ممرات السوق',
  )),
  _buildAswanPlace((
    id: 'aswan_sharia_el_souq_bazaar',
    nameEn: 'Aswan Tourist Souq (Sharia el-Souq)',
    nameAr: 'السوق السياحي بأسوان (شارع السوق)',
    category: 'Shopping',
    lat: 24.0915,
    lng: 32.8995,
    areaEn: 'Sharia el-Souq',
    areaAr: 'شارع السوق',
    openHours: '10:00 AM - 11:00 PM',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    storyEn:
        'the long market street mixes spice shops, souvenirs, textiles, and everyday businesses at the heart of Aswan’s trading quarter',
    storyAr:
        'يجمع شارع السوق الطويل متاجر التوابل والهدايا والمنسوجات والأعمال اليومية في قلب المنطقة التجارية بأسوان',
  )),
  _buildAswanPlace((
    id: 'aswan_nubian_spices_henna_market',
    nameEn: 'Aswan Nubian Spices, Hibiscus and Henna Bazaar',
    nameAr: 'سوق العطارة والكركديه النوبي',
    category: 'Shopping',
    lat: 24.0902,
    lng: 32.8992,
    areaEn: 'Aswan Souq',
    areaAr: 'سوق أسوان',
    openHours: '10:00 AM - 11:00 PM',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    storyEn:
        'colorful stalls offer dried hibiscus, henna, seeds, and spice blends that reflect Nubian and Upper Egyptian food traditions',
    storyAr:
        'تعرض الأكشاك الملونة الكركديه المجفف والحناء والبذور وخلطات التوابل المرتبطة بتقاليد الطعام النوبية والصعيدية',
  )),
  _buildAswanPlace((
    id: 'aswan_gharb_soheil_handicraft_bazaar',
    nameEn: 'Gharb Soheil Nubian Beadwork and Baskets Market',
    nameAr: 'بازار المشغولات اليدوية النوبية',
    category: 'Shopping',
    lat: 24.0588,
    lng: 32.8692,
    areaEn: 'Gharb Soheil Village',
    areaAr: 'قرية غرب سهيل',
    openHours: '10:00 AM - 11:00 PM',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    storyEn:
        'village makers sell beadwork, woven baskets, and small crafts that showcase contemporary Nubian patterns and materials',
    storyAr:
        'يعرض حرفيو القرية أعمال الخرز والسلال المنسوجة والمشغولات التي تبرز الأنماط والخامات النوبية المعاصرة',
  )),
  _buildAswanPlace((
    id: 'aswan_daraw_historic_market',
    nameEn: 'Daraw Traditional Upper Egypt Market',
    nameAr: 'سوق دراو الشعبي بأسوان',
    category: 'Shopping',
    lat: 24.4050,
    lng: 32.9300,
    areaEn: 'Daraw Market, Kom Ombo District',
    areaAr: 'سوق دراو، مركز كوم أمبو',
    openHours: '10:00 AM - 11:00 PM',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    storyEn:
        'the regional market links farmers and traders through produce, livestock, and household goods, offering a glimpse of Upper Egyptian commerce',
    storyAr:
        'يربط السوق الإقليمي المزارعين والتجار عبر المحاصيل والماشية والسلع المنزلية، ويعرض جانباً من تجارة الصعيد',
  )),
  _buildAswanPlace((
    id: 'aswan_sofitel_legend_old_cataract',
    nameEn: 'Sofitel Legend Old Cataract Aswan',
    nameAr: 'فندق سوفيتيل ليجند أولد كتراكت أسوان',
    category: 'Hotels',
    lat: 24.0811,
    lng: 32.8886,
    areaEn: 'Old Cataract, Nile Corniche',
    areaAr: 'كتراكت القديمة، كورنيش النيل',
    openHours: '24 hours',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    storyEn:
        'opened in 1899, the landmark hotel combines Victorian-era interiors with terraces above the Nile’s First Cataract',
    storyAr:
        'افتتح الفندق التاريخي عام ١٨٩٩، ويجمع بين الديكورات الفيكتورية وشرفات مرتفعة فوق الشلال الأول للنيل',
  )),
  _buildAswanPlace((
    id: 'aswan_movenpick_resort_elephantine',
    nameEn: 'Mövenpick Resort Aswan (Elephantine Island)',
    nameAr: 'منتجع موفنبيك جزيرة إلفنتين',
    category: 'Hotels',
    lat: 24.0890,
    lng: 32.8880,
    areaEn: 'Elephantine Island',
    areaAr: 'جزيرة إلفنتين',
    openHours: '24 hours',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    storyEn:
        'the resort occupies an island setting with expansive views toward the city, desert bank, and river channels around Elephantine',
    storyAr:
        'يقع المنتجع في بيئة جزيرية بإطلالات واسعة نحو المدينة والضفة الصحراوية ومجاري النهر حول إلفنتين',
  )),
  _buildAswanPlace((
    id: 'aswan_benben_by_dhara_heissa',
    nameEn: 'Benben by Dhara Boutique Hotel (Heissa Island)',
    nameAr: 'فندق بنبن بجزيرة هيسا',
    category: 'Hotels',
    lat: 24.0210,
    lng: 32.8815,
    areaEn: 'Heissa Island',
    areaAr: 'جزيرة هيسا',
    openHours: '24 hours',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    storyEn:
        'the boutique stay pairs contemporary rooms with a quiet island location and views across the water toward the High Dam region',
    storyAr:
        'يجمع الفندق البوتيكي بين الغرف العصرية والموقع الهادئ على الجزيرة وإطلالات عبر الماء نحو منطقة السد العالي',
  )),
  _buildAswanPlace((
    id: 'aswan_tolip_hotel_corniche',
    nameEn: 'Tolip Aswan Hotel on the Nile',
    nameAr: 'فندق توليب أسوان على الكورنيش',
    category: 'Hotels',
    lat: 24.0985,
    lng: 32.9015,
    areaEn: 'Nile Corniche, Aswan',
    areaAr: 'كورنيش النيل، أسوان',
    openHours: '24 hours',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    storyEn:
        'the modern riverside hotel is positioned along the Corniche, close to central services and views of the Nile channel',
    storyAr:
        'يقع الفندق الحديث على ضفة الكورنيش بالقرب من خدمات وسط المدينة وإطلالات مجرى النيل',
  )),
  _buildAswanPlace((
    id: 'aswan_kato_dool_wellness_resort',
    nameEn: 'Kato Dool Nubian Resort Gharb Soheil',
    nameAr: 'منتجع كاتو دول النوبي بغرب سهيل',
    category: 'Hotels',
    lat: 24.0575,
    lng: 32.8688,
    areaEn: 'Gharb Soheil, West Bank',
    areaAr: 'غرب سهيل، البر الغربي',
    openHours: '24 hours',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    storyEn:
        'the Nubian-style retreat uses colorful architecture and a village setting to offer a quieter alternative to the central hotel strip',
    storyAr:
        'يعتمد المنتجع ذو الطابع النوبي على العمارة الملونة وموقع القرية ليقدم إقامة أهدأ من فنادق وسط المدينة',
  )),
  _buildAswanPlace((
    id: 'aswan_pyramisa_isis_island_resort',
    nameEn: 'Pyramisa Island Hotel Aswan',
    nameAr: 'منتجع بيراميزا جزيرة إيزيس أسوان',
    category: 'Hotels',
    lat: 24.0725,
    lng: 32.8835,
    areaEn: 'Isis Island, Aswan',
    areaAr: 'جزيرة إيزيس، أسوان',
    openHours: '24 hours',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    storyEn:
        'the island resort is reached by boat and places gardens, pools, and broad Nile views between the city and the High Dam',
    storyAr:
        'يمكن الوصول إلى المنتجع بالقارب، وتحيط به الحدائق والمسابح وإطلالات النيل بين المدينة والسد العالي',
  )),
  _buildAswanPlace((
    id: 'atm_nbe_aswan_corniche_station',
    nameEn: 'National Bank of Egypt ATM - Aswan Railway Station Square',
    nameAr: 'صراف البنك الأهلي - ميدان محطة أسوان',
    category: 'ATMs',
    lat: 24.0955,
    lng: 32.9008,
    areaEn: 'Aswan Railway Station Square',
    areaAr: 'ميدان محطة أسوان',
    openHours: '24 hours',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    storyEn:
        'this NBE cash point is near the railway station and central Corniche, convenient for travelers arriving by train or walking toward the souq',
    storyAr:
        'تقع ماكينة البنك الأهلي قرب محطة السكك الحديدية والكورنيش المركزي، وتفيد القادمين بالقطار أو المتجهين إلى السوق',
  )),
  _buildAswanPlace((
    id: 'atm_banque_misr_old_cataract_aswan',
    nameEn: 'Banque Misr ATM - Old Cataract & Faryal Garden',
    nameAr: 'صراف بنك مصر - كتراكت القديمة وحديقة فريال',
    category: 'ATMs',
    lat: 24.0818,
    lng: 32.8902,
    areaEn: 'Old Cataract and Faryal Garden',
    areaAr: 'كتراكت القديمة وحديقة فريال',
    openHours: '24 hours',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    storyEn:
        'the Banque Misr machine serves the hotel and garden district above the Nile, near a popular route between the museum and riverfront',
    storyAr:
        'تخدم ماكينة بنك مصر منطقة الفندق والحديقة المطلة على النيل، قرب المسار بين المتحف والواجهة النهرية',
  )),
  _buildAswanPlace((
    id: 'atm_cib_aswan_tourist_souq',
    nameEn: 'CIB ATM - Aswan Tourist Souq Corniche',
    nameAr: 'صراف البنك التجاري الدولي - كورنيش سوق أسوان',
    category: 'ATMs',
    lat: 24.0910,
    lng: 32.8988,
    areaEn: 'Tourist Souq and Nile Corniche',
    areaAr: 'السوق السياحي وكورنيش النيل',
    openHours: '24 hours',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    storyEn:
        'this CIB cash point lies between the market lanes and river promenade, close to shops, boat landings, and visitor services',
    storyAr:
        'تقع ماكينة البنك التجاري الدولي بين ممرات السوق وممشى النيل قرب المتاجر ومراسي القوارب وخدمات الزوار',
  )),
  _buildAswanPlace((
    id: 'atm_qnb_nubian_museum_aswan',
    nameEn: 'QNB ATM - Nubian Museum Road',
    nameAr: 'صراف بنك قطر الوطني - طريق متحف النوبة',
    category: 'ATMs',
    lat: 24.0790,
    lng: 32.8898,
    areaEn: 'Nubian Museum Road',
    areaAr: 'طريق متحف النوبة',
    openHours: '24 hours',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    storyEn:
        'the QNB machine is positioned near the Nubian Museum and southern city approaches, useful before continuing toward the High Dam',
    storyAr:
        'تقع ماكينة بنك قطر الوطني قرب متحف النوبة والطريق الجنوبي للمدينة، وتفيد قبل مواصلة الرحلة إلى السد العالي',
  )),
  _buildAswanPlace((
    id: 'atm_nbe_kom_ombo_temple_plaza',
    nameEn: 'National Bank of Egypt ATM - Kom Ombo Temple Corniche',
    nameAr: 'صراف البنك الأهلي - كورنيش معبد كوم أمبو',
    category: 'ATMs',
    lat: 24.4525,
    lng: 32.9295,
    areaEn: 'Kom Ombo Temple Corniche',
    areaAr: 'كورنيش معبد كوم أمبو',
    openHours: '24 hours',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    storyEn:
        'the NBE machine serves the temple plaza and nearby river landing, a useful stop for travelers continuing along the Nile route',
    storyAr:
        'تخدم ماكينة البنك الأهلي ساحة المعبد والمرسى النهري القريب، وتفيد المسافرين على امتداد طريق النيل',
  )),
  _buildAswanPlace((
    id: 'atm_banque_misr_edfu_temple_square',
    nameEn: 'Banque Misr ATM - Edfu Temple Square',
    nameAr: 'صراف بنك مصر - ساحة معبد إدفو',
    category: 'ATMs',
    lat: 24.9785,
    lng: 32.8745,
    areaEn: 'Edfu Temple Square',
    areaAr: 'ساحة معبد إدفو',
    openHours: '24 hours',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    storyEn:
        'the Banque Misr cash point is near Edfu Temple’s visitor approach and the town center, convenient for regional travel and local purchases',
    storyAr:
        'تقع ماكينة بنك مصر قرب مدخل زوار معبد إدفو ووسط المدينة، وتفيد في التنقل الإقليمي والمشتريات المحلية',
  )),
  _buildAswanPlace((
    id: 'aswan_el_kab_necropolis',
    nameEn: 'El-Kab Ancient City & Tombs',
    nameAr: 'مدينة ومقابر الكاب',
    category: 'Historical',
    lat: 25.1189,
    lng: 32.7981,
    areaEn: 'El-Kab',
    areaAr: 'الكاب',
    openHours: '07:00 AM - 04:00 PM',
    priceLocalEgp: 40,
    priceForeignerEgp: 200,
    storyEn:
        'the ancient walled settlement of Nekheb preserves temples and rock-cut tombs that trace Upper Egypt’s history from early dynasties through the New Kingdom',
    storyAr:
        'تحفظ مدينة نخِب القديمة المحاطة بالأسوار معابد ومقابر صخرية توثق تاريخ صعيد مصر من الأسرات المبكرة حتى الدولة الحديثة',
  )),
  _buildAswanPlace((
    id: 'aswan_wadi_el_sebua_temples',
    nameEn: 'Temples of Wadi el-Sebua',
    nameAr: 'معابد وادي السبوع',
    category: 'Historical',
    lat: 22.7936,
    lng: 32.5458,
    areaEn: 'Wadi el-Sebua, Lake Nasser',
    areaAr: 'وادي السبوع، بحيرة ناصر',
    openHours: '07:00 AM - 04:00 PM',
    priceLocalEgp: 40,
    priceForeignerEgp: 260,
    storyEn:
        'the New Kingdom sanctuary built by Ramesses II combines a processional avenue of sphinxes with a rock-cut temple dedicated to Amun-Ra and the deified king',
    storyAr:
        'يجمع المعبد الذي شيده رمسيس الثاني في الدولة الحديثة بين طريق احتفالي تصطف عليه تماثيل أبي الهول ومعبد منحوت في الصخر مكرس لآمون رع والملك المؤله',
  )),
  _buildAswanPlace((
    id: 'aswan_amada_pennut_temples',
    nameEn: 'Temple of Amada & Derr',
    nameAr: 'معبد عمدا والدر',
    category: 'Historical',
    lat: 22.7311,
    lng: 32.2625,
    areaEn: 'Lake Nasser',
    areaAr: 'بحيرة ناصر',
    openHours: '07:00 AM - 04:00 PM',
    priceLocalEgp: 40,
    priceForeignerEgp: 260,
    storyEn:
        'the Temple of Amada and the nearby temple of Derr preserve richly decorated Nubian sanctuaries relocated during the Lake Nasser rescue campaign',
    storyAr:
        'يحفظ معبد عمدا ومعبد الدر القريب مزارات نوبية غنية بالزخارف نُقلت خلال حملة إنقاذ آثار بحيرة ناصر',
  )),
]);

final Map<String, PlaceModel> _aswanPlacesById = {
  for (final place in aswanSeedPlaces) place.id: place,
};

List<PlaceModel> _aswanTourStops(List<String> placeIds) => [
  for (final id in placeIds) _aswanPlacesById[id]!,
];

final List<ItineraryModel>
aswanSeedItineraries = List<ItineraryModel>.unmodifiable([
  ItineraryModel(
    id: 'aswan_philae_high_dam_obelisk_trail',
    title: 'Philae, High Dam, and Unfinished Obelisk Trail',
    titleAr: 'مسار معبد فيلة والسد العالي والمسلة الناقصة',
    description:
        'Trace Aswan’s modern and ancient histories from the High Dam to the granite quarry, then cross by boat to Philae and the sanctuary of Isis.',
    descriptionAr:
        'تتبع تاريخ أسوان القديم والحديث من السد العالي إلى محجر الجرانيت، ثم اعبر بالقارب إلى فيلة ومعبد إيزيس.',
    duration: 'Full day',
    durationAr: 'يوم كامل',
    imageUrl: aswanImageUrls['aswan_philae_temple']!,
    governorate: 'luxor',
    places: _aswanTourStops([
      'aswan_high_dam_memorial',
      'aswan_unfinished_obelisk',
      'aswan_philae_temple',
    ]),
  ),
  ItineraryModel(
    id: 'aswan_nubian_museum_cataract_elephantine',
    title: 'Nubian Museum, Cataract, and Elephantine',
    titleAr: 'جولة متحف النوبة وجزيرة إلفنتين وفندق كتراكت',
    description:
        'Begin with Nubian heritage at the museum, continue to the Old Cataract’s Nile terrace, and cross to Elephantine for its archaeological landscape.',
    descriptionAr:
        'ابدأ بتراث النوبة في المتحف، ثم تابع إلى شرفة كتراكت القديمة على النيل، واعبر إلى المشهد الأثري في جزيرة إلفنتين.',
    duration: 'Full day',
    durationAr: 'يوم كامل',
    imageUrl: aswanImageUrls['aswan_nubian_museum']!,
    governorate: 'luxor',
    places: _aswanTourStops([
      'aswan_nubian_museum',
      'aswan_sofitel_legend_old_cataract',
      'aswan_elephantine_museum_ruins',
      'aswan_elephantine_nilometer',
    ]),
  ),
  ItineraryModel(
    id: 'aswan_west_bank_nobles_simeon_nubian_village',
    title: 'West Bank Nobles, St. Simeon, and Nubian Village',
    titleAr: 'مقابر قبة الهوا ودير الأنبا سمعان والقرية النوبية',
    description:
        'Cross the Nile to visit the painted tombs at Qubbet el-Hawa and the desert monastery, then continue south to Gharb Soheil’s Nubian village.',
    descriptionAr:
        'اعبر النيل لزيارة مقابر قبة الهوا المزينة ودير الصحراء، ثم تابع جنوباً إلى القرية النوبية بغرب سهيل.',
    duration: 'Full day',
    durationAr: 'يوم كامل',
    imageUrl: aswanImageUrls['aswan_qubbet_el_hawa_tombs']!,
    governorate: 'luxor',
    places: _aswanTourStops([
      'aswan_qubbet_el_hawa_tombs',
      'aswan_st_simeon_monastery',
      'aswan_gharb_soheil_nubian_village',
    ]),
  ),
  ItineraryModel(
    id: 'aswan_botanical_island_sehel_corniche_sail',
    title: 'Botanical Island, Sehel, Corniche, and Souq Sail',
    titleAr: 'رحلة الفلوكة للحديقة النباتية وجزيرة سهيل والسوق',
    description:
        'Sail between Kitchener’s Island and the First Cataract, stop at Sehel’s inscribed granite, then return to the Corniche and Aswan’s market streets.',
    descriptionAr:
        'أبحر بين جزيرة النباتات والشلال الأول، وتوقف عند جرانيت سهيل المنقوش، ثم عد إلى الكورنيش وشوارع سوق أسوان.',
    duration: 'Full day',
    durationAr: 'يوم كامل',
    imageUrl: aswanImageUrls['aswan_botanical_garden_kitchener']!,
    governorate: 'luxor',
    places: _aswanTourStops([
      'aswan_botanical_garden_kitchener',
      'aswan_sehel_island_famine_stele',
      'aswan_nile_corniche_promenade',
      'aswan_sharia_el_souq_bazaar',
    ]),
  ),
  ItineraryModel(
    id: 'aswan_kom_ombo_edfu_nile_temples_route',
    title: 'Kom Ombo and Edfu Nile Temples Route',
    titleAr: 'مسار معبدي كوم أمبو وإدفو ومتحف التماسيح',
    description:
        'Follow the river north to Kom Ombo’s double sanctuary and crocodile collection, then continue to Edfu’s exceptionally preserved Temple of Horus.',
    descriptionAr:
        'اتبع مجرى النيل شمالاً إلى معبد كوم أمبو المزدوج ومجموعة التماسيح، ثم تابع إلى معبد حورس المحفوظ جيداً في إدفو.',
    duration: 'Full day',
    durationAr: 'يوم كامل',
    imageUrl: aswanImageUrls['aswan_kom_ombo_temple']!,
    governorate: 'luxor',
    places: _aswanTourStops([
      'aswan_kom_ombo_temple',
      'aswan_crocodile_museum_kom_ombo',
      'aswan_edfu_horus_temple',
      'aswan_tell_edfu_archaeological_site',
    ]),
  ),
  ItineraryModel(
    id: 'aswan_abu_simbel_lake_nasser_royal_expedition',
    title: 'Abu Simbel and Lake Nasser Royal Expedition',
    titleAr: 'رحلة معبدي أبو سمبل ومعبد كلابشة على بحيرة ناصر',
    description:
        'Explore the twin rock-cut temples of Ramesses II and Nefertari at Abu Simbel, then return toward Aswan for the rescued sanctuary at New Kalabsha.',
    descriptionAr:
        'استكشف معبدي رمسيس الثاني ونفرتاري المنحوتين في أبو سمبل، ثم عد باتجاه أسوان لزيارة معبد كلابشة المنقذ في الموقع الجديد.',
    duration: 'Full day',
    durationAr: 'يوم كامل',
    imageUrl: aswanImageUrls['aswan_abu_simbel_great_temple']!,
    governorate: 'luxor',
    places: _aswanTourStops([
      'aswan_abu_simbel_great_temple',
      'aswan_abu_simbel_nefertari_temple',
      'aswan_kalabsha_temple',
      'aswan_beit_el_wali_temple',
    ]),
  ),
]);
