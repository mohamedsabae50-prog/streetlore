import 'alexandria_image_urls.dart';
import 'models/place_model.dart';

typedef _AlexandriaPlaceSpec = ({
  String id,
  String nameEn,
  String nameAr,
  String category,
  String categoryAr,
  double lat,
  double lng,
});

const List<_AlexandriaPlaceSpec> _alexandriaPlaceSpecs = [
  (
    id: 'alex_sadat_museum_bibliotheca',
    nameEn: 'Sadat Museum at Bibliotheca Alexandrina',
    nameAr: 'متحف السادات بمكتبة الإسكندرية',
    category: 'Culture',
    categoryAr: 'ثقافة',
    lat: 31.2084,
    lng: 29.9096,
  ),
  (
    id: 'alex_ras_el_tin_palace',
    nameEn: 'Ras El-Tin Palace',
    nameAr: 'قصر رأس التين',
    category: 'Historical',
    categoryAr: 'تاريخي',
    lat: 31.1995,
    lng: 29.8690,
  ),
  (
    id: 'alex_antoniadis_gardens',
    nameEn: 'Antoniadis Gardens',
    nameAr: 'حدائق أنطونيادس',
    category: 'Nature',
    categoryAr: 'طبيعة',
    lat: 31.2038,
    lng: 29.9478,
  ),
  (
    id: 'alex_mahmoud_said_museum',
    nameEn: 'Mahmoud Said Museum',
    nameAr: 'متحف محمود سعيد',
    category: 'Culture',
    categoryAr: 'ثقافة',
    lat: 31.2422,
    lng: 29.9658,
  ),
  (
    id: 'alex_eliyahu_hanavi_synagogue',
    nameEn: 'Eliyahu Hanavi Synagogue',
    nameAr: 'معبد إلياهو هانبي',
    category: 'Culture',
    categoryAr: 'ثقافة',
    lat: 31.1986,
    lng: 29.9018,
  ),
  (
    id: 'alex_shatby_ancient_tombs',
    nameEn: 'Shatby Ancient Tombs',
    nameAr: 'مقابر الشاطبي الأثرية',
    category: 'Historical',
    categoryAr: 'تاريخي',
    lat: 31.2112,
    lng: 29.9145,
  ),
  (
    id: 'alex_nelson_island_abou_qir',
    nameEn: 'Nelson Island, Abou Qir',
    nameAr: 'جزيرة نلسون بأبو قير',
    category: 'Nature',
    categoryAr: 'طبيعة',
    lat: 31.3550,
    lng: 30.1020,
  ),
];

List<PlaceModel> buildAdditionalAlexandriaPlaces() => [
  for (final spec in _alexandriaPlaceSpecs) _buildAlexandriaPlace(spec),
];

PlaceModel _buildAlexandriaPlace(_AlexandriaPlaceSpec spec) {
  final imageUrl = alexandriaImageUrls[spec.id] ?? '';
  return PlaceModel(
    id: spec.id,
    nameEn: spec.nameEn,
    nameAr: spec.nameAr,
    descriptionEn:
        '${spec.nameEn} is a notable ${spec.category.toLowerCase()} destination in Alexandria. Confirm current visitor information before your visit.',
    descriptionAr:
        '${spec.nameAr} من أبرز وجهات ${spec.categoryAr} في الإسكندرية. يُرجى التأكد من معلومات الزيارة الحالية قبل الذهاب.',
    imageUrl: imageUrl,
    imageUrls: [imageUrl],
    rating: 4.5,
    category: spec.category,
    categoryAr: spec.categoryAr,
    lat: spec.lat,
    lng: spec.lng,
    address: '${spec.nameEn}, Alexandria, Egypt',
    addressAr: '${spec.nameAr}، الإسكندرية، مصر',
    governorate: 'alexandria',
    openHours: 'Check current opening hours',
    priceNote: 'Check current prices and visitor access',
    priceNoteAr: 'يُرجى التحقق من الأسعار وإمكانية الزيارة',
  );
}
