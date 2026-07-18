class JournalEntry {
  final String id;
  final String placeId;
  final String placeName;
  final String? note;
  final DateTime visitedAt;
  final int rating;
  final String? photoUrl;

  const JournalEntry({
    required this.id,
    required this.placeId,
    required this.placeName,
    required this.visitedAt,
    this.note,
    this.rating = 5,
    this.photoUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'placeId': placeId,
      'placeName': placeName,
      'note': note,
      'visitedAt': visitedAt.toIso8601String(),
      'rating': rating,
      'photoUrl': photoUrl,
    };
  }

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      placeId: json['placeId'] as String,
      placeName: json['placeName'] as String,
      note: json['note'] as String?,
      visitedAt: DateTime.parse(json['visitedAt'] as String),
      rating: (json['rating'] as int?) ?? 5,
      photoUrl: json['photoUrl'] as String?,
    );
  }

  JournalEntry copyWith({
    String? note,
    int? rating,
    String? photoUrl,
  }) {
    return JournalEntry(
      id: id,
      placeId: placeId,
      placeName: placeName,
      note: note ?? this.note,
      visitedAt: visitedAt,
      rating: rating ?? this.rating,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
