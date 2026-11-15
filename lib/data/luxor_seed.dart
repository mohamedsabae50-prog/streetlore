import 'models/itinerary_model.dart';
import 'models/place_model.dart';
import 'luxor_image_urls.dart';

typedef _LuxorPlaceSpec = ({
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
  String descriptionEn,
  String descriptionAr,
});

String _categoryAr(String category) => switch (category) {
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

PriceLevel _priceLevel(_LuxorPlaceSpec spec) {
  if (spec.category == 'Hotels' ||
      spec.id == 'luxor_1886_restaurant_winter_palace' ||
      spec.id == 'luxor_marsam_west_bank_restaurant' ||
      spec.id == 'luxor_el_kababgy_nile_dining') {
    return PriceLevel.expensive;
  }
  if (spec.category == 'Food' || spec.category == 'Cafes') {
    return PriceLevel.moderate;
  }
  if (spec.category == 'Shopping') return PriceLevel.moderate;
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

PlaceModel _buildLuxorPlace(_LuxorPlaceSpec spec) {
  final imageUrl = luxorImageUrls[spec.id]!;
  String nameDescription(String name, String description) =>
      description.toLowerCase().contains(name.toLowerCase())
      ? description
      : '$name: ${description[0].toLowerCase()}${description.substring(1)}';
  final hasAdmission =
      spec.priceLocalEgp != null && spec.priceForeignerEgp != null;
  final priceNote = hasAdmission
      ? 'Egyptian ticket EGP ${spec.priceLocalEgp}; foreign visitor ticket '
            'EGP ${spec.priceForeignerEgp}.'
      : switch (spec.category) {
          'Hotels' => 'Room rates vary by date and room type.',
          'Food' || 'Cafes' => 'Meal and drink prices vary by order.',
          'Shopping' => 'Prices vary by craft, material, and item.',
          'Mosques' || 'Churches' => 'Worship access has no admission charge.',
          'ATMs' => '',
          _ => 'Open-air access; no admission ticket is required.',
        };
  final priceNoteAr = hasAdmission
      ? 'تذكرة المصريين ${spec.priceLocalEgp} جنيهاً؛ وتذكرة الزائر الأجنبي '
            '${spec.priceForeignerEgp} جنيهاً.'
      : switch (spec.category) {
          'Hotels' => 'تختلف أسعار الغرف حسب الموعد ونوع الغرفة.',
          'Food' || 'Cafes' => 'تختلف أسعار الطعام والمشروبات حسب الطلب.',
          'Shopping' => 'تختلف الأسعار باختلاف الحرفة والخامة والقطعة.',
          'Mosques' || 'Churches' => 'لا تُفرض رسوم دخول على أماكن العبادة.',
          'ATMs' => '',
          _ => 'المكان مفتوح في الهواء الطلق ولا يحتاج إلى تذكرة دخول.',
        };
  return PlaceModel(
    id: spec.id,
    nameEn: spec.nameEn,
    nameAr: spec.nameAr,
    descriptionEn: nameDescription(spec.nameEn, spec.descriptionEn),
    descriptionAr: nameDescription(spec.nameAr, spec.descriptionAr),
    imageUrl: imageUrl,
    imageUrls: [imageUrl],
    rating: 4.5,
    category: spec.category,
    categoryAr: _categoryAr(spec.category),
    lat: spec.lat,
    lng: spec.lng,
    address: '${spec.areaEn}, Luxor Governorate, Egypt',
    addressAr: '${spec.areaAr}، محافظة الأقصر، مصر',
    governorate: 'luxor',
    openHours: spec.openHours,
    reviewCount: 450,
    priceLevel: _priceLevel(spec),
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

final List<PlaceModel> luxorSeedPlaces = List<PlaceModel>.unmodifiable([
  _buildLuxorPlace((
    id: 'luxor_karnak_temple',
    nameEn: 'Karnak Temple',
    nameAr: 'مجمع معابد الكرنك',
    category: 'Historical',
    lat: 25.7188,
    lng: 32.6573,
    areaEn: 'Karnak',
    areaAr: 'الكرنك',
    openHours: '06:00 AM - 05:30 PM',
    priceLocalEgp: 80,
    priceForeignerEgp: 600,
    descriptionEn:
        'Karnak is a vast sacred precinct where generations of pharaohs raised pylons, obelisks, and the immense Hypostyle Hall for Amun. Follow the processional axis to read how each ruler added a distinct layer to Thebes.',
    descriptionAr:
        'الكرنك مجمع مقدس شاسع أضاف إليه ملوك متعاقبون بوابات ومسلات وقاعة الأعمدة الكبرى المكرسة لآمون. اتبع محور المواكب لتتأمل كيف ترك كل حاكم بصمته في طيبة القديمة.',
  )),
  _buildLuxorPlace((
    id: 'luxor_temple',
    nameEn: 'Luxor Temple',
    nameAr: 'معبد الأقصر',
    category: 'Historical',
    lat: 25.6995,
    lng: 32.6391,
    areaEn: 'Luxor East Bank',
    areaAr: 'البر الشرقي بالأقصر',
    openHours: '06:00 AM - 09:00 PM',
    priceLocalEgp: 80,
    priceForeignerEgp: 500,
    descriptionEn:
        'Set beside the Nile-side city, Luxor Temple was shaped by Amenhotep III and Ramesses II and later adapted for changing faiths. Its colossi, court, and avenue connection make the monument especially evocative after dusk.',
    descriptionAr:
        'يقع معبد الأقصر بجوار المدينة والنيل، وشيده أمنحتب الثالث ورمسيس الثاني ثم تبدلت استخداماته الدينية عبر القرون. تمنح تماثيله وساحته واتصاله بطريق الكباش للمكان حضوراً مميزاً بعد الغروب.',
  )),
  _buildLuxorPlace((
    id: 'luxor_avenue_of_sphinxes',
    nameEn: 'Avenue of Sphinxes',
    nameAr: 'طريق الكباش',
    category: 'Historical',
    lat: 25.7085,
    lng: 32.6465,
    areaEn: 'East Bank',
    areaAr: 'البر الشرقي',
    openHours: '06:00 AM - 09:00 PM',
    priceLocalEgp: 80,
    priceForeignerEgp: 500,
    descriptionEn:
        'The restored ceremonial avenue links Karnak with Luxor Temple along a route once lined with ram-headed and human-headed sphinxes. Walking its excavated stretches reveals how religious festivals connected the two great sanctuaries.',
    descriptionAr:
        'يربط الطريق الاحتفالي المُرمم بين الكرنك ومعبد الأقصر، وكانت تصطف على جانبيه تماثيل أبي الهول برؤوس كباش أو بشرية. تكشف جولتك بين أجزائه المكتشفة عن مسار المواكب التي وصلت بين المجمعين.',
  )),
  _buildLuxorPlace((
    id: 'luxor_museum',
    nameEn: 'Luxor Museum',
    nameAr: 'متحف الأقصر',
    category: 'Culture',
    lat: 25.7076,
    lng: 32.6445,
    areaEn: 'East Bank Corniche',
    areaAr: 'كورنيش البر الشرقي',
    openHours: '09:00 AM - 08:00 PM',
    priceLocalEgp: 50,
    priceForeignerEgp: 400,
    descriptionEn:
        'This carefully curated museum presents sculpture and objects excavated around ancient Thebes, including celebrated royal statuary and material from the Karnak cache. Its measured galleries offer a clear introduction before visiting the monuments outdoors.',
    descriptionAr:
        'يعرض المتحف قطعاً ومنحوتات كُشفت في طيبة القديمة، ومنها تماثيل ملكية شهيرة ومقتنيات من خبيئة الكرنك. تمنح قاعاته الهادئة مدخلاً واضحاً لفهم المواقع الأثرية التي ستزورها في الهواء الطلق.',
  )),
  _buildLuxorPlace((
    id: 'luxor_mummification_museum',
    nameEn: 'Mummification Museum',
    nameAr: 'متحف التحنيط',
    category: 'Culture',
    lat: 25.7022,
    lng: 32.6398,
    areaEn: 'East Bank Corniche',
    areaAr: 'كورنيش البر الشرقي',
    openHours: '09:00 AM - 08:00 PM',
    priceLocalEgp: 40,
    priceForeignerEgp: 300,
    descriptionEn:
        'Small but focused, this museum explains the craft of embalming through tools, materials, animal mummies, and human remains. The displays connect ritual beliefs with the practical knowledge behind preparing the dead for the afterlife.',
    descriptionAr:
        'يشرح هذا المتحف المتخصص فن التحنيط من خلال الأدوات والمواد ومومياوات الحيوانات والبقايا البشرية. تربط المعروضات بين المعتقدات الجنائزية والمعرفة العملية التي أُعد بها الموتى للحياة الأخرى.',
  )),
  _buildLuxorPlace((
    id: 'luxor_valley_of_the_kings',
    nameEn: 'Valley of the Kings',
    nameAr: 'وادي الملوك',
    category: 'Historical',
    lat: 25.7402,
    lng: 32.6014,
    areaEn: 'West Bank, Theban Necropolis',
    areaAr: 'البر الغربي، جبانة طيبة',
    openHours: '06:00 AM - 05:00 PM',
    priceLocalEgp: 100,
    priceForeignerEgp: 750,
    descriptionEn:
        'Hidden in a desert valley, the royal necropolis holds elaborately painted New Kingdom tombs cut deep into limestone cliffs. The standard ticket covers a changing selection, so check which decorated chambers are open at the gate.',
    descriptionAr:
        'يضم وادي الملوك مقابر ملكية من الدولة الحديثة نُحتت في الحجر الجيري وزُينت جدرانها بمشاهد جنائزية. تشمل التذكرة الأساسية مجموعة متغيرة من المقابر، لذلك تحقق من المقابر المفتوحة عند البوابة.',
  )),
  _buildLuxorPlace((
    id: 'luxor_tomb_of_tutankhamun',
    nameEn: 'Tomb of Tutankhamun KV62',
    nameAr: 'مقبرة توت عنخ آمون',
    category: 'Historical',
    lat: 25.7405,
    lng: 32.6018,
    areaEn: 'Valley of the Kings',
    areaAr: 'وادي الملوك',
    openHours: '06:00 AM - 05:00 PM',
    priceLocalEgp: 80,
    priceForeignerEgp: 700,
    descriptionEn:
        'KV62 is the compact burial chamber discovered by Howard Carter in 1922, famous for the extraordinary objects found within it. Visitors can see its wall paintings and the young king’s mummy, while the golden treasures are displayed elsewhere.',
    descriptionAr:
        'المقبرة KV62 حجرة دفن صغيرة اكتشفها هوارد كارتر عام ١٩٢٢ واشتهرت باللقى الفريدة التي عُثر عليها فيها. يشاهد الزائر رسوم الجدران ومومياء الملك الشاب، أما كنوزه الذهبية فتُعرض في متاحف أخرى.',
  )),
  _buildLuxorPlace((
    id: 'luxor_tomb_of_ramesses_vi',
    nameEn: 'Tomb of Ramesses V & VI KV9',
    nameAr: 'مقبرة رمسيس السادس',
    category: 'Historical',
    lat: 25.7400,
    lng: 32.6011,
    areaEn: 'Valley of the Kings',
    areaAr: 'وادي الملوك',
    openHours: '06:00 AM - 05:00 PM',
    priceLocalEgp: 60,
    priceForeignerEgp: 220,
    descriptionEn:
        'KV9 descends through a long corridor whose ceilings preserve vivid astronomical scenes and richly colored funerary texts. Its decorated chambers reward a slow look at the stars, deities, and royal journey painted across the stone.',
    descriptionAr:
        'تهبط المقبرة KV9 عبر ممر طويل يحمل سقفه مشاهد فلكية ونصوصاً جنائزية زاهية الألوان. تستحق حجراتها المزخرفة التأمل في النجوم والآلهة ورحلة الملك المرسومة على الحجر.',
  )),
  _buildLuxorPlace((
    id: 'luxor_valley_of_the_queens',
    nameEn: 'Valley of the Queens',
    nameAr: 'وادي الملكات',
    category: 'Historical',
    lat: 25.7286,
    lng: 32.5929,
    areaEn: 'West Bank, Theban Necropolis',
    areaAr: 'البر الغربي، جبانة طيبة',
    openHours: '06:00 AM - 05:00 PM',
    priceLocalEgp: 60,
    priceForeignerEgp: 220,
    descriptionEn:
        'South of the royal kings’ valley, this necropolis contains burials for queens, princes, and royal children of the New Kingdom. The dry cliffs and painted interiors reveal a more intimate side of Theban funerary life.',
    descriptionAr:
        'تقع هذه الجبانة جنوب وادي الملوك وتضم مقابر لملكات وأمراء وأطفال من الأسرة الملكية في الدولة الحديثة. تكشف المنحدرات الجافة والزخارف الملونة جانباً أكثر خصوصية من طقوس الدفن في طيبة.',
  )),
  _buildLuxorPlace((
    id: 'luxor_tomb_of_nefertari',
    nameEn: 'Tomb of Queen Nefertari QV66',
    nameAr: 'مقبرة الملكة نفرتاري',
    category: 'Historical',
    lat: 25.7289,
    lng: 32.5925,
    areaEn: 'Valley of the Queens',
    areaAr: 'وادي الملكات',
    openHours: '06:00 AM - 05:00 PM',
    priceLocalEgp: 600,
    priceForeignerEgp: 2000,
    descriptionEn:
        'QV66 is the celebrated burial of Ramesses II’s great royal wife, restored for its exceptionally vivid painted scenes. Admission is separately priced and tightly managed to protect the fragile pigments, so confirm access before planning the visit.',
    descriptionAr:
        'المقبرة QV66 هي مدفن الزوجة الملكية العظمى لرمسيس الثاني، وتشتهر برسومها الزاهية التي خضعت للترميم. تُباع تذكرتها بصورة منفصلة ويُنظم الدخول لحماية الألوان الحساسة، لذا تحقق من الإتاحة قبل الزيارة.',
  )),
  _buildLuxorPlace((
    id: 'luxor_hatshepsut_temple',
    nameEn: 'Temple of Hatshepsut',
    nameAr: 'معبد حتشبسوت بالدير البحري',
    category: 'Historical',
    lat: 25.7380,
    lng: 32.6065,
    areaEn: 'Deir el-Bahari',
    areaAr: 'الدير البحري',
    openHours: '06:00 AM - 05:00 PM',
    priceLocalEgp: 80,
    priceForeignerEgp: 440,
    descriptionEn:
        'Hatshepsut’s mortuary temple rises in terraced colonnades against the cliffs of Deir el-Bahari. Reliefs on its walls recount the queen’s divine birth and the trading expedition to Punt, placing royal ambition within a dramatic landscape.',
    descriptionAr:
        'يرتفع معبد حتشبسوت بشرفات وأروقة متدرجة أمام منحدرات الدير البحري. تروي نقوشه قصة الميلاد الإلهي للملكة ورحلتها التجارية إلى بلاد بونت، وتجمع بين الطموح الملكي والمشهد الصحراوي.',
  )),
  _buildLuxorPlace((
    id: 'luxor_medinet_habu',
    nameEn: 'Medinet Habu',
    nameAr: 'معبد مدينة هابو',
    category: 'Historical',
    lat: 25.7197,
    lng: 32.6007,
    areaEn: 'West Bank, Medinet Habu',
    areaAr: 'البر الغربي، مدينة هابو',
    openHours: '06:00 AM - 05:00 PM',
    priceLocalEgp: 60,
    priceForeignerEgp: 220,
    descriptionEn:
        'The fortified mortuary complex of Ramesses III is known for its monumental gate and extensive reliefs of royal campaigns. Color traces remain in sheltered halls, and the enclosure preserves a rare sense of a temple precinct as a working community.',
    descriptionAr:
        'يشتهر مجمع رمسيس الثالث الجنائزي ببوابته الضخمة ونقوشه الواسعة التي تصور الحملات الملكية. ما زالت آثار الألوان باقية في بعض القاعات، ويمنح السور إحساساً نادراً بمعبد كان مركزاً لمجتمع عامل.',
  )),
  _buildLuxorPlace((
    id: 'luxor_ramesseum',
    nameEn: 'Ramesseum',
    nameAr: 'معبد الرامسيوم',
    category: 'Historical',
    lat: 25.7280,
    lng: 32.6105,
    areaEn: 'West Bank, Qurna',
    areaAr: 'البر الغربي، القرنة',
    openHours: '06:00 AM - 05:00 PM',
    priceLocalEgp: 60,
    priceForeignerEgp: 220,
    descriptionEn:
        'Ramesses II’s memorial temple preserves fallen colossi, courts, and carved scenes of the Battle of Kadesh. The broken statue fragments are a striking reminder of the scale once commanded by this royal complex on the Theban west bank.',
    descriptionAr:
        'يحفظ معبد رمسيس الثاني الجنائزي تماثيل ضخمة متهدمة وساحات ومناظر من معركة قادش. تذكر شظايا التمثال الزائر بالحجم الهائل الذي اتخذه هذا المجمع الملكي على الضفة الغربية لطيبة.',
  )),
  _buildLuxorPlace((
    id: 'luxor_colossi_of_memnon',
    nameEn: 'Colossi of Memnon',
    nameAr: 'تمثالا ممنون',
    category: 'Historical',
    lat: 25.7206,
    lng: 32.6105,
    areaEn: 'West Bank, Al-Qurna',
    areaAr: 'البر الغربي، القرنة',
    openHours: '24 hours',
    priceLocalEgp: 0,
    priceForeignerEgp: 0,
    descriptionEn:
        'These two seated quartzite figures once guarded the entrance to Amenhotep III’s now-ruined mortuary temple. Their weathered surfaces and open roadside setting make them an accessible stop at sunrise on the west-bank circuit.',
    descriptionAr:
        'كان التمثالان الجالسان من الكوارتزيت يحـرسان مدخل المعبد الجنائزي لأمنحتب الثالث الذي اندثر معظمُه. تمنح ملامحهما المتآكلة وموقعهما المفتوح على الطريق محطة سهلة للتوقف عند شروق الشمس.',
  )),
  _buildLuxorPlace((
    id: 'luxor_deir_el_medina',
    nameEn: 'Deir el-Medina',
    nameAr: 'دير المدينة',
    category: 'Historical',
    lat: 25.7285,
    lng: 32.6015,
    areaEn: 'West Bank, Deir el-Medina',
    areaAr: 'البر الغربي، دير المدينة',
    openHours: '06:00 AM - 05:00 PM',
    priceLocalEgp: 60,
    priceForeignerEgp: 220,
    descriptionEn:
        'This planned village housed the artisans who cut and decorated royal tombs in the Valley of the Kings. Its compact house remains, community temple, and nearby private tombs illuminate the daily lives behind Thebes’ grand monuments.',
    descriptionAr:
        'سكنت هذه القرية المنظمة الحرفيين الذين نحتوا وزينوا المقابر الملكية في وادي الملوك. تكشف بقايا البيوت الصغيرة ومعبد القرية والمقابر الخاصة القريبة عن حياة صناع آثار طيبة العظيمة.',
  )),
  _buildLuxorPlace((
    id: 'luxor_tombs_of_the_nobles',
    nameEn: 'Tombs of the Nobles',
    nameAr: 'مقابر النبلاء',
    category: 'Historical',
    lat: 25.7315,
    lng: 32.6075,
    areaEn: 'West Bank, Qurna',
    areaAr: 'البر الغربي، القرنة',
    openHours: '06:00 AM - 05:00 PM',
    priceLocalEgp: 60,
    priceForeignerEgp: 200,
    descriptionEn:
        'Cut into the foothills above Qurna, these private tombs belonged to officials who served Theban rulers. Their scenes of farms, banquets, and crafts provide unusually detailed views of work and family beyond royal ceremony.',
    descriptionAr:
        'نُحتت مقابر النبلاء في سفوح القرنة وكانت لمديرين وكبار موظفي حكام طيبة. تعرض مناظر الزراعة والولائم والحرف تفاصيل نادرة عن العمل والأسرة بعيداً عن الاحتفالات الملكية.',
  )),
  _buildLuxorPlace((
    id: 'luxor_ramose_tomb',
    nameEn: 'Tomb of Ramose TT55',
    nameAr: 'مقبرة رع موسى',
    category: 'Historical',
    lat: 25.7310,
    lng: 32.6082,
    areaEn: 'Sheikh Abd el-Qurna',
    areaAr: 'الشيخ عبد القرنة',
    openHours: '06:00 AM - 05:00 PM',
    priceLocalEgp: 40,
    priceForeignerEgp: 160,
    descriptionEn:
        'TT55 belonged to vizier Ramose and is remarkable for its transition from traditional raised relief to the softer Amarna style. The unfinished decoration lets visitors compare artistic choices within a single tomb chapel.',
    descriptionAr:
        'تعود المقبرة TT55 للوزير رع موسى وتتميز بالانتقال من النقش البارز التقليدي إلى أسلوب العمارنة الأكثر رقة. تتيح الزخارف غير المكتملة مقارنة الاختيارات الفنية داخل مقصورة جنائزية واحدة.',
  )),
  _buildLuxorPlace((
    id: 'luxor_sennedjem_tomb',
    nameEn: 'Tomb of Sennedjem TT1',
    nameAr: 'مقبرة سنجم',
    category: 'Historical',
    lat: 25.7281,
    lng: 32.6012,
    areaEn: 'Deir el-Medina',
    areaAr: 'دير المدينة',
    openHours: '06:00 AM - 05:00 PM',
    priceLocalEgp: 40,
    priceForeignerEgp: 160,
    descriptionEn:
        'The small TT1 burial chamber is celebrated for its crisp scenes of Sennedjem and his family in the afterlife. Its vivid agricultural imagery and careful preservation make this artisans’ tomb a memorable complement to the nearby village.',
    descriptionAr:
        'تشتهر حجرة الدفن الصغيرة TT1 بمناظر واضحة لسنجم وأسرته في العالم الآخر. تجعل صور الزراعة الزاهية وحالة الحفظ الجيدة مقبرة هذا الحرفي زيارة مكملة لقرية دير المدينة المجاورة.',
  )),
  _buildLuxorPlace((
    id: 'luxor_howard_carter_house',
    nameEn: 'Howard Carter House',
    nameAr: 'بيت هوارد كارتر',
    category: 'Culture',
    lat: 25.7382,
    lng: 32.6250,
    areaEn: 'West Bank, Gezira',
    areaAr: 'البر الغربي، الجزيرة',
    openHours: '08:00 AM - 05:00 PM',
    priceLocalEgp: 60,
    priceForeignerEgp: 220,
    descriptionEn:
        'The former home of the archaeologist who uncovered Tutankhamun’s tomb has been preserved with period furnishings and expedition context. A replica burial chamber helps visitors understand the discovery without entering the fragile original tomb.',
    descriptionAr:
        'حُفظ منزل عالم الآثار الذي اكتشف مقبرة توت عنخ آمون بأثاثه ومقتنياته المرتبطة بالبعثة. وتساعد نسخة من حجرة الدفن الزائر على فهم الاكتشاف دون التأثير في المقبرة الأصلية الحساسة.',
  )),
  _buildLuxorPlace((
    id: 'luxor_temple_of_seti_i_qurna',
    nameEn: 'Temple of Seti I at Qurna',
    nameAr: 'معبد سيتي الأول بالقرنة',
    category: 'Historical',
    lat: 25.7327,
    lng: 32.6281,
    areaEn: 'Qurna, West Bank',
    areaAr: 'القرنة، البر الغربي',
    openHours: '06:00 AM - 05:00 PM',
    priceLocalEgp: 40,
    priceForeignerEgp: 160,
    descriptionEn:
        'Seti I’s memorial temple at Qurna survives in a quieter setting than the major west-bank complexes. Its remaining reliefs and courts reveal the ritual program dedicated to the king and the gods of Thebes.',
    descriptionAr:
        'يقع معبد سيتي الأول الجنائزي في القرنة ضمن أجواء أهدأ من مجمعات البر الغربي الكبرى. تكشف النقوش والساحات الباقية عن الطقوس التي خُصصت للملك وآلهة طيبة.',
  )),
  _buildLuxorPlace((
    id: 'luxor_merenptah_mortuary_temple',
    nameEn: 'Temple of Merenptah',
    nameAr: 'معبد مرنبتاح',
    category: 'Historical',
    lat: 25.7248,
    lng: 32.6075,
    areaEn: 'West Bank, Qurna',
    areaAr: 'البر الغربي، القرنة',
    openHours: '06:00 AM - 05:00 PM',
    priceLocalEgp: 40,
    priceForeignerEgp: 140,
    descriptionEn:
        'The remains of Merenptah’s memorial temple include blocks reused from earlier monuments and reliefs documenting royal devotion. The site’s museum displays finds that help reconstruct the complex’s changing history.',
    descriptionAr:
        'تضم بقايا معبد مرنبتاح الجنائزي أحجاراً أعيد استخدامها من آثار أقدم ونقوشاً توثق التعبد الملكي. تعرض مساحة المتحف المكتشفات التي تساعد على تتبع التحولات التي مر بها المجمع.',
  )),
  _buildLuxorPlace((
    id: 'luxor_assasif_necropolis',
    nameEn: 'El-Assasif Necropolis',
    nameAr: 'جبانة العساسيف',
    category: 'Historical',
    lat: 25.7345,
    lng: 32.6122,
    areaEn: 'West Bank, El-Assasif',
    areaAr: 'البر الغربي، العساسيف',
    openHours: '06:00 AM - 05:00 PM',
    priceLocalEgp: 40,
    priceForeignerEgp: 160,
    descriptionEn:
        'El-Assasif spreads across the low desert plain with monumental tombs of officials from several periods, including the richly decorated tombs of the Twenty-fifth and Twenty-sixth Dynasties. Its broad scale rewards visitors who look beyond the royal valleys.',
    descriptionAr:
        'تمتد جبانة العساسيف في السهل الصحراوي وتضم مقابر ضخمة لمسؤولين من عصور متعددة، ومنها مقابر مزخرفة من الأسرتين الخامسة والعشرين والسادسة والعشرين. يكشف اتساعها جانباً آخر من جبانة طيبة خارج الوديان الملكية.',
  )),
  _buildLuxorPlace((
    id: 'luxor_deir_el_shelwit',
    nameEn: 'Temple of Isis at Deir el-Shelwit',
    nameAr: 'معبد دير الشلويط',
    category: 'Historical',
    lat: 25.6960,
    lng: 32.5785,
    areaEn: 'West Bank, Deir el-Shelwit',
    areaAr: 'البر الغربي، دير الشلويط',
    openHours: '06:00 AM - 05:00 PM',
    priceLocalEgp: 30,
    priceForeignerEgp: 100,
    descriptionEn:
        'This modest Roman-period sanctuary dedicated to Isis stands apart from Luxor’s better-known pharaonic temples. Its surviving gateway and reliefs offer a compact glimpse of later religious life in the Theban region.',
    descriptionAr:
        'يقف هذا المعبد الصغير من العصر الروماني، والمكرس لإيزيس، بعيداً عن المعابد الفرعونية الأشهر في الأقصر. تمنح بوابته ونقوشه الباقية لمحة مركزة عن الحياة الدينية المتأخرة في منطقة طيبة.',
  )),
  _buildLuxorPlace((
    id: 'luxor_medamud_temple',
    nameEn: 'Temple of Montu at Medamud',
    nameAr: 'معبد المدامود',
    category: 'Historical',
    lat: 25.7347,
    lng: 32.6997,
    areaEn: 'Medamud, North-East Luxor',
    areaAr: 'المدامود، شمال شرق الأقصر',
    openHours: '07:00 AM - 04:00 PM',
    priceLocalEgp: 30,
    priceForeignerEgp: 100,
    descriptionEn:
        'Medamud was a cult center of Montu, the falcon-associated god of war, and the temple precinct preserves traces of successive building phases. Its quieter archaeological landscape rewards travelers exploring beyond central Luxor.',
    descriptionAr:
        'كانت المدامود مركزاً لعبادة منتو، إله الحرب المرتبط بالصقر، ويحفظ نطاق المعبد آثار مراحل بناء متعاقبة. تكافئ أجواء الموقع الهادئة من يستكشف الآثار خارج وسط الأقصر.',
  )),
  _buildLuxorPlace((
    id: 'luxor_tod_temple',
    nameEn: 'Temple of Montu at Tod',
    nameAr: 'معبد الطود',
    category: 'Historical',
    lat: 25.5819,
    lng: 32.5333,
    areaEn: 'Tod, South of Luxor',
    areaAr: 'الطود، جنوب الأقصر',
    openHours: '07:00 AM - 04:00 PM',
    priceLocalEgp: 30,
    priceForeignerEgp: 100,
    descriptionEn:
        'The temple at Tod honors Montu and grew through Middle Kingdom and later additions near the ancient route south of Thebes. The quieter remains and nearby settlement make this a rewarding excursion for visitors tracing the region’s wider sacred geography.',
    descriptionAr:
        'يكرم معبد الطود الإله منتو، وتطورت مبانيه منذ الدولة الوسطى قرب الطريق القديم جنوب طيبة. تمنح بقاياه الهادئة والقرية المجاورة رحلة مميزة لمن يتتبع جغرافية المنطقة المقدسة.',
  )),
  _buildLuxorPlace((
    id: 'luxor_armant_temple',
    nameEn: 'Temple of Montu at Armant',
    nameAr: 'معبد أرمنت',
    category: 'Historical',
    lat: 25.6186,
    lng: 32.5439,
    areaEn: 'Armant, South-West Luxor',
    areaAr: 'أرمنت، جنوب غرب الأقصر',
    openHours: '07:00 AM - 04:00 PM',
    priceLocalEgp: 30,
    priceForeignerEgp: 100,
    descriptionEn:
        'Armant, ancient Hermonthis, was another important center for Montu, and its temple history spans pharaonic and later periods. The site adds a southern chapter to the network of sanctuaries that shaped life around Thebes.',
    descriptionAr:
        'كانت أرمنت، المعروفة قديماً باسم هيرمونثيس، مركزاً مهماً لعبادة منتو، ويمتد تاريخ معبدها عبر عصور فرعونية ولاحقة. يضيف الموقع فصلاً جنوبياً إلى شبكة المعابد التي شكلت الحياة حول طيبة.',
  )),
  _buildLuxorPlace((
    id: 'luxor_banana_island',
    nameEn: 'Banana Island',
    nameAr: 'جزيرة الموز',
    category: 'Nature',
    lat: 25.6765,
    lng: 32.6180,
    areaEn: 'Nile West Bank',
    areaAr: 'النيل، الضفة الغربية',
    openHours: '09:00 AM - 05:00 PM',
    priceLocalEgp: 50,
    priceForeignerEgp: 150,
    descriptionEn:
        'A short boat ride brings visitors to this green Nile-side island, where shaded paths pass banana groves and small farm animals. The contrast between river gardens and the surrounding desert makes it an easy-paced break from temple visits.',
    descriptionAr:
        'تصل رحلة قصيرة بالقارب إلى هذه الجزيرة الخضراء على النيل، حيث تمر الممرات المظللة بين أشجار الموز وبعض حيوانات المزرعة. يشكل التباين بين البساتين والنطاق الصحراوي استراحة هادئة من جولات المعابد.',
  )),
  _buildLuxorPlace((
    id: 'luxor_nile_corniche',
    nameEn: 'Luxor Nile Corniche',
    nameAr: 'كورنيش النيل بالأقصر',
    category: 'Nature',
    lat: 25.7035,
    lng: 32.6415,
    areaEn: 'East Bank, Nile Corniche',
    areaAr: 'البر الشرقي، كورنيش النيل',
    openHours: '24 hours',
    priceLocalEgp: 0,
    priceForeignerEgp: 0,
    descriptionEn:
        'The riverside promenade follows the East Bank past ferry landings, gardens, and views toward the Theban hills. Come at sunset to watch boats cross the water as the west-bank cliffs change color.',
    descriptionAr:
        'يمتد ممشى النيل على البر الشرقي بمحاذاة المراسي والحدائق، مع إطلالات نحو جبال طيبة. تعال عند الغروب لمشاهدة القوارب وهي تعبر النهر وتغير ألوان منحدرات البر الغربي.',
  )),
  _buildLuxorPlace((
    id: 'luxor_west_bank_balloon_field',
    nameEn: 'West Bank Balloon Field',
    nameAr: 'منطقة انطلاق المناطيد بالبر الغربي',
    category: 'Nature',
    lat: 25.7250,
    lng: 32.6190,
    areaEn: 'West Bank, Qurna',
    areaAr: 'البر الغربي، القرنة',
    openHours: '04:30 AM - 08:30 AM',
    priceLocalEgp: 800,
    priceForeignerEgp: 3500,
    descriptionEn:
        'Before dawn, balloon crews gather here for flights above the Nile valley and the west-bank monuments. The launch field is the meeting point rather than a viewing deck; wind and operator decisions determine whether flights proceed.',
    descriptionAr:
        'تجتمع فرق المناطيد هنا قبل الفجر استعداداً للتحليق فوق وادي النيل وآثار البر الغربي. المنطقة نقطة تجمع وانطلاق وليست منصة مشاهدة، كما تحدد الرياح وقرارات المشغلين تنفيذ الرحلات.',
  )),
  _buildLuxorPlace((
    id: 'luxor_felucca_sail_dock',
    nameEn: 'Felucca Sail Dock',
    nameAr: 'مرسى المراكب الشراعية',
    category: 'Nature',
    lat: 25.6960,
    lng: 32.6365,
    areaEn: 'East Bank, Luxor',
    areaAr: 'البر الشرقي، الأقصر',
    openHours: '06:00 AM - 10:00 PM',
    priceLocalEgp: 100,
    priceForeignerEgp: 300,
    descriptionEn:
        'Traditional feluccas leave this riverside landing for unhurried sails between the East and West Banks. Agree on the route, duration, and fare with the boat operator before boarding, especially for sunset trips.',
    descriptionAr:
        'تنطلق المراكب الشراعية التقليدية من هذا المرسى في رحلات هادئة بين الضفتين الشرقية والغربية. اتفق مع المشغل على المسار والمدة والأجرة قبل الصعود، خصوصاً في رحلات الغروب.',
  )),
  _buildLuxorPlace((
    id: 'luxor_crocodile_island_park',
    nameEn: 'Crocodile Island Park',
    nameAr: 'منتزه جزيرة التمساح',
    category: 'Nature',
    lat: 25.6730,
    lng: 32.6265,
    areaEn: 'Nile Islands, Luxor',
    areaAr: 'جزر النيل، الأقصر',
    openHours: '09:00 AM - 05:00 PM',
    priceLocalEgp: 40,
    priceForeignerEgp: 120,
    descriptionEn:
        'This small island-side outing combines a short Nile crossing with garden paths and informal animal displays. Ask locally about the day’s boat arrangements and park access, then keep a respectful distance from wildlife.',
    descriptionAr:
        'تجمع هذه النزهة الصغيرة بين عبور قصير للنيل وممرات حدائق وعروض حيوانات بسيطة. استفسر محلياً عن ترتيبات القارب وإتاحة المنتزه في يوم الزيارة، وحافظ على مسافة آمنة من الحيوانات.',
  )),
  _buildLuxorPlace((
    id: 'luxor_abu_haggag_mosque',
    nameEn: 'Abu Haggag Mosque',
    nameAr: 'مسجد أبو الحجاج',
    category: 'Mosques',
    lat: 25.7002,
    lng: 32.6395,
    areaEn: 'Luxor Temple precinct',
    areaAr: 'نطاق معبد الأقصر',
    openHours: '04:00 AM - 10:00 PM',
    priceLocalEgp: 0,
    priceForeignerEgp: 0,
    descriptionEn:
        'Built within the surviving walls of Luxor Temple, Abu Haggag Mosque reflects centuries of reuse at one sacred site. Its elevated position and minaret create a striking meeting of Islamic architecture and ancient Egyptian masonry.',
    descriptionAr:
        'شُيّد مسجد أبو الحجاج داخل الجدران الباقية لمعبد الأقصر، ويجسد تعاقب استخدامات المكان المقدس عبر القرون. يبرز موقعه المرتفع ومئذنته التقاء العمارة الإسلامية بالحجر المصري القديم.',
  )),
  _buildLuxorPlace((
    id: 'luxor_el_mekashkesh_mosque',
    nameEn: 'El Mekashkesh Mosque',
    nameAr: 'مسجد المكاشكش',
    category: 'Mosques',
    lat: 25.6980,
    lng: 32.6425,
    areaEn: 'Luxor town center',
    areaAr: 'وسط مدينة الأقصر',
    openHours: '04:00 AM - 10:00 PM',
    priceLocalEgp: 0,
    priceForeignerEgp: 0,
    descriptionEn:
        'This neighborhood mosque serves the busy streets around central Luxor and offers a quiet pause from the market lanes. Visitors should dress modestly and avoid entering during prayer unless welcomed by the congregation.',
    descriptionAr:
        'يخدم المسجد شوارع وسط الأقصر النشطة ويوفر مساحة هادئة بعيداً عن ممرات السوق. على الزوار ارتداء ملابس محتشمة وتجنب الدخول أثناء الصلاة ما لم ترحب بهم الجماعة.',
  )),
  _buildLuxorPlace((
    id: 'luxor_ahmed_el_negm_mosque',
    nameEn: 'Ahmed El Negm Mosque',
    nameAr: 'مسجد أحمد النجم',
    category: 'Mosques',
    lat: 25.7010,
    lng: 32.6455,
    areaEn: 'East Bank, Luxor',
    areaAr: 'البر الشرقي، الأقصر',
    openHours: '04:00 AM - 10:00 PM',
    priceLocalEgp: 0,
    priceForeignerEgp: 0,
    descriptionEn:
        'Located among East Bank homes and shops, Ahmed El Negm Mosque is a local place of worship rather than a ticketed attraction. Its everyday setting offers a respectful glimpse of contemporary religious life in Luxor.',
    descriptionAr:
        'يقع مسجد أحمد النجم بين مساكن ومحال البر الشرقي، وهو مكان عبادة محلي لا مزاراً بتذكرة. يتيح محيطه اليومي التعرف باحترام إلى الحياة الدينية المعاصرة في الأقصر.',
  )),
  _buildLuxorPlace((
    id: 'luxor_virgin_mary_cathedral',
    nameEn: 'Virgin Mary Cathedral',
    nameAr: 'كاتدرائية السيدة العذراء',
    category: 'Churches',
    lat: 25.7025,
    lng: 32.6432,
    areaEn: 'Luxor city',
    areaAr: 'مدينة الأقصر',
    openHours: '08:00 AM - 08:00 PM',
    priceLocalEgp: 0,
    priceForeignerEgp: 0,
    descriptionEn:
        'The cathedral is an active Christian worship center within modern Luxor, serving the city’s Coptic community. Check service times before entering and keep photography and movement considerate during prayer.',
    descriptionAr:
        'تُعد الكاتدرائية مركزاً نشطاً للعبادة المسيحية في الأقصر الحديثة وتخدم المجتمع القبطي بالمدينة. تحقق من مواعيد الصلوات قبل الدخول، وراعِ الهدوء والخصوصية أثناء العبادة.',
  )),
  _buildLuxorPlace((
    id: 'luxor_st_anthony_monastery_qurna',
    nameEn: 'St Anthony Monastery at Qurna',
    nameAr: 'دير الأنبا أنطونيوس بالقرنة',
    category: 'Churches',
    lat: 25.7145,
    lng: 32.6160,
    areaEn: 'Qurna, West Bank',
    areaAr: 'القرنة، البر الغربي',
    openHours: '08:00 AM - 08:00 PM',
    priceLocalEgp: 0,
    priceForeignerEgp: 0,
    descriptionEn:
        'This small Christian monastic site stands in the Qurna landscape near the Theban necropolis. Its quiet setting is a reminder that the west bank’s sacred geography continued beyond pharaonic temples and tombs.',
    descriptionAr:
        'يقع هذا الموقع الرهباني المسيحي الصغير في مشهد القرنة قرب جبانة طيبة. يذكر هدوؤه بأن جغرافية البر الغربي المقدسة استمرت بعد المعابد والمقابر الفرعونية.',
  )),
  _buildLuxorPlace((
    id: 'luxor_sofra_restaurant',
    nameEn: 'Sofra Restaurant',
    nameAr: 'مطعم سفرة',
    category: 'Food',
    lat: 25.6952,
    lng: 32.6418,
    areaEn: 'East Bank, Luxor',
    areaAr: 'البر الشرقي، الأقصر',
    openHours: '10:00 AM - 01:00 AM',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    descriptionEn:
        'Sofra serves Egyptian home-style dishes in a restored house with carved wood, patterned tiles, and a leafy courtyard. Order several shared plates to sample regional cooking in an intimate Old Luxor setting.',
    descriptionAr:
        'يقدم مطعم سفرة أطباقاً مصرية منزلية في بيت مُرمم يضم خشباً محفوراً وبلاطاً مزخرفاً وفناءً نباتياً. اطلب أطباقاً متنوعة للمشاركة وتذوق المطبخ المحلي في أجواء الأقصر القديمة.',
  )),
  _buildLuxorPlace((
    id: 'luxor_1886_restaurant_winter_palace',
    nameEn: '1886 Restaurant at Winter Palace',
    nameAr: 'مطعم ١٨٨٦ بقصر الشتاء',
    category: 'Food',
    lat: 25.6966,
    lng: 32.6373,
    areaEn: 'Winter Palace, Nile Corniche',
    areaAr: 'قصر الشتاء، كورنيش النيل',
    openHours: '10:00 AM - 01:00 AM',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    descriptionEn:
        'Set inside the historic Winter Palace, 1886 pairs formal dining rooms with the hotel’s grand colonial-era interiors. It is an occasion-focused choice for a long meal near the gardens and Nile-facing terraces.',
    descriptionAr:
        'يقع مطعم ١٨٨٦ داخل قصر الشتاء التاريخي، وتحيط به قاعات أنيقة وديكورات الفندق ذات الطابع الكلاسيكي. يناسب وجبة هادئة لمناسبة خاصة قرب الحدائق والشرفات المطلة على النيل.',
  )),
  _buildLuxorPlace((
    id: 'luxor_al_sahaby_lane_restaurant',
    nameEn: 'Al Sahaby Lane Restaurant',
    nameAr: 'مطعم السحابي لين',
    category: 'Food',
    lat: 25.7012,
    lng: 32.6408,
    areaEn: 'Al Sahaby Lane, East Bank',
    areaAr: 'ممر السحابي، البر الشرقي',
    openHours: '10:00 AM - 01:00 AM',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    descriptionEn:
        'This rooftop dining address looks across the East Bank rooftops toward Luxor Temple and the Nile. Egyptian grills and mezze are best enjoyed near sunset, when the skyline and temple lights become part of the view.',
    descriptionAr:
        'يطل المطعم من سطحه على أسطح البر الشرقي باتجاه معبد الأقصر والنيل. تمنح المشاوي والمقبلات المصرية تجربة أجمل قرب الغروب حين يضيء الأفق ومعبد الأقصر.',
  )),
  _buildLuxorPlace((
    id: 'luxor_marsam_west_bank_restaurant',
    nameEn: 'Marsam West Bank Restaurant',
    nameAr: 'مطعم مرسم بالبر الغربي',
    category: 'Food',
    lat: 25.7192,
    lng: 32.6115,
    areaEn: 'Qurna, West Bank',
    areaAr: 'القرنة، البر الغربي',
    openHours: '10:00 AM - 01:00 AM',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    descriptionEn:
        'The Marsam’s shaded garden dining room is close to the west-bank monuments and has long welcomed artists and archaeological travelers. Pause here for a cooked meal between visits to Qurna’s temples and tombs.',
    descriptionAr:
        'تقع قاعة الطعام المظللة في مرسم وسط حديقة قرب آثار البر الغربي، واستقبل المكان الفنانين والباحثين والزوار منذ زمن طويل. استرح هنا لتناول وجبة بين معابد القرنة ومقابرها.',
  )),
  _buildLuxorPlace((
    id: 'luxor_el_kababgy_nile_dining',
    nameEn: 'El Kababgy Nile Dining',
    nameAr: 'مطعم الكبابجي على النيل',
    category: 'Food',
    lat: 25.6915,
    lng: 32.6345,
    areaEn: 'Nile Corniche, Luxor',
    areaAr: 'كورنيش النيل، الأقصر',
    openHours: '10:00 AM - 01:00 AM',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    descriptionEn:
        'A Nile-facing dining room centers its menu on grilled meats, kofta, and Egyptian side dishes. Choose a table outdoors for river traffic and evening air, and ask about the day’s fish and seasonal offerings.',
    descriptionAr:
        'يركز المطعم المطل على النيل على اللحوم المشوية والكفتة والأطباق الجانبية المصرية. اختر طاولة خارجية لمتابعة حركة النهر والاستمتاع بنسيم المساء، واسأل عن السمك والأطباق الموسمية.',
  )),
  _buildLuxorPlace((
    id: 'luxor_gerda_garden_cafe',
    nameEn: 'Gerda Garden Cafe',
    nameAr: 'مقهى حديقة جيردا',
    category: 'Cafes',
    lat: 25.7095,
    lng: 32.6315,
    areaEn: 'East Bank, Luxor',
    areaAr: 'البر الشرقي، الأقصر',
    openHours: '10:00 AM - 01:00 AM',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    descriptionEn:
        'Gerda’s garden tables offer a relaxed stop for coffee, fresh juice, and light meals away from the busiest streets. The planted courtyard is especially welcome during a warm afternoon between museum and temple visits.',
    descriptionAr:
        'توفر طاولات حديقة جيردا مكاناً مريحاً للقهوة والعصائر الطازجة والوجبات الخفيفة بعيداً عن الشوارع المزدحمة. يصبح الفناء المزروع ملاذاً لطيفاً في فترة الظهيرة بين زيارة المتحف والمعابد.',
  )),
  _buildLuxorPlace((
    id: 'luxor_oasis_cafe_karnak',
    nameEn: 'Oasis Cafe Karnak',
    nameAr: 'مقهى الواحة بالكرنك',
    category: 'Cafes',
    lat: 25.7165,
    lng: 32.6525,
    areaEn: 'Karnak, East Bank',
    areaAr: 'الكرنك، البر الشرقي',
    openHours: '10:00 AM - 01:00 AM',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    descriptionEn:
        'This Karnak-side cafe is a convenient pause for tea, cold drinks, and simple snacks before or after the temple grounds. Its neighborhood location gives visitors a glimpse of daily life beyond the archaeological entrance.',
    descriptionAr:
        'يقدم المقهى القريب من الكرنك الشاي والمشروبات الباردة والوجبات البسيطة قبل زيارة المعبد أو بعدها. يتيح موقعه في الحي رؤية جانب من الحياة اليومية خارج بوابة الموقع الأثري.',
  )),
  _buildLuxorPlace((
    id: 'luxor_tutankhamun_corniche_cafe',
    nameEn: 'Tutankhamun Corniche Cafe',
    nameAr: 'مقهى توت عنخ آمون بالكورنيش',
    category: 'Cafes',
    lat: 25.7042,
    lng: 32.6420,
    areaEn: 'Nile Corniche, East Bank',
    areaAr: 'كورنيش النيل، البر الشرقي',
    openHours: '10:00 AM - 01:00 AM',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    descriptionEn:
        'A casual cafe near the river promenade, suited to mint tea, coffee, or a light bite while watching the ferry crossings. Evening tables catch the cooler breeze and the changing reflections on the Nile.',
    descriptionAr:
        'يقع المقهى غير الرسمي قرب ممشى النيل، ويناسب شاي النعناع أو القهوة مع متابعة عبور العبارات. تستفيد الطاولات المسائية من النسيم الألطف وانعكاسات الضوء المتغيرة على الماء.',
  )),
  _buildLuxorPlace((
    id: 'luxor_tourist_bazaar_savoy',
    nameEn: 'Tourist Bazaar at Savoy',
    nameAr: 'بازار السياح عند السافوي',
    category: 'Shopping',
    lat: 25.6988,
    lng: 32.6412,
    areaEn: 'East Bank, Luxor',
    areaAr: 'البر الشرقي، الأقصر',
    openHours: '10:00 AM - 11:00 PM',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    descriptionEn:
        'The bazaar’s narrow lanes display alabaster figures, papyrus prints, scarves, and small souvenirs for visitors heading between the temple and riverfront. Compare workmanship and agree on a price before completing a purchase.',
    descriptionAr:
        'تعرض ممرات البازار الضيقة تماثيل الألباستر ومطبوعات البردي والأوشحة والهدايا الصغيرة بين المعبد وضفة النيل. قارن جودة الصناعة واتفق على السعر قبل إتمام الشراء.',
  )),
  _buildLuxorPlace((
    id: 'luxor_habiba_handweaving_gallery',
    nameEn: 'Habiba Handweaving Gallery',
    nameAr: 'معرض حبيبة للنسيج اليدوي',
    category: 'Shopping',
    lat: 25.6975,
    lng: 32.6405,
    areaEn: 'East Bank, Luxor',
    areaAr: 'البر الشرقي، الأقصر',
    openHours: '10:00 AM - 11:00 PM',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    descriptionEn:
        'Habiba presents handwoven textiles and locally made crafts, with a focus on work produced by Egyptian artisans. The gallery is a good place to learn about weaving techniques while choosing a practical keepsake.',
    descriptionAr:
        'يعرض معرض حبيبة المنسوجات اليدوية والحرف المحلية مع الاهتمام بمنتجات الحرفيين المصريين. يمكنك التعرف إلى تقنيات النسيج واختيار تذكار عملي في الوقت نفسه.',
  )),
  _buildLuxorPlace((
    id: 'luxor_qurna_alabaster_workshops',
    nameEn: 'Qurna Alabaster Workshops',
    nameAr: 'ورش الألباستر بالقرنة',
    category: 'Shopping',
    lat: 25.7340,
    lng: 32.6155,
    areaEn: 'Qurna, West Bank',
    areaAr: 'القرنة، البر الغربي',
    openHours: '10:00 AM - 11:00 PM',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    descriptionEn:
        'Family workshops shape translucent alabaster into vessels and carved souvenirs using techniques associated with the west bank. Watch the stone being worked, ask about its source, and handle pieces in natural light to compare quality.',
    descriptionAr:
        'تشكل ورش عائلية حجر الألباستر الشفاف في أوانٍ وتذكارات محفورة بتقنيات اشتهرت بها الضفة الغربية. شاهد العمل على الحجر واسأل عن مصدره وقارن القطع في الضوء الطبيعي.',
  )),
  _buildLuxorPlace((
    id: 'luxor_fair_trade_craft_center',
    nameEn: 'Fair Trade Craft Center',
    nameAr: 'مركز الحرف والتجارة العادلة',
    category: 'Shopping',
    lat: 25.7055,
    lng: 32.6438,
    areaEn: 'East Bank, Luxor',
    areaAr: 'البر الشرقي، الأقصر',
    openHours: '10:00 AM - 11:00 PM',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    descriptionEn:
        'This craft center gathers handmade goods from small producers, including textiles, baskets, and gifts with regional patterns. Clear labeling and a calmer browsing setting make it useful for travelers seeking locally made alternatives.',
    descriptionAr:
        'يجمع المركز منتجات يدوية من صناع صغار، منها المنسوجات والسلال والهدايا ذات الزخارف المحلية. تساعد البطاقات الواضحة وأجواء التسوق الهادئة المسافر على اختيار بدائل مصنوعة محلياً.',
  )),
  _buildLuxorPlace((
    id: 'luxor_sofitel_winter_palace',
    nameEn: 'Sofitel Winter Palace Luxor',
    nameAr: 'سوفتيل وينتر بالاس الأقصر',
    category: 'Hotels',
    lat: 25.6968,
    lng: 32.6375,
    areaEn: 'Nile Corniche, East Bank',
    areaAr: 'كورنيش النيل، البر الشرقي',
    openHours: '24 hours',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    descriptionEn:
        'Opened in 1886, the Winter Palace is a landmark hotel set among gardens on the Nile Corniche, known for its historic interiors and royal-era associations. Its location makes the East Bank temples, museum, and river walks easy to reach.',
    descriptionAr:
        'افتُتح قصر الشتاء عام ١٨٨٦، وهو فندق تاريخي بين حدائق كورنيش النيل ارتبط بتاريخه بالضيوف الملكيين. يتيح موقعه الوصول بسهولة إلى معابد البر الشرقي والمتحف وممشى النهر.',
  )),
  _buildLuxorPlace((
    id: 'luxor_steigenberger_nile_palace',
    nameEn: 'Steigenberger Nile Palace',
    nameAr: 'شتايجنبرجر نايل بالاس',
    category: 'Hotels',
    lat: 25.6865,
    lng: 32.6312,
    areaEn: 'Khaled Ibn El Walid Street',
    areaAr: 'شارع خالد بن الوليد',
    openHours: '24 hours',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    descriptionEn:
        'This full-service Nile-side hotel places guest rooms, dining, and leisure facilities close to Luxor’s ferry crossings. The river-facing setting offers a convenient base for moving between the East Bank center and West Bank sites.',
    descriptionAr:
        'يوفر الفندق المطل على النيل غرفاً ومطاعم ومرافق ترفيهية قرب مراسي العبارات في الأقصر. يجعل موقعه النهري قاعدة مريحة للتنقل بين وسط البر الشرقي ومواقع البر الغربي.',
  )),
  _buildLuxorPlace((
    id: 'luxor_sonesta_st_george',
    nameEn: 'Sonesta St George Hotel Luxor',
    nameAr: 'فندق سونستا سان جورج الأقصر',
    category: 'Hotels',
    lat: 25.6895,
    lng: 32.6332,
    areaEn: 'Nile Corniche, East Bank',
    areaAr: 'كورنيش النيل، البر الشرقي',
    openHours: '24 hours',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    descriptionEn:
        'Set along the central Corniche, this hotel combines Nile views with quick access to the city’s restaurants and boat landings. It is a useful base for guests planning early starts to the west-bank monuments.',
    descriptionAr:
        'يقع الفندق على الكورنيش المركزي ويجمع بين إطلالات النيل وسهولة الوصول إلى مطاعم المدينة ومراسي القوارب. يناسب الزوار الذين يخططون للانطلاق مبكراً إلى آثار البر الغربي.',
  )),
  _buildLuxorPlace((
    id: 'luxor_hilton_karnak_resort',
    nameEn: 'Hilton Luxor Resort & Spa',
    nameAr: 'منتجع وسبا هيلتون الأقصر',
    category: 'Hotels',
    lat: 25.7315,
    lng: 32.6562,
    areaEn: 'Karnak, Nile East Bank',
    areaAr: 'الكرنك، الضفة الشرقية للنيل',
    openHours: '24 hours',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    descriptionEn:
        'North of the city center, this resort sits beside the Nile with landscaped grounds and spa facilities. Its Karnak-side location suits travelers who want a quieter stay while remaining within reach of the temple precinct.',
    descriptionAr:
        'يقع المنتجع شمال وسط المدينة بمحاذاة النيل، وتحيط به حدائق منسقة ومرافق للسبا. يناسب موقعه قرب الكرنك من يبحث عن إقامة أهدأ مع بقاء مجمع المعبد قريباً.',
  )),
  _buildLuxorPlace((
    id: 'luxor_al_moudira_hotel_west_bank',
    nameEn: 'Al Moudira Hotel',
    nameAr: 'فندق الموديرا',
    category: 'Hotels',
    lat: 25.6950,
    lng: 32.5650,
    areaEn: 'West Bank, Hager Al-Dabbeya',
    areaAr: 'البر الغربي، حجر الدبابية',
    openHours: '24 hours',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    descriptionEn:
        'Al Moudira is a low-rise retreat on the West Bank, arranged around courtyards with handcrafted furnishings and regional architectural details. Staying here offers a slower rural setting away from the East Bank’s main streets.',
    descriptionAr:
        'يقع فندق الموديرا منخفض البناء في البر الغربي، وتحيط بأفنيته مفروشات يدوية وتفاصيل معمارية محلية. تمنح الإقامة فيه أجواء ريفية هادئة بعيداً عن شوارع البر الشرقي الرئيسية.',
  )),
  _buildLuxorPlace((
    id: 'luxor_jolie_ville_kings_island',
    nameEn: 'Jolie Ville Kings Island Luxor',
    nameAr: 'جولي فيل جزيرة الملوك بالأقصر',
    category: 'Hotels',
    lat: 25.6722,
    lng: 32.6258,
    areaEn: 'Kings Island, Nile',
    areaAr: 'جزيرة الملوك، النيل',
    openHours: '24 hours',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    descriptionEn:
        'This resort occupies a landscaped island in the Nile south of central Luxor, with gardens and broad river views. Boat connections and the island setting create a secluded base between visits to the city’s archaeological sites.',
    descriptionAr:
        'يشغل المنتجع جزيرة منسقة في النيل جنوب وسط الأقصر، وتحيط به حدائق وإطلالات واسعة على النهر. تمنح القوارب وموقع الجزيرة إقامة منعزلة بين جولات المواقع الأثرية.',
  )),
  _buildLuxorPlace((
    id: 'atm_nbe_luxor_temple_corniche',
    nameEn: 'NBE ATM, Luxor Temple Corniche',
    nameAr: 'صراف البنك الأهلي، كورنيش معبد الأقصر',
    category: 'ATMs',
    lat: 25.6985,
    lng: 32.6388,
    areaEn: 'Luxor Temple Corniche',
    areaAr: 'كورنيش معبد الأقصر',
    openHours: '24 hours',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    descriptionEn:
        'This National Bank of Egypt cash point is positioned by the busy temple-side Corniche, convenient for visitors before river transport or nearby shops. Check your card’s fees and withdrawal limits with your bank before using an overseas card.',
    descriptionAr:
        'تقع ماكينة البنك الأهلي قرب كورنيش معبد الأقصر النشط، وتفيد الزوار قبل استخدام القوارب أو التسوق في الجوار. تحقق من رسوم بطاقتك وحدود السحب لدى مصرفك قبل استخدام بطاقة أجنبية.',
  )),
  _buildLuxorPlace((
    id: 'atm_banque_misr_karnak_plaza',
    nameEn: 'Banque Misr ATM, Karnak Plaza',
    nameAr: 'صراف بنك مصر، ساحة الكرنك',
    category: 'ATMs',
    lat: 25.7175,
    lng: 32.6545,
    areaEn: 'Karnak Plaza',
    areaAr: 'ساحة الكرنك',
    openHours: '24 hours',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    descriptionEn:
        'The Banque Misr machine serves the Karnak neighborhood near the temple approach and local businesses. Cash availability can change through the day, so keep a second payment option when traveling beyond the central East Bank.',
    descriptionAr:
        'تخدم ماكينة بنك مصر حي الكرنك قرب مدخل المعبد والمتاجر المحلية. قد يتغير توفر النقد خلال اليوم، لذلك احتفظ بوسيلة دفع بديلة عند التوجه إلى مناطق أبعد من البر الشرقي.',
  )),
  _buildLuxorPlace((
    id: 'atm_cib_winter_palace_luxor',
    nameEn: 'CIB ATM, Winter Palace Luxor',
    nameAr: 'صراف البنك التجاري الدولي، قصر الشتاء',
    category: 'ATMs',
    lat: 25.6962,
    lng: 32.6378,
    areaEn: 'Winter Palace, East Bank',
    areaAr: 'قصر الشتاء، البر الشرقي',
    openHours: '24 hours',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    descriptionEn:
        'This CIB cash point is close to the Winter Palace and the Corniche’s hotels and restaurants. It is a practical stop in the central visitor district; verify exchange rates and fees on the ATM screen before confirming.',
    descriptionAr:
        'تقع ماكينة البنك التجاري الدولي قرب قصر الشتاء وفنادق ومطاعم الكورنيش. تفيد في منطقة الزوار المركزية؛ راجع سعر الصرف والرسوم على شاشة الصراف قبل تأكيد العملية.',
  )),
  _buildLuxorPlace((
    id: 'atm_qnb_luxor_station_square',
    nameEn: 'QNB ATM, Luxor Station Square',
    nameAr: 'صراف بنك قطر الوطني، ميدان محطة الأقصر',
    category: 'ATMs',
    lat: 25.6965,
    lng: 32.6442,
    areaEn: 'Luxor Station Square',
    areaAr: 'ميدان محطة الأقصر',
    openHours: '24 hours',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    descriptionEn:
        'Near the railway station, this QNB machine is useful for travelers arriving by train or walking through the central market district. Use a well-lit location and retain the transaction receipt if a withdrawal needs follow-up.',
    descriptionAr:
        'تقع ماكينة بنك قطر الوطني قرب محطة السكك الحديدية وتفيد القادمين بالقطار أو المتجولين في السوق المركزي. اختر موقعاً مضاءً واحتفظ بإيصال العملية إذا احتجت إلى مراجعة السحب.',
  )),
  _buildLuxorPlace((
    id: 'atm_nbe_west_bank_ferry_qurna',
    nameEn: 'NBE ATM, West Bank Ferry at Qurna',
    nameAr: 'صراف البنك الأهلي، عبّارة القرنة بالبر الغربي',
    category: 'ATMs',
    lat: 25.7068,
    lng: 32.6312,
    areaEn: 'West Bank Ferry Landing',
    areaAr: 'مرسى عبّارات البر الغربي',
    openHours: '24 hours',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    descriptionEn:
        'This National Bank of Egypt machine is near the West Bank ferry crossing, a handy cash stop before continuing toward Qurna. Ferry schedules and machine service may vary, so carry enough small notes for local transport.',
    descriptionAr:
        'تقع ماكينة البنك الأهلي قرب عبّارة البر الغربي، وهي محطة مناسبة للسحب قبل مواصلة الطريق إلى القرنة. قد تختلف مواعيد العبارات وخدمة الصراف، لذا احمل أوراقاً نقدية صغيرة للمواصلات المحلية.',
  )),
  _buildLuxorPlace((
    id: 'atm_banque_misr_steigenberger_luxor',
    nameEn: 'Banque Misr ATM, Steigenberger Luxor',
    nameAr: 'صراف بنك مصر، شتايجنبرجر الأقصر',
    category: 'ATMs',
    lat: 25.6872,
    lng: 32.6318,
    areaEn: 'Khaled Ibn El Walid Street',
    areaAr: 'شارع خالد بن الوليد',
    openHours: '24 hours',
    priceLocalEgp: null,
    priceForeignerEgp: null,
    descriptionEn:
        'The Banque Misr machine serves the hotel corridor along Khaled Ibn El Walid Street and the nearby Nile-side promenade. It is convenient for routine cash access, though foreign-card limits are set by both the ATM and the card issuer.',
    descriptionAr:
        'تخدم ماكينة بنك مصر منطقة الفنادق بشارع خالد بن الوليد والممشى القريب من النيل. توفر وصولاً سهلاً إلى النقد، مع العلم أن حدود البطاقة الأجنبية يحددها الصراف ومصرف البطاقة معاً.',
  )),
]);

final Map<String, PlaceModel> _luxorPlacesById = {
  for (final place in luxorSeedPlaces) place.id: place,
};

List<PlaceModel> _tourStops(List<String> placeIds) => [
  for (final id in placeIds) _luxorPlacesById[id]!,
];

final List<ItineraryModel>
luxorSeedItineraries = List<ItineraryModel>.unmodifiable([
  ItineraryModel(
    id: 'luxor_east_bank_royal_temples_trail',
    title: 'East Bank Royal Temples Trail',
    titleAr: 'مسار المعابد الملكية بالبر الشرقي',
    description:
        'Follow the ceremonial spine of ancient Thebes from Karnak to Luxor Temple and the Avenue of Sphinxes. Add the Luxor Museum for sculptures and finds that deepen the story of both sanctuaries.',
    descriptionAr:
        'اتبع محور طيبة الاحتفالي من الكرنك إلى معبد الأقصر وطريق الكباش. أضف متحف الأقصر لمشاهدة منحوتات ومكتشفات توضح تاريخ المجمعين.',
    duration: 'Full day',
    durationAr: 'يوم كامل',
    imageUrl: luxorImageUrls['luxor_karnak_temple']!,
    governorate: 'luxor',
    places: _tourStops([
      'luxor_karnak_temple',
      'luxor_avenue_of_sphinxes',
      'luxor_temple',
      'luxor_museum',
      'luxor_mummification_museum',
    ]),
  ),
  ItineraryModel(
    id: 'luxor_valley_of_kings_hatshepsut_trail',
    title: 'Valley of the Kings & Hatshepsut Trail',
    titleAr: 'مسار وادي الملوك ومعبد حتشبسوت',
    description:
        'Cross to the West Bank for royal tombs in the Valley of the Kings, then continue to Hatshepsut’s terraced temple at Deir el-Bahari. The route pairs painted burial chambers with a dramatic cliffside memorial.',
    descriptionAr:
        'اعبر إلى البر الغربي لزيارة المقابر الملكية في وادي الملوك، ثم تابع إلى معبد حتشبسوت المدرج بالدير البحري. يجمع المسار بين حجرات الدفن المزخرفة ومعبد جنائزي أمام المنحدرات.',
    duration: 'Full day',
    durationAr: 'يوم كامل',
    imageUrl: luxorImageUrls['luxor_hatshepsut_temple']!,
    governorate: 'luxor',
    places: _tourStops([
      'luxor_valley_of_the_kings',
      'luxor_tomb_of_tutankhamun',
      'luxor_tomb_of_ramesses_vi',
      'luxor_hatshepsut_temple',
      'luxor_colossi_of_memnon',
    ]),
  ),
  ItineraryModel(
    id: 'luxor_west_bank_medinet_habu_artisans',
    title: 'West Bank: Medinet Habu & Artisans',
    titleAr: 'البر الغربي: مدينة هابو والحرفيون',
    description:
        'Explore Ramesses III’s fortified temple at Medinet Habu before visiting the artisans’ village of Deir el-Medina and its painted tombs. Finish among the private chapels and workshops that reveal how west-bank communities lived.',
    descriptionAr:
        'استكشف معبد رمسيس الثالث المحصن بمدينة هابو، ثم زر قرية الحرفيين بدير المدينة ومقابرها الملونة. اختتم الجولة بين المقابر الخاصة والورش التي تكشف حياة مجتمعات البر الغربي.',
    duration: 'Full day',
    durationAr: 'يوم كامل',
    imageUrl: luxorImageUrls['luxor_medinet_habu']!,
    governorate: 'luxor',
    places: _tourStops([
      'luxor_medinet_habu',
      'luxor_ramesseum',
      'luxor_deir_el_medina',
      'luxor_sennedjem_tomb',
      'luxor_tombs_of_the_nobles',
    ]),
  ),
  ItineraryModel(
    id: 'luxor_museums_corniche_winter_palace',
    title: 'Museums, Corniche & Winter Palace',
    titleAr: 'المتاحف والكورنيش وقصر الشتاء',
    description:
        'Start with the Luxor Museum and Mummification Museum, then stroll the East Bank Corniche beside the river. The Winter Palace gardens and historic dining rooms make a graceful finish to this city-centered day.',
    descriptionAr:
        'ابدأ بمتحف الأقصر ومتحف التحنيط، ثم تجول على كورنيش البر الشرقي بمحاذاة النهر. تمنح حدائق قصر الشتاء وقاعاته التاريخية ختاماً هادئاً ليوم داخل المدينة.',
    duration: 'Half day',
    durationAr: 'نصف يوم',
    imageUrl: luxorImageUrls['luxor_museum']!,
    governorate: 'luxor',
    places: _tourStops([
      'luxor_museum',
      'luxor_mummification_museum',
      'luxor_nile_corniche',
      'luxor_sofitel_winter_palace',
      'luxor_1886_restaurant_winter_palace',
    ]),
  ),
  ItineraryModel(
    id: 'luxor_nile_sail_banana_island_bazaar',
    title: 'Nile Sail, Banana Island & Bazaar',
    titleAr: 'إبحار النيل وجزيرة الموز والبازار',
    description:
        'Take a traditional felucca across the Nile, pause among Banana Island’s groves, and return to browse the East Bank craft lanes. Plan the sail around daylight and agree on the boat fare before departure.',
    descriptionAr:
        'استقل مركباً شراعياً تقليدياً لعبور النيل، واسترح بين بساتين جزيرة الموز، ثم عد للتجول في ممرات الحرف بالبر الشرقي. رتّب الإبحار وفق ضوء النهار واتفق على الأجرة قبل الانطلاق.',
    duration: 'Half day',
    durationAr: 'نصف يوم',
    imageUrl: luxorImageUrls['luxor_banana_island']!,
    governorate: 'luxor',
    places: _tourStops([
      'luxor_felucca_sail_dock',
      'luxor_banana_island',
      'luxor_nile_corniche',
      'luxor_habiba_handweaving_gallery',
      'luxor_tourist_bazaar_savoy',
    ]),
  ),
  ItineraryModel(
    id: 'luxor_complete_thebes_east_to_west_tour',
    title: 'Complete Thebes: East to West',
    titleAr: 'طيبة كاملة: من البر الشرقي إلى الغربي',
    description:
        'Connect the East Bank sanctuaries at Karnak and Luxor with the royal and artisan landscapes across the river. This ambitious route includes the Valley of the Kings, Hatshepsut’s temple, Medinet Habu, and a sunset crossing.',
    descriptionAr:
        'اربط معابد الكرنك والأقصر في البر الشرقي بمشاهد الملوك والحرفيين عبر النهر. يشمل المسار الممتد وادي الملوك ومعبد حتشبسوت ومدينة هابو وعبوراً عند الغروب.',
    duration: 'Full day',
    durationAr: 'يوم كامل',
    imageUrl: luxorImageUrls['luxor_avenue_of_sphinxes']!,
    governorate: 'luxor',
    places: _tourStops([
      'luxor_karnak_temple',
      'luxor_avenue_of_sphinxes',
      'luxor_temple',
      'luxor_valley_of_the_kings',
      'luxor_hatshepsut_temple',
      'luxor_medinet_habu',
      'luxor_felucca_sail_dock',
    ]),
  ),
]);
