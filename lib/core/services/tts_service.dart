import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  
  Future<void> _ensureInit() async {
    if (_initialized) return;
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _tts.setStartHandler(() => _isSpeaking = true);
      _tts.setCompletionHandler(() => _isSpeaking = false);
      _tts.setCancelHandler(() => _isSpeaking = false);
      _tts.setErrorHandler((_) => _isSpeaking = false);
      _initialized = true;
    } catch (e) {
      debugPrint('TTSService: init failed: $e');
    }
  }

  
  
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _ensureInit();
    await stop();
    try {
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTSService.speak error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _isSpeaking = false;
  }
}
