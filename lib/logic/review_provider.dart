import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/supabase_service.dart';
import '../data/models/review_model.dart';

class ReviewProvider extends ChangeNotifier {
  List<ReviewModel> _reviews = [];
  List<ReviewModel> get reviews => _reviews;

  ReviewProvider() {
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('community_reviews') ?? [];
    _reviews = data.map((jsonStr) => ReviewModel.fromJson(jsonStr)).toList();
    try {
      final remote = await SupabaseService.instance.fetchReviews();
      final byId = <String, ReviewModel>{
        for (final review in _reviews) review.id: review,
      };
      for (final review in remote) {
        byId[review.id] = review;
      }
      _reviews = byId.values.toList(growable: true);
    } catch (error, stackTrace) {
      debugPrint(
        'ReviewProvider: remote reviews load failed: $error\n$stackTrace',
      );
    }
    notifyListeners();
  }

  List<ReviewModel> getReviewsForPlace(String placeId) {
    return _reviews.where((review) => review.placeId == placeId).toList();
  }

  Future<void> addReview(ReviewModel review) async {
    final client = SupabaseService.instance.clientOrNull;
    final authenticatedId = client?.auth.currentUser?.id;
    if (authenticatedId != null && authenticatedId.isNotEmpty) {
      await SupabaseService.instance.createReview(review);
    }
    _reviews.add(review);
    await _saveReviews();
    notifyListeners();
  }

  Future<void> removeReview(String reviewId) async {
    final index = _reviews.indexWhere((entry) => entry.id == reviewId);
    final review = index < 0 ? null : _reviews[index];
    if (review != null &&
        SupabaseService.instance.clientOrNull?.auth.currentUser != null) {
      await SupabaseService.instance.deleteReview(reviewId);
    }
    _reviews.removeWhere((r) => r.id == reviewId);
    await _saveReviews();
    notifyListeners();
  }

  Future<void> _saveReviews() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _reviews.map((r) => r.toJson()).toList();
    await prefs.setStringList('community_reviews', data);
  }
}
