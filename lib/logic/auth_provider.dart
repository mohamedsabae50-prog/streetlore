import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool _hasSeenOnboarding = false;
  bool _isLoading = true;
  String _userName = '';
  String _userEmail = '';
  String _userId = '';
  bool _isGuest = false;

  bool get isLoggedIn => _isLoggedIn;
  bool get hasSeenOnboarding => _hasSeenOnboarding;
  bool get isLoading => _isLoading;
  String get userName => _userName;
  String get userEmail => _userEmail;
  String get userId => _userId;
  bool get isGuest => _isGuest;

  String get currentUserId => _userId.isEmpty ? 'guest' : _userId;

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
    _isGuest = prefs.getBool('is_guest') ?? false;
    _userName = prefs.getString('user_name') ?? '';
    _userEmail = prefs.getString('user_email') ?? '';
    _userId = prefs.getString('user_id') ?? '';
    _isLoading = false;
    notifyListeners();
  }

  Future<void> signIn({required String name, required String email}) async {
    _isLoggedIn = true;
    _isGuest = false;
    _userName = name.trim().isEmpty ? 'Explorer' : name.trim();
    _userEmail = email.trim().isEmpty ? 'explorer@streetlore.com' : email.trim();
    if (_userId.isEmpty) {
      _userId = const Uuid().v4();
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setBool('is_guest', false);
    await prefs.setString('user_name', _userName);
    await prefs.setString('user_email', _userEmail);
    await prefs.setString('user_id', _userId);
  }

  Future<void> signInAsGuest(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    _isLoggedIn = true;
    _isGuest = true;
    _userName = cleanName;
    _userEmail = 'guest@streetlore.com';
    if (_userId.isEmpty) {
      _userId = const Uuid().v4();
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setBool('is_guest', true);
    await prefs.setString('user_name', _userName);
    await prefs.setString('user_email', _userEmail);
    await prefs.setString('user_id', _userId);
  }

  Future<void> updateGuestName(String newName) async {
    if (newName.trim().isEmpty) return;
    _userName = newName.trim();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _userName);
  }

  Future<void> signOut() async {
    _isLoggedIn = false;
    _isGuest = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    await prefs.setBool('is_guest', false);
  }

  Future<void> completeOnboarding() async {
    _hasSeenOnboarding = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
  }
}
