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

  Future<AiTripPlan> generateTrip({
    required String prompt,
    required List<PlaceModel> availablePlaces,
    int? daysHint,
  }) async {
    final model = _ensureModel();
    if (model == null) {
      return _mockPlan(
        prompt: prompt,
        daysHint: daysHint ?? 2,
        availablePlaces: availablePlaces,
      );
    }

    final availablePlaceIds =
        availablePlaces.map((p) => p.id).toList(growable: false);

    final placesForContext = availablePlaces
        .map((p) =>
            '{"id":"${p.id}","name":${jsonEncode(p.name)},"category":"${p.category}","lat":${p.lat},"lng":${p.lng}}')
        .join(',');

    final system = """
You are a travel planner for Alexandria, Egypt. Given a user prompt and a
JSON list of available places, return ONLY a JSON object matching this shape:

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
- Output raw JSON, no markdown fences.
""";

    final user = 'User prompt: ${jsonEncode(prompt)}\n'
        'Days hint: ${daysHint ?? "auto"}\n'
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
      return _mockPlan(
        prompt: prompt,
        daysHint: daysHint ?? 2,
        availablePlaces: availablePlaces,
      );
    }
  }

  AiTripPlan _parsePlan(
    Map<String, dynamic> json,
    List<String> availablePlaceIds,
  ) {
    final days = (json['days'] as List<dynamic>? ?? const [])
        .map((d) => AiTripDay(
              dayNumber: (d['dayNumber'] as num?)?.toInt() ?? 1,
              theme: (d['theme'] as String?) ?? 'Explore',
              stops: (d['stops'] as List<dynamic>? ?? const [])
                  .map((s) => AiTripStop(
                        placeId: (s['placeId'] as String?) ?? '',
                        suggestedTime:
                            (s['suggestedTime'] as String?) ?? 'Flexible',
                        note: (s['note'] as String?) ?? '',
                      ))
                  .where((s) => availablePlaceIds.contains(s.placeId))
                  .toList(),
            ))
        .toList();
    return AiTripPlan(
      title: (json['title'] as String?) ?? 'Your Alexandria Adventure',
      summary: (json['summary'] as String?) ?? '',
      totalDays: (json['totalDays'] as num?)?.toInt() ?? days.length,
      estimatedBudget: (json['estimatedBudget'] as String?) ?? r'$$',
      days: days,
      tips: ((json['tips'] as List<dynamic>?) ?? const []).cast<String>(),
    );
  }

  AiTripPlan _mockPlan({
    required String prompt,
    required int daysHint,
    required List<PlaceModel> availablePlaces,
  }) {
    final all = availablePlaces;
    if (all.isEmpty) {
      return AiTripPlan(
        title: 'No places available',
        summary:
            'Connect to the network or add places to start planning your trip.',
        totalDays: daysHint,
        estimatedBudget: r'$$',
        days: const [],
        tips: const [
          'Pull to refresh and try again once places are loaded.',
        ],
      );
    }
    final perDay = (all.length / daysHint).ceil();
    final days = <AiTripDay>[];
    for (var i = 0; i < daysHint; i++) {
      final start = i * perDay;
      final end = (start + perDay).clamp(0, all.length);
      if (start >= all.length) break;
      final slice = all.sublist(start, end);
      if (slice.isEmpty) break;
      days.add(AiTripDay(
        dayNumber: i + 1,
        theme: i == 0
            ? 'Icons of the City'
            : i == 1
                ? 'Tastes & Traditions'
                : 'Hidden Corners',
        stops: [
          for (var j = 0; j < slice.length; j++)
            AiTripStop(
              placeId: slice[j].id,
              suggestedTime:
                  '${(9 + j * 3).toString().padLeft(2, '0')}:00 - ${(11 + j * 3).toString().padLeft(2, '0')}:00',
              note: 'Suggested by AI based on: "$prompt"',
            ),
        ],
      ));
    }
    return AiTripPlan(
      title: 'Your $daysHint-Day Alexandria Plan',
      summary:
          'A draft itinerary generated locally. Connect a Gemini key in lib/core/config/app_config.dart for tailored results.',
      totalDays: daysHint,
      estimatedBudget: r'$$',
      days: days,
      tips: const [
        'Start early to avoid crowds at the most popular sites.',
        'Carry a light jacket - Mediterranean breeze surprises in the evening.',
        'Try the local seafood for an authentic Alexandrian dinner.',
      ],
    );
  }
}
