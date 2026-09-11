import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../config/app_config.dart';
import '../../data/models/ai_trip_plan.dart';
import '../../data/models/place_model.dart';

class AiService {
  AiService._();
  static final AiService instance = AiService._();

  GenerativeModel? _model;

  GenerativeModel? _ensureModel() {
    if (!AppConfig.geminiEnabled) return null;
    if (_model != null) return _model;
    _model = GenerativeModel(
      model: AppConfig.geminiModel,
      apiKey: AppConfig.geminiApiKey,
    );
    return _model;
  }

  bool _isArabic(String text) {
    return text.runes.any((r) => r >= 0x0600 && r <= 0x06FF);
  }

  Future<AiTripPlan> generateTrip({
    required String prompt,
    required List<PlaceModel> availablePlaces,
    int? daysHint,
    String? budget,
  }) async {
    final model = _ensureModel();
    if (model == null) {
      return _localPlan(
        prompt: prompt,
        daysHint: daysHint ?? 2,
        availablePlaces: availablePlaces,
        budget: budget ?? r'$$',
      );
    }

    final availablePlaceIds = availablePlaces
        .map((p) => p.id)
        .toList(growable: false);

    final bool isArabic = _isArabic(prompt);

    final placesForContext = availablePlaces
        .map(
          (p) =>
              '{"id":"${p.id}","name":${jsonEncode(p.name)},"category":"${p.category}","lat":${p.lat},"lng":${p.lng}}',
        )
        .join(',');

    final seed = DateTime.now().millisecondsSinceEpoch.toString();

    final system =
        """
You are a creative travel planner for Alexandria, Egypt. Given a user prompt,
a budget level, and a JSON list of available places, return ONLY a JSON
object matching this shape:

{
  "title": string,
  "summary": string,
  "totalDays": int,
  "estimatedBudget": "\$" | "\$\$" | "\$\$\$" | "\$\$\$\$",
  "days": [
    { "dayNumber": int, "theme": string,
      "stops": [{ "placeId": string, "suggestedTime": string, "note": string }]
    }
  ],
  "tips": [string]
}

Rules:
- Only use placeIds from the provided list.
- Order stops logically (geographically + chronologically).
- Be concise; "note" should be <= 18 words.
- Vary wording: each note, theme, tip must be UNIQUE across the response — no copy-paste.
- Adapt to the user's prompt: family, romantic, foodie, history, hidden gems, budget trip, etc. — recommendations and notes must reflect what the user asked for.
- Reflect the budget: \$ is free/street-food, \$\$ is casual, \$\$\$ is mid-range, \$\$\$\$ is premium — adjust tip and summary tone accordingly.
- For totalDays, prefer the user hint when provided; otherwise pick what fits the prompt.
- Output raw JSON, no markdown fences.
- IMPORTANT: The user's prompt language is ${isArabic ? 'Arabic' : 'English'}. Respond in the SAME language. All text fields (title, summary, theme, note, tips) must be in ${isArabic ? 'Arabic' : 'English'}.
- Variety seed for this request: $seed. Treat as opaque; used only to encourage fresh wording.
""";

    final user =
        'User prompt: ${jsonEncode(prompt)}\n'
        'Days hint: ${daysHint ?? "auto"}\n'
        'Budget: ${budget ?? r"\$\$"}\n'
        'Variety seed: $seed\n'
        'Available places: [$placesForContext]';

    try {
      final response = await model.generateContent([
        Content.text(system),
        Content.text(user),
      ]);
      final text = response.text ?? '{}';
      final cleaned = text
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      return _parsePlan(json, availablePlaceIds);
    } catch (e) {
      debugPrint('AiService: Gemini call failed, falling back to mock: $e');
      return _localPlan(
        prompt: prompt,
        daysHint: daysHint ?? 2,
        availablePlaces: availablePlaces,
        budget: budget ?? r'$$',
      );
    }
  }

  AiTripPlan _parsePlan(
    Map<String, dynamic> json,
    List<String> availablePlaceIds,
  ) {
    final rawDays = (json['days'] as List<dynamic>? ?? const []);
    final days = <AiTripDay>[];
    for (var i = 0; i < rawDays.length; i++) {
      final d = rawDays[i] as Map<String, dynamic>;
      final parsed = (d['dayNumber'] as num?)?.toInt() ?? (i + 1);
      final dayNumber = parsed < 1 ? (i + 1) : parsed;
      final stops = (d['stops'] as List<dynamic>? ?? const [])
          .map((s) {
            final raw = (s as Map<String, dynamic>);
            return AiTripStop(
              placeId: (raw['placeId'] as String?) ?? '',
              suggestedTime: _normalizeTime(
                (raw['suggestedTime'] as String?) ?? 'Flexible',
              ),
              note: (raw['note'] as String?) ?? '',
            );
          })
          .where((s) => availablePlaceIds.contains(s.placeId))
          .toList();
      if (stops.isEmpty) continue;
      days.add(
        AiTripDay(
          dayNumber: dayNumber,
          theme: (d['theme'] as String?) ?? 'Explore',
          stops: stops,
        ),
      );
    }
    return AiTripPlan(
      title: (json['title'] as String?) ?? 'Your Alexandria Adventure',
      summary: (json['summary'] as String?) ?? '',
      totalDays: (json['totalDays'] as num?)?.toInt() ?? days.length,
      estimatedBudget: (json['estimatedBudget'] as String?) ?? r'$$',
      days: days,
      tips: ((json['tips'] as List<dynamic>?) ?? const []).cast<String>(),
    );
  }

  String _normalizeTime(String raw) {
    final t = raw.trim();
    if (t.isEmpty || t.toLowerCase() == 'flexible') return t;
    final parts = t.split('-');
    if (parts.length != 2) return t;
    final a = _parseHHmm(parts[0]);
    final b = _parseHHmm(parts[1]);
    if (a == null || b == null) return t;
    if (b < a) {
      return '${_fmtHHmm(b)} - ${_fmtHHmm(a)}';
    }
    return '${_fmtHHmm(a)} - ${_fmtHHmm(b)}';
  }

  int? _parseHHmm(String s) {
    final m = RegExp(r'(\d{1,2})[:.:](\d{2})').firstMatch(s.trim());
    if (m == null) return null;
    final h = int.tryParse(m.group(1)!);
    final min = int.tryParse(m.group(2)!);
    if (h == null || min == null) return null;
    if (h < 0 || h > 24 || min < 0 || min > 59) return null;
    return h * 60 + min;
  }

  String _fmtHHmm(int totalMinutes) {
    final h = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final m = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  AiTripPlan _localPlan({
    required String prompt,
    required int daysHint,
    required List<PlaceModel> availablePlaces,
    required String budget,
  }) {
    final isArabic = _isArabic(prompt);
    final all = availablePlaces;
    if (all.isEmpty) {
      return AiTripPlan(
        title: 'No places available',
        summary:
            'Connect to the network or add places to start planning your trip.',
        totalDays: daysHint,
        estimatedBudget: budget,
        days: const [],
        tips: const ['Pull to refresh and try again once places are loaded.'],
      );
    }

    final q = prompt.toLowerCase();

    const categoryKeywords = <String, List<String>>{
      'Historical': [
        'history',
        'historical',
        'castle',
        'fort',
        'ancient',
        'roman',
        'ruins',
        'citadel',
        'ØªØ§Ø±ÙŠØ®',
        'ØªØ§Ø±ÙŠØ®ÙŠ',
        'Ù‚Ù„Ø¹Ø©',
        'Ø¢Ø«Ø§Ø±',
        'Ø­ØµÙ†',
      ],
      'Culture': [
        'culture',
        'museum',
        'art',
        'library',
        'Ø«Ù‚Ø§ÙØ©',
        'Ø«Ù‚Ø§ÙÙŠ',
        'Ù…ØªØ­Ù',
        'ÙÙ†',
        'Ù…ÙƒØªØ¨Ø©',
      ],
      'Food': [
        'food',
        'seafood',
        'restaurant',
        'eat',
        'fish',
        'cafe',
        'cafÃ©',
        'coffee',
        'dinner',
        'lunch',
        'Ø£ÙƒÙ„',
        'Ø§ÙƒÙ„',
        'Ø³Ù…Ùƒ',
        'Ù…Ø·Ø¹Ù…',
        'Ù…Ø£ÙƒÙˆÙ„Ø§Øª',
        'Ù‚Ù‡ÙˆØ©',
        'ÙƒØ§ÙÙŠÙ‡',
      ],
      'Nature': [
        'nature',
        'beach',
        'park',
        'garden',
        'sea',
        'corniche',
        'Ø·Ø¨ÙŠØ¹Ø©',
        'Ø´Ø§Ø·Ø¦',
        'Ø¨Ø­Ø±',
        'Ø¬Ù†ÙŠÙ†Ø©',
        'Ø­Ø¯ÙŠÙ‚Ø©',
        'ÙƒÙˆØ±Ù†ÙŠØ´',
      ],
      'Shopping': [
        'shopping',
        'shop',
        'market',
        'bazaar',
        'Ø³ÙˆÙ‚',
        'ØªØ³ÙˆÙ‚',
      ],
      'Mosques': ['mosque', 'Ù…Ø³Ø¬Ø¯', 'Ø¬Ø§Ù…Ø¹', 'Ù…Ø³Ø§Ø¬Ø¯'],
      'Churches': ['church', 'ÙƒÙ†ÙŠØ³Ø©', 'ÙƒÙ†Ø§Ø¦Ø³'],
      'Streets': [
        'street',
        'walk',
        'downtown',
        'stroll',
        'Ø´Ø§Ø±Ø¹',
        'Ø´ÙˆØ§Ø±Ø¹',
        'Ù…Ù…Ø´Ù‰',
        'ÙˆØ³Ø· Ø§Ù„Ø¨Ù„Ø¯',
      ],
    };

    final wantsHidden = [
      'hidden',
      'gem',
      'gems',
      'Ù…Ø®ÙÙŠ',
      'Ù…Ø®ÙÙŠØ©',
      'Ø¬ÙˆØ§Ù‡Ø±',
    ].any(q.contains);

    double score(PlaceModel p) {
      var s = p.rating;
      final kws = categoryKeywords[p.category] ?? const <String>[];
      for (final k in kws) {
        if (q.contains(k)) {
          s += 6;
          break;
        }
      }
      if (wantsHidden && p.isHiddenGem) s += 6;
      if (budget == r'$') {
        if (p.isFree) {
          s += 3;
        } else if (p.priceLevel == PriceLevel.cheap) {
          s += 1.5;
        } else {
          s -= 2;
        }
      } else if (budget == r'$$$$' && p.priceLevel == PriceLevel.expensive) {
        s += 2;
      }
      return s;
    }

    final ranked = [...all]..sort((a, b) => score(b).compareTo(score(a)));

    final perDay = (ranked.length / daysHint).ceil().clamp(2, 4);
    final days = <AiTripDay>[];
    var index = 0;
    for (var d = 0; d < daysHint && index < ranked.length; d++) {
      final end = (index + perDay).clamp(0, ranked.length);
      final slice = ranked.sublist(index, end);
      index = end;
      final ordered = _geoOrder(slice);
      days.add(
        AiTripDay(
          dayNumber: d + 1,
          theme: _themeFor(ordered, d, isArabic: isArabic),
          stops: [
            for (var j = 0; j < ordered.length; j++)
              AiTripStop(
                placeId: ordered[j].id,
                suggestedTime:
                    '${(9 + j * 3).toString().padLeft(2, '0')}:00 - ${(11 + j * 3).toString().padLeft(2, '0')}:00',
                note: _noteFor(ordered[j], isArabic: isArabic),
              ),
          ],
        ),
      );
    }
    return AiTripPlan(
      title: isArabic
          ? 'خطتك لـ $daysHint يوم في الإسكندرية'
          : 'Your $daysHint-Day Alexandria Plan',
      summary: isArabic
          ? 'خطة مُعدّة على جهازك بناءً على طلبك: أفضل الأماكن مرتبة جغرافياً ليومك.'
          : 'Planned on your device from your request: best-matching places, '
                'ordered so each day flows as one walkable route.',
      totalDays: daysHint,
      estimatedBudget: budget,
      days: days,
      tips: isArabic
          ? const [
              'ابدأ مبكراً لتجنب الازدحام في أشهر المواقع.',
              'احمل جاكيت خفيف — النسيم المتوسطي يفاجئك مساءً.',
              'جرّب المأكولات البحرية المحلية لتجربة إسكندرانية أصيلة.',
            ]
          : const [
              'Start early to avoid crowds at the most popular sites.',
              'Carry a light jacket - Mediterranean breeze surprises in the evening.',
              'Try the local seafood for an authentic Alexandrian dinner.',
            ],
    );
  }

  List<PlaceModel> _geoOrder(List<PlaceModel> places) {
    final remaining = [...places]..sort((a, b) => b.lat.compareTo(a.lat));
    final ordered = <PlaceModel>[];
    var current = remaining.removeAt(0);
    ordered.add(current);
    while (remaining.isNotEmpty) {
      remaining.sort((a, b) => _dist(current, a).compareTo(_dist(current, b)));
      current = remaining.removeAt(0);
      ordered.add(current);
    }
    return ordered;
  }

  double _dist(PlaceModel a, PlaceModel b) {
    final dx = a.lat - b.lat;
    final dy = a.lng - b.lng;
    return dx * dx + dy * dy;
  }

  String _themeFor(
    List<PlaceModel> dayPlaces,
    int dayIndex, {
    bool isArabic = false,
  }) {
    final counts = <String, int>{};
    for (final p in dayPlaces) {
      counts[p.category] = (counts[p.category] ?? 0) + 1;
    }
    var top = '';
    var topN = -1;
    counts.forEach((cat, n) {
      if (n > topN) {
        top = cat;
        topN = n;
      }
    });
    switch (top) {
      case 'Historical':
        return isArabic ? 'أبرز المواقع التاريخية' : 'Historical Highlights';
      case 'Food':
        return isArabic ? 'نكهات المدينة' : 'Tastes of the City';
      case 'Nature':
        return isArabic ? 'الطبيعة ونسيم البحر' : 'Nature & Sea Breeze';
      case 'Culture':
        return isArabic ? 'الثقافة والمتاحف' : 'Culture & Museums';
      case 'Shopping':
        return isArabic ? 'الأسواق والتسوق' : 'Markets & Shopping';
      case 'Mosques':
        return isArabic ? 'المعالم الدينية' : 'Spiritual Landmarks';
      case 'Churches':
        return isArabic ? 'العمارة المقدسة' : 'Sacred Architecture';
      case 'Streets':
        return isArabic ? 'شوارع وحياة محلية' : 'Streets & Local Life';
      default:
        return isArabic
            ? (dayIndex == 0 ? 'أيقونات المدينة' : 'زوايا خفية')
            : (dayIndex == 0 ? 'City Icons' : 'Hidden Corners');
    }
  }

  String _noteFor(PlaceModel p, {bool isArabic = false}) => p.isHiddenGem
      ? (isArabic
            ? 'جوهرة خفية يحبها السكان المحليون.'
            : 'Hidden gem loved by locals.')
      : (isArabic
            ? 'وجهة ${p.category} مميزة ومُقيَّمة بعلامة عالية.'
            : 'Top-rated ${p.category.toLowerCase()} stop.');
}
