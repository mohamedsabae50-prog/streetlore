import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/journal_entry.dart';

class JournalProvider extends ChangeNotifier {
  static const _kPrefix = 'journal_v2_';

  List<JournalEntry> _entries = [];
  String _userId = '';
  bool _ready = false;

  List<JournalEntry> get entries => List.unmodifiable(_entries);
  int get totalEntries => _entries.length;
  bool get isReady => _ready;

  JournalProvider() {
    _load();
  }

  Future<void> setUserId(String userId) async {
    if (userId.isEmpty || userId == _userId) {
      if (userId.isNotEmpty) await _load();
      return;
    }
    _userId = userId;
    _entries = [];
    await _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (_userId.isEmpty) {
      _entries = [];
      _ready = true;
      notifyListeners();
      return;
    }
    final data = prefs.getStringList(_key) ?? [];
    _entries = data
        .map((s) => JournalEntry.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    _entries.sort((a, b) => b.visitedAt.compareTo(a.visitedAt));
    _ready = true;
    notifyListeners();
  }

  Future<void> _save() async {
    if (_userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final data = _entries.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_key, data);
  }

  Future<void> add(JournalEntry entry) async {
    if (_userId.isEmpty) return;
    _entries = [entry, ..._entries];
    _entries.sort((a, b) => b.visitedAt.compareTo(a.visitedAt));
    await _save();
    notifyListeners();
  }

  Future<void> update(JournalEntry entry) async {
    _entries = _entries.map((e) => e.id == entry.id ? entry : e).toList();
    _entries.sort((a, b) => b.visitedAt.compareTo(a.visitedAt));
    await _save();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _entries = _entries.where((e) => e.id != id).toList();
    await _save();
    notifyListeners();
  }

  List<JournalEntry> forPlace(String placeId) {
    return _entries.where((e) => e.placeId == placeId).toList();
  }

  bool hasEntryFor(String placeId) {
    return _entries.any((e) => e.placeId == placeId);
  }

  String get _key => '$_kPrefix$_userId';
}
