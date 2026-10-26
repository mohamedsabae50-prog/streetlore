import 'dart:convert';

class ReviewModel {
  final String id;
  final String placeId;
  final String userName;
  final String userId;
  final double rating;
  final String comment;
  final String? imagePath;
  final DateTime date;
  final bool isFlagged;
  final int reportCount;

  ReviewModel({
    required this.id,
    required this.placeId,
    required this.userName,
    this.userId = 'me',
    required this.rating,
    required this.comment,
    this.imagePath,
    required this.date,
    this.isFlagged = false,
    this.reportCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'placeId': placeId,
      'userName': userName,
      'userId': userId,
      'rating': rating,
      'comment': comment,
      'imagePath': imagePath,
      'date': date.toIso8601String(),
      'isFlagged': isFlagged,
      'reportCount': reportCount,
    };
  }

  factory ReviewModel.fromMap(Map<String, dynamic> map) {
    return ReviewModel(
      id: map['id'],
      placeId: map['placeId'],
      userName: map['userName'],
      userId: map['userId'] ?? 'me',
      rating: map['rating'],
      comment: map['comment'],
      imagePath: map['imagePath'],
      date: DateTime.parse(map['date']),
      isFlagged: map['isFlagged'] as bool? ?? false,
      reportCount: (map['reportCount'] as num?)?.toInt() ?? 0,
    );
  }

  String toJson() => json.encode(toMap());
  factory ReviewModel.fromJson(String source) =>
      ReviewModel.fromMap(json.decode(source));
}
