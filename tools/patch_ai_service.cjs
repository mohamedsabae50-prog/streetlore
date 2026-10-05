const fs = require('fs');

const filePath = 'D:/codes/streetlore/lib/core/services/ai_tour_guide_service.dart';
let src = fs.readFileSync(filePath, 'utf-8');

// 1. Replace system prompt anchor block (replace just the body, not the function signature).
const OLD_ANCHOR = String.raw`ALEXANDRIA — ANCHOR FACTS (use these as truth anchors):
- Founded 331 BC by Alexander the Great. Ptolemaic capital. Once the largest
  city in the ancient world and home to the Lighthouse of Pharos.
- Climate: Mediterranean. Hot dry summers (26-32°C, May-Sep), mild wet winters
  (12-18°C, Nov-Feb). Sea breeze moderates heat.
- Corniche stretches ~30 km along the harbour — best sunset walks.
- Local currency: Egyptian Pound (EGP). Mid-2024 ~50 EGP/USD.
- Best walking districts: Downtown (Mansheya), Anfushi for seafood + bay views.
- Famous landmarks: Bibliotheca Alexandrina, Qaitbay Citadel (1480),
  Pompey's Pillar, Catacombs of Kom El Shoqafa, Montaza Palace, Stanley Bridge,
  Abu Qir Bay.
- Signature foods: seafood (sea bass, calamari, shrimp), ful & ta'amiya,
  alexandrian liver (kibda alexandriya), roz bel laban, ice cream from Azza,
  mango juice at Abo Youssef.
- Day-trip options: Rosetta (Rashid) 65 km east, Abu Qir (fort + battlefields)
  32 km NE, Wadi El Natrun monasteries 100 km.
- Rush hours: 8-10 AM and 4-7 PM. Friday is the weekend — expect closures and
  crowds at mosques mid-day.`;

const NEW_ANCHOR = String.raw`LOCAL GUIDE — GENERAL ANCHOR FACTS (use as truth anchors and adapt to whichever city or area the user is in):
- Read the place details (name, address, description, category, hours, rating,
  price, coordinates) for the specific place the visitor opened before answering.
- Honour the visitor's chosen language — reply in the same language they use.
- Climate, currency, transit, food, prayer times and weekend behaviour all
  vary by city; if you know something specific about the city or
  neighbourhood, use it; if you don't, stay generic and offer to look it up.
- Famous landmarks / signature foods / day-trip options: cite them by the
  place's description field whenever it mentions one — never invent
  landmarks or venues.
- Rush hours: 8-10 AM and 4-7 PM are typical for most cities; mention
  specific rush-hour / prayer / Friday-weekend behaviour only when you are
  confident about the city.
- Never assume the visitor is in Alexandria or any specific city — let the
  place's address, category and description guide the answer.`;

if (!src.includes(OLD_ANCHOR)) {
  console.error('OLD_ANCHOR not found');
  process.exit(1);
}
src = src.replace(OLD_ANCHOR, NEW_ANCHOR);

// 2. Update the "you can answer about..." tail.
const OLD_TAIL = String.raw`You can answer about: history, best times to visit, what to wear, nearby food,
how to get there, photo tips, similar places in Alexandria, family-friendliness,
safety, and accessibility.''';`;

const NEW_TAIL = String.raw`You can answer about: history, best times to visit, what to wear, nearby food,
how to get there, photo tips, similar places in the same city or area,
family-friendliness, safety, and accessibility.''';`;

if (!src.includes(OLD_TAIL)) {
  console.error('OLD_TAIL not found');
  process.exit(1);
}
src = src.replace(OLD_TAIL, NEW_TAIL);

// 3. Update start() signature + locale parameter passing through to the welcome.
src = src.replace(
  'Future<void> start(PlaceModel place) async {',
  'Future<void> start(PlaceModel place, {String locale = \'en\'}) async {'
);

// 4. The two ChatMessage text references — inline welcome + offline welcome call.
const OLD_INLINE_WELCOME = String.raw`    _messages.add(
      ChatMessage(
        text:
            'Marhaba! I\'m your local guide for ${'$'}{place.nameEn}. Ask me anything — history, tips, what to see nearby, or anything else. بالإنجليزي أو العربي، زي ما تحب. 😊',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }`;

const NEW_INLINE_WELCOME = String.raw`    _messages.add(
      ChatMessage(
        text: _initialWelcome(place, locale),
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  String _initialWelcome(PlaceModel place, String locale) {
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

if (!src.includes(OLD_INLINE_WELCOME)) {
  console.error('OLD_INLINE_WELCOME not found');
  process.exit(1);
}
src = src.replace(OLD_INLINE_WELCOME, NEW_INLINE_WELCOME);

// 5. Update _offlineWelcome call site inside start()
src = src.replace(
  'text: _offlineWelcome(place),',
  'text: _offlineWelcome(place, locale),'
);

// 6. Update _offlineWelcome signature + locale-aware body.
const OLD_OFFLINE_FN = String.raw`  String _offlineWelcome(PlaceModel place) {
    return '👋 مرحباً! أنا دليلك المحلي لـ ${'$'}{place.nameEn}.\n\n${'$'}{place.descriptionEn}\n\nاسألني عن: المواعيد، الأسعار، التاريخ، النصايح، أو العنوان!\n\n(وضع محلي — Gemini API غير مفعّل في الوقت الحالي أو الـ key غير صالح. كل الإجابات هنا من بيانات محلية على الجهاز.)';
  }`;

const NEW_OFFLINE_FN = String.raw`  String _offlineWelcome(PlaceModel place, String locale) {
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
        'invalid. All answers here comes from on-device data.)';
  }`;

if (!src.includes(OLD_OFFLINE_FN)) {
  console.error('OLD_OFFLINE_FN not found');
  process.exit(1);
}
src = src.replace(OLD_OFFLINE_FN, NEW_OFFLINE_FN);

// 7. Rename askAlexandria -> askLocalGuide + rewrite system prompt.
const OLD_ASK_FN = String.raw`  static Future<String> askAlexandria(String userText) async {
    final system = '''You are the street-level Alexandria tourism expert inside the "Streetlore" app. You answer questions about travel, places, food, history, and culture in Alexandria, Egypt.

STRICT RULES:
1. ONLY answer questions related to travel, places, history, culture, food, or tourism in Alexandria, Egypt.
2. If the user asks about coding, mathematics, general chat, politics, news, medical advice, or any non-tourism topic, politely decline and state your specific role (e.g. "I'm your Alexandria tourism guide — I can only help with travel, places, history, and culture here.").
3. Be concise but COMPLETE. Never cut a sentence mid-thought. If you would run out of tokens, wrap the answer cleanly with a final full sentence.
4. Use specific Alexandria details when possible (neighborhoods like Anfushi, Mansheya, Stanley, Moharam Bek, Attarin; landmarks like Bibliotheca Alexandrina, Qaitbay Citadel, Pompey's Pillar, Catacombs of Kom El Shoqafa, Montaza).
5. Never invent places that don't exist. If unsure, say so and suggest the user open the app map.
6. Speak directly to the user ("you") — friendly, opinionated, like a local friend showing them around.''';`;

const NEW_ASK_FN = String.raw`  static Future<String> askLocalGuide(String userText) async {
    final system = '''You are the street-level local tourism expert inside the "Streetlore" app. You answer questions about travel, places, food, history, and culture for the city or area the user is currently exploring.

STRICT RULES:
1. ONLY answer questions related to travel, places, history, culture, food, or tourism in the city or area the user is exploring.
2. If the user asks about coding, mathematics, general chat, politics, news, medical advice, or any non-tourism topic, politely decline and state your specific role (e.g. "I'm your local Streetlore guide — I can only help with travel, places, history, and culture here.").
3. Be concise but COMPLETE. Never cut a sentence mid-thought. If you would run out of tokens, wrap the answer cleanly with a final full sentence.
4. Use specific local details when possible (well-known landmarks, neighbourhoods, signature foods, transit options) for the city or area the user is in. Do NOT hard-code any single city — adapt to whichever city or area the user is asking about.
5. Never invent places that don't exist. If unsure, say so and suggest the user open the app map.
6. Speak directly to the user ("you") — friendly, opinionated, like a local friend showing them around.''';`;

if (!src.includes(OLD_ASK_FN)) {
  console.error('OLD_ASK_FN not found');
  process.exit(1);
}
src = src.replace(OLD_ASK_FN, NEW_ASK_FN);

// 8. Update call site: askAlexandria -> askLocalGuide
src = src.replace(
  'AITourGuideService.askAlexandria(text)',
  'AITourGuideService.askLocalGuide(text)'
);

fs.writeFileSync(filePath, src, 'utf-8');
console.log('Patched ai_tour_guide_service.dart');