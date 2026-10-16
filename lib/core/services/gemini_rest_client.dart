import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'supabase_service.dart';

class GeminiRestClient {
  GeminiRestClient._();
  static final GeminiRestClient instance = GeminiRestClient._();

  static const Duration _timeout = Duration(seconds: 45);

  Future<GeminiResult> generateContent({
    required String model,
    required String systemInstruction,
    required String userPrompt,
    String? sessionId,
    String? logPrompt,
    List<GeminiChatTurn> conversationHistory = const [],
    double temperature = 0.7,
    int maxOutputTokens = 1024,
  }) async {
    // One request = one quota unit. The ai-proxy function owns model
    // validation and fallback, so the client must not retry with other
    // models (each retry used to burn another unit).
    try {
      final response = await SupabaseService.instance
          .aiProxyInvoke({
            'model': model,
            'systemInstruction': {
              'parts': [
                {'text': systemInstruction},
              ],
            },
            'contents': _contents(conversationHistory, userPrompt),
            if (sessionId != null) 'session_id': sessionId,
            if (logPrompt != null) 'log_prompt': logPrompt,
            'generationConfig': {
              'temperature': temperature,
              'maxOutputTokens': maxOutputTokens,
            },
          })
          .timeout(_timeout);

      final candidates = response['candidates'];
      final content = candidates is List && candidates.isNotEmpty
          ? candidates.first['content']
          : null;
      final parts = content is Map ? content['parts'] : null;
      final text = parts is List
          ? parts
                .whereType<Map>()
                .map((part) => part['text'])
                .whereType<String>()
                .join()
          : '';
      if (text.isEmpty) {
        return const GeminiResult(
          text: null,
          statusCode: 200,
          errorBody: 'Gemini returned no text',
          raw: null,
        );
      }
      return GeminiResult(
        text: text,
        statusCode: 200,
        errorBody: null,
        raw: null,
      );
    } catch (error) {
      final status = _statusCode(error.toString());
      debugPrintGemini(
        'Proxy call failed (model=$model, status=$status): $error',
      );
      return GeminiResult(
        text: null,
        statusCode: status,
        errorBody: error.toString(),
        raw: null,
      );
    }
  }

  Stream<String> generateContentStream({
    required String model,
    required String systemInstruction,
    required String userPrompt,
    String? sessionId,
    String? logPrompt,
    List<GeminiChatTurn> conversationHistory = const [],
    double temperature = 0.7,
    int maxOutputTokens = 1024,
  }) async* {
    // One request = one quota unit; ai-proxy handles model fallback. See
    // generateContent.
    try {
      final body = {
        'model': model,
        'stream': true,
        'systemInstruction': {
          'parts': [
            {'text': systemInstruction},
          ],
        },
        'contents': _contents(conversationHistory, userPrompt),
        if (sessionId != null) 'session_id': sessionId,
        if (logPrompt != null) 'log_prompt': logPrompt,
        'generationConfig': {
          'temperature': temperature,
          'maxOutputTokens': maxOutputTokens,
        },
      };
      final eventData = <String>[];
      await for (final line
          in SupabaseService.instance
              .aiProxyStream(body)
              .timeout(_timeout)
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (line.isEmpty) {
          final text = _textFromEvent(eventData);
          eventData.clear();
          if (text.isNotEmpty) yield text;
        } else if (line.startsWith('data:')) {
          eventData.add(line.substring(5).replaceFirst(RegExp(r'^ '), ''));
        }
      }
      final text = _textFromEvent(eventData);
      if (text.isNotEmpty) yield text;
    } catch (error) {
      debugPrintGemini(
        'Streaming proxy call failed (model=$model, '
        'status=${_statusCode(error.toString())}): $error',
      );
      rethrow;
    }
  }

  List<Map<String, dynamic>> _contents(
    List<GeminiChatTurn> history,
    String userPrompt,
  ) => [
    for (final turn in history)
      {
        'role': turn.role,
        'parts': [
          {'text': turn.text},
        ],
      },
    {
      'role': 'user',
      'parts': [
        {'text': userPrompt},
      ],
    },
  ];

  String _textFromEvent(List<String> eventData) {
    if (eventData.isEmpty) return '';
    final data = jsonDecode(eventData.join('\n'));
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Gemini stream event was not a JSON object');
    }
    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty) return '';
    final content = candidates.first is Map
        ? (candidates.first as Map)['content']
        : null;
    final parts = content is Map ? content['parts'] : null;
    return parts is List
        ? parts
              .whereType<Map>()
              .map((part) => part['text'])
              .whereType<String>()
              .join()
        : '';
  }

  int _statusCode(String message) {
    if (message.contains('AI_QUOTA_EXCEEDED') ||
        message.contains('AI_DAILY_LIMIT_EXCEEDED')) {
      return 429;
    }
    final match = RegExp(r'ai-proxy HTTP (\d{3})').firstMatch(message);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  int statusCodeFor(Object error) => _statusCode(error.toString());
}

class GeminiChatTurn {
  final String role;
  final String text;

  const GeminiChatTurn({required this.role, required this.text});
}

class GeminiResult {
  final String? text;
  final int statusCode;
  final String? errorBody;
  final String? raw;

  const GeminiResult({
    required this.text,
    required this.statusCode,
    required this.errorBody,
    required this.raw,
  });

  bool get isOk => text != null && (statusCode == 200 || statusCode == 201);
}

void debugPrintGemini(String msg) {
  debugPrint('[GeminiRestClient] $msg');
}
