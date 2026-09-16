import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/config/app_config.dart';

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

  AuthProvider() {
    if (AppConfig.supabaseEnabled) {
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        final event = data.event;
        if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.tokenRefreshed) {
          _syncFromSupabase();
        } else if (event == AuthChangeEvent.signedOut) {
          _isLoggedIn = false;
          _isGuest = false;
          notifyListeners();
        }
      });
    }
  }

  Future<void> bootstrap() => _load();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (AppConfig.supabaseEnabled) {
      // Force-load session from secure storage; refresh if access token expired.
      Session? session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        try {
          final response = await Supabase.instance.client.auth.refreshSession();
          session = response.session;
        } catch (_) {
          // refresh may fail when no stored session exists; fall through.
        }
      }
      if (session?.user != null) {
        _syncFromSupabase();
        _isLoading = false;
        notifyListeners();
        return;
      }
    }
    _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    _hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
    _isGuest = prefs.getBool('is_guest') ?? false;
    _userName = prefs.getString('user_name') ?? '';
    _userEmail = prefs.getString('user_email') ?? '';
    _userId = prefs.getString('user_id') ?? '';
    _isLoading = false;
    notifyListeners();
  }

  /// Pulls the latest user info from the active Supabase session into local
  /// state and persists it to SharedPreferences.
  Future<void> _syncFromSupabase() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    _isLoggedIn = true;
    _isGuest = false;
    _userId = user.id;
    final meta = user.userMetadata ?? const <String, dynamic>{};
    _userName =
        (meta['full_name'] as String?) ??
        (meta['name'] as String?) ??
        (user.email?.split('@').first) ??
        'Explorer';
    _userEmail = user.email ?? _userEmail;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setBool('is_guest', false);
    await prefs.setString('user_name', _userName);
    await prefs.setString('user_email', _userEmail);
    await prefs.setString('user_id', _userId);
  }

  /// Exchanges the deep-link URI (from the OAuth redirect) for a Supabase
  /// session. Called from the platform `app_links` / `uni_links` callback
  /// when the browser returns to `io.supabase.streetlore:
  Future<bool> handleAuthCallback(Uri uri) async {
    if (!AppConfig.supabaseEnabled) return false;
    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
      return true;
    } catch (e) {
      debugPrint('AuthProvider: failed to exchange callback: $e');
      return false;
    }
  }

  Future<String?> signIn({
    required String name,
    required String email,
    required String password,
    required bool isSignUp,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim();
    final cleanPassword = password;
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return 'invalid_email';
    }
    if (cleanName.isEmpty) {
      return 'invalid_name';
    }
    if (isSignUp && cleanPassword.length < 6) {
      return 'password_too_short';
    }

    final prefs = await SharedPreferences.getInstance();

    if (isSignUp) {
      final existing = prefs.getString('user_email_${cleanEmail}_password');
      if (existing != null) {
        return 'account_exists';
      }
      await prefs.setString('user_email_${cleanEmail}_name', cleanName);
      await prefs.setString('user_email_${cleanEmail}_password', cleanPassword);
    } else {
      final stored = prefs.getString('user_email_${cleanEmail}_password');
      if (stored == null) {
        return 'no_account';
      }
      if (stored != cleanPassword) {
        return 'wrong_password';
      }
    }

    _isLoggedIn = true;
    _isGuest = false;
    _userName = cleanName;
    _userEmail = cleanEmail;
    if (_userId.isEmpty) {
      _userId = const Uuid().v4();
    }
    notifyListeners();
    await prefs.setBool('is_logged_in', true);
    await prefs.setBool('is_guest', false);
    await prefs.setString('user_name', _userName);
    await prefs.setString('user_email', _userEmail);
    await prefs.setString('user_id', _userId);
    return null;
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

  /// Native Google Sign-In using the google_sign_in package directly.
  /// This bypasses the OAuth deep link flow and works reliably on Android.
  Future<String?> signInWithGoogleNative() async {
    if (!AppConfig.supabaseEnabled) return 'supabase_disabled';
    try {
      final googleSignIn = GoogleSignIn(scopes: const ['email', 'profile']);
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return 'cancelled';
      }
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        return 'no_id_token';
      }

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );
      return null;
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      if (e.toString().contains('sign_in_canceled') ||
          e.toString().contains('User canceled')) {
        return 'cancelled';
      }
      return 'error';
    }
  }

  Future<void> completeOnboarding() async {
    _hasSeenOnboarding = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
  }
}
