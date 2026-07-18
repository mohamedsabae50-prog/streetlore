import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/journal_entry.dart';

class JournalProvider extends ChangeNotifier {
  static const _key = 'travel_journal_entries';

  List<JournalEntry> _entries = [];
  List<JournalEntry> get entries => List.unmodifiable(_entries);

  JournalProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_key) ?? [];
    _entries = data
        .map((s) => JournalEntry.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    _entries.sort((a, b) => b.visitedAt.compareTo(a.visitedAt));
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _entries.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_key, data);
    notifyListeners();
  }

  Future<void> add(JournalEntry entry) async {
    _entries = [entry, ..._entries];
    _entries.sort((a, b) => b.visitedAt.compareTo(a.visitedAt));
    await _save();
  }

  Future<void> update(JournalEntry entry) async {
    _entries = _entries.map((e) => e.id == entry.id ? entry : e).toList();
    _entries.sort((a, b) => b.visitedAt.compareTo(a.visitedAt));
    await _save();
  }

  Future<void> remove(String id) async {
    _entries = _entries.where((e) => e.id != id).toList();
    await _save();
  }

  List<JournalEntry> forPlace(String placeId) {
    return _entries.where((e) => e.placeId == placeId).toList();
  }

  bool hasEntryFor(String placeId) {
    return _entries.any((e) => e.placeId == placeId);
  }

  int get totalEntries => _entries.length;
}
