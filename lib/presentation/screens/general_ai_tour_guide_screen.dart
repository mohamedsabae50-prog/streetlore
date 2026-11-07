import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/ai_tour_guide_service.dart';
import '../../core/services/gemini_rest_client.dart';
import '../../core/widgets/ai_quota_banner.dart';
import '../../l10n/app_strings.dart';
import '../../logic/connectivity_provider.dart';
import 'package:provider/provider.dart';
import 'paywall_screen.dart';
import '../widgets/report_content_sheet.dart';
import '../widgets/chat_text_direction.dart';

class GeneralAITourGuideScreen extends StatefulWidget {
  const GeneralAITourGuideScreen({super.key});

  @override
  State<GeneralAITourGuideScreen> createState() =>
      _GeneralAITourGuideScreenState();
}

class _GeneralAITourGuideScreenState extends State<GeneralAITourGuideScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();
  final GlobalKey<AiQuotaBannerState> _quotaKey =
      GlobalKey<AiQuotaBannerState>();
  final String _sessionId = const Uuid().v4();

  late final String _welcomeText = context.tr('ai_guide_welcome_en');

  final List<_Msg> _messages = [];

  @override
  void initState() {
    super.initState();
    _messages.add(_Msg(id: '', role: _Role.bot, text: _welcomeText));
  }

  bool _busy = false;

  void _openPaywall() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const PaywallScreen()),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (context.read<ConnectivityProvider>().hasInternet == false) return;
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    final history = _messages
        .where((message) => message.text.isNotEmpty)
        .map(
          (message) => GeminiChatTurn(
            role: message.role == _Role.user ? 'user' : 'model',
            text: message.text,
          ),
        )
        .toList(growable: false);
    final responseId = const Uuid().v4();
    setState(() {
      _messages.add(_Msg(id: '', role: _Role.user, text: text));
      _messages.add(_Msg(id: responseId, role: _Role.bot, text: ''));
      _busy = true;
    });
    _input.clear();
    _scrollToBottom();
    try {
      final reply = await AITourGuideService.askLocalGuide(
        text,
        sessionId: _sessionId,
        conversationHistory: history,
        onResponseChunk: (response) {
          if (!mounted) return;
          setState(() {
            _messages[_messages.length - 1] = _Msg(
              id: responseId,
              role: _Role.bot,
              text: response,
            );
          });
          _scrollToBottom();
        },
      );
      if (!mounted) return;
      setState(() {
        _messages[_messages.length - 1] = _Msg(
          id: responseId,
          role: _Role.bot,
          text: reply,
        );
        _busy = false;
      });
      _scrollToBottom();
    } on GeminiApiException catch (e, stackTrace) {
      debugPrint('Gemini Error: $e\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _messages[_messages.length - 1] = _Msg(
          id: '',
          role: _Role.bot,
          text: e.statusCode == 429
              ? context.tr('ai_daily_limit_body')
              : 'Could not reach the AI right now (${e.message}). Try again '
                    'in a moment.',
          isDailyLimitExceeded: e.statusCode == 429,
        );
        _busy = false;
      });
      _scrollToBottom();
    } catch (e, stackTrace) {
      debugPrint('Gemini Error: $e\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _messages[_messages.length - 1] = _Msg(
          id: '',
          role: _Role.bot,
          text: 'Something went wrong: $e',
        );
        _busy = false;
      });
      _scrollToBottom();
    } finally {
      await _quotaKey.currentState?.refresh();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOffline =
        context.watch<ConnectivityProvider>().hasInternet == false;
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.travel_explore_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text(
              context.tr('ai_guide_general_title'),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              itemCount: _messages.length,
              itemBuilder: (context, i) =>
                  _Bubble(msg: _messages[i], onUpgrade: _openPaywall),
            ),
          ),
          if (_busy)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.tr('ai_guide_thinking'),
                    style: TextStyle(color: context.textSec, fontSize: 12),
                  ),
                ],
              ),
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
          AiQuotaBanner(key: _quotaKey),
          _Composer(
            controller: _input,
            focusNode: _focus,
            busy: _busy,
            enabled: !isOffline,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

enum _Role { user, bot }

class _Msg {
  final String id;
  final _Role role;
  final String text;
  final bool isDailyLimitExceeded;
  const _Msg({
    required this.id,
    required this.role,
    required this.text,
    this.isDailyLimitExceeded = false,
  });
}

class _Bubble extends StatelessWidget {
  final _Msg msg;
  final VoidCallback onUpgrade;
  const _Bubble({required this.msg, required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    if (msg.isDailyLimitExceeded) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AiDailyLimitCard(onUpgrade: onUpgrade),
      );
    }
    final isUser = msg.role == _Role.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF514116),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
              ),
              child: const Icon(
                Icons.travel_explore_rounded,
                color: Color(0xFFFFE082),
                size: 20,
              ),
            ),
          if (!isUser) const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : Theme.of(context).cardColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: Border.all(
                  color: isUser
                      ? Colors.transparent
                      : context.borderColor.withValues(alpha: 0.5),
                ),
              ),
              child: ChatMessageText(
                text: msg.text,
                style: TextStyle(
                  color: isUser ? Colors.white : context.textPri,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (!isUser && msg.id.isNotEmpty && msg.text.isNotEmpty)
            IconButton(
              tooltip: context.tr('report_title'),
              onPressed: () => ReportContentSheet.show(
                context,
                targetId: msg.id,
                targetType: 'ai_message',
                targetContext: msg.text,
              ),
              icon: const Icon(Icons.flag_outlined, size: 18),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;
  final bool enabled;
  final Future<void> Function() onSend;
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.busy,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        12,
        12 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: BoxDecoration(
        color: context.cardColor,
        border: Border(
          top: BorderSide(color: context.borderColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: context.tr('ai_guide_hint'),
                filled: true,
                fillColor: context.bgColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                hintStyle: TextStyle(color: context.textSec),
              ),
              style: TextStyle(color: context.textPri),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: IconButton(
              onPressed: busy || !enabled ? null : () => onSend(),
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
