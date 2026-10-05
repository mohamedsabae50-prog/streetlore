const fs = require('fs');

const file = 'D:/codes/streetlore/lib/core/services/ai_tour_guide_service.dart';
let src = fs.readFileSync(file, 'utf-8');

// Fix 1: _initialWelcome — replace concat with interpolation
const OLD_WELCOME = String.raw`  String _initialWelcome(PlaceModel place, String locale) {
    final placeName = place.localizedName(locale);
    if (locale == 'ar') {
      return 'مرحباً! أنا دليلك المحلي لـ ' +
          placeName +
          '. اسألني عن أي حاجة '
          '— التاريخ، نصايح، أماكن قريبة، أو أي سؤال تاني. '
          'بالعربي أو الإنجليزي، زي ما تحب. 😊';
    }
    return "Marhaba! I'm your local guide for " +
        placeName +
        '. Ask me anything — '
        'history, tips, what to see nearby, or anything else. '
        'In English or Arabic, whatever you prefer. 😊';
  }`;

const NEW_WELCOME = String.raw`  String _initialWelcome(PlaceModel place, String locale) {
    final placeName = place.localizedName(locale);
    if (locale == 'ar') {
      return 'مرحباً! أنا دليلك المحلي لـ $placeName. اسألني عن أي حاجة '
          '— التاريخ، نصايح، أماكن قريبة، أو أي سؤال تاني. '
          'بالعربي أو الإنجليزي، زي ما تحب. 😊';
    }
    return "Marhaba! I'm your local guide for $placeName. Ask me anything — "
        'history, tips, what to see nearby, or anything else. '
        'In English or Arabic, whatever you prefer. 😊';
  }`;

if (!src.includes(OLD_WELCOME)) {
  console.error('OLD_WELCOME not found');
  process.exit(1);
}
src = src.replace(OLD_WELCOME, NEW_WELCOME);

// Fix 2: _offlineWelcome — replace concat with interpolation
const OLD_OFFLINE = String.raw`  String _offlineWelcome(PlaceModel place, String locale) {
    final placeName = place.localizedName(locale);
    final description = place.localizedDescription(locale);
    if (locale == 'ar') {
      return '👋 مرحباً! أنا دليلك المحلي لـ ' +
          placeName +
          '.\n\n' +
          description +
          '\n\n'
          'اسألني عن: المواعيد، الأسعار، التاريخ، النصايح، أو العنوان!\n\n'
          '(وضع محلي — Gemini API غير مفعّل في الوقت الحالي أو الـ key غير '
          'صالح. كل الإجابات هنا من بيانات محلية على الجهاز.)';
    }
    return '👋 Hello! I am your local guide for ' +
        placeName +
        '.\n\n' +
        description +
        '\n\n'
        'Ask me about: hours, prices, history, tips, or address!\n\n'
        '(Offline mode — Gemini API is currently disabled or the key is '
        'invalid. All answers here come from on-device data.)';
  }`;

const NEW_OFFLINE = String.raw`  String _offlineWelcome(PlaceModel place, String locale) {
    final placeName = place.localizedName(locale);
    final description = place.localizedDescription(locale);
    if (locale == 'ar') {
      return '👋 مرحباً! أنا دليلك المحلي لـ $placeName.\n\n$description\n\n'
          'اسألني عن: المواعيد، الأسعار، التاريخ، النصايح، أو العنوان!\n\n'
          '(وضع محلي — Gemini API غير مفعّل في الوقت الحالي أو الـ key غير '
          'صالح. كل الإجابات هنا من بيانات محلية على الجهاز.)';
    }
    return '👋 Hello! I am your local guide for $placeName.\n\n$description\n\n'
        'Ask me about: hours, prices, history, tips, or address!\n\n'
        '(Offline mode — Gemini API is currently disabled or the key is '
        'invalid. All answers here come from on-device data.)';
  }`;

if (!src.includes(OLD_OFFLINE)) {
  console.error('OLD_OFFLINE not found');
  process.exit(1);
}
src = src.replace(OLD_OFFLINE, NEW_OFFLINE);

fs.writeFileSync(file, src, 'utf-8');
console.log('Cleaned ai_tour_guide_service.dart lints');