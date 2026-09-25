import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

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
      // ============================================================
      // Per debugging spec: log the EXACT URL we are calling so the
      // 401 / model-not-found failure can be triaged from logcat.
      // The key travels ONLY in the query string (no Bearer header).
      // ============================================================
      debugPrintGemini('API URL: $uri');
      // Also print the parsed host + path + a redacted key (first 4 +
      // last 4 chars only) so the URL structure is verifiable in
      // logcat without leaking the full key.
      final keyRedacted = key.length > 8
          ? '${key.substring(0, 4)}...${key.substring(key.length - 4)}'
          : '****';
      debugPrintGemini(
        'generateContent: host=${uri.host} path=${uri.path} '
        'model=$model key=$keyRedacted keyLen=${key.length}',
      );
      // v1.0.33: build a brand-new vanilla HttpClient per request with
      // only the User-Agent set on the client itself. The previous
      // `http.Client()` was inheriting the global HttpOverrides (which
      // on Android can include the default `User-Agent: Dart/...` plus
      // any interceptor the rest of the app installs) - and the Google
      // AI Studio endpoint was seeing an `Authorization: Bearer ...`
      // header leaking from the shared client and returning 401 OAuth
      // even though our URL had `?key=...`. Constructing a fresh
      // `HttpClient()` here and wrapping it in an `IOClient` gives us a
      // completely isolated request.
      final rawHttp = HttpClient()
        ..userAgent = 'streetlore/1.0.34'
        ..idleTimeout = const Duration(seconds: 15);
      final client = IOClient(rawHttp);
      try {
        final req = http.Request('POST', uri)
          // Build the header map from scratch with ONLY the three
          // headers we want. The `http.Request` constructor already
          // gives us a fresh, empty header map, so nothing leaks
          // from any global default.
          ..headers['Content-Type'] = 'application/json'
          ..headers['Accept'] = 'application/json'
          ..headers['User-Agent'] = 'streetlore/1.0.34'
          ..body = body;
        // Belt-and-braces: explicitly clear any of the well-known
        // auth-related keys that a future Dart SDK or plugin might
        // silently add. (Safe no-ops if they are not present.)
        for (final k in const [
          'authorization',
          'Authorization',
          'x-goog-api-key',
          'X-Goog-Api-Key',
          'x-goog-user-project',
          'cookie',
          'Cookie',
        ]) {
          req.headers.remove(k);
        }

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
        // v1.0.34: per the spec, only 401 / 403 / 429 (and 5xx
        // transients, plus client-level timeouts / network errors) are
        // considered "this key is bad / exhausted" - in those cases we
        // silently fall through to the next key. Any other status (e.g.
        // a 400 from a malformed prompt, or a 404 from the wrong model
        // name) is OUR fault and we should NOT burn the remaining
        // quota on it.
        if (!_shouldRotateKey(resp.statusCode)) {
          debugPrintGemini(
            'generateContent: non-rotation status ${resp.statusCode} '
            'on key #${i + 1}, surfacing without burning more keys',
          );
          return lastResult;
        }
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

  /// v1.0.34: true when an HTTP status means "this key is bad or
  /// exhausted, try the next one". Per the user's spec: 401 (invalid /
  /// revoked key), 403 (forbidden / wrong model), 429 (rate /
  /// quota-limited). Any 5xx is also rotation-worthy because it's a
  /// transient upstream / CDN failure that the next key may avoid.
  /// 400 (bad request - our fault) and 404 (model not found - our
  /// fault) intentionally fall through so we don't waste quota.
  bool _shouldRotateKey(int statusCode) {
    if (statusCode == 401 || statusCode == 403 || statusCode == 429) {
      return true;
    }
    if (statusCode >= 500 && statusCode < 600) return true;
    return false;
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
