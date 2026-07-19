import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool _hasSeenOnboarding = false;
  bool _isLoading = true;
  String _userName = 'Explorer User';
  String _userEmail = 'explorer@streetlore.com';

  bool get isLoggedIn => _isLoggedIn;
  bool get hasSeenOnboarding => _hasSeenOnboarding;
  bool get isLoading => _isLoading;
  String get userName => _userName;
  String get userEmail => _userEmail;

  /// Stable id of the current user, used for content-ownership checks.
  /// Logged-in users are keyed by email; guests share a local 'guest' id.
  String get currentUserId => _isLoggedIn ? _userEmail : 'guest';

  /// True when [ownerId] refers to content created by the current user.
  /// Legacy records stored with the placeholder id 'me' (before per-user
  /// ids existed) are treated as created on this device by the current user.
  bool owns(String? ownerId) =>
      ownerId == null ||
      ownerId.isEmpty ||
      ownerId == 'me' ||
      ownerId == currentUserId;

  AuthProvider();

  Future<void> bootstrap() => _load();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    _hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
    _userName = prefs.getString('user_name') ?? 'Explorer User';
    _userEmail = prefs.getString('user_email') ?? 'explorer@streetlore.com';
    _isLoading = false;
    notifyListeners();
  }

  Future<void> signIn({required String name, required String email}) async {
    _isLoggedIn = true;
    _userName = name.trim().isEmpty ? 'Explorer User' : name.trim();
    _userEmail = email.trim().isEmpty ? 'explorer@streetlore.com' : email.trim();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setString('user_name', _userName);
    await prefs.setString('user_email', _userEmail);
  }

  Future<void> signOut() async {
    _isLoggedIn = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
  }

  Future<void> completeOnboarding() async {
    _hasSeenOnboarding = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
  }
}
