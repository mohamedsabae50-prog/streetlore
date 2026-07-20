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
    'quick_transport': {'en': 'Transport', 'ar': 'المواصلات'},
    'quick_journal': {'en': 'Journal', 'ar': 'اليوميات'},
    'quick_ranking': {'en': 'Ranking', 'ar': 'الترتيب'},
    'quick_offline': {'en': 'Offline', 'ar': 'أوفلاين'},
    'quick_chat': {'en': 'Live Chat', 'ar': 'دردشة مباشرة'},

    'weather_feels': {
      'en': 'feels {t}° · {h}% humidity',
      'ar': 'الإحساس {t}° · رطوبة {h}%',
    },
    'weather_my_location': {'en': 'Use my location', 'ar': 'استخدم موقعي'},
    'location_denied': {
      'en': 'Location permission denied. Enable it to see local weather.',
      'ar': 'تم رفض إذن الموقع. فعّله لعرض طقس منطقتك.',
    },
    'refresh': {'en': 'Refresh', 'ar': 'تحديث'},
    'map_title': {'en': 'Map · {n} places', 'ar': 'الخريطة · {n} مكان'},
    'map_my_location': {'en': 'My location', 'ar': 'موقعي'},
    'community_chat': {'en': 'Community Chat', 'ar': 'دردشة المجتمع'},
    'community_chat_sub': {
      'en': 'Ask travelers about this place',
      'ar': 'اسأل المسافرين عن هذا المكان',
    },
    'ai_planner_title': {'en': 'Smart Trip Planner', 'ar': 'مخطط الرحلات الذكي'},
    'ai_planner_sub': {
      'en': "Describe your ideal Alexandria trip and we'll plan it.",
      'ar': 'صف رحلتك المثالية في إسكندرية وهنخططها لك.',
    },

    'lb_subtitle': {
      'en': 'Most travelled around the world',
      'ar': 'الأكثر تنقلًا حول العالم',
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
      'en': 'All places on interactive map',
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
    'tour_filter_all': {'en': 'All', 'ar': 'الكل'},
    'tour_filter_short': {'en': 'Up to 3h', 'ar': 'حتى 3 ساعات'},
    'tour_filter_half': {'en': 'Half day', 'ar': 'نصف يوم'},
    'tour_filter_full': {'en': 'Full day', 'ar': 'يوم كامل'},
    'tour_none_in_filter': {
      'en': 'No tours in this category',
      'ar': 'لا توجد جولات في هذه الفئة',
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
    'delete_review_q': {'en': 'Delete this review?', 'ar': 'حذف هذا التقييم؟'},
    'delete': {'en': 'Delete', 'ar': 'حذف'},
    'edit': {'en': 'Edit', 'ar': 'تعديل'},

    'trip_title': {'en': 'My Trip Planner', 'ar': 'مخطط رحلتي'},
    'trip_empty': {
      'en': 'Your trip is empty.\nAdd places from the explore screen!',
      'ar': 'رحلتك فاضية.\nضيف أماكن من شاشة الاستكشاف!',
    },
    'trip_places_planned': {
      'en': '{n} Places Planned',
      'ar': '{n} مكان مخطط',
    },
    'trip_clear_all': {'en': 'Clear All', 'ar': 'مسح الكل'},

    'offline_title': {'en': 'Offline Mode', 'ar': 'الوضع دون اتصال'},
    'offline_hero_title': {'en': 'Travel without signal', 'ar': 'سافر من غير شبكة'},
    'offline_mb_downloaded': {
      'en': '{n} MB downloaded',
      'ar': '{n} ميجابايت محمّلة',
    },
    'offline_downloaded': {'en': 'Downloaded', 'ar': 'المحمّلة'},
    'offline_available': {
      'en': 'Available to download',
      'ar': 'متاحة للتحميل',
    },
    'offline_pack_size': {
      'en': '{mb} MB · {n} places',
      'ar': '{mb} ميجابايت · {n} مكان',
    },
    'offline_download': {'en': 'Download', 'ar': 'تحميل'},

    'geo_title': {'en': 'Geofencing Alerts', 'ar': 'تنبيهات الموقع'},
    'geo_hero_title': {'en': 'Get notified nearby', 'ar': 'تنبيهات عند الاقتراب'},
    'geo_hero_sub': {
      'en': 'Choose the places you want alerts for - within 500m by default.',
      'ar': 'اختار الأماكن اللي عايز تنبيهات لها - في نطاق ٥٠٠ متر افتراضيًا.',
    },
    'geo_monitoring_on': {
      'en': 'Monitoring your location for nearby places',
      'ar': 'بنراقب موقعك للأماكن القريبة',
    },
    'geo_monitoring_off': {'en': 'Monitoring paused', 'ar': 'المراقبة متوقفة'},
    'geo_choose_places': {'en': 'Choose places', 'ar': 'اختار الأماكن'},
    'geo_distance': {
      'en': '{d} m from city center',
      'ar': '{d} م من وسط المدينة',
    },

    'chat_live': {'en': 'Live chat', 'ar': 'دردشة مباشرة'},
    'chat_empty': {
      'en': 'Be the first to say hi',
      'ar': 'كن أول واحد يقول أهلًا',
    },
    'chat_now': {'en': 'now', 'ar': 'الآن'},
    'chat_hint': {
      'en': 'Say something to fellow travellers...',
      'ar': 'قول حاجة للمسافرين اللي معاك...',
    },

    'map_err_location_denied': {
      'en': 'Location permission is required to show the route.',
      'ar': 'يجب الموافقة على صلاحية الموقع لعرض المسار.',
    },
    'map_err_location_denied_forever': {
      'en':
          'Location permission is permanently denied. Please enable it in Settings.',
      'ar': 'صلاحية الموقع مرفوضة دائماً، يرجى تفعيلها من الإعدادات.',
    },
    'map_err_location': {
      'en': 'Something went wrong while locating you.',
      'ar': 'حدث خطأ أثناء تحديد الموقع.',
    },
    'map_err_route': {
      'en': 'Failed to load the road route.',
      'ar': 'فشل في تحميل مسار الطريق.',
    },
    'map_err_offline': {
      'en': 'Check your internet connection.',
      'ar': 'تأكد من اتصالك بالإنترنت.',
    },
    'map_open_details': {'en': 'Open details', 'ar': 'افتح التفاصيل'},
    'map_close': {'en': 'Close', 'ar': 'إغلاق'},

    'saved_count': {'en': '{n} saved', 'ar': '{n} محفوظ'},
    'swipe_remove_hint': {
      'en': '<- Swipe left to remove',
      'ar': '<- اسحب لليسار للإزالة',
    },

    'tour_no_locations': {
      'en': 'No locations available for this tour.',
      'ar': 'لا توجد مواقع متاحة لهذه الجولة.',
    },
    'tour_removed_offline': {
      'en': 'Tour removed from offline access',
      'ar': 'تمت إزالة الجولة من الوصول دون اتصال',
    },
    'tour_saved_offline': {
      'en': 'Tour saved for offline access!',
      'ar': 'تم حفظ الجولة للوصول دون اتصال!',
    },
    'tour_duration': {'en': 'Duration', 'ar': 'المدة'},
    'tour_stops': {'en': 'Stops', 'ar': 'محطات'},
    'tour_access': {'en': 'Access', 'ar': 'الدخول'},
    'tour_free': {'en': 'Free', 'ar': 'مجاني'},
    'tour_about': {'en': 'About this Tour', 'ar': 'عن هذه الجولة'},
    'tour_itinerary': {'en': 'Tour Itinerary', 'ar': 'خط سير الجولة'},
    'tour_stops_count': {'en': '{n} stops', 'ar': '{n} محطة'},
    'tour_stops_along': {
      'en': '{n} stops along the way',
      'ar': '{n} محطة على الطريق',
    },
    'tour_start_nav': {'en': 'Start Navigation', 'ar': 'ابدأ التنقل'},
    'tour_locations_count': {'en': '{n} locations', 'ar': '{n} موقع'},

    'journal_add_memory': {'en': 'Add memory', 'ar': 'أضف ذكرى'},
    'journal_empty_title': {
      'en': 'Your travel journal is empty',
      'ar': 'يوميات سفرك فاضية',
    },
    'journal_empty_sub': {
      'en': 'Save memories, photos, and notes for every place you visit.',
      'ar': 'احفظ الذكريات والصور والملاحظات لكل مكان تزوره.',
    },
    'journal_add_first': {'en': 'Add first memory', 'ar': 'أضف أول ذكرى'},
    'journal_today': {'en': 'Today', 'ar': 'اليوم'},
    'journal_yesterday': {'en': 'Yesterday', 'ar': 'أمس'},
    'journal_days_ago': {'en': '{n} days ago', 'ar': 'منذ {n} يوم'},
    'journal_pick_place': {'en': 'Pick a place', 'ar': 'اختار مكانًا'},
    'journal_search_hint': {'en': 'Search places...', 'ar': 'ابحث عن أماكن...'},
    'journal_new_memory': {'en': 'New memory', 'ar': 'ذكرى جديدة'},
    'journal_edit_memory': {'en': 'Edit memory', 'ar': 'تعديل الذكرى'},
    'journal_notes': {'en': 'Notes', 'ar': 'ملاحظات'},
    'journal_note_hint': {
      'en': 'What did you think? What did you do? Tips for other travelers?',
      'ar': 'إيه رأيك؟ إيه اللي عملته؟ نصايح للمسافرين التانيين؟',
    },
    'journal_save_memory': {'en': 'Save memory', 'ar': 'احفظ الذكرى'},
    'journal_update_memory': {'en': 'Update memory', 'ar': 'حدّث الذكرى'},

    'ai_sugg_1': {
      'en': 'Two days in Alexandria, mid-budget, love history and seafood',
      'ar': 'يومين في إسكندرية، ميزانية متوسطة، بحب التاريخ والسي فود',
    },
    'ai_sugg_2': {
      'en': 'One relaxed day focused on cafés and the corniche',
      'ar': 'يوم واحد هادي على القهاوي والكورنيش',
    },
    'ai_sugg_3': {
      'en': 'Three days off the beaten path, hidden gems only',
      'ar': 'تلات أيام بعيد عن الزحمة، جواهر مخفية بس',
    },
    'ai_sugg_4': {
      'en': 'A family day with kid-friendly museums and a beach',
      'ar': 'يوم عائلي مع متاحف مناسبة للأطفال وشاطئ',
    },
    'ai_err_empty': {
      'en': 'Please describe what kind of trip you want.',
      'ar': 'من فضلك صف نوع الرحلة اللي عايزها.',
    },
    'ai_err_failed': {'en': 'Failed to generate: {e}', 'ar': 'فشل التوليد: {e}'},
    'ai_prompt_title': {'en': 'Tell us about your trip', 'ar': 'قولنا عن رحلتك'},
    'ai_prompt_hint': {
      'en': 'e.g. two days in Alexandria, mid-budget, love history',
      'ar': 'مثال: يومين في إسكندرية، ميزانية متوسطة، بحب التاريخ',
    },
    'ai_generating': {'en': 'Generating...', 'ar': 'جارٍ التخطيط...'},
    'ai_generate': {'en': 'Generate Itinerary', 'ar': 'خطّط رحلتي'},
    'ai_days': {'en': 'Days', 'ar': 'الأيام'},
    'ai_budget': {'en': 'Budget', 'ar': 'الميزانية'},
    'ai_days_count': {'en': '{n} days', 'ar': '{n} يوم'},
    'ai_added_to_planner': {
      'en': 'Added {n} places to your Trip Planner',
      'ar': 'اتضاف {n} مكان لمخطط رحلتك',
    },
    'ai_add_all': {
      'en': 'Add all to Trip Planner',
      'ar': 'ضيف الكل لمخطط الرحلة',
    },
    'ai_local_tips': {'en': 'Local tips', 'ar': 'نصايح من أهل البلد'},

    'cur_amount': {'en': 'Amount', 'ar': 'المبلغ'},
    'cur_enter_amount': {'en': 'Enter amount', 'ar': 'أدخل المبلغ'},
    'cur_from': {'en': 'From', 'ar': 'من'},
    'cur_to': {'en': 'To', 'ar': 'إلى'},
    'cur_disclaimer': {
      'en':
          'Rates are approximate and based on mid-market averages. Check with your bank or exchange for actual rates.',
      'ar':
          'الأسعار تقريبية ومبنية على متوسطات السوق. راجع البنك أو الصرافة للأسعار الفعلية.',
    },

    'transport_hero': {
      'en': 'Get around Alexandria with microbuses, buses, and taxis',
      'ar': 'اتنقل في إسكندرية بالميكروباص والأتوبيس والتاكسي',
    },
    'transport_bus_routes': {'en': 'Bus Routes', 'ar': 'خطوط الأتوبيس'},
    'transport_taxi_section': {
      'en': 'Taxis & Microbuses',
      'ar': 'التاكسي والميكروباص',
    },
    'transport_taxi': {'en': 'Taxi', 'ar': 'تاكسي'},
    'transport_taxi_desc': {
      'en':
          'Hail on the street or order by phone. Ask for the meter or agree the fare before you ride.',
      'ar':
          'اطلبه من الشارع أو بالتليفون. اطلب العداد أو اتفق على الأجرة قبل ما تركب.',
    },
    'transport_taxi_price': {
      'en': 'Meter: EGP 7-10 base + EGP 3/km',
      'ar': 'العداد: ٧-١٠ جنيه أساسي + ٣ جنيه لكل كم',
    },
    'transport_taxi_s1': {'en': 'Available citywide', 'ar': 'متاح في كل المدينة'},
    'transport_taxi_s2': {
      'en': 'Black & yellow cabs',
      'ar': 'تاكسي أسود وأصفر',
    },
    'transport_uber_desc': {
      'en': 'App-based. Cash or card. Surge pricing at peak hours.',
      'ar': 'بالتطبيق. كاش أو كارت. أسعار أعلى في أوقات الذروة.',
    },
    'transport_uber_price': {
      'en': 'EGP 30-100+ depending on distance',
      'ar': '٣٠-١٠٠+ جنيه حسب المسافة',
    },
    'transport_uber_s1': {'en': 'Download app', 'ar': 'حمّل التطبيق'},
    'transport_uber_s2': {
      'en': 'Set pickup & drop-off',
      'ar': 'حدد مكان الركوب والنزول',
    },
    'transport_micro_title': {
      'en': 'Microbus (Servis)',
      'ar': 'ميكروباص (سيرفيس)',
    },
    'transport_micro_desc': {
      'en': 'Shared 14-seater vans. Fixed routes, cheap.',
      'ar': 'ميكروباص ١٤ راكب مشترك. خطوط ثابتة ورخيصة.',
    },
    'transport_micro_s1': {'en': 'Set routes', 'ar': 'خطوط ثابتة'},
    'transport_micro_s2': {'en': 'Wave to board', 'ar': 'لوّح عشان تركب'},
    'transport_pro_tip': {
      'en':
          'Pro tip: Microbuses (servis) are the cheapest way along the Corniche — wave to board, and pay the driver directly when you get off.',
      'ar':
          'نصيحة: الميكروباص (السيرفيس) أرخص وسيلة على الكورنيش — لوّح عشان تركب، وادفع للسواق مباشرة لما تنزل.',
    },
    'transport_stops': {'en': 'Stops:', 'ar': 'المحطات:'},

    'bt_title': {'en': 'Best Time to Visit', 'ar': 'أفضل وقت للزيارة'},
    'bt_ranked_now': {
      'en': 'Ranked for right now',
      'ar': 'مرتبة حسب الوقت الحالي',
    },
    'greet_night': {'en': 'Good night', 'ar': 'ليلة سعيدة'},
    'bt_sub_great': {
      'en': '{day} — {n} place{s} glowing right now',
      'ar': '{day} — {n} مكان متألق دلوقتي',
    },
    'bt_sub_okay': {
      'en': '{day} — {n} decent pick{s} if you hurry',
      'ar': '{day} — {n} اختيار كويس لو لحقت',
    },
    'bt_sub_quiet': {
      'en': '{day} — quiet time, plan for later',
      'ar': '{day} — وقت هادي، خطط لبعدين',
    },
    'day_mon': {'en': 'Mon', 'ar': 'الاتنين'},
    'day_tue': {'en': 'Tue', 'ar': 'التلات'},
    'day_wed': {'en': 'Wed', 'ar': 'الأربع'},
    'day_thu': {'en': 'Thu', 'ar': 'الخميس'},
    'day_fri': {'en': 'Fri', 'ar': 'الجمعة'},
    'day_sat': {'en': 'Sat', 'ar': 'السبت'},
    'day_sun': {'en': 'Sun', 'ar': 'الحد'},
    'bt_sunrise': {'en': 'Sunrise', 'ar': 'الشروق'},
    'bt_daylight': {'en': 'Daylight', 'ar': 'النهار'},
    'bt_sunset': {'en': 'Sunset', 'ar': 'الغروب'},

    'emg_title': {'en': 'Emergency', 'ar': 'الطوارئ'},
    'emg_call_failed': {
      'en': 'Cannot place call to {n}',
      'ar': 'تعذر الاتصال بـ {n}',
    },
    'emg_numbers': {'en': 'Emergency Numbers', 'ar': 'أرقام الطوارئ'},
    'emg_hospitals': {'en': 'Hospitals', 'ar': 'المستشفيات'},
    'emg_embassies': {
      'en': 'Embassies & Consulates',
      'ar': 'السفارات والقنصليات',
    },
    'emg_pharmacies': {'en': '24h Pharmacies', 'ar': 'صيدليات ٢٤ ساعة'},
    'emg_transport': {'en': 'Transport', 'ar': 'المواصلات'},
    'emg_hero_title': {
      'en': 'Stay safe in Alexandria',
      'ar': 'خلي بالك في إسكندرية',
    },
    'emg_hero_sub': {
      'en': 'Tap any number to call. Save this page for quick access.',
      'ar': 'اضغط على أي رقم للاتصال. احفظ الصفحة دي للوصول السريع.',
    },

    'login_welcome': {'en': 'Welcome to\nStreetlore', 'ar': 'أهلًا بك في\nستريت لور'},
    'login_subtitle': {
      'en': 'Sign in to save your favorite places and access exclusive tours.',
      'ar': 'سجّل دخولك لحفظ أماكنك المفضلة والوصول لجولات حصرية.',
    },
    'login_full_name': {'en': 'Full Name', 'ar': 'الاسم الكامل'},
    'login_name_hint': {'en': 'e.g. Ahmed Hassan', 'ar': 'مثال: أحمد حسن'},
    'login_err_name': {
      'en': 'Please enter your name',
      'ar': 'من فضلك أدخل اسمك',
    },
    'login_email': {'en': 'Email Address', 'ar': 'البريد الإلكتروني'},
    'login_email_hint': {
      'en': 'e.g. ahmed@example.com',
      'ar': 'مثال: ahmed@example.com',
    },
    'login_err_email': {
      'en': 'Please enter your email',
      'ar': 'من فضلك أدخل بريدك الإلكتروني',
    },
    'login_err_email_invalid': {
      'en': 'Please enter a valid email',
      'ar': 'من فضلك أدخل بريدًا إلكترونيًا صحيحًا',
    },
    'login_sign_in': {'en': 'Sign In', 'ar': 'تسجيل الدخول'},
    'login_or': {'en': 'or', 'ar': 'أو'},
    'login_google': {'en': 'Google', 'ar': 'جوجل'},
    'login_just_exploring': {'en': 'Just exploring? ', 'ar': 'بتستكشف بس؟ '},
    'login_continue_guest': {'en': 'Continue as Guest', 'ar': 'ادخل كضيف'},
    'login_guest_name': {'en': 'Guest Explorer', 'ar': 'مستكشف زائر'},
    'guest_dialog_title': {'en': 'Pick a display name', 'ar': 'اختار اسم للعرض'},
    'guest_dialog_sub': {
      'en':
          'Other travellers will see this name on the leaderboard. You can change it later.',
      'ar':
          'المسافرين التانيين هيشوفوا الاسم ده في الترتيب. ممكن تغيّره بعدين.',
    },
    'sign_in_continue': {'en': 'Continue', 'ar': 'كمّل'},
    'edit_name': {'en': 'Edit name', 'ar': 'غيّر الاسم'},
    'edit_name_dialog_title': {
      'en': 'Change your display name',
      'ar': 'غيّر اسم العرض',
    },

    'ob_title_1': {'en': 'Discover the Unseen', 'ar': 'اكتشف المخفي'},
    'ob_sub_1': {
      'en':
          'Uncover 30+ hidden gems and landmarks of Alexandria that most tourists never find.',
      'ar': 'اكتشف أكتر من ٣٠ جوهرة مخفية ومعلم في إسكندرية معظم السياح مبيعرفوهاش.',
    },
    'ob_title_2': {'en': 'Plan Your Journey', 'ar': 'خطط رحلتك'},
    'ob_sub_2': {
      'en':
          'Choose from expertly curated tours. Navigate with ease and explore at your own pace.',
      'ar': 'اختار من جولات مختارة بعناية. اتنقل بسهولة واستكشف على مزاجك.',
    },
    'ob_title_3': {'en': 'Save & Revisit', 'ar': 'احفظ وارجع تاني'},
    'ob_sub_3': {
      'en':
          'Build your personal travel collection. Save your favorite places and access them anytime.',
      'ar': 'اعمل مجموعتك الخاصة. احفظ أماكنك المفضلة ووصلها في أي وقت.',
    },
    'ob_skip': {'en': 'Skip', 'ar': 'تخطَّ'},
    'ob_get_started': {'en': 'Get Started', 'ar': 'يلا نبدأ'},
    'ob_next': {'en': 'Next', 'ar': 'التالي'},
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
