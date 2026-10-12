import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppReviewService {
  AppReviewService._();

  static final AppReviewService instance = AppReviewService._();
  static const _requestedKey = 'in_app_review_requested_once';

  bool _requestInProgress = false;

  Future<void> requestAfterPositiveExperience({
    required bool successfulCheckIn,
    required int currentStreak,
  }) async {
    if ((!successfulCheckIn && currentStreak < 3) || _requestInProgress) return;
    _requestInProgress = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (preferences.getBool(_requestedKey) ?? false) return;

      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;

      await review.requestReview();
      await preferences.setBool(_requestedKey, true);
    } catch (error, stackTrace) {
      debugPrint(
        'AppReviewService: could not request an in-app review: '
        '$error\n$stackTrace',
      );
    } finally {
      _requestInProgress = false;
    }
  }
}
