import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const _base = TextStyle(
    fontFamily: 'Cairo',
    color: AppColors.textPrimary,
  );

  static TextStyle get displayLarge => _base.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      );

  static TextStyle get displayMedium => _base.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.3,
      );

  static TextStyle get screenTitle => _base.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.2,
      );

  static TextStyle get cardTitle => _base.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get placeName => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get placeDescription => _base.copyWith(
        fontSize: 13,
        color: AppColors.textSecondary,
        height: 1.5,
      );

  static TextStyle get ratingText => _base.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get bodyMedium => _base.copyWith(
        fontSize: 15,
        color: AppColors.textSecondary,
        height: 1.6,
      );

  static TextStyle get labelSmall => _base.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.8,
      );

  static TextStyle get buttonText => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: 0.3,
      );

  static TextStyle get sectionTitle => _base.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      );

  static TextStyle get tagText => _base.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
        letterSpacing: 0.5,
      );
}
