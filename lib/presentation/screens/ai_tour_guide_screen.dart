import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/ai_quota_banner.dart';
import '../../core/services/ai_tour_guide_service.dart';
import '../../core/utils/ai_place_matcher.dart';
import '../../data/models/egypt_governorate.dart';
import '../../data/models/place_model.dart';
import '../../data/mock_data.dart';
import '../../l10n/app_strings.dart';
import '../../logic/connectivity_provider.dart';
import '../../logic/auth_provider.dart';
import '../../logic/place_provider.dart';
import '../../logic/tour_provider.dart';
import 'package:provider/provider.dart';
import 'paywall_screen.dart';
import '../widgets/report_content_sheet.dart';
import '../widgets/chat_text_direction.dart';
import '../widgets/ai_place_recommendation_card.dart';

typedef PlaceAiMessageSender = Future<String> Function(String text);

class AITourGuideScreen extends StatefulWidget {
  final PlaceModel place;
  final Future<Map<String, dynamic>> Function()? fetchQuotaStatus;
  final PlaceAiMessageSender? onSendMessage;
  final bool? isOfflineOverride;

  const AITourGuideScreen({
    super.key,
    required this.place,
    this.fetchQuotaStatus,
    this.onSendMessage,
    this.isOfflineOverride,
  });

  @override
  State<AITourGuideScreen> createState() => _AITourGuideScreenState();
}

class _AITourGuideScreenState extends State<AITourGuideScreen> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey<AiQuotaBannerState> _quotaKey =
      GlobalKey<AiQuotaBannerState>();
  final String _sessionId = const Uuid().v4();
  bool _started = false;
  bool _bootstrapStarted = false;
  bool _sending = false;
  int _quotaRemaining = 3;
  int _quotaLimit = 3;
  String? _streamingReply;
  String _streamingPrompt = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapStarted) return;
    _bootstrapStarted = true;
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final locale = Localizations.localeOf(context).languageCode;
    final places = context.read<PlaceProvider>().allPlaces.where(
      (place) =>
          EgyptGovernorate.normalizeId(place.governorate) ==
          EgyptGovernorate.normalizeId(widget.place.governorate),
    );
    final itineraries = context.read<TourProvider>().allTours.where(
      (tour) =>
          EgyptGovernorate.normalizeId(tour.governorate) ==
          EgyptGovernorate.normalizeId(widget.place.governorate),
    );
    await AITourGuideService.instance.start(
      widget.place,
      sessionId: _sessionId,
      locale: locale,
      places: places,
      itineraries: itineraries,
    );
    if (mounted) setState(() => _started = true);
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    AITourGuideService.instance.clear();
    super.dispose();
  }

  Future<void> _send() async {
    if (_isOffline()) return;
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    if (_quotaRemaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('ai_quota_limit_reached'))),
      );
      return;
    }
    HapticFeedback.lightImpact();
    final consumed = await _quotaKey.currentState?.consumeOne() ?? false;
    if (!consumed || !mounted) return;
    _inputCtrl.clear();
    setState(() {
      _sending = true;
      _streamingReply = '';
      _streamingPrompt = text;
    });
    try {
      final sender = widget.onSendMessage;
      if (sender != null) {
        final response = await sender(text);
        if (mounted) setState(() => _streamingReply = response);
      } else {
        await AITourGuideService.instance.send(
          text,
          onResponseChunk: (response) {
            if (!mounted) return;
            setState(() => _streamingReply = response);
            _scrollToBottom();
          },
        );
      }
    } finally {
      await _quotaKey.currentState?.refresh();
      if (mounted) {
        setState(() {
          _sending = false;
          _streamingReply = null;
          _streamingPrompt = '';
        });
        _scrollToBottom();
      }
    }
  }

  bool _isOffline() =>
      widget.isOfflineOverride ??
      context.read<ConnectivityProvider>().hasInternet == false;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openPaywall() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const PaywallScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isOffline = widget.isOfflineOverride == null
        ? context.watch<ConnectivityProvider>().hasInternet == false
        : widget.isOfflineOverride!;
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        toolbarHeight: 86,
        backgroundColor: context.bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('ai_tour_guide'),
              style: TextStyle(
                fontSize: 14,
                color: context.textSec,
                fontWeight: FontWeight.w700,
              ),
            ),
            _buildQuotaSubtitle(context, auth.isPro || auth.isAdmin),
            Text(
              widget.place.localizedName(
                Localizations.localeOf(context).languageCode,
              ),
              style: TextStyle(
                fontSize: 18,
                color: context.textPri,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: !_started
                ? const Center(child: CircularProgressIndicator())
                : _buildChatList(),
          ),
          if (isOffline)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                context.tr('ai_offline_notice'),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textSec, fontSize: 12),
              ),
            ),
          AiQuotaBanner(
            key: _quotaKey,
            fetchQuotaStatus: widget.fetchQuotaStatus,
            onStatusChanged: _updateQuota,
            onUpgrade: _openPaywall,
          ),
          _buildInputBar(enabled: !isOffline),
        ],
      ),
    );
  }

  Widget _buildQuotaSubtitle(BuildContext context, bool isPro) {
    final limit = isPro ? kProDailyAiLimit : _quotaLimit;
    final remaining = isPro && _quotaLimit != kProDailyAiLimit
        ? kProDailyAiLimit
        : _quotaRemaining;
    final message = isPro
        ? context.tr('ai_quota_pro_remaining', {
            'remaining': '$remaining',
            'limit': '$limit',
          })
        : context.tr('ai_quota_remaining', {
            'remaining': '$_quotaRemaining',
            'limit': '$limit',
          });
    return SizedBox(
      height: 16,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          message,
          style: TextStyle(
            color: context.textSec,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _updateQuota(AiQuotaSnapshot snapshot) {
    if (!mounted) return;
    setState(() {
      _quotaRemaining = snapshot.remaining;
      _quotaLimit = snapshot.limit;
    });
  }

  Widget _buildChatList() {
    final msgs = AITourGuideService.instance.messages;
    if (msgs.isEmpty && _streamingReply == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: msgs.length + (_streamingReply == null ? 0 : 1),
      itemBuilder: (context, i) {
        if (i == msgs.length) {
          return _MessageBubble(
            text: _streamingReply!,
            isUser: false,
            id: '',
            onUpgrade: _openPaywall,
            userPrompt: _streamingPrompt,
            recommendedPlaces: _matchPlaces(
              userPrompt: _streamingPrompt,
              reply: _streamingReply!,
            ),
          );
        }
        final m = msgs[i];
        final userPrompt = !m.isUser && i > 0 && msgs[i - 1].isUser
            ? msgs[i - 1].text
            : '';
        return _MessageBubble(
          text: m.text,
          isUser: m.isUser,
          id: m.id,
          isDailyLimitExceeded: m.isDailyLimitExceeded,
          onUpgrade: _openPaywall,
          userPrompt: userPrompt,
          recommendedPlaces: _matchPlaces(
            userPrompt: userPrompt,
            reply: m.text,
          ),
        );
      },
    );
  }

  List<PlaceModel> _matchPlaces({
    required String userPrompt,
    required String reply,
  }) {
    final providerPlaces = context.read<PlaceProvider>().allPlaces;
    return AiPlaceMatcher.match(
      userPrompt: userPrompt,
      assistantReply: reply,
      places: providerPlaces.isEmpty ? MockData.places : providerPlaces,
      activeGovernorateId: widget.place.governorate,
    );
  }

  Widget _buildInputBar({required bool enabled}) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: context.cardColor,
        border: Border(top: BorderSide(color: context.borderColor, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: context.tr('tour_guide_hint', {
                  'name': widget.place.localizedName(
                    Localizations.localeOf(context).languageCode,
                  ),
                }),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: context.bgColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _sending || !enabled ? null : _send,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final String id;
  final String userPrompt;
  final List<PlaceModel> recommendedPlaces;
  final bool isDailyLimitExceeded;
  final VoidCallback onUpgrade;
  const _MessageBubble({
    required this.text,
    required this.isUser,
    required this.id,
    this.userPrompt = '',
    this.recommendedPlaces = const [],
    this.isDailyLimitExceeded = false,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    if (isDailyLimitExceeded) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AiDailyLimitCard(onUpgrade: onUpgrade),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF514116),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Color(0xFFFFE082),
                size: 18,
              ),
            ),
          if (!isUser) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isUser ? AppColors.primary : context.cardColor,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isUser ? 16 : 4),
                            bottomRight: Radius.circular(isUser ? 4 : 16),
                          ),
                          border: isUser
                              ? null
                              : Border.all(
                                  color: context.borderColor,
                                  width: 0.5,
                                ),
                        ),
                        child: ChatMessageText(
                          text: text,
                          style: TextStyle(
                            color: isUser ? Colors.white : context.textPri,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    if (!isUser && id.isNotEmpty && text.isNotEmpty)
                      IconButton(
                        tooltip: context.tr('report_title'),
                        onPressed: () => ReportContentSheet.show(
                          context,
                          targetId: id,
                          targetType: 'ai_message',
                          targetContext: text,
                        ),
                        icon: const Icon(Icons.flag_outlined, size: 18),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                if (!isUser)
                  for (final place in recommendedPlaces)
                    AiPlaceRecommendationCard(
                      key: Key('ai-recommended-place-card-${place.id}'),
                      place: place,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
