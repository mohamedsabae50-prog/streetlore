/// Whether a `profiles` row grants Pro right now.
///
/// Mirrors the server rule used by `consume_ai_quota`: `is_pro` must be true
/// and `subscription_end_date` must be null (lifetime / legacy rows) or still
/// in the future, so a missed expiration webhook cannot leave Pro on screen.
bool profileGrantsPro(Map<String, dynamic>? profile, {DateTime? now}) {
  if (profile == null || profile['is_pro'] != true) return false;
  final rawEnd = profile['subscription_end_date'];
  if (rawEnd == null) return true;
  final end = DateTime.tryParse(rawEnd.toString());
  if (end == null) return false;
  return end.isAfter(now ?? DateTime.now());
}
