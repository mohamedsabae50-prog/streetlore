import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../logic/locale_provider.dart';

class AppStrings {
  AppStrings._();

  static const Map<String, Map<String, String>> _v = {
    'nav_explore': {'en': 'Explore', 'ar': 'استكشاف'},
    'nav_tours': {'en': 'Tours', 'ar': 'الجولات'},
    'nav_profile': {'en': 'Profile', 'ar': 'حسابي'},
    'avatar_choose_title': {
      'en': 'Choose a profile avatar',
      'ar': 'اختر صورة للحساب',
    },
    'avatar_preset_explorer': {'en': 'Explorer', 'ar': 'مستكشف'},
    'avatar_preset_historian': {'en': 'Historian', 'ar': 'مؤرخ'},
    'avatar_preset_scholar': {'en': 'Scholar', 'ar': 'باحث'},
    'avatar_preset_sailor': {'en': 'Sailor', 'ar': 'بحّار'},
    'notification_friend_request': {
      'en': '{name} sent you a friend request.',
      'ar': 'أرسل {name} إليك طلب صداقة.',
    },
    'notification_friend_accepted': {
      'en': '{name} accepted your friend request.',
      'ar': 'وافق {name} على طلب صداقتك.',
    },
    'notification_badge_unlocked': {
      'en': '{name} unlocked a new badge.',
      'ar': 'حصل {name} على شارة جديدة.',
    },
    'friend_accept': {'en': 'Accept', 'ar': 'قبول'},
    'friend_decline': {'en': 'Decline', 'ar': 'رفض'},
    'friend': {'en': 'friend', 'ar': 'صديق'},
    'visited_by_friends_single': {
      'en': 'Visited by {name}',
      'ar': 'زاره {name}',
    },
    'visited_by_friends_many': {
      'en': 'Visited by {name} +{count} others',
      'ar': 'زاره {name} و {count} آخرين',
    },
    'head_to_head': {'en': 'Head-to-Head', 'ar': 'مقارنة الاستكشاف'},
    'mastery_you': {'en': 'You', 'ar': 'أنت'},
    'mastery_them': {'en': 'Them', 'ar': 'هو'},
    'mastery_you_ahead': {'en': '🏆 You’re ahead!', 'ar': '🏆 أنت متقدم!'},
    'mastery_them_ahead': {
      'en': '🔥 @{name} is ahead!',
      'ar': '🔥 @{name} متقدم!',
    },
    'mastery_tied': {'en': '🤝 Tied!', 'ar': '🤝 تعادل!'},
    'shared_places': {
      'en': 'Places you have both visited',
      'ar': 'أماكن مشتركة زرتموها',
    },
    'shared_places_count': {
      'en': '{count} shared places',
      'ar': '{count} أماكن مشتركة',
    },
    'shared_places_count_one': {
      'en': '1 shared place',
      'ar': 'مكان مشترك واحد',
    },

    'greet_morning': {'en': 'Good Morning', 'ar': 'صباح الخير'},
    'greet_afternoon': {'en': 'Good Afternoon', 'ar': 'مساء الخير'},
    'greet_evening': {'en': 'Good Evening', 'ar': 'مساء الخير'},
    'search_hint': {
      'en': 'Search places, landmarks...',
      'ar': 'ابحث عن أماكن أو معالم...',
    },
    'featured': {'en': 'Featured', 'ar': 'مميز'},
    'filter_free': {'en': 'Free only', 'ar': 'المجاني فقط'},
    'filter_hidden_gems': {'en': 'Hidden Gems', 'ar': 'جواهر مخفية'},
    'download_offline': {
      'en': 'Download for Offline',
      'ar': 'حمّل للوضع دون اتصال',
    },
    'downloaded': {'en': 'Downloaded', 'ar': 'تم التحميل'},
    'downloading_offline': {'en': 'Downloading...', 'ar': 'جاري التحميل...'},
    'download_failed': {
      'en': 'Offline download failed. Please try again.',
      'ar': 'تعذر التحميل للاستخدام دون اتصال. حاول مرة أخرى.',
    },
    'downloading_tour_offline': {
      'en': 'Downloading tour for offline use…',
      'ar': 'جارٍ تحميل الجولة للاستخدام دون اتصال…',
    },
    'removed_offline': {
      'en': 'Removed from offline',
      'ar': 'تمت الإزالة من الوضع دون اتصال',
    },
    'no_internet_title': {
      'en': 'No Internet Connection',
      'ar': 'لا يوجد اتصال بالإنترنت',
    },
    'no_internet_message': {
      'en':
          'Please reconnect to the internet to load the latest places and stories.',
      'ar': 'أعد الاتصال بالإنترنت لتحميل أحدث الأماكن والحكايات.',
    },
    'no_internet_retry': {'en': 'Try Again', 'ar': 'إعادة المحاولة'},
    'offline_mode_notice': {
      'en': 'Offline Mode: Your saved places are available.',
      'ar': 'وضع عدم الاتصال: الأماكن المحفوظة متاحة.',
    },
    'cat_hotels': {'en': 'Hotels', 'ar': 'الفنادق'},
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

    'quick_best_time': {'en': 'Best Time', 'ar': 'أفضل وقت'},
    'best_time_admin_hint': {
      'en': 'Set by the editorial team',
      'ar': 'حددها فريق التحرير',
    },
    'quick_map': {'en': 'Map', 'ar': 'الخريطة'},
    'quick_ranking': {'en': 'Ranking', 'ar': 'الترتيب'},
    'quick_badges': {'en': 'Badges', 'ar': 'إنجازات'},
    'quick_routes': {'en': 'Routes', 'ar': 'مسارات'},
    'ai_tour_guide': {'en': 'EgyptLore AI', 'ar': 'مساعد إيجيبت لور الذكي'},
    'ai_guide_general_title': {
      'en': 'EgyptLore AI',
      'ar': 'مساعد إيجيبت لور الذكي',
    },
    'ai_guide_welcome_en': {
      'en':
          "Hi! I'm EgyptLore AI. Ask me anything about places to "
          'visit, food, history, hidden gems, or tips for getting around the city.',
      'ar':
          "أهلاً! أنا مساعد إيجيبت لور الذكي. اسألني عن أي حاجة — أماكن للزيارة، "
          'أكل، تاريخ، جواهر مخفية، أو نصايح للتنقل في المدينة.',
    },
    'ai_guide_thinking': {'en': 'Thinking…', 'ar': 'بفكر…'},
    'ai_guide_hint': {
      'en': 'Ask about places, food, history…',
      'ar': 'اسأل عن أماكن، أكل، تاريخ…',
    },
    'ai_quota_loading': {
      'en': 'Loading AI quota…',
      'ar': 'جارٍ تحميل رصيد الذكاء الاصطناعي…',
    },
    'ai_quota_unavailable': {
      'en': 'AI quota unavailable',
      'ar': 'رصيد الذكاء الاصطناعي غير متاح',
    },
    'ai_quota_remaining': {
      'en': '{remaining} of {limit} AI calls remaining',
      'ar': 'متبقي {remaining} من {limit} طلبات للذكاء الاصطناعي',
    },
    'ai_quota_reset_utc': {
      'en': 'Resets at midnight UTC',
      'ar': 'يتجدد عند منتصف الليل بتوقيت UTC',
    },
    'ai_quota_retry': {'en': 'Retry', 'ar': 'إعادة المحاولة'},
    'ai_daily_limit_title': {
      'en': 'You’ve reached today’s free AI message limit',
      'ar': 'وصلت إلى الحد اليومي المجاني لرسائل الذكاء الاصطناعي',
    },
    'ai_daily_limit_body': {
      'en':
          'Your free messages reset at midnight UTC. Upgrade to Pro for higher AI limits.',
      'ar':
          'يتجدد رصيدك المجاني عند منتصف الليل بتوقيت UTC. اشترك في برو للحصول على حد أعلى.',
    },
    'ai_upgrade_pro': {'en': 'Upgrade to Pro', 'ar': 'الترقية إلى برو'},
    'admin_ai_chat_logs': {
      'en': 'AI Chat Logs',
      'ar': 'سجل محادثات الذكاء الاصطناعي',
    },
    'admin_ai_chat_exchange': {
      'en': '{count} AI exchange',
      'ar': '{count} محادثة',
    },
    'admin_ai_chat_exchanges': {
      'en': '{count} AI exchanges',
      'ar': '{count} محادثات',
    },
    'admin_ai_chat_user': {'en': 'User', 'ar': 'المستخدم'},
    'admin_ai_chat_assistant': {'en': 'AI', 'ar': 'الذكاء الاصطناعي'},
    'admin_ai_chat_empty': {
      'en': 'No AI chat sessions yet',
      'ar': 'لا توجد محادثات ذكاء اصطناعي بعد',
    },
    'admin_ai_chat_retry_error': {
      'en': 'Could not load more chat threads: {error}',
      'ar': 'تعذر تحميل المزيد من المحادثات: {error}',
    },
    'max_route_places': {
      'en': 'Max 5 places per route',
      'ar': 'أقصى عدد 5 أماكن في المسار',
    },

    'weather_feels': {
      'en': 'feels {t}  · {h}% humidity',
      'ar': 'الإحساس {t}  · رطوبة {h}%',
    },
    'weather_my_location': {'en': 'Use my location', 'ar': 'استخدم موقعي'},
    'weather_unavailable': {
      'en':
          'Current weather is unavailable. Check your location and connection.',
      'ar': 'الطقس الحالي غير متاح. تحقق من الموقع والاتصال بالإنترنت.',
    },
    'image_uploading': {'en': 'Uploading image...', 'ar': 'جاري رفع الصورة...'},
    'image_upload_success': {
      'en': 'Image uploaded successfully.',
      'ar': 'تم رفع الصورة بنجاح.',
    },
    'image_upload_error': {
      'en': 'Could not upload the image. Please try again.',
      'ar': 'تعذر رفع الصورة. حاول مرة أخرى.',
    },
    'suggest_place_success': {
      'en': 'Your place suggestion was submitted.',
      'ar': 'تم إرسال اقتراح المكان.',
    },
    'pro_monthly_reward_title': {
      'en': 'Finish #1 Top Visitor of the Month and earn 1 Month of Pro FREE!',
      'ar': 'أنه الشهر في المركز الأول كأفضل زائر واربح شهرًا من برو مجانًا!',
    },
    'pro_monthly_reward_countdown': {
      'en': '{days}d {hours}h left this month',
      'ar': 'متبقي {days} يوم و{hours} ساعة على نهاية الشهر',
    },
    'pro_monthly_reward_cta': {
      'en': 'Suggest a Hidden Gem',
      'ar': 'اقترح جوهرة مخفية',
    },
    'pro_hidden_gem_reward': {
      'en':
          'If our team approves your Hidden Gem, we’ll automatically add 30 days of Pro to your account for FREE.',
      'ar':
          'إذا وافق فريقنا على جوهرتك المخفية، سنضيف تلقائيًا 30 يومًا من برو إلى حسابك مجانًا.',
    },
    'share_place': {'en': 'Share this place', 'ar': 'شارك هذا المكان'},
    'weather_clear_sky': {'en': 'Clear sky', 'ar': 'سماء صافية'},
    'weather_mainly_clear': {'en': 'Mainly clear', 'ar': 'صحو غالبًا'},
    'weather_partly_cloudy': {'en': 'Partly cloudy', 'ar': 'غائم جزئيًا'},
    'weather_overcast': {'en': 'Overcast', 'ar': 'غائم'},
    'weather_rain_possible': {'en': 'Rain possible', 'ar': 'احتمال هطول أمطار'},
    'weather_rain': {'en': 'Rain', 'ar': 'ممطر'},
    'weather_drizzle': {'en': 'Drizzle', 'ar': 'رذاذ'},
    'weather_thunderstorm': {'en': 'Thunderstorm', 'ar': 'عاصفة رعدية'},
    'weather_snow': {'en': 'Snow', 'ar': 'ثلوج'},
    'weather_fog': {'en': 'Fog', 'ar': 'ضباب'},
    'weather_unknown': {'en': 'Current conditions', 'ar': 'الطقس الحالي'},
    'refresh': {'en': 'Refresh', 'ar': 'تحديث'},
    'map_title': {'en': 'Map · {n} places', 'ar': 'الخريطة · {n} مكان'},
    'map_my_location': {'en': 'My location', 'ar': 'موقعي'},
    'community_chat': {'en': 'Community Chat', 'ar': 'دردشة المجتمع'},
    'community_chat_sub': {
      'en': 'Ask travelers about this place',
      'ar': 'اسأل المسافرين عن هذا المكان',
    },

    'lb_city_title': {'en': 'King of Alexandria', 'ar': 'ملك الإسكندرية'},
    'lb_period_week': {'en': 'Weekly', 'ar': 'أسبوعي'},
    'lb_period_month': {'en': 'Monthly', 'ar': 'شهري'},
    'lb_period_all_time': {'en': 'All time', 'ar': 'طوال الوقت'},
    'lb_metric_checkins': {'en': 'Check-ins', 'ar': 'الزيارات'},
    'lb_metric_streak': {'en': 'Longest streak', 'ar': 'أطول سلسلة'},
    'lb_metric_gems': {'en': 'Hidden gems', 'ar': 'الجواهر المخفية'},
    'lb_stat_checkins': {'en': 'check-ins', 'ar': 'زيارات'},
    'lb_stat_streak': {'en': 'day streak', 'ar': 'أيام متتالية'},
    'lb_stat_gems': {'en': 'hidden gems', 'ar': 'جواهر مخفية'},
    'lb_badge_rank': {'en': '{level} rank', 'ar': 'رتبة {level}'},
    'lb_try_again': {'en': 'Try again', 'ar': 'حاول مرة أخرى'},
    'lb_title': {'en': 'Leaderboard', 'ar': 'الترتيب'},
    'lb_your_rank': {'en': 'YOUR RANK', 'ar': 'ترتيبك'},
    'lb_points_level': {'en': '{p} points · {l}', 'ar': '{p} نقطة · {l}'},
    'stat_visited': {'en': 'Visited', 'ar': 'زيارات'},
    'stat_reviews': {'en': 'Reviews', 'ar': 'تقييمات'},
    'lb_empty': {
      'en': 'No leaderboard data yet',
      'ar': 'لا توجد بيانات للترتيب بعد',
    },
    'username_title': {'en': 'Choose your username', 'ar': 'اختر اسم المستخدم'},
    'username_subtitle': {
      'en': 'This unique name helps other explorers find and follow you.',
      'ar':
          'يساعد هذا الاسم الفريد المستكشفين الآخرين في العثور عليك ومتابعتك.',
    },
    'username_label': {'en': 'Username', 'ar': 'اسم المستخدم'},
    'username_requirements': {
      'en':
          'Use 3-20 letters, numbers, dots, underscores, or hyphens. Start with a letter or number.',
      'ar':
          'استخدم ٣ إلى ٢٠ حرفًا أو رقمًا أو نقطة أو شرطة سفلية أو واصلة، وابدأ بحرف أو رقم.',
    },
    'username_continue': {'en': 'Continue', 'ar': 'متابعة'},
    'username_taken': {
      'en': 'That username is already taken. Try another.',
      'ar': 'اسم المستخدم هذا مستخدم بالفعل. جرّب اسمًا آخر.',
    },
    'username_invalid': {
      'en': 'Enter a valid username using the rules shown above.',
      'ar': 'أدخل اسم مستخدم صالحًا وفقًا للقواعد الموضحة أعلاه.',
    },
    'username_save_failed': {
      'en': 'We could not save your username. Please try again.',
      'ar': 'تعذر حفظ اسم المستخدم. حاول مرة أخرى.',
    },
    'username_check_failed': {
      'en':
          'We could not verify your account profile. Check your connection and try again.',
      'ar': 'تعذر التحقق من ملفك الشخصي. تحقق من الاتصال وحاول مرة أخرى.',
    },
    'users_search_title': {'en': 'Search Users', 'ar': 'البحث عن مستخدمين'},
    'users_suggested_title': {
      'en': 'Suggested explorers',
      'ar': 'مستكشفون مقترحون',
    },
    'users_suggestions_empty': {
      'en': 'No explorers are available yet.',
      'ar': 'لا يوجد مستكشفون متاحون بعد.',
    },
    'suggest_hidden_gem': {
      'en': 'Suggest a Hidden Gem',
      'ar': 'اقترح جوهرة مخفية',
    },
    'suggest_hidden_gem_subtitle': {
      'en': 'Share a special place with our team',
      'ar': 'شارك مكاناً مميزاً مع فريقنا',
    },
    'users_search_subtitle': {
      'en': 'Find explorers and manage your friend requests',
      'ar': 'اعثر على مستكشفين وأدر طلبات الصداقة',
    },
    'users_search_hint': {
      'en': 'Search usernames',
      'ar': 'ابحث عن أسماء المستخدمين',
    },
    'users_search_min_length': {
      'en': 'Enter at least two characters to search.',
      'ar': 'أدخل حرفين على الأقل للبحث.',
    },
    'users_search_failed': {
      'en': 'User search failed. Please try again.',
      'ar': 'تعذر البحث عن المستخدمين. حاول مرة أخرى.',
    },
    'users_search_empty': {
      'en': 'No users found. Try another username.',
      'ar': 'لم يتم العثور على مستخدمين. جرّب اسمًا آخر.',
    },
    'users_search_results': {'en': 'Search results', 'ar': 'نتائج البحث'},
    'users_sign_in_required': {
      'en': 'Sign in to find and add other explorers as friends.',
      'ar': 'سجّل الدخول للعثور على مستكشفين آخرين وإضافتهم كأصدقاء.',
    },
    'user_profile_title': {'en': 'Explorer Profile', 'ar': 'ملف المستكشف'},
    'profile_visited_places': {
      'en': 'Places visited',
      'ar': 'الأماكن التي زارها',
    },
    'profile_no_visits': {
      'en': 'No shared visits to show yet.',
      'ar': 'لا توجد زيارات متاحة للمشاركة بعد.',
    },
    'profile_visits_failed': {
      'en': 'Could not load visited places. Please try again.',
      'ar': 'تعذر تحميل الأماكن التي تمت زيارتها. حاول مرة أخرى.',
    },
    'send_friend_request': {'en': 'Add friend', 'ar': 'إرسال طلب صداقة'},
    'incoming_request': {'en': 'Incoming request', 'ar': 'طلب وارد'},
    'friend_request_pending': {
      'en': 'Request pending',
      'ar': 'الطلب قيد الانتظار',
    },
    'cancel_friend_request': {'en': 'Cancel request', 'ar': 'إلغاء الطلب'},
    'incoming_friend_requests': {
      'en': 'Incoming Friend Requests',
      'ar': 'طلبات الصداقة الواردة',
    },
    'sent_friend_requests': {'en': 'Sent Requests', 'ar': 'الطلبات المرسلة'},
    'friends_list_title': {'en': 'Friends', 'ar': 'الأصدقاء'},
    'accept_friend_request': {'en': 'Accept', 'ar': 'قبول'},
    'decline_friend_request': {'en': 'Decline', 'ar': 'رفض'},
    'remove_friend': {'en': 'Remove friend', 'ar': 'إزالة الصديق'},
    'remove_friend_title': {
      'en': 'Remove this friend?',
      'ar': 'إزالة هذا الصديق؟',
    },
    'remove_friend_confirmation': {
      'en': 'You will no longer share friend activity with each other.',
      'ar': 'لن تتم مشاركة النشاط بينكما بعد الآن.',
    },
    'friend_location_activity_sharing': {
      'en': 'Share my location and activity with this friend',
      'ar': 'مشاركة موقعي ونشاطي مع هذا الصديق',
    },
    'friends_load_failed': {
      'en': 'Could not load friends and requests.',
      'ar': 'تعذر تحميل الأصدقاء والطلبات.',
    },
    'friend_action_failed': {
      'en': 'Could not update this friend request. Please try again.',
      'ar': 'تعذر تحديث طلب الصداقة. حاول مرة أخرى.',
    },
    'follow_action_failed': {
      'en': 'Could not update follow status. Please try again.',
      'ar': 'تعذر تحديث حالة المتابعة. حاول مرة أخرى.',
    },
    'share_location_activity': {
      'en': 'Share my location & activity with friends',
      'ar': 'مشاركة موقعي ونشاطي مع الأصدقاء',
    },
    'share_location_activity_subtitle': {
      'en':
          'Friends can see visited places and activity only while this is on.',
      'ar':
          'يمكن للأصدقاء رؤية الأماكن التي زرتها ونشاطك عند تفعيل هذا الخيار فقط.',
    },
    'privacy_settings_failed': {
      'en': 'Could not load privacy settings.',
      'ar': 'تعذر تحميل إعدادات الخصوصية.',
    },
    'privacy_settings_save_failed': {
      'en': 'Could not save privacy settings. Please try again.',
      'ar': 'تعذر حفظ إعدادات الخصوصية. حاول مرة أخرى.',
    },
    'avatar_upload_failed': {
      'en': 'Could not upload your profile picture. Please try again.',
      'ar': 'تعذر تحميل صورة الملف الشخصي. حاول مرة أخرى.',
    },
    'profile_friends': {'en': 'friends', 'ar': 'أصدقاء'},
    'profile_no_public_badges': {
      'en': 'No badges earned yet',
      'ar': 'لا توجد شارات مكتسبة بعد',
    },
    'badge_earned_fallback': {'en': 'Explorer badge', 'ar': 'شارة مستكشف'},
    'feed_title': {'en': 'Activity', 'ar': 'النشاط'},
    'feed_header_subtitle': {
      'en': 'See what your community is exploring',
      'ar': 'تابع ما يستكشفه مجتمعك',
    },
    'feed_header_title': {'en': 'Your community', 'ar': 'مجتمعك'},
    'feed_updates': {'en': 'updates', 'ar': 'تحديثات'},
    'feed_filter_all': {'en': 'All', 'ar': 'الكل'},
    'feed_filter_checkin': {'en': 'Check-ins', 'ar': 'الزيارات'},
    'feed_filter_badge': {'en': 'Badges', 'ar': 'الشارات'},
    'feed_filter_suggestion': {'en': 'Suggestions', 'ar': 'الاقتراحات'},
    'feed_filter_empty': {
      'en': 'No activity in this category yet.',
      'ar': 'لا يوجد نشاط في هذه الفئة بعد.',
    },
    'feed_today': {'en': 'Today', 'ar': 'اليوم'},
    'feed_yesterday': {'en': 'Yesterday', 'ar': 'أمس'},
    'feed_empty': {
      'en':
          'No recent activity yet. Add friends to see their check-ins, badges, and approved place suggestions.',
      'ar':
          'لا يوجد نشاط حديث بعد. أضف أصدقاء لرؤية زياراتهم وشاراتهم واقتراحات الأماكن المقبولة.',
    },
    'feed_load_failed': {
      'en': 'Could not load the activity feed. Please try again.',
      'ar': 'تعذر تحميل موجز النشاط. حاول مرة أخرى.',
    },
    'feed_action_checkin': {'en': 'visited', 'ar': 'زار'},
    'feed_action_badge': {'en': 'unlocked a badge', 'ar': 'حصل على شارة'},
    'feed_action_suggestion': {'en': 'suggested a place', 'ar': 'اقترح مكانًا'},
    'report_title': {'en': 'Report content', 'ar': 'الإبلاغ عن محتوى'},
    'report_photo_title': {'en': 'Report Photo', 'ar': 'إبلاغ عن الصورة'},
    'photo_report_reason_inappropriate': {
      'en': 'Inappropriate content',
      'ar': 'محتوى غير لائق',
    },
    'photo_report_reason_unrelated': {
      'en': 'Not related to this place',
      'ar': 'غير مرتبطة بهذا المكان',
    },
    'photo_report_reason_offensive': {
      'en': 'Offensive/Abuse',
      'ar': 'محتوى مسيء أو ينطوي على إساءة',
    },
    'photo_report_reason_other': {'en': 'Other', 'ar': 'سبب آخر'},
    'photo_report_submitted': {
      'en': 'Photo reported. It has been hidden from your gallery.',
      'ar': 'تم الإبلاغ عن الصورة وإخفاؤها من معرضك.',
    },
    'photo_report_failed': {
      'en': 'Could not report this photo. Please try again.',
      'ar': 'تعذر الإبلاغ عن الصورة. حاول مرة أخرى.',
    },
    'report_reason_prompt': {
      'en': 'Why are you reporting this?',
      'ar': 'لماذا تريد الإبلاغ عن هذا المحتوى؟',
    },
    'report_reason_inappropriate': {
      'en': 'Inappropriate content',
      'ar': 'محتوى غير لائق',
    },
    'report_reason_spam': {'en': 'Spam', 'ar': 'رسائل مزعجة'},
    'report_reason_harassment': {'en': 'Harassment', 'ar': 'مضايقة'},
    'report_reason_false_info': {
      'en': 'False information',
      'ar': 'معلومات مضللة',
    },
    'report_reason_other': {'en': 'Other', 'ar': 'سبب آخر'},
    'report_submit': {'en': 'Submit report', 'ar': 'إرسال البلاغ'},
    'report_submitted': {
      'en': 'Thanks. Your report was submitted for review.',
      'ar': 'شكرًا. تم إرسال بلاغك للمراجعة.',
    },
    'report_failed': {
      'en': 'Could not submit your report. Please try again.',
      'ar': 'تعذر إرسال البلاغ. حاول مرة أخرى.',
    },
    'block_user': {'en': 'Block user', 'ar': 'حظر المستخدم'},
    'unblock_user': {'en': 'Unblock user', 'ar': 'إلغاء حظر المستخدم'},
    'block_user_title': {'en': 'Block this user?', 'ar': 'حظر هذا المستخدم؟'},
    'block_user_confirmation': {
      'en': 'Their community photos and activity will be hidden from you.',
      'ar': 'ستُخفى صور المجتمع ونشاط هذا المستخدم عنك.',
    },
    'user_blocked': {
      'en': 'User blocked. Their content is now hidden.',
      'ar': 'تم حظر المستخدم وإخفاء محتواه.',
    },
    'block_user_failed': {
      'en': 'Could not update the block list. Please try again.',
      'ar': 'تعذر تحديث قائمة الحظر. حاول مرة أخرى.',
    },
    'blocked_profile_hidden': {
      'en':
          'This user is blocked. Unblock them to view their profile and activity.',
      'ar': 'هذا المستخدم محظور. ألغِ حظره لعرض ملفه الشخصي ونشاطه.',
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
    'smart_alerts_title': {
      'en': 'Smart Location Alerts',
      'ar': 'تنبيهات الموقع الذكية',
    },
    'smart_alerts_subtitle': {
      'en': 'Get notified within 150 m of a hidden gem',
      'ar': 'احصل على تنبيه عند الاقتراب حتى ١٥٠ مترًا من جوهرة مخفية',
    },
    'smart_alerts_consent': {
      'en':
          'EgyptLore uses background location to alert you when you are within 150 m of a hidden gem. You can turn this off at any time.',
      'ar':
          'يستخدم EgyptLore موقعك في الخلفية لتنبيهك عند الاقتراب لمسافة ١٥٠ مترًا من جوهرة مخفية. يمكنك إيقاف ذلك في أي وقت.',
    },
    'smart_alerts_no_gems': {
      'en': 'No hidden gems are available to monitor right now.',
      'ar': 'لا توجد جواهر مخفية متاحة للتنبيه عنها حاليًا.',
    },
    'language': {'en': 'Language', 'ar': 'اللغة'},
    'emergency_info': {'en': 'Emergency Info', 'ar': 'معلومات الطوارئ'},
    'emergency_info_sub': {
      'en': 'Hospitals, embassies, hotlines',
      'ar': 'مستشفيات وسفارات وخطوط ساخنة',
    },
    'prayer_times': {'en': 'Prayer Times', 'ar': 'مواقيت الصلاة'},
    'prayer_times_sub': {
      'en': 'Daily prayer schedule for Alexandria',
      'ar': 'مواعيد الصلاة اليومية للإسكندرية',
    },
    'map_view': {'en': 'Map View', 'ar': 'عرض الخريطة'},
    'currency_converter': {'en': 'Currency Converter', 'ar': 'محوّل العملات'},
    'currency_converter_sub': {
      'en': 'EGP ↔ USD, EUR, GBP, SAR + more',
      'ar': 'جنيه ↔ دولار، يورو، إسترليني، ريال وأكثر',
    },
    'travel_journal': {'en': 'Travel Journal', 'ar': 'يوميات السفر'},
    'travel_journal_sub': {
      'en': 'Save memories, notes & photos',
      'ar': 'احفظ الذكريات والملاحظات والصور',
    },
    'help_center': {'en': 'Help Center', 'ar': 'مركز المساعدة'},
    'help_center_sub': {'en': 'FAQs and support', 'ar': 'أسئلة شائعة ودعم'},
    'rate_app': {'en': 'Rate EgyptLore', 'ar': 'قيّم إيجيبت لور'},
    'rate_app_sub': {'en': 'Share your experience', 'ar': 'شاركنا تجربتك'},
    'rate_thanks': {
      'en': 'Thank you for your support! ',
      'ar': 'شكرًا لدعمك! ',
    },
    'about_app': {'en': 'About EgyptLore', 'ar': 'عن إيجيبت لور'},
    'attributions_title': {'en': 'Attributions', 'ar': 'حقوق الملكية'},
    'attribution_osm': {
      'en':
          'Map tiles © OpenStreetMap contributors — open data under the Open Database License (ODbL).',
      'ar': 'خرائط © مساهمو OpenStreetMap — بيانات مفتوحة برخصة ODbL.',
    },
    'attribution_wikimedia': {
      'en':
          'Place photos courtesy of Wikimedia Commons, used under each file’s stated free-license terms.',
      'ar':
          'صور الأماكن من Wikimedia Commons، مستخدمة وفق شروط الرخصة المفتوحة لكل صورة.',
    },
    'version': {'en': 'Version', 'ar': 'الإصدار'},
    'saved_cleared': {
      'en': 'All saved places cleared.',
      'ar': 'تم مسح كل الأماكن المحفوظة.',
    },
    'passion_banner_title': {
      'en': 'A compass for every story worth telling',
      'ar': 'بوصلة كل قصة تستاهل أن تُروى',
    },
    'passion_banner_sub': {
      'en':
          'Your guide to the deepest stories behind every city. Free, ad-free, '
          'and made with care. Every recommendation here is written by '
          'someone who knows the place up close.',
      'ar':
          'دليلك لاكتشاف أعمق ما في المدن من حكايات وذكريات. بدون إعلانات، '
          'بدون اشتراكات، وكل توصية هنا كتبها إنسان يعرف المكان عن قرب.',
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
    'section_about': {'en': 'About', 'ar': 'حول'},
    'dark_theme_on': {'en': 'Dark theme enabled', 'ar': 'الوضع الداكن مفعّل'},
    'light_theme_on': {'en': 'Light theme active', 'ar': 'الوضع الفاتح مفعّل'},
    'clear_all_warning': {
      'en':
          'This will permanently remove all saved places. This cannot be undone.',
      'ar': 'سيتم حذف كل الأماكن المحفوظة نهائيًا. لا يمكن التراجع عن هذا.',
    },
    'help_contact': {
      'en':
          'For support, contact us at:\nmohamedsabe50@gmail.com\n\nWe reply within 24 hours.',
      'ar':
          'للدعم، تواصل معنا على:\nmohamedsabe50@gmail.com\n\nنرد خلال 24 ساعة.',
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
    'no_visited_places': {
      'en': 'No Visited Places',
      'ar': 'لا توجد أماكن تمت زيارتها',
    },
    'empty_visited_places_sub': {
      'en': 'Places you check in at will appear here.',
      'ar': 'ستظهر هنا الأماكن التي تسجل زيارتها.',
    },
    'no_visited_tours': {
      'en': 'No Visited Tours',
      'ar': 'لا توجد جولات تمت زيارتها',
    },
    'empty_visited_tours_sub': {
      'en': 'Tours you complete will appear here.',
      'ar': 'ستظهر هنا الجولات التي تكملها.',
    },
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
    'unvisit_title': {'en': 'Remove check-in?', 'ar': 'إلغاء تسجيل الزيارة؟'},
    'unvisit_body': {
      'en':
          'This will remove your check-in, deduct the points, and revoke any badges that were unlocked by it.',
      'ar':
          'ده هيلغي تسجيل الزيارة ويخصم من نقاطك ويلغي أي شارة اتفتحت بسببها.',
    },
    'unvisit_confirm': {'en': 'Remove', 'ar': 'إلغاء'},
    'go': {'en': 'Go', 'ar': 'اذهب'},
    'checkin': {'en': 'Check-in', 'ar': 'تسجيل زيارة'},
    'checked_in_streak': {
      'en': 'Checked in! Streak: {n}',
      'ar': 'تم تسجيل الزيارة! ستريك {n}',
    },
    'badges_title': {'en': 'Badges', 'ar': 'الشارات'},
    'no_badges': {
      'en': 'Check in at places to earn badges',
      'ar': 'سجّل زياراتك للأماكن لتكسب الشارات',
    },
    'ach_first_steps_name': {'en': 'First Steps', 'ar': 'الخطوات الأولى'},
    'ach_first_steps_desc': {
      'en': 'Check in at your first place',
      'ar': 'سجّل دخولك في أول مكان',
    },
    'ach_street_explorer_name': {
      'en': 'Street Explorer',
      'ar': 'مستكشف الشوارع',
    },
    'ach_street_explorer_desc': {
      'en': 'Visit 5 different places in Alexandria',
      'ar': 'زُر 5 أماكن مختلفة في الإسكندرية',
    },
    'ach_lore_master_name': {'en': 'Lore Master', 'ar': 'خبير الحكايات'},
    'ach_lore_master_desc': {
      'en': 'Visit 15 places and uncover their stories',
      'ar': 'زُر 15 مكانًا واكتشف حكاياتها',
    },
    'ach_alexandria_legend_name': {
      'en': 'Alexandria Legend',
      'ar': 'أسطورة الإسكندرية',
    },
    'ach_alexandria_legend_desc': {
      'en': 'Visit 30 places across Alexandria',
      'ar': 'زُر 30 مكانًا في أنحاء الإسكندرية',
    },
    'ach_explorer_5_name': {'en': 'Curious', 'ar': 'فضولي'},
    'ach_explorer_5_desc': {
      'en': 'Visit 5 different places',
      'ar': 'زُر 5 أماكن مختلفة',
    },
    'ach_explorer_10_name': {'en': 'Adventurer', 'ar': 'مغامر'},
    'ach_explorer_10_desc': {
      'en': 'Visit 10 different places',
      'ar': 'زُر 10 أماكن مختلفة',
    },
    'ach_explorer_25_name': {'en': 'Pathfinder', 'ar': 'مستكشف'},
    'ach_explorer_25_desc': {
      'en': 'Visit 25 different places',
      'ar': 'زُر 25 مكانًا مختلفًا',
    },
    'ach_lorekeeper_name': {'en': 'Lorekeeper', 'ar': 'حارس التراث'},
    'ach_lorekeeper_desc': {
      'en': 'Visit 42 places — the answer to everything',
      'ar': 'زُر 42 مكانًا — إجابة كل شيء',
    },
    'ach_culture_buff_name': {'en': 'Culture Buff', 'ar': 'ثقافة عالية'},
    'ach_culture_buff_desc': {
      'en': 'Visit 5 cultural spots',
      'ar': 'زُر 5 أماكن ثقافية',
    },
    'ach_time_traveler_name': {'en': 'Time Traveler', 'ar': 'مسافر عبر الزمن'},
    'ach_time_traveler_desc': {
      'en': 'Visit 5 Historical places',
      'ar': 'زُر 5 أماكن تاريخية',
    },
    'ach_culture_vulture_name': {'en': 'Culture Vulture', 'ar': 'عاشق الثقافة'},
    'ach_culture_vulture_desc': {
      'en': 'Visit 5 Culture places',
      'ar': 'زُر 5 أماكن ثقافية',
    },
    'ach_history_nerd_name': {'en': 'History Nerd', 'ar': 'مهووس بالتاريخ'},
    'ach_history_nerd_desc': {
      'en': 'Visit 10 historical spots',
      'ar': 'زُر 10 أماكن تاريخية',
    },
    'ach_foodie_name': {'en': 'Foodie', 'ar': 'ذوّاق'},
    'ach_foodie_desc': {
      'en': 'Check in at 3 food spots',
      'ar': 'سجّل دخولك في 3 أماكن أكل',
    },
    'ach_alex_foodie_name': {'en': 'Alex Foodie', 'ar': 'ذوّاق إسكندراني'},
    'ach_alex_foodie_desc': {
      'en': 'Visit 4 Food places in Alexandria',
      'ar': 'زُر 4 أماكن للطعام في الإسكندرية',
    },
    'ach_nature_lover_name': {'en': 'Nature Lover', 'ar': 'محب الطبيعة'},
    'ach_nature_lover_desc': {
      'en': 'Visit 3 Nature places',
      'ar': 'زُر 3 أماكن طبيعية',
    },
    'ach_gourmet_name': {'en': 'Gourmet', 'ar': 'خبير أكل'},
    'ach_gourmet_desc': {
      'en': 'Check in at 8 food spots',
      'ar': 'سجّل دخولك في 8 أماكن أكل',
    },
    'ach_shopaholic_name': {'en': 'Shopaholic', 'ar': 'مدمن تسوق'},
    'ach_shopaholic_desc': {
      'en': 'Visit 3 shopping spots',
      'ar': 'زُر 3 أماكن تسوق',
    },
    'ach_spiritual_seeker_name': {'en': 'Spiritual Seeker', 'ar': 'باحث روحي'},
    'ach_spiritual_seeker_desc': {'en': 'Visit 2 mosques', 'ar': 'زُر مسجدين'},
    'ach_pilgrim_name': {'en': 'Pilgrim', 'ar': 'حاج'},
    'ach_pilgrim_desc': {
      'en': 'Visit 2 churches or holy sites',
      'ar': 'زُر كنيستين أو موقعين مقدسين',
    },
    'ach_streak_3_name': {'en': 'Warming Up', 'ar': 'بداية دافئة'},
    'ach_streak_3_desc': {
      'en': '3-day check-in streak',
      'ar': 'سلسلة 3 أيام من تسجيل الدخول',
    },
    'ach_streak_7_name': {'en': 'On a Roll', 'ar': 'على مَوجة'},
    'ach_streak_7_desc': {
      'en': '7-day check-in streak',
      'ar': 'سلسلة 7 أيام من تسجيل الدخول',
    },
    'ach_streak_30_name': {'en': 'Devoted', 'ar': 'مُخلِص'},
    'ach_streak_30_desc': {
      'en': '30-day check-in streak',
      'ar': 'سلسلة 30 يومًا من تسجيل الدخول',
    },
    'ach_streak_100_name': {'en': 'Legend', 'ar': 'أسطورة'},
    'ach_streak_100_desc': {
      'en': '100-day check-in streak',
      'ar': 'سلسلة 100 يوم من تسجيل الدخول',
    },
    'ach_hidden_gem_hunter_name': {
      'en': 'Hidden Gem Hunter',
      'ar': 'صيّاد الجواهر المخفية',
    },
    'ach_hidden_gem_hunter_desc': {
      'en': 'Discover 3 hidden gems',
      'ar': 'اكتشف 3 جواهر مخفية',
    },
    'ach_reviewer_name': {'en': 'Reviewer', 'ar': 'مُراجِع'},
    'ach_reviewer_desc': {'en': 'Post 3 reviews', 'ar': 'انشر 3 تقييمات'},
    'ach_critic_name': {'en': 'Critic', 'ar': 'ناقد'},
    'ach_critic_desc': {'en': 'Post 10 reviews', 'ar': 'انشر 10 تقييمات'},
    'ach_photographer_name': {'en': 'Photographer', 'ar': 'مُصوِّر'},
    'ach_photographer_desc': {'en': 'Upload 5 photos', 'ar': 'ارفع 5 صور'},
    'ach_influencer_name': {'en': 'Influencer', 'ar': 'مؤثر'},
    'ach_influencer_desc': {'en': 'Upload 20 photos', 'ar': 'ارفع 20 صورة'},
    'ach_early_bird_name': {'en': 'Early Bird', 'ar': 'طائر الفجر'},
    'ach_early_bird_desc': {
      'en': 'Check in at 5 places before 9 AM',
      'ar': 'سجّل دخولك في 5 أماكن قبل 9 صباحًا',
    },
    'ach_night_owl_name': {'en': 'Night Owl', 'ar': 'بومة الليل'},
    'ach_night_owl_desc': {
      'en': 'Check in at 5 places after 9 PM',
      'ar': 'سجّل دخولك في 5 أماكن بعد 9 مساءً',
    },
    'ach_completionist_name': {'en': 'Completionist', 'ar': 'مُكتمِل'},
    'ach_completionist_desc': {
      'en': 'Unlock 20 different achievements',
      'ar': 'افتح 20 إنجازات مختلفة',
    },
    'ach_squad_explorer_name': {'en': 'Squad Explorer', 'ar': 'مستكشف الفريق'},
    'ach_squad_explorer_desc': {
      'en': 'Check in while exploring with an active squad',
      'ar': 'سجّل زيارتك أثناء الاستكشاف مع فريق نشط',
    },
    'ach_social_explorer_name': {
      'en': 'Social Explorer',
      'ar': 'مستكشف اجتماعي',
    },
    'ach_social_explorer_desc': {
      'en': 'Make friends with 3 explorers',
      'ar': 'كوّن صداقات مع 3 مستكشفين',
    },
    'squad_title': {'en': 'Co-op Exploration', 'ar': 'استكشاف جماعي'},
    'squad_active_title': {'en': 'Your active squad', 'ar': 'فريقك النشط'},
    'squad_invite_subtitle': {
      'en': 'Invite friends and explore together',
      'ar': 'ادعُ أصدقاءك واستكشفوا معًا',
    },
    'squad_start_subtitle': {
      'en': 'Create or join a squad with a short code',
      'ar': 'أنشئ فريقًا أو انضم إليه باستخدام رمز قصير',
    },
    'squad_create': {'en': 'Create a squad', 'ar': 'أنشئ فريقًا'},
    'squad_join': {'en': 'Join squad', 'ar': 'انضم إلى فريق'},
    'squad_code_label': {
      'en': '4-6 digit squad code',
      'ar': 'رمز الفريق من 4 إلى 6 أرقام',
    },
    'squad_copy_code': {'en': 'Copy code', 'ar': 'انسخ الرمز'},
    'squad_leave': {'en': 'Leave squad', 'ar': 'غادر الفريق'},
    'squad_members': {'en': '{n} members', 'ar': '{n} أعضاء'},
    'squad_roster': {'en': 'Squad members', 'ar': 'أعضاء الفريق'},
    'squad_leader': {'en': 'Leader', 'ar': 'قائد الفريق'},
    'squad_you_leader': {'en': 'Leader · You', 'ar': 'قائد الفريق · أنت'},
    'squad_you': {'en': 'You', 'ar': 'أنت'},
    'squad_sign_in': {
      'en': 'Sign in to create or join a squad.',
      'ar': 'سجّل الدخول لإنشاء فريق أو الانضمام إليه.',
    },
    'write_review': {'en': 'Write Review', 'ar': 'اكتب تقييمًا'},
    'community_reviews': {'en': 'Community Reviews', 'ar': 'تقييمات المجتمع'},
    'no_reviews': {
      'en': 'No reviews yet. Be the first to share your story!',
      'ar': 'لا توجد تقييمات بعد. كن أول من يشارك قصته!',
    },
    'about_place': {'en': 'About this place', 'ar': 'عن هذا المكان'},
    'nearby_places': {'en': 'Nearby Places', 'ar': 'أماكن قريبة'},
    'trip_visited': {'en': 'Visited', 'ar': 'تمت زيارتها'},
    'trip_visited_badge': {'en': 'Visited', 'ar': 'تمت الزيارة'},
    'trip_tab_saved': {'en': 'Saved', 'ar': 'المحفوظة'},
    'trip_tab_visited': {'en': 'Visited', 'ar': 'الزيارات'},
    'trip_tab_saved_empty_title': {
      'en': 'Nothing saved yet',
      'ar': 'مفيش حاجة محفوظة لسه',
    },
    'trip_tab_saved_empty_body': {
      'en': 'Tap the bookmark on any place to save it here for later.',
      'ar': 'اضغط على أيقونة الحفظ في أي مكان وهيظهر هنا.',
    },
    'trip_tab_visited_empty_title': {
      'en': 'No visits yet',
      'ar': 'مفيش زيارات لسه',
    },
    'trip_tab_visited_empty_body': {
      'en': 'Tap the flag on any place to check in — your visits show up here.',
      'ar': 'سجّل حضورك في أي مكان من زر العلم، وهتلاقي زياراتك هنا.',
    },
    'share_app': {'en': 'Share EgyptLore', 'ar': 'شارك إيجيبت لور'},
    'share_tour': {'en': 'Share completed tour', 'ar': 'شارك الجولة المكتملة'},
    'share_completed_tour': {'en': 'Tour completed', 'ar': 'جولة مكتملة'},
    'share_tour_details': {
      'en': '{places} places · {duration}',
      'ar': '{places} أماكن · {duration}',
    },
    'share_photo': {'en': 'Share photo', 'ar': 'مشاركة الصورة'},
    'share_place_photo': {
      'en': 'A moment from this place',
      'ar': 'لحظة من هذا المكان',
    },
    'share_card_footer': {
      'en': 'Discover the story behind every place',
      'ar': 'اكتشف حكاية كل مكان',
    },
    'share_failed': {
      'en': 'Could not prepare this share image. Please try again.',
      'ar': 'تعذر تجهيز صورة المشاركة. حاول مرة أخرى.',
    },
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
    'review_hint': {'en': 'Share your experience...', 'ar': 'شاركنا تجربتك...'},
    'add_photo_btn': {'en': 'Add Photo', 'ar': 'أضف صورة'},
    'post_review': {'en': 'Post Review', 'ar': 'انشر التقييم'},
    'review_empty_warn': {
      'en': 'Please write a comment first',
      'ar': 'من فضلك اكتب تعليقًا أولًا',
    },
    'review_failed': {'en': 'Could not post review', 'ar': 'تعذر نشر التقييم'},
    'delete_photo_q': {'en': 'Delete this photo?', 'ar': 'حذف هذه الصورة؟'},
    'delete_review_q': {'en': 'Delete this review?', 'ar': 'حذف هذا التقييم؟'},
    'delete': {'en': 'Delete', 'ar': 'حذف'},
    'edit': {'en': 'Edit', 'ar': 'تعديل'},

    'trip_title': {'en': 'My Trip Planner', 'ar': 'مخطط رحلتي'},

    'geo_title': {'en': 'Geofencing Alerts', 'ar': 'تنبيهات الموقع'},
    'geo_hero_title': {
      'en': 'Get notified nearby',
      'ar': 'تنبيهات عند الاقتراب',
    },
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
      'en': '{d} km from city center',
      'ar': '{d} كم من مركز المدينة',
    },
    'geo_select_first': {
      'en': 'Choose at least one place before enabling nearby alerts.',
      'ar': 'اختر مكانًا واحدًا على الأقل قبل تفعيل التنبيهات القريبة.',
    },
    'geo_background_title': {
      'en': 'Allow background location?',
      'ar': 'السماح بالموقع في الخلفية؟',
    },
    'geo_background_explanation': {
      'en':
          'EgyptLore collects location data in the background to enable '
          'geofenced notifications for nearby historical landmarks, even '
          'when the app is closed or not in use. This happens only while '
          'nearby alerts are enabled.',
      'ar':
          'يجمع EgyptLore بيانات الموقع في الخلفية لتمكين الإشعارات المحددة '
          'جغرافيًا عن المعالم التاريخية القريبة، حتى عندما يكون التطبيق '
          'مغلقًا أو غير قيد الاستخدام. يحدث ذلك فقط أثناء تفعيل التنبيهات '
          'القريبة.',
    },
    'privacy_policy_title': {'en': 'Privacy Policy', 'ar': 'سياسة الخصوصية'},
    'delete_account_public': {
      'en': 'Account deletion instructions',
      'ar': 'تعليمات حذف الحساب',
    },
    'public_link_failed': {
      'en': 'Could not open the page. Please try again later.',
      'ar': 'تعذر فتح الصفحة. حاول مرة أخرى لاحقًا.',
    },
    'subscription_disclosure': {
      'en':
          'Subscriptions renew automatically unless canceled at least 24 hours before the end of the current period. Payment is charged to your Google Play account at confirmation. Manage or cancel anytime in Google Play > Payments & subscriptions. Deleting your EgyptLore account does not cancel an active subscription.',
      'ar':
          'تتجدد الاشتراكات تلقائيًا ما لم تُلغَ قبل 24 ساعة على الأقل من نهاية الفترة الحالية. يُحصّل الدفع عبر حسابك في Google Play عند التأكيد. يمكنك إدارة الاشتراك أو إلغاؤه من Google Play > الدفعات والاشتراكات. حذف حساب EgyptLore لا يلغي الاشتراك النشط.',
    },
    'terms_of_service_title': {'en': 'Terms of Service', 'ar': 'شروط الخدمة'},
    'profile_legal_title': {
      'en': 'Settings & Legal',
      'ar': 'الإعدادات والشؤون القانونية',
    },
    'delete_account_title': {'en': 'Delete Account', 'ar': 'حذف الحساب'},
    'delete_account_warning': {
      'en':
          'This permanently deletes your account, personal data, saved items, and check-ins. Your EgyptLore Pro access will be lost. Deleting the account does not cancel or refund billing managed by Apple or Google; cancel any active subscription in your store settings first. This action cannot be undone.',
      'ar':
          'سيؤدي ذلك إلى حذف حسابك وبياناتك الشخصية والعناصر المحفوظة وتسجيلات الوصول نهائيًا. ستفقد إمكانية الوصول إلى إيجيبت لور برو. حذف الحساب لا يلغي أو يسترد المدفوعات التي تديرها Apple أو Google؛ ألغِ أي اشتراك نشط من إعدادات المتجر أولًا. لا يمكن التراجع عن هذا الإجراء.',
    },
    'delete_account_confirm': {'en': 'Delete my account', 'ar': 'احذف حسابي'},
    'delete_account_failed': {
      'en': 'Your account could not be deleted. Please try again.',
      'ar': 'تعذر حذف حسابك. حاول مرة أخرى.',
    },
    'geo_enable': {'en': 'Continue', 'ar': 'متابعة'},
    'geo_read_privacy_policy': {
      'en': 'Read the Privacy Policy',
      'ar': 'اقرأ سياسة الخصوصية',
    },
    'geo_background_denied': {
      'en':
          'Background location was not allowed. You can enable it in Settings.',
      'ar': 'لم يتم السماح بالموقع في الخلفية. يمكنك تفعيله من الإعدادات.',
    },
    'geo_notifications_denied': {
      'en':
          'Notifications are disabled. Enable them in Settings to receive nearby alerts.',
      'ar':
          'الإشعارات معطلة. فعّلها من الإعدادات لاستلام تنبيهات الأماكن القريبة.',
    },
    'geo_unsupported': {
      'en': 'Nearby alerts are not supported on this device.',
      'ar': 'تنبيهات الأماكن القريبة غير مدعومة على هذا الجهاز.',
    },
    'geo_start_failed': {
      'en': 'Nearby alerts could not be started. Please try again.',
      'ar': 'تعذر تشغيل تنبيهات الأماكن القريبة. حاول مرة أخرى.',
    },
    'checkin_too_far': {
      'en': 'You need to be within 100 meters of this place to check in.',
      'ar': 'يجب أن تكون على بُعد ١٠٠ متر من هذا المكان لتسجيل الزيارة.',
    },
    'checkin_location_permission': {
      'en': 'Allow location access to verify your check-in.',
      'ar': 'اسمح بالوصول إلى الموقع للتحقق من تسجيل زيارتك.',
    },
    'checkin_location_disabled': {
      'en': 'Turn on location services to check in.',
      'ar': 'فعّل خدمات الموقع لتسجيل زيارتك.',
    },
    'checkin_location_unavailable': {
      'en': 'Your location could not be verified. Please try again.',
      'ar': 'تعذر التحقق من موقعك. حاول مرة أخرى.',
    },
    'checkin_save_failed': {
      'en': 'Check-in could not be saved',
      'ar': 'تعذر حفظ تسجيل الزيارة',
    },
    'tour_progress': {
      'en': '{visited}/{total} visited',
      'ar': '{visited}/{total} تمت زيارتها',
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
    'chat_send_failed': {
      'en': 'Could not send your message. Please try again.',
      'ar': 'تعذر إرسال رسالتك. حاول مرة أخرى.',
    },
    'chat_sign_in_required': {
      'en': 'Sign in with an account to join the chat.',
      'ar': 'سجّل الدخول بحساب للمشاركة في الدردشة.',
    },

    'map_offline_fallback': {
      'en': 'Offline guidance: showing an estimated road-corridor route.',
      'ar': 'إرشاد دون اتصال: عرض مسار تقديري عبر ممرات الطرق.',
    },
    'map_offline_corridor': {
      'en': 'Offline guidance: showing an estimated road-corridor route.',
      'ar': 'إرشاد دون اتصال: عرض مسار تقديري عبر ممرات الطرق.',
    },
    'map_cached_road_route': {
      'en': 'Offline map: showing the cached road route to your destination.',
      'ar': 'خريطة دون اتصال: يظهر مسار الطريق المحفوظ إلى وجهتك.',
    },
    'map_straight_line_distance': {
      'en': '{distance} away · bearing {bearing}°',
      'ar': 'يبعد {distance} · الاتجاه {bearing}°',
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
    'tour_pro': {'en': 'EgyptLore Pro', 'ar': 'إيجيبت لور برو'},
    'tour_pro_locked': {
      'en':
          'This tour is part of EgyptLore Pro. Hidden Gems and Premium Tours are for Pro members.',
      'ar':
          'هذه الجولة متاحة ضمن إيجيبت لور برو. الجواهر المخفية والجولات المميزة حصرية لأعضاء برو.',
    },
    'pro_title': {'en': 'EgyptLore Pro', 'ar': 'إيجيبت لور برو'},
    'pro_detected_offerings': {
      'en': 'Detected offerings:',
      'ar': 'العروض المكتشفة:',
    },
    'pro_subtitle': {
      'en': 'Discover more of the stories behind your city.',
      'ar': 'اكتشف المزيد من الحكايات وراء مدينتك.',
    },
    'pro_benefit_hidden_gems': {
      'en': 'Hidden Gems and Premium Tours',
      'ar': 'الجواهر المخفية والجولات المميزة',
    },
    'pro_benefit_premium_tours': {
      'en': 'Curated Premium Tours from local experts',
      'ar': 'جولات مميزة مختارة من خبراء محليين',
    },
    'pro_benefit_ai': {
      'en': '50 AI Questions daily',
      'ar': '٥٠ سؤالًا للذكاء الاصطناعي يوميًا',
    },
    'pro_benefit_offline': {
      'en': 'Offline Downloads',
      'ar': 'التنزيلات دون اتصال',
    },
    'pro_benefit_badges': {
      'en': 'Exclusive Pro Badges',
      'ar': 'شارات برو حصرية',
    },
    'pro_weekly': {'en': 'Explorer Pass', 'ar': 'باقة المستكشف'},
    'pro_weekly_description': {
      'en': 'Pro access for one week',
      'ar': 'وصول برو لمدة أسبوع',
    },
    'pro_weekly_badge': {'en': 'WEEKLY PLAN', 'ar': 'باقة أسبوعية'},
    'pro_weekly_price': {
      'en': '49 EGP / week',
      'ar': '49 جنيهًا مصريًا / أسبوع',
    },
    'pro_monthly': {'en': 'Monthly Pro Plan', 'ar': 'اشتراك برو شهري'},
    'pro_monthly_description': {
      'en': 'Perfect for short trips',
      'ar': 'مثالي للرحلات القصيرة',
    },
    'pro_monthly_badge': {'en': 'MOST POPULAR', 'ar': 'الأكثر شيوعًا'},
    'pro_monthly_price': {
      'en': '99 EGP / month',
      'ar': '99 جنيهًا مصريًا / شهر',
    },
    'pro_annual': {'en': 'Annual Pro Plan', 'ar': 'اشتراك برو سنوي'},
    'pro_annual_description': {
      'en': 'One year of complete Pro access',
      'ar': 'عام كامل من مزايا برو',
    },
    'pro_annual_badge': {
      'en': 'BEST VALUE · SAVE 40%',
      'ar': 'أفضل قيمة · وفّر ٤٠٪',
    },
    'pro_annual_price': {
      'en': '699 EGP / year',
      'ar': '699 جنيهًا مصريًا / سنة',
    },
    'pro_annual_monthly_equivalent': {
      'en': 'Equivalent to ~58 EGP / month',
      'ar': 'ما يعادل نحو 58 جنيهًا مصريًا / شهر',
    },
    'pro_billing_period': {
      'en': 'Billed every {period}',
      'ar': 'يتم التجديد كل {period}',
    },
    'pro_period_day': {'en': 'day', 'ar': 'يوم'},
    'pro_period_days': {'en': '{count} days', 'ar': '{count} أيام'},
    'pro_period_week': {'en': 'week', 'ar': 'أسبوع'},
    'pro_period_weeks': {'en': '{count} weeks', 'ar': '{count} أسابيع'},
    'pro_period_month': {'en': 'month', 'ar': 'شهر'},
    'pro_period_months': {'en': '{count} months', 'ar': '{count} أشهر'},
    'pro_period_year': {'en': 'year', 'ar': 'سنة'},
    'pro_period_years': {'en': '{count} years', 'ar': '{count} سنوات'},
    'pro_includes_free': {
      'en': 'Everything in Free, plus:',
      'ar': 'كل مزايا الخطة المجانية، بالإضافة إلى:',
    },
    'pro_subscribe': {'en': 'Choose this plan', 'ar': 'اختر هذه الخطة'},
    'pro_store_note': {
      'en': 'Secure purchase through the App Store or Google Play.',
      'ar': 'شراء آمن عبر App Store أو Google Play.',
    },
    'pro_setup_note': {
      'en':
          'Pro subscriptions are coming soon. Stay tuned for the official launch!',
      'ar': 'اشتراكات برو قادمة قريباً. ترقّبوا الإطلاق الرسمي!',
    },
    'pro_coming_soon': {'en': 'Coming soon', 'ar': 'قريباً'},
    'pro_setup_required': {
      'en':
          'Purchases are not configured yet. Add the RevenueCat public SDK keys to enable them.',
      'ar':
          'لم يتم إعداد عمليات الشراء بعد. أضف مفاتيح RevenueCat العامة لتفعيلها.',
    },
    'pro_sign_in_required': {
      'en': 'Sign in to subscribe to EgyptLore Pro.',
      'ar': 'سجّل الدخول للاشتراك في إيجيبت لور برو.',
    },
    'pro_offering_unavailable': {
      'en': 'This purchase option is not available right now.',
      'ar': 'خيار الشراء هذا غير متاح حاليًا.',
    },
    'pro_purchase_success': {
      'en': 'EgyptLore Pro is active. Enjoy exploring!',
      'ar': 'تم تفعيل إيجيبت لور برو. استمتع بالاكتشاف!',
    },
    'pro_purchase_pending': {
      'en': 'Purchase received. Pro access will activate after verification.',
      'ar': 'تم استلام الشراء. سيتم تفعيل برو بعد التحقق.',
    },
    'pro_purchase_failed': {
      'en': 'The purchase could not be completed. Please try again.',
      'ar': 'تعذر إكمال عملية الشراء. حاول مرة أخرى.',
    },
    'pro_member': {'en': 'EgyptLore Pro Member', 'ar': 'عضو إيجيبت لور برو'},
    'pro_tier_weekly': {'en': 'Weekly', 'ar': 'أسبوعي'},
    'pro_tier_monthly': {'en': 'Monthly', 'ar': 'شهري'},
    'pro_tier_annual': {'en': 'Annual', 'ar': 'سنوي'},
    'pro_tier_lifetime': {'en': 'Lifetime', 'ar': 'مدى الحياة'},
    'pro_member_subtitle': {
      'en': 'Your membership is active',
      'ar': 'عضويتك فعّالة',
    },
    'restore_purchases': {'en': 'Restore Purchases', 'ar': 'استعادة المشتريات'},
    'restore_sign_in_required': {
      'en': 'Sign in to restore your EgyptLore Pro purchases.',
      'ar': 'سجّل الدخول لاستعادة مشتريات إيجيبت لور برو.',
    },
    'restore_setup_required': {
      'en': 'Purchase restoration is not available right now.',
      'ar': 'استعادة المشتريات غير متاحة حاليًا.',
    },
    'restore_none_found': {
      'en': 'No previous Pro purchases were found.',
      'ar': 'لم يتم العثور على مشتريات سابقة لبرو.',
    },
    'restore_success': {
      'en': 'Your EgyptLore Pro purchases have been restored.',
      'ar': 'تمت استعادة مشتريات إيجيبت لور برو.',
    },
    'restore_pending': {
      'en': 'Purchase restored. Pro access will activate after verification.',
      'ar': 'تمت استعادة الشراء. سيتم تفعيل برو بعد التحقق.',
    },
    'restore_failed': {
      'en': 'Purchases could not be restored. Please try again.',
      'ar': 'تعذرت استعادة المشتريات. حاول مرة أخرى.',
    },
    'tour_about': {'en': 'About this Tour', 'ar': 'عن هذه الجولة'},
    'tour_itinerary': {'en': 'Tour Itinerary', 'ar': 'خط سير الجولة'},
    'tour_stops_count': {'en': '{n} stops', 'ar': '{n} محطة'},
    'tour_stops_along': {
      'en': '{n} stops along the way',
      'ar': '{n} محطة على الطريق',
    },
    'tour_visited_badge': {'en': 'Visited', 'ar': 'تمت الزيارة'},
    'tour_start_nav': {'en': 'Start Navigation', 'ar': 'ابدأ التنقل'},
    'tour_locations_count': {'en': '{n} locations', 'ar': '{n} موقع'},
    'tour_visited': {'en': 'Visited', 'ar': 'تمت الزيارة'},

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

    'emg_title': {'en': 'Emergency', 'ar': 'الطوارئ'},
    'admin_title': {'en': 'Admin Panel', 'ar': 'لوحة الإدارة'},
    'admin_forbidden': {'en': 'Admin only', 'ar': 'للمشرفين فقط'},
    'admin_forbidden_sub': {
      'en': 'Your account is not authorised to add places.',
      'ar': 'حسابك مش مخوّل بإضافة أماكن.',
    },
    'admin_add_new': {'en': 'Add new place', 'ar': 'إضافة مكان'},
    'admin_view_list': {'en': 'View places list', 'ar': 'قائمة الأماكن'},
    'admin_field_name': {'en': 'Name', 'ar': 'الاسم'},
    'admin_field_category': {'en': 'Category', 'ar': 'الفئة'},
    'admin_field_address': {'en': 'Address', 'ar': 'العنوان'},
    'admin_field_description': {'en': 'Description', 'ar': 'الوصف'},
    'admin_field_image': {'en': 'Image', 'ar': 'الصورة'},
    'admin_field_hours': {'en': 'Open hours', 'ar': 'ساعات العمل'},
    'admin_field_rating': {'en': 'Rating', 'ar': 'التقييم'},
    'admin_err_name': {'en': 'Name is required', 'ar': 'الاسم مطلوب'},
    'admin_err_category': {
      'en': 'Category is required (e.g. ATM, Hotel, Cafe)',
      'ar': 'الفئة مطلوبة (مثلاً ATM, Hotel, Cafe)',
    },
    'admin_submit': {'en': 'Add to map', 'ar': 'أضف للخريطة'},
    'admin_added': {'en': 'Added', 'ar': 'اتضاف'},
    'admin_failed': {'en': 'Failed', 'ar': 'فشل'},
    'admin_location_search': {
      'en': 'Location search (Nominatim / OpenStreetMap)',
      'ar': 'بحث عن موقع (Nominatim / OpenStreetMap)',
    },
    'admin_location_search_hint': {
      'en': 'Type a place name or address (e.g. "Bibliotheca Alexandrina")',
      'ar': 'اكتب اسم مكان أو عنوان (مثلاً "Bibliotheca Alexandrina")',
    },
    'admin_location_no_results': {
      'en': 'No results. Try a more specific query.',
      'ar': 'مفيش نتائج. جرّب استعلام أعم.',
    },
    'admin_err_location': {
      'en': 'Pick a location from the search results first.',
      'ar': 'اختار موقع من نتائج البحث الأول.',
    },
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

    'login_welcome': {
      'en': 'Welcome to\nEgyptLore',
      'ar': 'أهلًا بك في\nإيجيبت لور',
    },
    'login_subtitle': {
      'en': 'Sign in to save your favorite places and access exclusive tours.',
      'ar': 'سجّل دخولك لحفظ أماكنك المفضلة والوصول لجولات حصرية.',
    },
    'google_sha1_error': {
      'en': 'Google Sign-In setup error (Code 10). Contact developer.',
      'ar': 'خطأ إعدادات تسجيل جوجل (كود 10). تواصل مع المطور.',
    },
    'google_config_error': {
      'en': 'Google Sign-In not configured properly. Try email login.',
      'ar': 'تسجيل جوجل غير مُعد بشكل صحيح. جرّب الإيميل.',
    },
    'google_network_error': {
      'en': 'Network error. Check your connection.',
      'ar': 'خطأ في الشبكة. تأكد من اتصالك بالإنترنت.',
    },
    'google_general_error': {
      'en': 'Google Sign-In failed. Try email login instead.',
      'ar': 'فشل تسجيل جوجل. جرّب الإيميل بدلاً من كده.',
    },
    'login_full_name': {'en': 'Full Name', 'ar': 'الاسم الكامل'},
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
    'login_err_password_short': {
      'en': 'Password must be at least 6 characters',
      'ar': 'كلمة المرور لازم تكون 6 حروف على الأقل',
    },
    'login_err_account_exists': {
      'en': 'An account with this email already exists. Try signing in.',
      'ar': 'في حساب بالفعل بالإيميل ده. جرّب تسجّل دخول.',
    },
    'login_err_no_account': {
      'en': 'No account found with this email. Tap Sign Up to create one.',
      'ar': 'مفيش حساب بالإيميل ده. اعمل حساب جديد من تسجيل.',
    },
    'login_err_wrong_password': {
      'en': 'Wrong password. Please try again.',
      'ar': 'كلمة المرور غلط. حاول تاني.',
    },
    'login_err_unknown': {
      'en': 'Something went wrong. Please try again.',
      'ar': 'حصل حاجة غلط. حاول تاني.',
    },
    'login_password': {'en': 'Password', 'ar': 'كلمة المرور'},
    'login_password_hint': {
      'en': 'Enter your password',
      'ar': 'اكتب كلمة مرورك',
    },
    'login_password_hint_signup': {
      'en': 'At least 6 characters',
      'ar': '6 حروف على الأقل',
    },
    'login_sign_in': {'en': 'Sign In', 'ar': 'تسجيل الدخول'},
    'login_sign_up': {'en': 'Sign Up', 'ar': 'إنشاء حساب'},
    'login_no_account': {'en': 'No account yet?', 'ar': 'مفيش حساب لسه؟'},
    'login_have_account': {
      'en': 'Already have an account?',
      'ar': 'عندك حساب بالفعل؟',
    },
    'login_username': {'en': 'Username', 'ar': 'اسم المستخدم'},
    'login_username_hint': {
      'en': '3-20 chars: letters, digits, . _ -',
      'ar': '3-20 حرف: حروف وأرقام و . _ -',
    },
    'login_err_username_empty': {
      'en': 'Please enter a username',
      'ar': 'من فضلك ادخل اسم المستخدم',
    },
    'login_err_username_length': {
      'en': 'Username must be 3-20 characters',
      'ar': 'اسم المستخدم لازم يكون 3 لـ 20 حرف',
    },
    'login_err_username_chars': {
      'en': 'Only letters, digits, dot, underscore and dash',
      'ar': 'حروف وأرقام و . _ - فقط',
    },
    'login_or': {'en': 'or', 'ar': 'أو'},
    'login_google': {'en': 'Google', 'ar': 'جوجل'},
    'login_google_unavailable': {
      'en': 'Google sign-in unavailable. Use email or continue as guest.',
      'ar': 'جوجل مش متاح دلوقتي. استخدم الإيميل أو كمّل كضيف.',
    },
    'login_google_timeout': {
      'en': 'Google sign-in took too long. Try again or use email.',
      'ar': 'تسجيل الدخول بجوجل استغرق وقت طويل. حاول تاني أو استخدم الإيميل.',
    },
    'login_google_failed': {
      'en': 'Google sign-in failed. Check your Supabase redirect URL settings.',
      'ar':
          'فشل تسجيل الدخول بجوجل. تأكد من إعدادات الـ redirect URL في Supabase.',
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
      'ar':
          'اكتشف أكتر من ٣٠ جوهرة مخفية ومعلم في إسكندرية معظم السياح مبيعرفوهاش.',
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

    'bt_label_go_now': {'en': 'Open now', 'ar': 'مفتوح الآن'},
    'bt_reason_great_time': {
      'en': 'Great time to visit',
      'ar': 'وقت مثالي للزيارة',
    },
    'bt_label_decent_now': {'en': 'Decent now', 'ar': 'كويس دلوقتي'},
    'bt_label_wait': {'en': 'Wait for a better window', 'ar': 'استنى وقت أحسن'},
    'bt_closed_now': {'en': 'Closed now', 'ar': 'مغلق حالياً'},
    'bt_closed_at_night': {'en': 'Closed at night', 'ar': 'مغلق ليلاً'},
    'bt_best_daylight': {
      'en': 'Best visited in daylight',
      'ar': 'الأفضل زيارته نهاراً',
    },
    'bt_best_morning': {
      'en': 'Best visited in the morning',
      'ar': 'يُفضل الزيارة صباحاً',
    },

    'bt_reason_quietest': {
      'en': 'Quietest, best light',
      'ar': 'أهدأ وقت وأفضل إضاءة',
    },
    'bt_reason_admin_set': {'en': 'Set by admin', 'ar': 'محدد من الأدمن'},
    'bt_reason_cool_photo': {
      'en': 'Cool, photogenic',
      'ar': 'مناخس، وقت التصوير',
    },
    'bt_reason_hot_crowd': {'en': 'Hot & crowded', 'ar': 'حر وزحمة'},
    'bt_reason_warm_ok': {'en': 'Warm but ok', 'ar': 'دافي بس مقبول'},
    'bt_reason_golden_hour': {
      'en': 'Golden hour magic',
      'ar': 'سحر الساعة الذهبية',
    },
    'bt_reason_closed_unsafe': {'en': 'Closed, unsafe', 'ar': 'مقفول ومش آمن'},
    'bt_reason_cool_empty': {'en': 'Cool & empty', 'ar': 'مناخس وفاضي'},
    'bt_reason_best_photos': {'en': 'Best for photos', 'ar': 'أفضل وقت للصور'},
    'bt_reason_hot_shaded': {'en': 'Hot but shaded', 'ar': 'حر بس في ضل'},
    'bt_reason_soft_light': {'en': 'Soft light', 'ar': 'إضاءة هادية'},
    'bt_reason_often_closing': {'en': 'Often closing', 'ar': 'بيقفل غالباً'},
    'bt_reason_closed': {'en': 'Closed', 'ar': 'مقفول'},
    'bt_reason_breakfast': {'en': 'Breakfast spots', 'ar': 'وقت الفطار'},
    'bt_reason_lunch': {'en': 'Lunch rush', 'ar': 'وقت الغدا'},
    'bt_reason_dinner': {'en': 'Dinner vibes', 'ar': 'وقت العشا'},
    'bt_reason_too_early': {'en': 'Too early', 'ar': 'بدري أوي'},

    'tour_guide_hint': {'en': 'Ask about {name}...', 'ar': 'اسأل عن {name}...'},

    'prayer_load_failed': {
      'en': 'Failed to load prayer times',
      'ar': 'فشل تحميل مواقيت الصلاة',
    },

    'prayer_fajr': {'en': 'Fajr', 'ar': 'الفجر'},
    'prayer_sunrise': {'en': 'Sunrise', 'ar': 'الشروق'},
    'prayer_dhuhr': {'en': 'Dhuhr', 'ar': 'الظهر'},
    'prayer_asr': {'en': 'Asr', 'ar': 'العصر'},
    'prayer_maghrib': {'en': 'Maghrib', 'ar': 'المغرب'},
    'prayer_isha': {'en': 'Isha', 'ar': 'العشاء'},

    'loc_perm_blocked': {
      'en': 'Location is blocked. Enable it in Settings to get nearby alerts.',
      'ar': 'تم رفض إذن الموقع. فعّله من الإعدادات عشان توصلك التنبيهات.',
    },
    'loc_service_off': {
      'en':
          'Location services are off. Turn them on to see what is around you.',
      'ar': 'خدمات الموقع مقفولة. شغّلها عشان تشوف اللي حواليك.',
    },
    'open_settings': {'en': 'Open settings', 'ar': 'افتح الإعدادات'},
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
