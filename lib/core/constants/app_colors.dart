import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF0F172A);
  static const Color primaryLight = Color(0xFF1E293B);
  static const Color primaryMid = Color(0xFF334155);

  static const Color accent = Color(0xFFE11D48);
  static const Color accentLight = Color(0xFFFF6584);
  static const Color accentGlow = Color(0xFFFF4D7C);

  static const Color ratingGold = Color(0xFFF59E0B);
  static const Color goldLight = Color(0xFFFCD34D);

  static const Color background = Color(0xFFF8FAFC);
  static const Color backgroundAlt = Color(0xFFF1F5F9);
  static const Color cardBackground = Colors.white;
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textHint = Color(0xFFCBD5E1);
  static const Color textOnDark = Colors.white;

  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0xCC0F172A)],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE11D48), Color(0xFFFF6584)],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFFCD34D)],
  );
}

extension ContextTheme on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get bgColor =>
      isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC);
  Color get bgAlt => isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9);
  Color get cardColor => isDark ? const Color(0xFF1C2433) : Colors.white;
  Color get borderColor =>
      isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0);
  Color get dividerColor =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

  Color get textPri =>
      isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get textSec =>
      isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get hintColor =>
      isDark ? const Color(0xFF4A5568) : const Color(0xFFCBD5E1);

  Color get shimmerBase =>
      isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0);
  Color get shimmerHighlight =>
      isDark ? const Color(0xFF4A5568) : const Color(0xFFF8FAFC);

  /// v1.0.71 — selected bottom-nav icon color. Was hardcoded to
  /// [AppColors.primary] (dark navy) which disappears against the
  /// dark-mode card background. Light blue in dark, navy in light.
  Color get navSelected =>
      isDark ? const Color(0xFF60A5FA) : const Color(0xFF0F172A);

  // v1.0.75 — theme-adaptive accent colors for quick-action icons on
  // Place Details (Save / Visited / Go / Download). The previous
  // hard-coded [AppColors.primary] / `#7C3AED` etc. were dark navy or
  // deep purple, both unreadable on a dark card background. Each
  // helper now returns a hue that pops in BOTH themes.

  Color get quickActionPrimary =>
      isDark ? const Color(0xFF60A5FA) : const Color(0xFF0F172A);
  Color get quickActionPrimaryBg =>
      isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0);

  Color get quickActionSuccess =>
      isDark ? const Color(0xFF34D399) : const Color(0xFF10B981);
  Color get quickActionSuccessBg =>
      isDark ? const Color(0xFF0F3D2E) : const Color(0xFFD1FAE5);

  Color get quickActionGold =>
      isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B);
  Color get quickActionGoldBg =>
      isDark ? const Color(0xFF422006) : const Color(0xFFFEF3C7);

  Color get quickActionPurple =>
      isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
  Color get quickActionPurpleBg =>
      isDark ? const Color(0xFF2E1A47) : const Color(0xFFEDE9FE);
}
