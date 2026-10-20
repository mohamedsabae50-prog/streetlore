List<Map<String, dynamic>> filterOtherUsersActivity(
  List<Map<String, dynamic>> rows,
  String currentUserId, {
  String currentUsername = '',
  String currentDisplayName = '',
}) {
  if (currentUserId.isEmpty) return rows;
  final ownNames = {
    currentUsername.trim().toLowerCase(),
    currentDisplayName.trim().toLowerCase(),
  }..removeWhere((name) => name.isEmpty);
  return rows
      .where((row) {
        final actorId =
            row['actor_id']?.toString() ??
            row['user_id']?.toString() ??
            row['actor_user_id']?.toString() ??
            '';
        if (actorId.isEmpty || actorId == currentUserId) return false;

        final actorNames = [
          row['actor_username'],
          row['actor_display_name'],
          row['username'],
          row['display_name'],
        ].map((name) => name?.toString().trim().toLowerCase() ?? '');
        if (actorNames.any(ownNames.contains)) return false;

        final activityText = [
          row['title']?.toString() ?? '',
          row['body']?.toString() ?? '',
        ].map((text) => text.trim().toLowerCase());
        return !activityText.any(
          (text) => ownNames.any((name) => text.startsWith('$name ')),
        );
      })
      .toList(growable: false);
}
