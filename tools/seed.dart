// ignore_for_file: avoid_print

import 'package:supabase/supabase.dart';
import 'dart:io';

const _url = 'https://tbivoxyxclwjjspwsgvc.supabase.co';
const _anonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRiaXZveHl4Y2x3ampzcHdzZ3ZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQzMjA3NjMsImV4cCI6MjA5OTg5Njc2M30.uM9F6_O-ObiiVkF8hjQmsFovf3h4gTaode719u6bAnI';

Future<String> _readServiceKey() async {
  final fromEnv = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  print('');
  print('=== Supabase Service Role Key Required ===');
  print('Get it from: Supabase Dashboard -> Project Settings -> API -> service_role');
  print('Or paste anon key to attempt (may fail with RLS).');
  stdout.write('Paste service_role key (or Enter to use anon): ');
  final input = stdin.readLineSync();
  if (input == null || input.isEmpty) return '';
  return input.trim();
}

Future<void> main() async {
  print('--- Streetlore seed script ---');

  final serviceKey = await _readServiceKey();
  final useService = serviceKey.isNotEmpty;

  if (useService) {
    print('Using SERVICE_ROLE key (admin access).');
  } else {
    print('Using ANON key - place/tour writes may be blocked by RLS.');
  }

  final client = SupabaseClient(_url, useService ? serviceKey : _anonKey);

  final places = _places();
  final tours = _tours(places);

  print('Upserting ${places.length} places...');
  for (final p in places) {
    try {
      await client.from('places').upsert(p, onConflict: 'id');
      print('  + place ${p['id']} (${p['name']})');
    } catch (e) {
      print('  ! place ${p['id']} failed: $e');
    }
  }

  print('Upserting ${tours.length} tours...');
  for (final t in tours) {
    final stops = (t.remove('place_ids') as List).cast<String>();
    try {
      await client.from('tours').upsert(t, onConflict: 'id');
      await client.from('tour_places').delete().eq('tour_id', t['id']);
      final rows = <Map<String, dynamic>>[];
      for (var i = 0; i < stops.length; i++) {
        rows.add({'tour_id': t['id'], 'place_id': stops[i], 'position': i});
      }
      if (rows.isNotEmpty) {
        await client.from('tour_places').insert(rows);
      }
      print('  + tour ${t['id']} (${t['title']}) with ${stops.length} stops');
    } catch (e) {
      print('  ! tour ${t['id']} failed: $e');
    }
  }

  print('--- Done ---');
  client.dispose();
}

List<Map<String, dynamic>> _places() => [
  {
    'id': '1',
    'name': 'Qaitbay Citadel',
    'description':
        'بناها السلطان المملوكي قايتباي عام 1477م على الموقع الدقيق لأحد عجائب الدنيا السبع - منارة الإسكندرية. من أعلى أبراجها ترى البحر المتوسط.',
    'image_url':
        'https://images.unsplash.com/photo-1682090471391-413a38705abe?w=800&q=80',
    'rating': 4.7,
    'category': 'Historical',
    'lat': 31.2140,
    'lng': 29.8856,
    'address': 'كورنيش الإسكندرية، الأنفوشي',
    'open_hours': '9:00 AM - 5:00 PM',
    'review_count': 2847,
    'price_level': 'moderate',
    'price_note': 'Egyptian EGP 60, Foreigner EGP 200',
    'is_hidden_gem': false,
    'price_local_egp': 60,
    'price_foreigner_egp': 200,
    'is_featured': true,
  },
  {
    'id': '2',
    'name': 'Bibliotheca Alexandrina',
    'description':
        'تحفة معمارية حديثة على شكل قرص شمسي مائل. تضم 8 مليون كتاب، 4 متاحف، مسرح، ومعمل إعادة ترميم المخطوطات.',
    'image_url':
        'https://images.unsplash.com/photo-1644743094370-66d819c455fd?w=800&q=80',
    'rating': 4.8,
    'category': 'Culture',
    'lat': 31.2089,
    'lng': 29.9092,
    'address': 'الشاطبي، الإسكندرية',
    'open_hours': '10:00 AM - 7:00 PM',
    'review_count': 3421,
    'price_level': 'moderate',
    'price_note': 'Egyptian EGP 20, Foreigner EGP 150',
    'is_hidden_gem': false,
    'price_local_egp': 20,
    'price_foreigner_egp': 150,
    'is_featured': true,
  },
  {
    'id': '3',
    'name': 'Montaza Palace Gardens',
    'description':
        'مصطاف الأسرة المالكية المصرية لأكثر من قرن. يمتد على 150 فداناً من الحدائق المطلة على البحر.',
    'image_url':
        'https://images.unsplash.com/photo-1564507592333-c60657eea523?auto=format&fit=crop&w=800&q=80',
    'rating': 4.5,
    'category': 'Nature',
    'lat': 31.2885,
    'lng': 30.0159,
    'address': 'المنتزه، الإسكندرية',
    'open_hours': '8:00 AM - 9:00 PM',
    'review_count': 1654,
    'price_level': 'cheap',
    'price_note': 'Gardens: EG 10/EG 60, Palace: EG 25/EG 100',
    'is_hidden_gem': false,
    'price_local_egp': 10,
    'price_foreigner_egp': 60,
    'is_featured': true,
  },
  {
    'id': '4',
    'name': 'Catacombs of Kom el Shoqafa',
    'description':
        'مقابر صخرية تمتد ثلاثة طوابق تحت الأرض حُفرت في القرن الثاني الميلادي. تمزج بين الفن المصري والإغريقي والروماني.',
    'image_url':
        'https://images.unsplash.com/photo-1539650116574-75c0c6d73f6e?auto=format&fit=crop&w=800&q=80',
    'rating': 4.6,
    'category': 'Historical',
    'lat': 31.1834,
    'lng': 29.8985,
    'address': 'كرموز، الإسكندرية',
    'open_hours': '9:00 AM - 4:30 PM',
    'review_count': 1892,
    'price_level': 'cheap',
    'price_note': 'Egyptian EGP 25, Foreigner EGP 150',
    'is_hidden_gem': false,
    'price_local_egp': 25,
    'price_foreigner_egp': 150,
    'is_featured': true,
  },
  {
    'id': '5',
    'name': 'El-Nouzha Botanical Garden',
    'description':
        'أقدم حديقة عامة في إسكندرية أُسست عام 1892م. أشجار عمرها أكثر من 130 عاماً من أندر الأنواع.',
    'image_url':
        'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?auto=format&fit=crop&w=800&q=80',
    'rating': 4.2,
    'category': 'Nature',
    'lat': 31.2200,
    'lng': 29.9500,
    'address': 'النزهة، الإسكندرية',
    'open_hours': '8:00 AM - 6:00 PM',
    'review_count': 876,
    'price_level': 'cheap',
    'price_note': 'Egyptian EGP 5, Foreigner EGP 30',
    'is_hidden_gem': true,
    'price_local_egp': 5,
    'price_foreigner_egp': 30,
    'is_featured': false,
  },
  {
    'id': '6',
    'name': 'Anfushi Fish Market',
    'description':
        'تجربة حسية كاملة - سمك طازج من البحر مباشرة. اختر سمكتك، حددها بالكيلو، وسيُقدّمونها لك بعد دقائق.',
    'image_url':
        'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=800&q=80',
    'rating': 4.4,
    'category': 'Food',
    'lat': 31.2001,
    'lng': 29.9187,
    'address': 'كورنيش الأنفوشي، الإسكندرية',
    'open_hours': '12:00 PM - 12:00 AM',
    'review_count': 2103,
    'price_level': 'free',
    'price_note': 'Pay only for the seafood',
    'is_hidden_gem': false,
    'is_featured': true,
  },
  {
    'id': '7',
    'name': "Pompey's Pillar",
    'description':
        'عمود ضخم من الغرانيت الأحمر ارتفاعه 30 متراً نُصب عام 297م. جزء من معبد السيرابيوم العظيم.',
    'image_url':
        'https://images.unsplash.com/photo-1526481280693-3bfa7568e0f3?auto=format&fit=crop&w=800&q=80',
    'rating': 4.3,
    'category': 'Historical',
    'lat': 31.1891,
    'lng': 29.9042,
    'address': 'عمود السواري، كرموز، الإسكندرية',
    'open_hours': '9:00 AM - 4:30 PM',
    'review_count': 1234,
    'price_level': 'cheap',
    'price_note': 'Egyptian EGP 30, Foreigner EGP 150',
    'is_hidden_gem': false,
    'price_local_egp': 30,
    'price_foreigner_egp': 150,
    'is_featured': false,
  },
  {
    'id': '8',
    'name': 'Stanley Bridge & Corniche',
    'description':
        'جسر ستانلي - قوسه الأبيض الأنيق يمتد فوق البحر الأزرق. وجهة للحياة الليلية في الإسكندرية.',
    'image_url':
        'https://images.unsplash.com/photo-1519046904884-53103b34b206?auto=format&fit=crop&w=800&q=80',
    'rating': 4.5,
    'category': 'Nature',
    'lat': 31.2156,
    'lng': 29.9614,
    'address': 'ستانلي، الإسكندرية',
    'open_hours': 'Open 24 hours',
    'review_count': 1876,
    'price_level': 'free',
    'price_note': 'Open public',
    'is_hidden_gem': false,
    'is_featured': true,
  },
  {
    'id': '9',
    'name': 'Roman Amphitheatre (Kom el-Dikka)',
    'description':
        'أمفيثياتر روماني مغمور اكتُشف بالصدفة في الستينيات. يضم 13 صفاً من المدرجات الرخامية.',
    'image_url':
        'https://images.unsplash.com/photo-1564507592333-c60657eea523?auto=format&fit=crop&w=800&q=80',
    'rating': 4.4,
    'category': 'Historical',
    'lat': 31.1973,
    'lng': 29.9090,
    'address': 'كوم الدكة، الإسكندرية',
    'open_hours': '9:00 AM - 5:00 PM',
    'review_count': 1456,
    'price_level': 'cheap',
    'price_note': 'Egyptian EGP 25, Foreigner EGP 100',
    'is_hidden_gem': true,
    'price_local_egp': 25,
    'price_foreigner_egp': 100,
    'is_featured': false,
  },
  {
    'id': '10',
    'name': 'Abu Abbas al-Mursi Mosque',
    'description':
        'أجمل مسجد في إسكندرية بلا منازع. مئذنتان أنیقتان بأسلوب مغربي أندلسي.',
    'image_url':
        'https://images.unsplash.com/photo-1564769625392-651b2c4444a4?auto=format&fit=crop&w=800&q=80',
    'rating': 4.6,
    'category': 'Culture',
    'lat': 31.2028,
    'lng': 29.8904,
    'address': 'الأنفوشي، الإسكندرية',
    'open_hours': 'Open 24 hours',
    'review_count': 1234,
    'price_level': 'free',
    'price_note': 'Free, donations welcome',
    'is_hidden_gem': false,
    'is_featured': false,
  },
  {
    'id': '11',
    'name': 'Alexandria National Museum',
    'description':
        'قصر إيطالي الطراز 1926م يضم 1800 قطعة أثرية من كل العصور - فراعنة، يونان، رومان، أقباط، إسلام.',
    'image_url':
        'https://images.unsplash.com/photo-1531058020387-3be344556be6?auto=format&fit=crop&w=800&q=80',
    'rating': 4.5,
    'category': 'Historical',
    'lat': 31.2012,
    'lng': 29.9184,
    'address': 'طريق الحرية 110، الإسكندرية',
    'open_hours': '9:00 AM - 4:30 PM',
    'review_count': 987,
    'price_level': 'moderate',
    'price_note': 'Egyptian EGP 50, Foreigner EGP 200',
    'is_hidden_gem': false,
    'price_local_egp': 50,
    'price_foreigner_egp': 200,
    'is_featured': false,
  },
  {
    'id': '12',
    'name': 'Ras el-Tin Palace',
    'description':
        'أقدم القصور الملكية في إسكندرية بناه محمد علي باشا. شهد تنازل الملك فاروق عن العرش 1952م.',
    'image_url':
        'https://images.unsplash.com/photo-1576675784201-0e142b423952?auto=format&fit=crop&w=800&q=80',
    'rating': 4.3,
    'category': 'Historical',
    'lat': 31.1967,
    'lng': 29.8734,
    'address': 'رأس التين، الإسكندرية',
    'open_hours': 'Exterior only',
    'review_count': 654,
    'price_level': 'free',
    'price_note': 'Exterior only',
    'is_hidden_gem': false,
    'is_featured': false,
  },
  {
    'id': '13',
    'name': 'El-Atarin Bazaar',
    'description':
        'أقدم سوق في الإسكندرية - شوارع ضيقة مسقوفة تعود للعهد العثماني. بهارات، عطور، فضة، تحف.',
    'image_url':
        'https://images.unsplash.com/photo-1480796927426-f609979314bd?auto=format&fit=crop&w=800&q=80',
    'rating': 4.2,
    'category': 'Culture',
    'lat': 31.1987,
    'lng': 29.9104,
    'address': 'العطارين، الإسكندرية',
    'open_hours': '9:00 AM - 10:00 PM',
    'review_count': 1432,
    'price_level': 'free',
    'price_note': 'Open public',
    'is_hidden_gem': false,
    'is_featured': false,
  },
  {
    'id': '14',
    'name': 'Abu Qir Seafood Coast',
    'description':
        'شاطئ أبو قير - أطلال معبد أوزيريون، حصن أبو قير، ومطاعم السمك الطازج على البحر مباشرة.',
    'image_url':
        'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?auto=format&fit=crop&w=800&q=80',
    'rating': 4.5,
    'category': 'Food',
    'lat': 31.3073,
    'lng': 30.0605,
    'address': 'أبو قير، الإسكندرية',
    'open_hours': '10:00 AM - 11:00 PM',
    'review_count': 1234,
    'price_level': 'free',
    'price_note': 'Open coast',
    'is_hidden_gem': true,
    'is_featured': false,
  },
  {
    'id': '15',
    'name': 'Sidi Bishr Beach',
    'description':
        'شاطئ سيدي بشر - وجهة شعبية مفضلة لسكان الإسكندرية. مياه نظيفة ورمال ناعمة.',
    'image_url':
        'https://images.unsplash.com/photo-1530541930197-ff16ac917b0e?auto=format&fit=crop&w=800&q=80',
    'rating': 4.3,
    'category': 'Nature',
    'lat': 31.2408,
    'lng': 29.9817,
    'address': 'سيدي بشر، الإسكندرية',
    'open_hours': 'Open 24 hours',
    'review_count': 1987,
    'price_level': 'free',
    'price_note': 'Open public beach',
    'is_hidden_gem': false,
    'is_featured': false,
  },
  {
    'id': '16',
    'name': 'El-Horeyya Garden (Shallalat)',
    'description':
        'حديقة الحرية (الشلالات) - حديقة وسط المدينة ببحيرات ونوافير. مكان للتنزه العائلي.',
    'image_url':
        'https://images.unsplash.com/photo-1545558014-8692077e9d5c?auto=format&fit=crop&w=800&q=80',
    'rating': 4.1,
    'category': 'Nature',
    'lat': 31.2011,
    'lng': 29.9231,
    'address': 'محرم بك، الإسكندرية',
    'open_hours': '8:00 AM - 10:00 PM',
    'review_count': 765,
    'price_level': 'free',
    'price_note': 'Open public',
    'is_hidden_gem': false,
    'is_featured': false,
  },
  {
    'id': '17',
    'name': 'Anfushi Tombs',
    'description':
        'مقابر الأنفوشي - مقابر منحوتة في الصخر تعود للعصر البطلمي والروماني. أقل ازدحاماً من كوم الشقافة.',
    'image_url':
        'https://images.unsplash.com/photo-1568322445389-f64ac2515020?auto=format&fit=crop&w=800&q=80',
    'rating': 4.2,
    'category': 'Historical',
    'lat': 31.2015,
    'lng': 29.8881,
    'address': 'الأنفوشي، الإسكندرية',
    'open_hours': '9:00 AM - 4:00 PM',
    'review_count': 432,
    'price_level': 'cheap',
    'price_note': 'Egyptian EGP 30, Foreigner EGP 100',
    'is_hidden_gem': false,
    'price_local_egp': 30,
    'price_foreigner_egp': 100,
    'is_featured': false,
  },
  {
    'id': '18',
    'name': 'Eliyahu Hanavi Synagogue',
    'description':
        'كنيس إلياهو حناوي - أكبر كنيس في الشرق الأوسط. بُني 1850م. رمز التنوع الثقافي للإسكندرية.',
    'image_url':
        'https://images.unsplash.com/photo-1564507592333-c60657eea523?auto=format&fit=crop&w=800&q=80',
    'rating': 4.7,
    'category': 'Culture',
    'lat': 31.2009,
    'lng': 29.9092,
    'address': 'النبي دانيال، الإسكندرية',
    'open_hours': '10:00 AM - 12:00 PM (Sundays only)',
    'review_count': 567,
    'price_level': 'free',
    'price_note': 'Free, donations welcome',
    'is_hidden_gem': false,
    'is_featured': false,
  },
  {
    'id': '19',
    'name': 'Trianon Café & Restaurant',
    'description':
        'كافيه تريانون - أقدم كافيه في الإسكندرية منذ 1907م. قهوة إسبرسو أصلية وحلويات فرنسية.',
    'image_url':
        'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=800&q=80',
    'rating': 4.4,
    'category': 'Food',
    'lat': 31.1992,
    'lng': 29.9098,
    'address': 'شارع صفية زغلول، الإسكندرية',
    'open_hours': '7:00 AM - 12:00 AM',
    'review_count': 1567,
    'price_level': 'moderate',
    'price_note': 'Avg EGP 250 / person',
    'is_hidden_gem': false,
    'is_featured': false,
  },
  {
    'id': '20',
    'name': 'Elite Café',
    'description':
        'إيليت كافيه - كافيه كلاسيكي بديكور عتيق. مكان الأدباء والكتاب في الأربعينيات.',
    'image_url':
        'https://images.unsplash.com/photo-1521017432531-fbd92d768814?auto=format&fit=crop&w=800&q=80',
    'rating': 4.3,
    'category': 'Food',
    'lat': 31.2004,
    'lng': 29.9099,
    'address': 'الفلكي، الإسكندرية',
    'open_hours': '8:00 AM - 11:00 PM',
    'review_count': 987,
    'price_level': 'cheap',
    'price_note': 'Avg EGP 150 / person',
    'is_hidden_gem': false,
    'is_featured': false,
  },
  {
    'id': '21',
    'name': 'Zephyrion Restaurant',
    'description':
        'مطعم زيفيريون - أرقى مطعم للأسماك في الإسكندرية. فيلا قديمة على البحر مباشرة.',
    'image_url':
        'https://images.unsplash.com/photo-1559339352-11d035aa65de?auto=format&fit=crop&w=800&q=80',
    'rating': 4.6,
    'category': 'Food',
    'lat': 31.3085,
    'lng': 30.0636,
    'address': 'أبو قير، الإسكندرية',
    'open_hours': '12:00 PM - 12:00 AM',
    'review_count': 1789,
    'price_level': 'expensive',
    'price_note': 'Avg per person: EG 250/EG 600',
    'is_hidden_gem': false,
    'price_local_egp': 250,
    'price_foreigner_egp': 600,
    'is_featured': false,
  },
  {
    'id': '22',
    'name': 'Kadoura Seafood Restaurant',
    'description':
        'مطعم قدورة - أشهر مطعم سمك في الإسكندرية. أسس 1958م. الوصفة السرية في الصلصة.',
    'image_url':
        'https://images.unsplash.com/photo-1559329007-40df8a9345d8?auto=format&fit=crop&w=800&q=80',
    'rating': 4.5,
    'category': 'Food',
    'lat': 31.2142,
    'lng': 29.9231,
    'address': 'كورنيش بحري، الإسكندرية',
    'open_hours': '11:00 AM - 1:00 AM',
    'review_count': 2654,
    'price_level': 'moderate',
    'price_note': 'Avg per person: EG 200/EG 450',
    'is_hidden_gem': false,
    'price_local_egp': 200,
    'price_foreigner_egp': 450,
    'is_featured': false,
  },
  {
    'id': '23',
    'name': 'Abu Ashraf Seafood',
    'description':
        'أبو أشرف - محل صغير في أعماق الأنفوشي. الطوابير تبدأ قبل الفتح بساعة. الأسعار زهيدة والطعم أسطوري.',
    'image_url':
        'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=800&q=80',
    'rating': 4.6,
    'category': 'Food',
    'lat': 31.2011,
    'lng': 29.8897,
    'address': 'حي الأنفوشي، الإسكندرية',
    'open_hours': '1:00 PM - 10:00 PM',
    'review_count': 1987,
    'price_level': 'cheap',
    'price_note': 'Avg per person: EG 100/EG 250',
    'is_hidden_gem': true,
    'price_local_egp': 100,
    'price_foreigner_egp': 250,
    'is_featured': false,
  },
  {
    'id': '24',
    'name': 'Miami Beach Alexandria',
    'description':
        'شاطئ ميامي - سُمي بهذا الاسم من الأوروبيين في القرن العشرين لمياهه الفيروزية الشفافة.',
    'image_url':
        'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=800&q=80',
    'rating': 4.3,
    'category': 'Nature',
    'lat': 31.2625,
    'lng': 29.9981,
    'address': 'المندرة، الإسكندرية الشرقية',
    'open_hours': 'Open 24 hours',
    'review_count': 1567,
    'price_level': 'free',
    'price_note': 'Open public beach',
    'is_hidden_gem': false,
    'is_featured': false,
  },
  {
    'id': '25',
    'name': 'Agami Beach',
    'description':
        'شاطئ عجمي - 24 كم غرب الإسكندرية. المياه الأنقى على الساحل الإسكندراني.',
    'image_url':
        'https://images.unsplash.com/photo-1519046904884-53103b34b206?auto=format&fit=crop&w=800&q=80',
    'rating': 4.4,
    'category': 'Nature',
    'lat': 31.1833,
    'lng': 29.7017,
    'address': 'عجمي، غرب الإسكندرية',
    'open_hours': 'Open 24 hours',
    'review_count': 1345,
    'price_level': 'free',
    'price_note': 'Open public beach',
    'is_hidden_gem': false,
    'is_featured': false,
  },
  {
    'id': '26',
    'name': "El-Ma'amoura Beach",
    'description':
        'شاطئ المعمورة - في أقصى شرق الإسكندرية. شروق الشمس من البحر مباشرة.',
    'image_url':
        'https://images.unsplash.com/photo-1473177104440-ffee2f376098?auto=format&fit=crop&w=800&q=80',
    'rating': 4.2,
    'category': 'Nature',
    'lat': 31.2854,
    'lng': 30.0044,
    'address': 'المعمورة، شرق الإسكندرية',
    'open_hours': 'Open 24 hours',
    'review_count': 876,
    'price_level': 'free',
    'price_note': 'Open public beach',
    'is_hidden_gem': false,
    'is_featured': false,
  },
  {
    'id': '27',
    'name': 'Roman Cisterns of Alexandria',
    'description':
        'خزانات رومانية تحت شوارع الإسكندرية. 18 صفاً من الأعمدة الرخامية في ظلام شبه تام.',
    'image_url':
        'https://images.unsplash.com/photo-1533050487297-09b450131914?auto=format&fit=crop&w=800&q=80',
    'rating': 4.7,
    'category': 'Historical',
    'lat': 31.1995,
    'lng': 29.9078,
    'address': 'شارع النبي دانيال، وسط الإسكندرية',
    'open_hours': '9:00 AM - 4:00 PM',
    'review_count': 634,
    'price_level': 'cheap',
    'price_note': 'Egyptian EGP 25, Foreigner EGP 150',
    'is_hidden_gem': true,
    'price_local_egp': 25,
    'price_foreigner_egp': 150,
    'is_featured': false,
  },
  {
    'id': '28',
    'name': 'Latin Cemetery (El-Moqattam)',
    'description':
        'مقبرة اللاتين - أضرحة رخامية منحوتة بإيطاليين، فرنسيين، يونانيين من القرن التاسع عشر.',
    'image_url':
        'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?auto=format&fit=crop&w=800&q=80',
    'rating': 4.4,
    'category': 'Historical',
    'lat': 31.2031,
    'lng': 29.9274,
    'address': 'الحضرة، الإسكندرية',
    'open_hours': '9:00 AM - 3:00 PM',
    'review_count': 298,
    'price_level': 'free',
    'price_note': 'Open public',
    'is_hidden_gem': true,
    'is_featured': false,
  },
  {
    'id': '29',
    'name': 'El-Bourse (Cotton Exchange)',
    'description':
        'بورصة القطن - بناء عبقري 1909م كان قلب تجارة القطن العالمية.',
    'image_url':
        'https://images.unsplash.com/photo-1555992457-b8fefdd09069?auto=format&fit=crop&w=800&q=80',
    'rating': 4.2,
    'category': 'Culture',
    'lat': 31.1990,
    'lng': 29.9091,
    'address': 'شارع طلعت حرب، وسط الإسكندرية',
    'open_hours': '9:00 AM - 5:00 PM',
    'review_count': 445,
    'price_level': 'free',
    'price_note': 'Exterior only',
    'is_hidden_gem': false,
    'is_featured': false,
  },
  {
    'id': '30',
    'name': 'Pastroudi Restaurant',
    'description':
        'باسترودي - منذ 1923م. مطعم الملك فاروق المفضل. كانيلوني بالإسكالوب وكعكة شوكولاتة سرية.',
    'image_url':
        'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?auto=format&fit=crop&w=800&q=80',
    'rating': 4.3,
    'category': 'Food',
    'lat': 31.1988,
    'lng': 29.9089,
    'address': 'شارع الحرية (فؤاد سابقاً)، الإسكندرية',
    'open_hours': '12:00 PM - 11:00 PM',
    'review_count': 876,
    'price_level': 'moderate',
    'price_note': 'Avg per person: EG 200/EG 500',
    'is_hidden_gem': false,
    'price_local_egp': 200,
    'price_foreigner_egp': 500,
    'is_featured': false,
  },
  {
    'id': '31',
    'name': 'City Centre Alexandria',
    'description':
        'سيتي سنتر الإسكندرية - أكبر مجمع تجاري في المدينة. يضم كارفور، سينمات، مطاعم، ومحلات علامات تجارية عالمية.',
    'image_url':
        'https://images.unsplash.com/photo-1519567241046-7f570eee3ce6?auto=format&fit=crop&w=800&q=80',
    'rating': 4.5,
    'category': 'Shopping',
    'lat': 31.2210,
    'lng': 29.9440,
    'address': 'طريق 14 مايو، سيدي جابر، الإسكندرية',
    'open_hours': '10:00 AM - 12:00 AM',
    'review_count': 5432,
    'price_level': 'moderate',
    'price_note': 'Open public, prices vary',
    'is_hidden_gem': false,
    'is_featured': true,
  },
  {
    'id': '32',
    'name': 'San Stefano Grand Plaza',
    'description':
        'سان ستيفانو جراند بلازا - مول فاخر على البحر مباشرة. يضم محلات راقية ومطاعم بإطلالة بحرية.',
    'image_url':
        'https://images.unsplash.com/photo-1582539510883-4b35bb3a2d33?auto=format&fit=crop&w=800&q=80',
    'rating': 4.6,
    'category': 'Shopping',
    'lat': 31.2456,
    'lng': 29.9653,
    'address': 'سان ستيفانو، الإسكندرية',
    'open_hours': '10:00 AM - 12:00 AM',
    'review_count': 3876,
    'price_level': 'expensive',
    'price_note': 'No entry fee (mall)',
    'is_hidden_gem': false,
    'price_local_egp': 0,
    'price_foreigner_egp': 0,
    'is_featured': false,
  },
  {
    'id': '33',
    'name': 'Souq El-Gumrok',
    'description':
        'سوق الجمرك - سوق شعبي أصيل في قلب الإسكندرية القديمة. بهارات، تحف، ملابس تقليدية، وأسماك طازجة.',
    'image_url':
        'https://images.unsplash.com/photo-1555529669-e69e7aa0ba9a?auto=format&fit=crop&w=800&q=80',
    'rating': 4.3,
    'category': 'Shopping',
    'lat': 31.1998,
    'lng': 29.8978,
    'address': 'حي الجمرك، الإسكندرية',
    'open_hours': '8:00 AM - 10:00 PM',
    'review_count': 1234,
    'price_level': 'free',
    'price_note': 'Open public, pay for goods',
    'is_hidden_gem': true,
    'is_featured': false,
  },
  {
    'id': '34',
    'name': 'Al-Qaed Ibrahim Mosque',
    'description':
        'مسجد القائد إبراهيم - أكبر مساجد الإسكندرية وأشهرها. شُيد عام 1948م بأسلوب إسلامي حديث مميز. مئذنتان طويلتان تريان من بعيد.',
    'image_url':
        'https://images.unsplash.com/photo-1591604129939-f1efa4d9f7fa?auto=format&fit=crop&w=800&q=80',
    'rating': 4.7,
    'category': 'Mosques',
    'lat': 31.2031,
    'lng': 29.9143,
    'address': 'ميدان القائد إبراهيم، الإسكندرية',
    'open_hours': 'Open 24 hours',
    'review_count': 2143,
    'price_level': 'free',
    'price_note': 'Free, donations welcome',
    'is_hidden_gem': false,
    'is_featured': true,
  },
  {
    'id': '35',
    'name': 'Sidi Bishr Mosque',
    'description':
        'مسجد سيدي بشر - من أقدم مساجد الإسكندرية. يحتوي على ضريح الصحابي الجليل بُشر بن أبي ربيعة، أحد رواة الحديث.',
    'image_url':
        'https://images.unsplash.com/photo-1564769625392-651b2c4444a4?auto=format&fit=crop&w=800&q=80',
    'rating': 4.5,
    'category': 'Mosques',
    'lat': 31.2410,
    'lng': 29.9810,
    'address': 'سيدي بشر، الإسكندرية',
    'open_hours': 'Open 24 hours',
    'review_count': 987,
    'price_level': 'free',
    'price_note': 'Free, donations welcome',
    'is_hidden_gem': true,
    'is_featured': false,
  },
  {
    'id': '36',
    'name': 'Shatibi Mosque',
    'description':
        'مسجد الشاطبي - مسجد تاريخي على شاطئ البحر. يحكي تاريخ العائلة الشاطبية التي حكمت الإسكندرية في العصر العثماني.',
    'image_url':
        'https://images.unsplash.com/photo-1542816417-0983c9c9ad53?auto=format&fit=crop&w=800&q=80',
    'rating': 4.4,
    'category': 'Mosques',
    'lat': 31.2100,
    'lng': 29.9080,
    'address': 'الشاطبي، الإسكندرية',
    'open_hours': 'Open 24 hours',
    'review_count': 543,
    'price_level': 'free',
    'price_note': 'Free, donations welcome',
    'is_hidden_gem': true,
    'is_featured': false,
  },
  {
    'id': '37',
    'name': 'Raml Station Square',
    'description':
        'ميدان محطة الرمل - قلب الإسكندرية النابض. يلتقي فيه الترام القديم بالعمارة الإيطالية. نقطة التقاء كل المسارات في المدينة.',
    'image_url':
        'https://images.unsplash.com/photo-1503899036084-c55cdd92da26?auto=format&fit=crop&w=800&q=80',
    'rating': 4.4,
    'category': 'Streets',
    'lat': 31.2010,
    'lng': 29.9120,
    'address': 'ميدان محطة الرمل، الإسكندرية',
    'open_hours': 'Open 24 hours',
    'review_count': 2876,
    'price_level': 'free',
    'price_note': 'Open public',
    'is_hidden_gem': false,
    'is_featured': true,
  },
  {
    'id': '38',
    'name': 'Corniche Road (Tatweer)',
    'description':
        'كورنيش الإسكندرية - الممشى البحري الأشهر في مصر. يمتد 15 كم على شاطئ البحر المتوسط، مع مقاعد ومقاهي وإطلالات خلابة.',
    'image_url':
        'https://images.unsplash.com/photo-1545158535-c3f7168c28b6?auto=format&fit=crop&w=800&q=80',
    'rating': 4.7,
    'category': 'Streets',
    'lat': 31.2447,
    'lng': 29.9653,
    'address': 'كورنيش الإسكندرية من المنتزه إلى المنتزة',
    'open_hours': 'Open 24 hours',
    'review_count': 4521,
    'price_level': 'free',
    'price_note': 'Open public',
    'is_hidden_gem': false,
    'is_featured': true,
  },
  {
    'id': '39',
    'name': 'Fouad Street',
    'description':
        'شارع فؤاد (الحرية حالياً) - الشارع التجاري الأول في الإسكندرية منذ القرن التاسع عشر. يضم محلات تاريخية، مقاهي عتيقة، وفنادق ملكة مثل وندسور وكارلتون.',
    'image_url':
        'https://images.unsplash.com/photo-1480796927426-f609979314bd?auto=format&fit=crop&w=800&q=80',
    'rating': 4.3,
    'category': 'Streets',
    'lat': 31.1990,
    'lng': 29.9091,
    'address': 'شارع فؤاد (الحرية)، الإسكندرية',
    'open_hours': 'Open 24 hours',
    'review_count': 1654,
    'price_level': 'free',
    'price_note': 'Open public',
    'is_hidden_gem': false,
    'is_featured': false,
  },
  {
    'id': '40',
    'name': 'St. Mark Coptic Orthodox Cathedral',
    'description':
        'كاتدرائية القديس مرقس القبطية الأرثوذكسية - أقدم كنيسة قبطية في إفريقيا. شُيدت في القرن التاسع عشر. تضم مقام القديس مرقس، أحد رسل المسيح. المقر البابوي الثاني بعد القاهرة.',
    'image_url':
        'https://images.unsplash.com/photo-1709485400031-6094ea4f0bad?w=800&q=80',
    'rating': 4.7,
    'category': 'Churches',
    'lat': 31.2040,
    'lng': 29.9120,
    'address': 'حي الكوم الأخضر، الإسكندرية',
    'open_hours': '7:00 AM - 8:00 PM',
    'review_count': 1234,
    'price_level': 'free',
    'price_note': 'Free, donations welcome',
    'is_hidden_gem': false,
    'is_featured': true,
  },
  {
    'id': '41',
    'name': 'Our Lady of Lourdes Church',
    'description':
        'كنيسة سيدة لورد - كنيسة كاثوليكية رائعة بتصميم معماري فرنسي. شُيدت في القرن التاسع عشر. تتميز بنوافذها الزجاجية الملونة وقبابها المهيبة. تعتبر من أجمل الكنائس الكاثوليكية في الإسكندرية.',
    'image_url':
        'https://images.unsplash.com/photo-1735914773197-8881803666e5?w=800&q=80',
    'rating': 4.6,
    'category': 'Churches',
    'lat': 31.2010,
    'lng': 29.9092,
    'address': 'شارع صفية زغلول، الإسكندرية',
    'open_hours': '6:00 AM - 7:00 PM',
    'review_count': 765,
    'price_level': 'free',
    'price_note': 'Free, donations welcome',
    'is_hidden_gem': true,
    'is_featured': false,
  },
  {
    'id': '42',
    'name': "Saint Catherine's Cathedral",
    'description':
        'كاتدرائية القديسة كاترين - كنيسة أرثوذكسية يونانية بمعمار بيزنطي مميز. شُيدت في القرن التاسع عشر. تتميز بأيقوناتها المذهبة وقبابها الفريدة.',
    'image_url':
        'https://images.unsplash.com/photo-1557640047-75c97a5f1ea4?w=800&q=80',
    'rating': 4.5,
    'category': 'Churches',
    'lat': 31.2120,
    'lng': 29.9220,
    'address': 'سيدي جابر، الإسكندرية',
    'open_hours': '7:00 AM - 7:00 PM',
    'review_count': 543,
    'price_level': 'free',
    'price_note': 'Free, donations welcome',
    'is_hidden_gem': false,
    'is_featured': false,
  },
];

List<Map<String, dynamic>> _tours(List<Map<String, dynamic>> places) => [
  {
    'id': 't1',
    'title': 'Alexandria Historical Walk',
    'description':
        'جولة عبر الزمن من الحصن المملوكي إلى مقابر تحت الأرض إلى أمفيثياتر روماني.',
    'duration': '4 Hours',
    'image_url':
        'https://images.unsplash.com/photo-1572252009286-268acec5ca0a?auto=format&fit=crop&w=800&q=80',
    'place_ids': ['1', '4', '9'],
  },
  {
    'id': 't2',
    'title': 'Royal Gardens & Culture',
    'description':
        'حدائق المنتزه الملكية، مكتبة الإسكندرية الحديثة، المتحف الوطني.',
    'duration': '5 Hours',
    'image_url':
        'https://images.unsplash.com/photo-1564507592333-c60657eea523?auto=format&fit=crop&w=800&q=80',
    'place_ids': ['3', '2', '11'],
  },
  {
    'id': 't3',
    'title': 'Foodie Tour',
    'description': 'جولة في أفضل مطاعم السمك والقهوة في الإسكندرية.',
    'duration': '3 Hours',
    'image_url':
        'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?auto=format&fit=crop&w=800&q=80',
    'place_ids': ['6', '19', '23', '20', '22'],
  },
  {
    'id': 't4',
    'title': 'Hidden Alexandria',
    'description': 'الجانب المخفي من الإسكندرية - أماكن لا يعرفها السياح.',
    'duration': '4 Hours',
    'image_url':
        'https://images.unsplash.com/photo-1539650116574-75c0c6d73f6e?auto=format&fit=crop&w=800&q=80',
    'place_ids': ['27', '28', '5', '9'],
  },
  {
    'id': 't5',
    'title': 'Beach Day',
    'description': 'يوم شواطئ كاملة - من المعمورة شرقاً إلى عجمي غرباً.',
    'duration': 'Full Day',
    'image_url':
        'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=800&q=80',
    'place_ids': ['26', '15', '24', '25'],
  },
  {
    'id': 't6',
    'title': 'Religious & Cultural Diversity',
    'description':
        'تنوع الإسكندرية الديني والثقافي - مساجد، كنائس، معابد، مقابر.',
    'duration': '4 Hours',
    'image_url':
        'https://images.unsplash.com/photo-1564769625392-651b2c4444a4?auto=format&fit=crop&w=800&q=80',
    'place_ids': ['10', '18', '13'],
  },
];
