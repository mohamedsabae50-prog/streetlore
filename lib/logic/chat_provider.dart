import 'dart:async';
import 'package:flutter/foundation.dart';

import '../core/services/supabase_service.dart';
import '../core/services/offline_storage_service.dart';
import '../core/services/realtime_resilience.dart';
import '../data/models/chat_message.dart';

class ChatProvider extends ChangeNotifier {
  final Map<String, List<ChatMessage>> _byPlace = {};
  final Map<String, StreamSubscription> _subs = {};
  final Future<dynamic> Function(ChatMessage) _post;
  final bool Function(String userId) _isBlocked;

  /// [postMessage] is injectable for tests; it defaults to the Supabase insert.
  ChatProvider({
    Future<dynamic> Function(ChatMessage)? postMessage,
    bool Function(String userId)? isBlocked,
  }) : _post = postMessage ?? SupabaseService.instance.postMessage,
       _isBlocked = isBlocked ?? _neverBlocked;

  static bool _neverBlocked(String _) => false;

  SupabaseService get _supa => SupabaseService.instance;

  List<ChatMessage> messagesFor(String placeId) =>
      (_byPlace[placeId] ?? const [])
          .where((message) => !_isBlocked(message.userId))
          .toList(growable: false);

  Future<void> load(String placeId) async {
    final storage = OfflineStorageService.instance;
    try {
      final msgs = await _supa.fetchMessages(placeId);
      _byPlace[placeId] = _visibleMessages(msgs);
      await storage.cacheApiRows(
        _chatCacheKey(placeId),
        _byPlace[placeId]!.map((message) => message.toJson()).toList(),
      );
      notifyListeners();
      _subscribe(placeId);
    } catch (error, stackTrace) {
      debugPrint('ChatProvider.load($placeId) failed: $error\n$stackTrace');
      final rows = storage.getCachedApiRows(_chatCacheKey(placeId));
      if (rows != null) {
        try {
          _byPlace[placeId] = _visibleMessages(rows.map(ChatMessage.fromJson));
        } catch (cacheError, cacheStackTrace) {
          debugPrint(
            'ChatProvider: cached messages for $placeId are invalid: '
            '$cacheError\n$cacheStackTrace',
          );
          _byPlace[placeId] = const [];
        }
      } else {
        _byPlace.putIfAbsent(placeId, () => []);
      }
      notifyListeners();
    }
  }

  String _chatCacheKey(String placeId) => 'place_chat_$placeId';

  void _subscribe(String placeId) {
    _subs[placeId]?.cancel();
    final stream = _supa.streamMessages(placeId);
    if (stream == null) return;
    _subs[placeId] = swallowTransientRealtimeErrors(stream).listen(
      (rows) {
        _byPlace[placeId] = _visibleMessages(rows);
        unawaited(
          OfflineStorageService.instance.cacheApiRows(
            _chatCacheKey(placeId),
            _byPlace[placeId]!.map((message) => message.toJson()).toList(),
          ),
        );
        notifyListeners();
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('ChatProvider: realtime stream failed: $error');
      },
    );
  }

  void refreshBlockedContent() {
    for (final entry in _byPlace.entries) {
      entry.value.removeWhere((message) => _isBlocked(message.userId));
    }
    notifyListeners();
  }

  List<ChatMessage> _visibleMessages(Iterable<ChatMessage> messages) =>
      messages.where((message) => !_isBlocked(message.userId)).toList();

  /// Shows [message] immediately, then posts it. If the post fails the
  /// optimistic copy is removed again and the error is rethrown so the UI can
  /// tell the user the message was not delivered.
  Future<void> send(ChatMessage message) async {
    final list = List<ChatMessage>.from(_byPlace[message.placeId] ?? const []);
    list.add(message);
    _byPlace[message.placeId] = list;
    notifyListeners();
    try {
      final persisted = await _post(message);
      if (persisted is ChatMessage) {
        final current = List<ChatMessage>.from(
          _byPlace[message.placeId] ?? const [],
        );
        final index = current.indexWhere((entry) => entry.id == message.id);
        if (index >= 0) current[index] = persisted;
        _byPlace[message.placeId] = current;
        notifyListeners();
      }
      await OfflineStorageService.instance.cacheApiRows(
        _chatCacheKey(message.placeId),
        _visibleMessages(
          _byPlace[message.placeId] ?? const [],
        ).map((entry) => entry.toJson()).toList(),
      );
    } catch (_) {
      final current = List<ChatMessage>.from(
        _byPlace[message.placeId] ?? const [],
      )..removeWhere((m) => m.id == message.id);
      _byPlace[message.placeId] = current;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteMessage(ChatMessage message) async {
    await _supa.deletePlaceChatMessage(message.id);
    final updated = List<ChatMessage>.from(
      _byPlace[message.placeId] ?? const [],
    )..removeWhere((entry) => entry.id == message.id);
    _byPlace[message.placeId] = updated;
    notifyListeners();
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
