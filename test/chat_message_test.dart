import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/data/models/chat_message.dart';
import 'package:streetlore/logic/chat_provider.dart';

// A row exactly as PostgREST / realtime return it for public.place_chat
// (supabase_setup.sql): id bigint identity, message text, user_id uuid.
const _uid = '3f2b8c1e-9d4a-4e6b-8a57-1c0d2e9f7a10';
Map<String, dynamic> _tableRow() => {
  'id': 42,
  'place_id': 'qaitbay-citadel',
  'user_id': _uid,
  'user_name': 'Mona',
  'message': 'Is the citadel open at night?',
  'sent_at': '2026-10-16T09:30:00.123456+00:00',
};

ChatMessage _local() => ChatMessage(
  id: 'local-uuid-v4',
  placeId: 'qaitbay-citadel',
  userId: _uid,
  userName: 'Mona',
  text: 'Hello from the app',
  sentAt: DateTime.utc(2026, 10, 16, 9, 31),
  userAvatarColor: '0xFF3B82F6',
);

void main() {
  group('ChatMessage.toJson', () {
    test('only sends columns the place_chat table can accept', () {
      expect(_local().toJson(), {
        'place_id': 'qaitbay-citadel',
        'user_id': _uid,
        'user_name': 'Mona',
        'message': 'Hello from the app',
      });
    });

    test('never sends a client id (bigint identity, GENERATED ALWAYS)', () {
      expect(_local().toJson().containsKey('id'), isFalse);
    });

    test('uses the message column, not text', () {
      final json = _local().toJson();
      expect(json.containsKey('text'), isFalse);
      expect(json['message'], 'Hello from the app');
    });
  });

  group('ChatMessage.fromJson', () {
    test('parses a row shaped like the table (int id, message column)', () {
      final m = ChatMessage.fromJson(_tableRow());
      expect(m.id, '42');
      expect(m.placeId, 'qaitbay-citadel');
      expect(m.userId, _uid);
      expect(m.userName, 'Mona');
      expect(m.text, 'Is the citadel open at night?');
      expect(m.sentAt.toUtc(), DateTime.utc(2026, 10, 16, 9, 30, 0, 123, 456));
      expect(m.userAvatarColor, isNull);
    });

    test('accepts a String id too', () {
      final m = ChatMessage.fromJson({..._tableRow(), 'id': '42'});
      expect(m.id, '42');
    });

    test('falls back to a legacy text column', () {
      final row = _tableRow()
        ..remove('message')
        ..['text'] = 'legacy body';
      expect(ChatMessage.fromJson(row).text, 'legacy body');
    });

    test('tolerates a null user_id and user_name', () {
      final m = ChatMessage.fromJson({
        ..._tableRow(),
        'user_id': null,
        'user_name': null,
      });
      expect(m.userId, '');
      expect(m.userName, 'Explorer');
    });

    test('a row written by toJson plus server columns round-trips', () {
      final sent = _local();
      final row = {
        ...sent.toJson(),
        'id': 7,
        'sent_at': sent.sentAt.toIso8601String(),
      };
      final back = ChatMessage.fromJson(row);
      expect(back.text, sent.text);
      expect(back.userId, sent.userId);
      expect(back.placeId, sent.placeId);
      expect(back.id, '7');
    });
  });

  group('ChatProvider.send', () {
    test('keeps the message once the post succeeds', () async {
      final posted = <ChatMessage>[];
      final chat = ChatProvider(postMessage: (m) async => posted.add(m));
      await chat.send(_local());
      expect(posted, hasLength(1));
      expect(chat.messagesFor('qaitbay-citadel'), hasLength(1));
    });

    test('rolls the optimistic message back and rethrows on failure', () async {
      final chat = ChatProvider(
        postMessage: (m) async => throw StateError('rls denied'),
      );
      var notified = 0;
      chat.addListener(() => notified++);

      await expectLater(chat.send(_local()), throwsStateError);

      expect(chat.messagesFor('qaitbay-citadel'), isEmpty);
      expect(notified, 2); // shown optimistically, then removed again
    });
  });
}
