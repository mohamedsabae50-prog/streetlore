const fs = require('fs');

const filePath = 'D:/codes/streetlore/lib/core/services/ai_service.dart';
let src = fs.readFileSync(filePath, 'utf-8');

// 1. Remove the entire _alexandriaKnowledge constant block.
const OLD_KNOWLEDGE = String.raw`  static const String _alexandriaKnowledge = '''
ALEXANDRIA — ANCHOR FACTS (always ground answers here):
- Founded 331 BC by Alexander the Great. Ptolemaic capital. Once the
  largest city in the ancient world and home to the Lighthouse of
  Pharos (one of the Seven Wonders).
- Climate: Mediterranean. Hot dry summers (26-32°C, May-Sep) and mild
  wet winters (12-18°C, Nov-Feb). Sea breeze moderates heat.
- Corniche stretches ~30 km along the harbour — best sunset walks.
- Local currency: Egyptian Pound (EGP). Mid-2024 rate ~50 EGP/USD.
- Best walking districts: Downtown (Mansheya) for cafes and the
  Cecil Hotel legacy, Anfushi for seafood and bay views.
- Famous landmarks: Bibliotheca Alexandrina, Qaitbay Citadel
  (1480), Pompey's Pillar, Catacombs of Kom El Shoqafa, Montaza
  Palace gardens, Stanley Bridge, Abu Qir Bay.
- Signature foods: seafood (sea bass, calamari, shrimp), ful & ta'amiya,
  alexandrian liver (kibda alexandriya), roz bel laban, ice cream
  from Azza, mango juice at Abo Youssef.
- Day-trip options: Rosetta (Rashid) 65 km east, Abu Qir
  (battlefields + fort) 32 km NE, Wadi El Natrun monasteries 100 km.
- Rush hours: 8-10 AM and 4-7 PM. Friday is the weekend — expect
  closures and crowds at mosques mid-day.''';`;

const NEW_KNOWLEDGE = String.raw`  static const String _cityAgnosticKnowledge = '''
LOCAL GUIDE — CITY-AGNOSTIC TRAVEL PLANNING FACTS:
  - You are an expert local travel planner who helps users plan trips to
    whichever city or area they ask about. Do not assume a single city —
    adapt to the user's prompt and the place list provided below.
  - Always ground your answers in the place list (id, name, category,
    description, address, bestTimeToVisit, indoor/outdoor, coordinates)
    plus your own knowledge of the city the user mentions.
  - Use the place's description field as your primary source of
    concrete details (specific food, photo angle, time, neighbourhood).
  - Climate, currency, transit, food, prayer times and weekend behaviour
    vary by city — if you know something specific about the city the
    user is asking about, use it; if you don't, stay generic and offer
    to look it up.
  - Famous landmarks and signature foods: cite them by name only when
    you are confident they exist in the city the user is asking about.
    Never invent landmarks, neighbourhoods, or restaurants.
  - Never hard-code any single city in your replies — read the user's
    prompt to figure out which city they're asking about.''';`;

if (!src.includes(OLD_KNOWLEDGE)) {
  console.error('OLD_KNOWLEDGE not found');
  process.exit(1);
}
src = src.replace(OLD_KNOWLEDGE, NEW_KNOWLEDGE);

// 2. Replace the Alexandria-specific "You are an expert local travel planner who actually lives in Alexandria, Egypt."
src = src.replace(
  `You are an expert local travel planner who actually lives in Alexandria, Egypt.`,
  `You are an expert local travel planner. You help users plan trips to whichever city or area they're asking about. Adapt to the user's prompt and the available place list.`
);

// 3. Replace $_alexandriaKnowledge with $_cityAgnosticKnowledge
src = src.replace('$_alexandriaKnowledge', '$_cityAgnosticKnowledge');

// 4. Replace the default title fallback "Your Alexandria Adventure"
src = src.replace(
  `"Your Alexandria Adventure"`,
  `"Your Local Adventure"`
);

// 5. Replace the local plan English title
src = src.replace(
  `'Your $daysHint-Day Alexandria Plan'`,
  `'Your $daysHint-Day Local Plan'`
);

// 6. Replace the local plan English summary line
src = src.replace(
  `'A local-style $daysHint-day Alexandria plan built from your '`,
  `'A local-style $daysHint-day plan built from your '`
);

// 7. Replace the Alexandria tip
src = src.replace(
  `'Walk slowly — Alexandrian magic hides in street-level detail.'`,
  `'Walk slowly — local magic hides in street-level detail.'`
);

// 8. Replace the availablePlaces JSON line to use localized fields
const OLD_PLACES_JSON = String.raw`    final placesForContext = availablePlaces
        .map(
          (p) =>
              '{"id":"${'$'}{p.id}","name":${'$'}{jsonEncode(p.nameEn)},"category":"${'$'}{p.category}","description":${'$'}{jsonEncode(p.descriptionEn)},"address":${'$'}{jsonEncode(p.address)},"bestTimeToVisit":${'$'}{jsonEncode(p.bestTimeToVisit ?? '')},"isIndoor":${'$'}{p.isIndoor},"lat":${'$'}{p.lat},"lng":${'$'}{p.lng}}',
        )
        .join(',');`;

const NEW_PLACES_JSON = String.raw`    final locale = _isArabic(prompt) ? 'ar' : 'en';
    final placesForContext = availablePlaces
        .map(
          (p) =>
              '{"id":"${'$'}{p.id}","name":${'$'}{jsonEncode(p.localizedName(locale))},"category":"${'$'}{p.localizedCategory(locale)}","description":${'$'}{jsonEncode(p.localizedDescription(locale))},"address":${'$'}{jsonEncode(p.localizedAddress(locale))},"bestTimeToVisit":${'$'}{jsonEncode(p.bestTimeToVisit ?? '')},"isIndoor":${'$'}{p.isIndoor},"lat":${'$'}{p.lat},"lng":${'$'}{p.lng}}',
        )
        .join(',');`;

if (!src.includes(OLD_PLACES_JSON)) {
  console.error('OLD_PLACES_JSON not found');
  process.exit(1);
}
src = src.replace(OLD_PLACES_JSON, NEW_PLACES_JSON);

// 9. Remove "Mention a real Alexandria detail" instruction
src = src.replace(
  `Mention a real Alexandria detail (e.g. "the rooftop of the Sofitel faces
  the sunset — order a fresh lemon mint at golden hour").`,
  `Mention a real, concrete local detail from the place's description or
  from your knowledge of the city — never invent landmarks or venues.`
);

fs.writeFileSync(filePath, src, 'utf-8');
console.log('Patched ai_service.dart');