import 'dart:async';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../config/app_config.dart';

/// Wrapper around the official `google_generative_ai` SDK with a 5-key
/// rotation fallback. v1.0.36 replaces the manual `dart:io` REST
/// client (which carried auth quirks and got a 404 NOT_FOUND on
/// `gemini-1.5-flash-latest`) with the official SDK call shape:
///
///   final model = GenerativeModel(model: 'gemini-1.5-flash',
///       apiKey: currentKey);
///   final response = await model.generateContent(
///       [Content.text(prompt)]);
///
/// The SDK uses the documented `x-goog-api-key` header
/// (NOT the URL `?key=` query form). On any failure that looks like
/// "this key is bad / exhausted" (401 / 403 / 429 / 5xx) the wrapper
/// transparently retries with the next key. Non-rotation status codes
/// (400 / 404) and empty responses surface immediately so we don't
/// burn quota on a misconfiguration.
///
/// Public surface (`generateContent` + `GeminiResult.isOk`) is the
/// same as v1.0.34/35, so `ai_service.dart` and
/// `ai_tour_guide_service.dart` need no changes.
class GeminiRestClient {
  GeminiRestClient._();
  static final GeminiRestClient instance = GeminiRestClient._();

  static const Duration _timeout = Duration(seconds: 45);

  /// Send a `generateContent` request.
  ///
  /// Returns the concatenated text of the first candidate, or a
  /// populated [GeminiResult] with the last error. Never throws —
  /// failures are logged and returned so callers can decide on their
  /// own fallback.
  ///
  /// If [apiKeys] (or [apiKey]) is null/empty, falls back to the keys
  /// defined in [AppConfig.geminiApiKeys] and rotates through them on
  /// 401 / 403 / 429 / 5xx / network failures.
  Future<GeminiResult?> generateContent({
    String? apiKey,
    List<String>? apiKeys,
    required String model,
    required String systemInstruction,
    required String userPrompt,
    double temperature = 0.7,
    int maxOutputTokens = 1024,
  }) async {
    // Build the ordered key list. Prefer the explicit apiKey first
    // if provided, then the configured keys (deduped).
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
    for (final k in _configuredKeys) {
      if (!keys.contains(k)) keys.add(k);
    }
    if (keys.isEmpty) {
      debugPrintGemini('SDK call: no api keys available');
      return null;
    }

    final body = '$systemInstruction\n\n$userPrompt';

    GeminiResult? lastResult;
    for (var i = 0; i < keys.length; i++) {
      final key = keys[i];
      final keyRedacted = key.length > 8
          ? '${key.substring(0, 4)}...${key.substring(key.length - 4)}'
          : '****';
      debugPrintGemini(
        'SDK call: model=$model key=$keyRedacted keyLen=${key.length} '
        'attempt=${i + 1}/${keys.length}',
      );
      try {
        final m = GenerativeModel(
          model: model,
          apiKey: key,
          generationConfig: GenerationConfig(
            temperature: temperature,
            maxOutputTokens: maxOutputTokens,
          ),
        );
        final response = await m
            .generateContent([Content.text(body)])
            .timeout(_timeout);
        final text = response.text;
        if (text == null || text.isEmpty) {
          debugPrintGemini(
            'SDK call: 200 but empty text on key #${i + 1}',
          );
          // Surface the empty result so the caller can fall back to
          // a local response. Don't silently try another key on an
          // empty success — that's a content issue, not a key issue.
          return const GeminiResult(
            text: null,
            statusCode: 200,
            errorBody: 'empty text',
            raw: null,
          );
        }
        return GeminiResult(
          text: text,
          statusCode: 200,
          errorBody: null,
          raw: null,
        );
      } on InvalidApiKey catch (e) {
        // 401-class — that key is dead, try the next one.
        debugPrintGemini(
          'SDK call: InvalidApiKey on key #${i + 1}: ${e.message}',
        );
        lastResult = GeminiResult(
          text: null,
          statusCode: 401,
          errorBody: e.message,
          raw: null,
        );
      } on UnsupportedUserLocation catch (e) {
        // 403-class (permitted? usually billing), try next key.
        debugPrintGemini(
          'SDK call: UnsupportedUserLocation on key #${i + 1}: '
          '${e.message}',
        );
        lastResult = GeminiResult(
          text: null,
          statusCode: 403,
          errorBody: e.message,
          raw: null,
        );
      } on ServerException catch (e) {
        // The SDK only attaches the status code for 5xx (via the
        // 'Server Error [NNN]: ...' format), but for 4xx it just
        // gives us the human message. Try to pull the status code
        // out of the message text (`[404]`, `[429]`, etc.); otherwise
        // inspect the message itself.
        final status = _classifyExceptionMessage(e.message);
        debugPrintGemini(
          'SDK call: ServerException on key #${i + 1} '
          '(status=$status): ${e.message}',
        );
        lastResult = GeminiResult(
          text: null,
          statusCode: status,
          errorBody: e.message,
          raw: null,
        );
        if (status > 0 && !_shouldRotateKey(status)) {
          debugPrintGemini(
            'SDK call: non-rotation status $status on key #${i + 1}, '
            'surfacing without burning more keys',
          );
          return lastResult;
        }
      } on GenerativeAIException catch (e) {
        // Catch-all for the SDK's base exception type (used by the
        // underlying makeRequest() when statusCode >= 500: the SDK
        // throws `GenerativeAIException('Server Error [500]: ...')`).
        final status = _parseStatusFromMessage(e.message);
        debugPrintGemini(
          'SDK call: GenerativeAIException on key #${i + 1} '
          '(status=$status): ${e.message}',
        );
        lastResult = GeminiResult(
          text: null,
          statusCode: status,
          errorBody: e.message,
          raw: null,
        );
        if (status > 0 && !_shouldRotateKey(status)) {
          return lastResult;
        }
      } on GenerativeAISdkException catch (e) {
        // SDK has a stale package version / implementation bug. Treat
        // as a hard failure so the user sees something actionable in
        // logcat.
        debugPrintGemini(
          'SDK call: GenerativeAISdkException on key #${i + 1}: '
          '$e',
        );
        lastResult = GeminiResult(
          text: null,
          statusCode: 0,
          errorBody: e.message,
          raw: null,
        );
        // Don't keep rotating on a code bug — surface it after the
        // first failure.
        return lastResult;
      } on TimeoutException {
        debugPrintGemini('SDK call: timeout on key #${i + 1}');
        lastResult = const GeminiResult(
          text: null,
          statusCode: 0,
          errorBody: 'timeout',
          raw: null,
        );
      } catch (e) {
        debugPrintGemini(
          'SDK call: unknown exception on key #${i + 1}: $e',
        );
        lastResult = GeminiResult(
          text: null,
          statusCode: 0,
          errorBody: e.toString(),
          raw: null,
        );
      }
    }
    return lastResult;
  }

  /// Pull the HTTP status code out of an SDK exception message.
  /// - For 5xx the SDK formats the string as `Server Error [500]: ...`
  ///   so the regex catches it.
  /// - For 4xx the SDK just hands us the JSON `error.message` (often
  ///   `models/gemini-1.5-flash is not found for API version v1beta`),
  ///   so we inspect the text to detect the most common cases:
  ///     "not found" -> 404, "quota" / "rate" -> 429, "API key" -> 401
  ///   Anything else falls through as 0 (rotate-on-failure).
  int _classifyExceptionMessage(String message) {
    final fromBrackets = _parseStatusFromMessage(message);
    if (fromBrackets > 0) return fromBrackets;
    final lower = message.toLowerCase();
    if (lower.contains('not found') ||
        lower.contains('no longer available') ||
        lower.contains('is not supported')) {
      return 404;
    }
    if (lower.contains('quota') ||
        lower.contains('rate') ||
        lower.contains('too many requests') ||
        lower.contains('resource_exhausted')) {
      return 429;
    }
    if (lower.contains('api key') || lower.contains('permission')) {
      return 401;
    }
    return 0;
  }

  /// Parse `[NNN]` out of a message like `Server Error [500]: ...`.
  int _parseStatusFromMessage(String message) {
    final m = RegExp(r'\[(\d{3})\]').firstMatch(message);
    if (m == null) return 0;
    return int.tryParse(m.group(1) ?? '') ?? 0;
  }

  /// v1.0.34 spec: 401 / 403 / 429 / 5xx rotate; 400 / 404 (and any
  /// 0-status unknown) rotate-on-network-failure.
  bool _shouldRotateKey(int statusCode) {
    if (statusCode == 401 || statusCode == 403 || statusCode == 429) {
      return true;
    }
    if (statusCode >= 500 && statusCode < 600) return true;
    if (statusCode == 0) return true; // network/timeout
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
