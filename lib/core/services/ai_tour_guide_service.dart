import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/app_config.dart';
import '../../data/models/place_model.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class AITourGuideService {
  AITourGuideService._();
  static final AITourGuideService instance = AITourGuideService._();

  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  GenerativeModel? _model;
  ChatSession? _session;
  bool _busy = false;
  bool get isBusy => _busy;

  String _buildSystemPrompt(PlaceModel place) {
    return '''You are an enthusiastic local tour guide for Alexandria, Egypt. You are currently talking about "${place.name}" (category: ${place.category}).

Key facts about this place:
- Description: ${place.description}
- Address: ${place.address}
- Open hours: ${place.openHours}
- Rating: ${place.rating}/5
${place.priceLocalEgp != null ? '- Local price: ${place.priceLocalEgp} EGP\n- Foreigner price: ${place.priceForeignerEgp} EGP' : ''}
- Coordinates: ${place.lat}, ${place.lng}

Your personality:
- Friendly, warm, and uses Egyptian expressions like "يا باشا" sparingly
- Gives practical, actionable tips
- Mixes English with Arabic when appropriate
- Keeps answers concise (2-4 sentences typically)
- Suggests nearby places or related activities when relevant
- Never makes up facts - if unsure, say so

You can answer about: history, best times to visit, what to wear, nearby food, how to get there, photo tips, similar places in Alexandria.''';
  }

  Future<void> start(PlaceModel place) async {
    if (!AppConfig.geminiEnabled) {
      _messages.add(ChatMessage(
        text: 'AI tour guide is currently disabled. Check your config!',
        isUser: false,
        timestamp: DateTime.now(),
      ));
      return;
    }
    if (AppConfig.geminiApiKey.isEmpty) {
      _messages.add(ChatMessage(
        text: 'API key not set. Cannot start AI tour guide.',
        isUser: false,
        timestamp: DateTime.now(),
      ));
      return;
    }
    _messages.clear();
    _model = GenerativeModel(
      model: AppConfig.geminiModel,
      apiKey: AppConfig.geminiApiKey,
    );
    _session = _model!.startChat(
      history: [
        Content.text(_buildSystemPrompt(place)),
        Content.model([TextPart(
            'Marhaba! I\'m your local guide for ${place.name}. Ask me anything - history, tips, what to see nearby, or anything else. بالإنجليزي أو العربي، زي ما تحب.')]),
      ],
    );
  }

  Future<String> send(String userText) async {
    if (_session == null) return 'Chat not started. Call start() first.';
    if (_busy) return 'Please wait for the previous reply.';
    _busy = true;
    _messages.add(ChatMessage(
      text: userText,
      isUser: true,
      timestamp: DateTime.now(),
    ));
    try {
      final res = await _session!.sendMessage(Content.text(userText));
      final reply = res.text ?? '(empty reply)';
      _messages.add(ChatMessage(
        text: reply,
        isUser: false,
        timestamp: DateTime.now(),
      ));
      return reply;
    } catch (e) {
      final err = 'AI tour guide error: $e';
      debugPrint(err);
      _messages.add(ChatMessage(
        text: 'Sorry, I hit a snag talking to Gemini: ${e.toString().split("\n").first}',
        isUser: false,
        timestamp: DateTime.now(),
      ));
      return err;
    } finally {
      _busy = false;
    }
  }

  void clear() {
    _messages.clear();
    _session = null;
    _model = null;
  }
}
