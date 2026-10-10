import 'package:flutter/foundation.dart';

import 'supabase_service.dart';

class GeminiRestClient {
  GeminiRestClient._();
  static final GeminiRestClient instance = GeminiRestClient._();

  static const Duration _timeout = Duration(seconds: 45);
  static const List<String> _modelFallbackOrder = ['gemini-2.5-flash-lite'];

  Future<GeminiResult> generateContent({
    required String model,
    required String systemInstruction,
    required String userPrompt,
    double temperature = 0.7,
    int maxOutputTokens = 1024,
  }) async {
    final models = <String>[model];
    for (final fallback in _modelFallbackOrder) {
      if (!models.contains(fallback)) models.add(fallback);
    }

    for (final modelToTry in models) {
      try {
        final response = await SupabaseService.instance
            .aiProxyInvoke({
              'model': modelToTry,
              'systemInstruction': {
                'parts': [
                  {'text': systemInstruction},
                ],
              },
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': userPrompt},
                  ],
                },
              ],
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
          'Proxy call failed (model=$modelToTry, status=$status): $error',
        );
        final result = GeminiResult(
          text: null,
          statusCode: status,
          errorBody: error.toString(),
          raw: null,
        );
        if (status == 404 && modelToTry != models.last) continue;
        return result;
      }
    }

    return const GeminiResult(
      text: null,
      statusCode: 404,
      errorBody: 'No configured Gemini model is available',
      raw: null,
    );
  }

  int _statusCode(String message) {
    if (message.contains('AI_QUOTA_EXCEEDED')) return 429;
    final match = RegExp(r'ai-proxy HTTP (\d{3})').firstMatch(message);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
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
  debugPrint('[GeminiRestClient] $msg');
}
