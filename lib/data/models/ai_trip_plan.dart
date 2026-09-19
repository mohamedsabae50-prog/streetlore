/// Provenance of a generated plan or chat reply. UI uses this to label the
/// answer as `live` (real Gemini API) or `local` (offline fallback) so the
/// user is never misled into thinking static text is an AI response.
enum AiSource { live, local }

class AiTripPlan {
  final String title;
  final String summary;
  final int totalDays;
  final String estimatedBudget;
  final List<AiTripDay> days;
  final List<String> tips;
  AiSource source;

  AiTripPlan({
    required this.title,
    required this.summary,
    required this.totalDays,
    required this.estimatedBudget,
    required this.days,
    this.tips = const [],
    this.source = AiSource.local,
  });
}

class AiTripDay {
  final int dayNumber;
  final String theme;
  final List<AiTripStop> stops;

  const AiTripDay({
    required this.dayNumber,
    required this.theme,
    required this.stops,
  });
}

class AiTripStop {
  final String placeId;
  final String suggestedTime;
  final String note;

  const AiTripStop({
    required this.placeId,
    required this.suggestedTime,
    required this.note,
  });
}
