import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  static const _kKey = 'app_locale_v1';
  Locale _locale = const Locale('en');
  bool _ready = false;

  Locale get locale => _locale;
  bool get isReady => _ready;
  bool get isArabic => _locale.languageCode == 'ar';

  LocaleProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kKey);
    if (code != null && code.isNotEmpty) {
      _locale = Locale(code);
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, locale.languageCode);
    notifyListeners();
  }

  Future<void> toggle() async {
    await setLocale(isArabic ? const Locale('en') : const Locale('ar'));
  }
}
