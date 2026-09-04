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
  PlaceModel? _currentPlace;
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
    _currentPlace = place;
    if (!AppConfig.geminiEnabled) {
      _messages.add(ChatMessage(
        text: _offlineWelcome(place),
        isUser: false,
        timestamp: DateTime.now(),
      ));
      return;
    }
    // Validate API key format
    final key = AppConfig.geminiApiKey;
    if (key.isEmpty || (!key.startsWith('AIza') && !key.startsWith('AI'))) {
      // Bad key — use offline mode silently
      _messages.add(ChatMessage(
        text: _offlineWelcome(place),
        isUser: false,
        timestamp: DateTime.now(),
      ));
      return;
    }
    try {
      _messages.clear();
      _model = GenerativeModel(
        model: AppConfig.geminiModel,
        apiKey: key,
      );
      _session = _model!.startChat(
        history: [
          Content.text(_buildSystemPrompt(place)),
          Content.model([TextPart(
              'Marhaba! I\'m your local guide for ${place.name}. Ask me anything - history, tips, what to see nearby, or anything else. بالإنجليزي أو العربي، زي ما تحب.')]),
        ],
      );
      _messages.add(ChatMessage(
        text: 'Marhaba! I\'m your local guide for ${place.name}. Ask me anything — history, tips, what to see nearby, or anything else. بالإنجليزي أو العربي، زي ما تحب. 😊',
        isUser: false,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      debugPrint('AITourGuideService.start error: $e');
      _session = null;
      _messages.add(ChatMessage(
        text: _offlineWelcome(place),
        isUser: false,
        timestamp: DateTime.now(),
      ));
    }
  }

  String _offlineWelcome(PlaceModel place) {
    return '👋 مرحباً! أنا دليلك المحلي لـ ${place.name}.\n\n${place.description}\n\nاسألني عن: المواعيد، الأسعار، التاريخ، النصايح، أو العنوان!\n\n(ملاحظة: الوضع حالياً بدون إنترنت — الإجابات من بيانات محلية)';
  }


  Future<String> send(String userText) async {

    if (_session == null && _currentPlace != null) {
      // Offline fallback — answer from local knowledge
      _busy = true;
      _messages.add(ChatMessage(
        text: userText,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      final reply = _offlineAnswer(userText, _currentPlace!);
      _messages.add(ChatMessage(
        text: reply,
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _busy = false;
      return reply;
    }
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
      debugPrint('AITourGuideService.send error: $e');
      // Fallback to local answer on any network/auth error
      final reply = _offlineAnswer(userText, _currentPlace!);
      _messages.add(ChatMessage(
        text: reply,
        isUser: false,
        timestamp: DateTime.now(),
      ));
      return reply;
    } finally {
      _busy = false;
    }
  }

  String _offlineAnswer(String q, PlaceModel place) {
    final lower = q.toLowerCase();
    final isArabic = q.runes.any((r) => r >= 0x0600 && r <= 0x06FF);

    if (lower.contains('hour') || lower.contains('open') || lower.contains('time') ||
        lower.contains('وقت') || lower.contains('مفتوح') || lower.contains('ساعة')) {
      return isArabic
          ? '🕐 ${place.name} مفتوح: ${place.openHours}.\nحاول تزور بدري الصبح لتجنب الزحام!'
          : '🕐 ${place.name} is open: ${place.openHours}.\nTip: Visit early morning to avoid crowds!';
    }
    if (lower.contains('price') || lower.contains('cost') || lower.contains('ticket') ||
        lower.contains('سعر') || lower.contains('تذكرة') || lower.contains('تكلف')) {
      if (place.isFree) {
        return isArabic ? '🎉 ${place.name} دخوله مجاناً!' : '🎉 ${place.name} is FREE entry!';
      }
      final local = place.priceLocalEgp ?? '?';
      final foreign = place.priceForeignerEgp ?? '?';
      return isArabic
          ? '🎟️ أسعار الدخول:\n• مصريون: $local جنيه\n• أجانب: $foreign جنيه'
          : '🎟️ Entry prices:\n• Egyptians: $local EGP\n• Foreigners: $foreign EGP';
    }
    if (lower.contains('address') || lower.contains('where') || lower.contains('location') ||
        lower.contains('عنوان') || lower.contains('فين') || lower.contains('موقع')) {
      return isArabic
          ? '📍 ${place.name} موجود في: ${place.address}.\nتقدر تضغط على زر "Go" في صفحة المكان علشان يفتحلك خريطة.'
          : '📍 ${place.name} is located at: ${place.address}.\nTap the "Go" button on the place page to open directions.';
    }
    if (lower.contains('history') || lower.contains('about') || lower.contains('tell') ||
        lower.contains('تاريخ') || lower.contains('عن') || lower.contains('إيه')) {
      return isArabic
          ? '🏛️ ${place.description}\n\nتقييم المكان: ⭐ ${place.rating}/5 من ${place.reviewCount} زيارة.'
          : '🏛️ ${place.description}\n\nRating: ⭐ ${place.rating}/5 from ${place.reviewCount} visits.';
    }
    if (lower.contains('tip') || lower.contains('advice') || lower.contains('recommend') ||
        lower.contains('نصيحة') || lower.contains('نصايح') || lower.contains('توصية')) {
      return isArabic
          ? '💡 نصايح لزيارة ${place.name}:\n• زور بدري الصبح لتجنب الزحام\n• خد معك مياه كتير\n• الكاميرا تجيب صور جامدة من الجهة الشمالية\n• الوقت المثالي: ${place.openHours}'
          : '💡 Tips for ${place.name}:\n• Go early morning to avoid crowds\n• Bring plenty of water\n• Best photos from the north side\n• Best visiting time: ${place.openHours}';
    }
    // Default: general info
    return isArabic
        ? '🌟 ${place.name} - ${place.category}\n\n${place.description}\n\n⭐ التقييم: ${place.rating}/5\n🕐 مواعيد: ${place.openHours}\n📍 العنوان: ${place.address}\n\nاسألني عن أي حاجة تانية!'
        : '🌟 ${place.name} - ${place.category}\n\n${place.description}\n\n⭐ Rating: ${place.rating}/5\n🕐 Hours: ${place.openHours}\n📍 Address: ${place.address}\n\nAsk me anything else!';
  }

  void clear() {
    _messages.clear();
    _session = null;
    _model = null;
  }
}
