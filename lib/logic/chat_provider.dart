import 'dart:async';
import 'package:flutter/foundation.dart';

import '../core/services/supabase_service.dart';
import '../data/models/chat_message.dart';

class ChatProvider extends ChangeNotifier {
  final Map<String, List<ChatMessage>> _byPlace = {};
  final Map<String, StreamSubscription> _subs = {};
  final Future<void> Function(ChatMessage) _post;

  /// [postMessage] is injectable for tests; it defaults to the Supabase insert.
  ChatProvider({Future<void> Function(ChatMessage)? postMessage})
    : _post = postMessage ?? SupabaseService.instance.postMessage;

  SupabaseService get _supa => SupabaseService.instance;

  List<ChatMessage> messagesFor(String placeId) =>
      _byPlace[placeId] ?? const [];

  Future<void> load(String placeId) async {
    final msgs = await _supa.fetchMessages(placeId);
    _byPlace[placeId] = msgs;
    notifyListeners();
    _subscribe(placeId);
  }

  void _subscribe(String placeId) {
    _subs[placeId]?.cancel();
    final stream = _supa.streamMessages(placeId);
    if (stream == null) return;
    _subs[placeId] = stream.listen((rows) {
      _byPlace[placeId] = rows;
      notifyListeners();
    });
  }

  /// Shows [message] immediately, then posts it. If the post fails the
  /// optimistic copy is removed again and the error is rethrown so the UI can
  /// tell the user the message was not delivered.
  Future<void> send(ChatMessage message) async {
    final list = List<ChatMessage>.from(_byPlace[message.placeId] ?? const []);
    list.add(message);
    _byPlace[message.placeId] = list;
    notifyListeners();
    try {
      await _post(message);
    } catch (_) {
      final current = List<ChatMessage>.from(
        _byPlace[message.placeId] ?? const [],
      )..removeWhere((m) => m.id == message.id);
      _byPlace[message.placeId] = current;
      notifyListeners();
      rethrow;
    }
  }

  void appendLocal(ChatMessage message) {
    final list = List<ChatMessage>.from(_byPlace[message.placeId] ?? const []);
    list.add(message);
    _byPlace[message.placeId] = list;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subs.values) {
      s.cancel();
    }
    super.dispose();
  }
}
