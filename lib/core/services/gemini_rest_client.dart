import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Direct REST client for the Google Gemini Developer API.
///
/// Uses the URL-parameter auth style (?key=...) which is the format
/// documented for the Gemini Developer API. This sidesteps the SDK's
/// `x-goog-api-key` header (which on some proxy/gateway setups has been
/// observed to be re-formatted into an OAuth `Authorization: Bearer`
/// header, returning the "Expected OAuth 2 access token" error).
///
/// Endpoint:
///   POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={API_KEY}
class GeminiRestClient {
  GeminiRestClient._();
  static final GeminiRestClient instance = GeminiRestClient._();

  static const String _base = 'https://generativelanguage.googleapis.com/v1beta';
  static const Duration _timeout = Duration(seconds: 45);

  /// Send a `generateContent` request.
  ///
  /// `systemInstruction` and `userPrompt` are combined into a
  /// `contents: [{role:user, parts:[{text: ...}]}]` payload.
  /// Returns the concatenated text of the first candidate, or null on
  /// failure. Never throws — failures are logged and surfaced as `null`
  /// so callers can decide on their own fallback.
  ///
  /// If [apiKeys] (or [apiKey]) is null/empty, falls back to the keys
  /// defined in [AppConfig.geminiApiKeys] and rotates through them on
  /// 4xx / network errors so a single revoked key doesn't kill the call.
  Future<GeminiResult?> generateContent({
    String? apiKey,
    List<String>? apiKeys,
    required String model,
    required String systemInstruction,
    required String userPrompt,
    double temperature = 0.7,
    int maxOutputTokens = 1024,
  }) async {
    // Build the ordered key list. Prefer the explicit apiKey first if
    // provided, then append the configured keys (deduped).
    final keys = <String>[];
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      keys.add(apiKey.trim());
    }
    if (apiKeys != null) {
      for (final k in apiKeys) {
        final t = k.trim();
        if (t.isNotEmpty && !keys.contains(t)) keys.add(t);
      }
    }
    // Always fall back to AppConfig keys if nothing else was supplied.
    for (final k in _configuredKeys) {
      if (!keys.contains(k)) keys.add(k);
    }
    if (keys.isEmpty) {
      debugPrintGemini('generateContent: no api keys available');
      return null;
    }

    final body = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': '$systemInstruction\n\n$userPrompt'},
          ],
        },
      ],
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': maxOutputTokens,
      },
    });

    GeminiResult? lastResult;
    for (var i = 0; i < keys.length; i++) {
      final key = keys[i];
      final uri = Uri.parse(
        '$_base/models/$model:generateContent'
        '?key=$key',
      );
      debugPrintGemini(
        'generateContent: trying key #${i + 1}/${keys.length} '
        '(len=${key.length})',
      );
      // Use a fresh HttpClient per request. We DO NOT touch any
      // `Authorization` header — sending an empty value here was being
      // parsed by the gateway as an empty Bearer token and yielded a
      // 401 "Expected OAuth 2 access token" error. The auth for the
      // Google AI Studio REST endpoint is the URL query string `?key=`
      // (which is already in `uri`), nothing else.
      final client = http.Client();
      try {
        final req = http.Request('POST', uri)
          ..headers['Content-Type'] = 'application/json'
          ..headers['Accept'] = 'application/json'
          ..headers['User-Agent'] = 'streetlore/1.0.22'
          ..body = body;
        final streamed = await client.send(req).timeout(_timeout);
        final resp = await http.Response.fromStream(streamed);
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final json = jsonDecode(resp.body) as Map<String, dynamic>;
          final candidates =
              (json['candidates'] as List<dynamic>?) ?? const [];
          if (candidates.isEmpty) {
            debugPrintGemini(
              'generateContent: 200 but empty candidates on key #${i + 1}',
            );
            return GeminiResult(
              text: null,
              statusCode: resp.statusCode,
              errorBody: 'empty candidates',
              raw: null,
            );
          }
          final content =
              (candidates.first as Map<String, dynamic>)['content'] as Map?;
          final parts = (content?['parts'] as List<dynamic>?) ?? const [];
          final buffer = StringBuffer();
          for (final p in parts) {
            final m = p as Map<String, dynamic>;
            final t = m['text'];
            if (t is String) buffer.write(t);
          }
          return GeminiResult(
            text: buffer.toString(),
            statusCode: resp.statusCode,
            errorBody: null,
            raw: resp.body,
          );
        }
        final errBody = _summarizeErrorBody(resp.body);
        debugPrintGemini(
          'generateContent: HTTP ${resp.statusCode} on key #${i + 1}: $errBody',
        );
        lastResult = GeminiResult(
          text: null,
          statusCode: resp.statusCode,
          errorBody: errBody,
          raw: resp.body,
        );
      } on TimeoutException {
        debugPrintGemini(
          'generateContent: timeout on key #${i + 1}',
        );
        lastResult = const GeminiResult(
          text: null,
          statusCode: 0,
          errorBody: 'timeout',
          raw: null,
        );
      } catch (e) {
        debugPrintGemini(
          'generateContent: exception on key #${i + 1}: $e',
        );
        lastResult = GeminiResult(
          text: null,
          statusCode: 0,
          errorBody: e.toString(),
          raw: null,
        );
      } finally {
        client.close();
      }
    }
    return lastResult;
  }

  /// Keys from AppConfig, evaluated lazily so tests / build time tools
  /// can override them.
  List<String> get _configuredKeys =>
      _configKeysAccessor?.call() ??
      AppConfig.geminiApiKeys.toList(growable: false);

  /// Indirection hook so we can swap out the key source in tests.
  static List<String> Function()? _configKeysAccessor;

  /// Test hook: replace the key source (e.g. with an in-memory list).
  static void setConfigKeysAccessorForTest(List<String> Function()? f) {
    _configKeysAccessor = f;
  }

  String _summarizeErrorBody(String body) {
    if (body.isEmpty) return 'empty body';
    try {
      final m = jsonDecode(body) as Map<String, dynamic>;
      final err = (m['error'] as Map?)?.cast<String, dynamic>();
      if (err != null) {
        final code = err['code'] ?? '';
        final status = err['status'] ?? '';
        final message = err['message'] ?? '';
        return '[$code/$status] $message';
      }
    } catch (_) {}
    return body.length > 200 ? '${body.substring(0, 200)}...' : body;
  }
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
  // ignore: avoid_print
  print('[GeminiRestClient] $msg');
}
