import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

bool isTransientSupabaseError(Object? error) {
  if (error is TimeoutException ||
      error is SocketException ||
      error is http.ClientException) {
    return true;
  }
  if (error is PostgrestException) {
    final code = error.code;
    if (code == '502' || code == '503' || code == '504') return true;
    if (code?.startsWith('PGRST') ?? false) return true;
  }
  final description = '${error.runtimeType}: $error'.toLowerCase();
  return description.contains('realtimesubscribeexception') ||
      description.contains('websocketchannnel') ||
      description.contains('websocketchannel') ||
      description.contains('websocketexception') ||
      description.contains('gateway timeout') ||
      description.contains('failed host lookup') ||
      description.contains('no address associated with hostname') ||
      description.contains('errno = 7') ||
      description.contains('socketexception') ||
      RegExp(r'\b(502|503|504)\b').hasMatch(description);
}

bool isTransientNetworkError(Object? error) => isTransientSupabaseError(error);

Stream<T> swallowTransientRealtimeErrors<T>(
  Stream<T> stream, {
  void Function(Object error, StackTrace stackTrace)? onTransientError,
}) {
  return stream.transform(
    StreamTransformer<T, T>.fromHandlers(
      handleError: (Object error, StackTrace stackTrace, sink) {
        if (isTransientNetworkError(error)) {
          onTransientError?.call(error, stackTrace);
        } else {
          sink.addError(error, stackTrace);
        }
      },
    ),
  );
}
