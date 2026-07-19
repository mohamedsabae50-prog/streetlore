import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../logic/locale_provider.dart';

class AppStrings {
  AppStrings._();

  static const Map<String, Map<String, String>> _v = {
    'nav_explore': {'en': 'Explore', 'ar': 'استكشاف'},
    'nav_tours': {'en': 'Tours', 'ar': 'الجولات'},
    'nav_saved': {'en': 'Saved', 'ar': 'المحفوظات'},
    'nav_profile': {'en': 'Profile', 'ar': 'حسابي'},

    'greet_morning': {'en': 'Good Morning', 'ar': 'صباح الخير'},
    'greet_afternoon': {'en': 'Good Afternoon', 'ar': 'مساء الخير'},
    'greet_evening': {'en': 'Good Evening', 'ar': 'مساء الخير'},
    'compass_title': {'en': 'Compass direction', 'ar': 'اتجاه البوصلة'},
    'compass_sub': {
      'en':
          'Discover the city with a sweeping animated compass that grows into place.',
      'ar': 'اكتشف المدينة ببوصلة متحركة تنساب إلى مكانها.',
    },
    'search_hint': {
      'en': 'Search places, landmarks...',
      'ar': 'ابحث عن أماكن أو معالم...',
    },
    'featured': {'en': 'Featured', 'ar': 'مميز'},
    'see_all': {'en': 'See all', 'ar': 'عرض الكل'},
    'filter_open_now': {'en': 'Open Now', 'ar': 'مفتوح الآن'},
    'filter_cheapest': {'en': 'Cheapest', 'ar': 'الأرخص'},
    'filter_nearest': {'en': 'Nearest', 'ar': 'الأقرب'},
    'filter_free': {'en': 'Free only', 'ar': 'المجاني فقط'},
    'filter_hidden_gems': {'en': 'Hidden Gems', 'ar': 'جواهر مخفية'},
    'all_places': {'en': 'All Places', 'ar': 'كل الأماكن'},
    'places_count': {'en': '{n} places', 'ar': '{n} مكان'},
    'no_places': {'en': 'No places found', 'ar': 'لا توجد أماكن'},
    'no_results_for': {'en': 'No results for "{q}"', 'ar': 'لا نتائج عن "{q}"'},
    'try_different': {
      'en': 'Try a different name or category',
      'ar': 'جرّب اسمًا أو فئة مختلفة',
    },
    'results_for': {'en': '{n} results for "{q}"', 'ar': '{n} نتيجة عن "{q}"'},
    'discover': {'en': 'Discover', 'ar': 'اكتشف'},

    'cat_all': {'en': 'All', 'ar': 'الكل'},
    'cat_historical': {'en': 'Historical', 'ar': 'تاريخي'},
    'cat_culture': {'en': 'Culture', 'ar': 'ثقافة'},
    'cat_nature': {'en': 'Nature', 'ar': 'طبيعة'},
    'cat_food': {'en': 'Food', 'ar': 'أكل'},
    'cat_shopping': {'en': 'Shopping', 'ar': 'تسوق'},
    'cat_mosques': {'en': 'Mosques', 'ar': 'مساجد'},
    'cat_churches': {'en': 'Churches', 'ar': 'كنائس'},
    'cat_streets': {'en': 'Streets', 'ar': 'شوارع'},

    'quick_ai_trip': {'en': 'AI Trip', 'ar': 'رحلة ذكية'},
    'quick_best_time': {'en': 'Best Time', 'ar': 'أفضل وقت'},
    'quick_map': {'en': 'Map', 'ar': 'الخريطة'},
    'quick_currency': {'en': 'Currency', 'ar': 'العملات'},
    'quick_transport': {'en': 'Transport', 'ar': 'المواصلات'},
    'quick_journal': {'en': 'Journal', 'ar': 'اليوميات'},
    'quick_ranking': {'en': 'Ranking', 'ar': 'الترتيب'},
    'quick_offline': {'en': 'Offline', 'ar': 'أوفلاين'},
    'quick_nearby': {'en': 'Nearby', 'ar': 'بالقرب'},
    'quick_chat': {'en': 'Live Chat', 'ar': 'دردشة مباشرة'},

    'weather_feels': {
      'en': 'feels {t}° · {h}% humidity',
      'ar': 'الإحساس {t}° · رطوبة {h}%',
    },

    'lb_subtitle': {
      'en': 'Most travelled in Alexandria',
      'ar': 'الأكثر تنقلًا في الإسكندرية',
    },
    'lb_title': {'en': 'Leaderboard', 'ar': 'الترتيب'},
    'lb_your_rank': {'en': 'YOUR RANK', 'ar': 'ترتيبك'},
    'lb_points_level': {'en': '{p} points · {l}', 'ar': '{p} نقطة · {l}'},
    'stat_visited': {'en': 'Visited', 'ar': 'زيارات'},
    'stat_reviews': {'en': 'Reviews', 'ar': 'تقييمات'},
    'lb_empty': {
      'en': 'No leaderboard data yet',
      'ar': 'لا توجد بيانات للترتيب بعد',
    },
    'lb_row_sub': {
      'en': '{v} visited · {r} reviews',
      'ar': '{v} زيارة · {r} تقييم',
    },

    'level_explorer': {'en': 'Explorer', 'ar': 'مستكشف'},
    'level_wanderer': {'en': 'Wanderer', 'ar': 'متجوّل'},
    'level_cartographer': {'en': 'Cartographer', 'ar': 'رسّام خرائط'},
    'level_lorekeeper': {'en': 'Lorekeeper', 'ar': 'حافظ الحكايات'},

    'prof_saved': {'en': 'Saved', 'ar': 'محفوظ'},
    'prof_explored': {'en': 'Explored', 'ar': 'تم استكشافه'},
    'prof_tours': {'en': 'Tours', 'ar': 'جولات'},
    'dark_mode': {'en': 'Dark Mode', 'ar': 'الوضع الداكن'},
    'push_notif': {'en': 'Push Notifications', 'ar': 'الإشعارات'},
    'push_notif_sub': {
      'en': 'Get tips and discoveries',
      'ar': 'نصائح واكتشافات جديدة',
    },
    'location_services': {'en': 'Location Services', 'ar': 'خدمات الموقع'},
    'location_services_sub': {
      'en': 'Used for nearby recommendations',
      'ar': 'تُستخدم لاقتراح أماكن قريبة',
    },
    'language': {'en': 'Language', 'ar': 'اللغة'},
    'clear_saved': {'en': 'Clear Saved Places', 'ar': 'مسح الأماكن المحفوظة'},
    'export_data': {'en': 'Export My Data', 'ar': 'تصدير بياناتي'},
    'export_data_sub': {
      'en': 'Download your saved collection',
      'ar': 'حمّل مجموعتك المحفوظة',
    },
    'export_soon': {
      'en': 'Export feature coming soon!',
      'ar': 'ميزة التصدير قادمة قريبًا!',
    },
    'emergency_info': {'en': 'Emergency Info', 'ar': 'معلومات الطوارئ'},
    'emergency_info_sub': {
      'en': 'Hospitals, embassies, hotlines',
      'ar': 'مستشفيات وسفارات وخطوط ساخنة',
    },
    'map_view': {'en': 'Map View', 'ar': 'عرض الخريطة'},
    'map_view_sub': {
      'en': 'All 42 places on interactive map',
      'ar': 'كل الأماكن على خريطة تفاعلية',
    },
    'currency_converter': {'en': 'Currency Converter', 'ar': 'محوّل العملات'},
    'currency_converter_sub': {
      'en': 'EGP ↔ USD, EUR, GBP, SAR + more',
      'ar': 'جنيه ↔ دولار، يورو، إسترليني، ريال وأكثر',
    },
    'public_transport': {'en': 'Public Transport', 'ar': 'المواصلات العامة'},
    'public_transport_sub': {
      'en': 'Microbuses, buses & taxis in Alexandria',
      'ar': 'ميكروباص وأتوبيسات وتاكسي في الإسكندرية',
    },
    'travel_journal': {'en': 'Travel Journal', 'ar': 'يوميات السفر'},
    'travel_journal_sub': {
      'en': 'Save memories, notes & photos',
      'ar': 'احفظ الذكريات والملاحظات والصور',
    },
    'help_center': {'en': 'Help Center', 'ar': 'مركز المساعدة'},
    'help_center_sub': {'en': 'FAQs and support', 'ar': 'أسئلة شائعة ودعم'},
    'rate_app': {'en': 'Rate Streetlore', 'ar': 'قيّم ستريت لور'},
    'rate_app_sub': {'en': 'Share your experience', 'ar': 'شاركنا تجربتك'},
    'rate_thanks': {
      'en': 'Thank you for your support! ',
      'ar': 'شكرًا لدعمك! ',
    },
    'about_app': {'en': 'About Streetlore', 'ar': 'عن ستريت لور'},
    'version': {'en': 'Version 2.0.0', 'ar': 'الإصدار 2.0.0'},
    'saved_cleared': {
      'en': 'All saved places cleared.',
      'ar': 'تم مسح كل الأماكن المحفوظة.',
    },
    'free_banner_title': {'en': 'Everything is free', 'ar': 'كل حاجة مجانية'},
    'free_banner_sub': {
      'en': 'All tours, places & guides are unlocked for everyone.',
      'ar': 'كل الجولات والأماكن والمرشدين متاحين للجميع.',
    },
    'streak_start': {'en': 'Start your streak', 'ar': 'ابدأ سلسلتك'},
    'streak_days': {'en': '{n} visits streak', 'ar': 'ستريك {n} زيارة'},
    'streak_best': {
      'en': 'Best: {b} · {t} day{s} total',
      'ar': 'الأفضل: {b} · إجمالي {t} يوم',
    },
    'streak_begin': {
      'en': 'Check in at any place to begin',
      'ar': 'سجّل زيارتك في أي مكان للبدء',
    },
    'section_app_settings': {'en': 'App Settings', 'ar': 'إعدادات التطبيق'},
    'section_data_privacy': {
      'en': 'Data & Privacy',
      'ar': 'البيانات والخصوصية',
    },
    'section_about': {'en': 'About', 'ar': 'حول'},
    'dark_theme_on': {'en': 'Dark theme enabled', 'ar': 'الوضع الداكن مفعّل'},
    'light_theme_on': {'en': 'Light theme active', 'ar': 'الوضع الفاتح مفعّل'},
    'places_in_collection': {
      'en': '{n} places in your collection',
      'ar': '{n} مكان في مجموعتك',
    },
    'clear_all_saved_q': {'en': 'Clear All Saved?', 'ar': 'مسح كل المحفوظات؟'},
    'clear_all_warning': {
      'en':
          'This will permanently remove all saved places. This cannot be undone.',
      'ar': 'سيتم حذف كل الأماكن المحفوظة نهائيًا. لا يمكن التراجع عن هذا.',
    },
    'help_contact': {
      'en':
          'For support, contact us at:\nsupport@streetlore.com\n\nWe reply within 24 hours.',
      'ar':
          'للدعم، تواصل معنا على:\nsupport@streetlore.com\n\nنرد خلال 24 ساعة.',
    },
    'got_it': {'en': 'Got it', 'ar': 'فهمت'},
    'sign_out': {'en': 'Sign Out', 'ar': 'تسجيل الخروج'},
    'sign_out_q': {'en': 'Sign Out?', 'ar': 'تسجيل الخروج؟'},
    'sign_out_sub': {
      'en':
          'Are you sure you want to sign out? Your saved places will be preserved.',
      'ar': 'هل أنت متأكد؟ أماكنك المحفوظة ستبقى كما هي.',
    },

    'saved_collection': {'en': 'Your collection', 'ar': 'مجموعتك'},
    'saved_title': {'en': 'Saved', 'ar': 'المحفوظات'},
    'tab_places': {'en': 'Places', 'ar': 'أماكن'},
    'tab_tours': {'en': 'Tours', 'ar': 'جولات'},
    'no_saved_places': {'en': 'No Saved Places', 'ar': 'لا توجد أماكن محفوظة'},
    'discover_places': {'en': 'Discover Places', 'ar': 'اكتشف الأماكن'},
    'switch_explore': {
      'en': 'Switch to the Explore tab to discover places!',
      'ar': 'انتقل إلى تبويب استكشاف لاكتشاف الأماكن!',
    },
    'clear': {'en': 'Clear', 'ar': 'مسح'},
    'undo': {'en': 'Undo', 'ar': 'تراجع'},
    'clear_all_title': {
      'en': 'Clear All Saved Places?',
      'ar': 'مسح كل الأماكن المحفوظة؟',
    },
    'cancel': {'en': 'Cancel', 'ar': 'إلغاء'},
    'no_saved_tours': {'en': 'No Saved Tours', 'ar': 'لا توجد جولات محفوظة'},
    'browse_tours': {'en': 'Browse Tours', 'ar': 'تصفح الجولات'},
    'switch_tours': {
      'en': 'Switch to the Tours tab to discover tours!',
      'ar': 'انتقل إلى تبويب الجولات لاكتشافها!',
    },
    'remove': {'en': 'Remove', 'ar': 'إزالة'},
    'empty_saved_places_sub': {
      'en':
          'Start exploring and tap the bookmark icon on any place to save it here for easy access.',
      'ar':
          'ابدأ الاستكشاف واضغط على أيقونة الحفظ في أي مكان لحفظه هنا للوصول السريع.',
    },
    'removed_from_saved': {
      'en': '{name} removed from saved places',
      'ar': 'تمت إزالة {name} من المحفوظات',
    },
    'empty_saved_tours_sub': {
      'en':
          'Tap the download icon on any tour to save it here for offline access.',
      'ar': 'اضغط على أيقونة التحميل في أي جولة لحفظها هنا للوصول بدون إنترنت.',
    },

    'tours_subtitle': {'en': 'Curated for you', 'ar': 'مختارة لك'},
    'tours_title': {'en': 'Guided Tours', 'ar': 'جولات إرشادية'},
    'no_tours': {'en': 'No tours yet', 'ar': 'لا توجد جولات بعد'},
    'loading_tours': {'en': 'Loading tours...', 'ar': 'جارٍ تحميل الجولات...'},
    'tours_available': {
      'en': '{n} tours available - all free',
      'ar': '{n} جولة متاحة - كلها مجانية',
    },

    'open_now': {'en': 'Open Now', 'ar': 'مفتوح الآن'},
    'closed': {'en': 'Closed', 'ar': 'مغلق'},
    'save': {'en': 'Save', 'ar': 'حفظ'},
    'saved': {'en': 'Saved', 'ar': 'محفوظ'},
    'visited': {'en': 'Visited', 'ar': 'تمت الزيارة'},
    'checkin_removed': {
      'en': 'Check-in removed',
      'ar': 'تم إلغاء تسجيل الزيارة',
    },
    'go': {'en': 'Go', 'ar': 'اذهب'},
    'checkin': {'en': 'Check-in', 'ar': 'تسجيل زيارة'},
    'checked_in_streak': {
      'en': 'Checked in! Streak: {n}',
      'ar': 'تم تسجيل الزيارة! ستريك {n}',
    },
    'badge_unlocked': {
      'en': 'Badge unlocked: {name} 🏅',
      'ar': 'شارة جديدة: {name} 🏅',
    },
    'badges_title': {'en': 'Badges', 'ar': 'الشارات'},
    'no_badges': {
      'en': 'Check in at places to earn badges',
      'ar': 'سجّل زياراتك للأماكن لتكسب الشارات',
    },
    'badge_streak_5': {'en': '5 Visits', 'ar': '5 زيارات'},
    'badge_streak_10': {'en': '10 Visits', 'ar': '10 زيارات'},
    'badge_streak_25': {'en': '25 Visits', 'ar': '25 زيارة'},
    'badge_streak_50': {'en': '50 Visits', 'ar': '50 زيارة'},
    'First Steps': {'en': 'First Steps', 'ar': 'الخطوات الأولى'},
    'write_review': {'en': 'Write Review', 'ar': 'اكتب تقييمًا'},
    'community_reviews': {'en': 'Community Reviews', 'ar': 'تقييمات المجتمع'},
    'no_reviews': {
      'en': 'No reviews yet. Be the first to share your story!',
      'ar': 'لا توجد تقييمات بعد. كن أول من يشارك قصته!',
    },
    'about_place': {'en': 'About this place', 'ar': 'عن هذا المكان'},
    'nearby_gems': {'en': 'Nearby Hidden Gems', 'ar': 'جواهر مخفية قريبة'},
    'experience': {'en': 'Experience', 'ar': 'التجربة'},
    'book_tour': {'en': 'Book a Tour', 'ar': 'احجز جولة'},
    'book_now': {'en': 'Book Now', 'ar': 'احجز الآن'},
    'share_app': {'en': 'Share Streetlore', 'ar': 'شارك ستريت لور'},
    'copy_link': {'en': 'Copy Link', 'ar': 'نسخ الرابط'},
    'message': {'en': 'Message', 'ar': 'رسالة'},
    'email': {'en': 'Email', 'ar': 'بريد'},
    'free_entry': {'en': 'Free entry', 'ar': 'دخول مجاني'},
    'budget_friendly': {'en': 'Budget-friendly', 'ar': 'مناسب للميزانية'},
    'standard_ticket': {'en': 'Standard ticket', 'ar': 'تذكرة عادية'},
    'premium_experience': {'en': 'Premium experience', 'ar': 'تجربة مميزة'},
    'egyptians': {'en': 'Egyptians', 'ar': 'مصريون'},
    'foreigners': {'en': 'Foreigners', 'ar': 'أجانب'},

    'photos': {'en': 'Photos', 'ar': 'الصور'},
    'add': {'en': 'Add', 'ar': 'أضف'},
    'add_photo_title': {'en': 'Add a photo', 'ar': 'أضف صورة'},
    'take_photo': {'en': 'Take photo', 'ar': 'التقط صورة'},
    'choose_gallery': {'en': 'Choose from gallery', 'ar': 'اختر من المعرض'},
    'first_photo': {
      'en': 'Be the first to share a photo',
      'ar': 'كن أول من يشارك صورة',
    },
    'rating_label': {'en': 'Rating', 'ar': 'التقييم'},
    'review_hint': {
      'en': 'Share your experience...',
      'ar': 'شاركنا تجربتك...',
    },
    'add_photo_btn': {'en': 'Add Photo', 'ar': 'أضف صورة'},
    'post_review': {'en': 'Post Review', 'ar': 'انشر التقييم'},
    'review_empty_warn': {
      'en': 'Please write a comment first',
      'ar': 'من فضلك اكتب تعليقًا أولًا',
    },
    'review_failed': {
      'en': 'Could not post review',
      'ar': 'تعذر نشر التقييم',
    },
    'delete_photo_q': {'en': 'Delete this photo?', 'ar': 'حذف هذه الصورة؟'},
    'delete': {'en': 'Delete', 'ar': 'حذف'},
  };

  static String level(BuildContext context, String levelName) =>
      tr(context, 'level_${levelName.toLowerCase()}');

  static String tr(
    BuildContext context,
    String key, [
    Map<String, String>? params,
  ]) {
    final code = Provider.of<LocaleProvider>(
      context,
      listen: false,
    ).locale.languageCode;
    var s = _v[key]?[code] ?? _v[key]?['en'] ?? key;
    if (params != null) {
      params.forEach((k, val) => s = s.replaceAll('{$k}', val));
    }
    return s;
  }
}

extension AppStringsX on BuildContext {
  String tr(String key, [Map<String, String>? params]) =>
      AppStrings.tr(this, key, params);
}
