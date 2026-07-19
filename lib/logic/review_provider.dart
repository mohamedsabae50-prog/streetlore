import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    notifyListeners();
  }

  
  List<ReviewModel> getReviewsForPlace(String placeId) {
    return _reviews.where((review) => review.placeId == placeId).toList();
  }

  
  Future<void> addReview(ReviewModel review) async {
    _reviews.add(review);
    await _saveReviews();
    notifyListeners();
  }

  
  Future<void> removeReview(String reviewId) async {
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
