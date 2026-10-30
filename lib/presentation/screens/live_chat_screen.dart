import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/animated_icons.dart';
import '../../core/utils/profanity_filter.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/place_model.dart';
import '../../l10n/app_strings.dart';
import '../../logic/auth_provider.dart';
import '../../logic/blocked_users_provider.dart';
import '../../logic/chat_provider.dart';
import '../../logic/gamification_provider.dart';
import '../widgets/report_content_sheet.dart';

class LiveChatScreen extends StatefulWidget {
  final PlaceModel place;
  const LiveChatScreen({super.key, required this.place});

  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().load(widget.place.id);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    if (ProfanityFilter.containsProfanity(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('chat_profanity_warning'))),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    final chat = context.read<ChatProvider>();
    final gamification = context.read<GamificationProvider>();
    final messenger = ScaffoldMessenger.of(context);
    // Posting requires a real account: the insert RLS policy checks
    // user_id = auth.uid(), which a guest (random local id) can never satisfy.
    if (auth.isGuest || auth.userId.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('chat_sign_in_required'))),
      );
      return;
    }
    final msg = ChatMessage(
      id: const Uuid().v4(),
      placeId: widget.place.id,
      userId: auth.userId,
      userName: auth.userName,
      text: text,
      sentAt: DateTime.now(),
      userAvatarColor: '0xFF3B82F6',
      avatarUrl: auth.avatarUrl,
    );
    _input.clear();

    try {
      await chat.send(msg);
    } catch (_) {
      if (!mounted) return;
      // Give the text back so the user can retry instead of retyping it.
      if (_input.text.isEmpty) _input.text = text;
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('chat_send_failed'))),
      );
      return;
    }
    try {
      await gamification.applyAction('chat_message');
    } catch (error, stackTrace) {
      debugPrint('LiveChatScreen: chat XP update failed: $error\n$stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.localizedName(
                      Localizations.localeOf(context).languageCode,
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    context.tr('chat_live'),
                    style: TextStyle(fontSize: 11, color: context.textSec),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, chat, _) {
                  final msgs = chat.messagesFor(place.id);
                  if (msgs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 90,
                            height: 90,
                            child: AnimatedLottieIcon(
                              animation: LottieAnimations.chat,
                              size: 90,
                              color: AppColors.primary,
                              secondaryColor: AppColors.accent,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.tr('chat_empty'),
                            style: TextStyle(
                              color: context.textSec,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scroll.hasClients) {
                      _scroll.animateTo(
                        _scroll.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                  return ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    physics: const BouncingScrollPhysics(),
                    itemCount: msgs.length,
                    itemBuilder: (_, i) =>
                        _MessageBubble(message: msgs[i], placeId: place.id),
                  );
                },
              ),
            ),
            _Composer(controller: _input, onSend: _send),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final String placeId;
  const _MessageBubble({required this.message, required this.placeId});

  Future<void> _delete(BuildContext context) async {
    try {
      await context.read<ChatProvider>().deleteMessage(message);
    } catch (error, stackTrace) {
      debugPrint('LiveChatScreen: message delete failed: $error\n$stackTrace');
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('chat_delete_failed'))));
    }
  }

  Future<void> _block(BuildContext context) async {
    final blockedUsers = context.read<BlockedUsersProvider>();
    final chatProvider = context.read<ChatProvider>();
    try {
      await blockedUsers.blockUser(message.userId);
      chatProvider.refreshBlockedContent();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('user_blocked'))));
    } catch (error, stackTrace) {
      debugPrint('LiveChatScreen: user block failed: $error\n$stackTrace');
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('block_user_failed'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canDelete = auth.isAdmin || auth.userId == message.userId;
    final canBlock =
        !auth.isGuest &&
        auth.userId.isNotEmpty &&
        auth.userId != message.userId &&
        message.userId.isNotEmpty;
    final canReportAccount =
        !auth.isGuest &&
        auth.userId.isNotEmpty &&
        auth.userId != message.userId &&
        message.userId.isNotEmpty;
    final color = message.userAvatarColor == null
        ? AppColors.primary
        : Color(int.parse(message.userAvatarColor!.replaceFirst('0x', '0xff')));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color,
            child: Text(
              message.userName.isNotEmpty
                  ? message.userName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: context.hintColor.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        message.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _relativeTime(context, message.sentAt),
                        style: TextStyle(color: context.textSec, fontSize: 10),
                      ),
                      if (message.isFlagged || message.reportCount > 0) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.flag_rounded,
                          color: AppColors.error,
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.text,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: context.tr('report_title'),
                        visualDensity: VisualDensity.compact,
                        onPressed: auth.userId.isEmpty
                            ? null
                            : () => ReportContentSheet.show(
                                context,
                                targetId: message.id,
                                targetType: 'chat',
                                targetContext: '$placeId\n${message.text}',
                                authorName: message.userName,
                              ),
                        icon: const Icon(Icons.flag_outlined, size: 18),
                      ),
                      if (canReportAccount)
                        IconButton(
                          tooltip: context.tr('report_account'),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => ReportContentSheet.show(
                            context,
                            targetId: message.userId,
                            targetType: 'user',
                            authorName: message.userName,
                            targetAvatarUrl: message.avatarUrl,
                          ),
                          icon: const Icon(
                            Icons.person_off_outlined,
                            size: 18,
                          ),
                        ),
                      if (canBlock)
                        IconButton(
                          tooltip: context.tr('block_user'),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _block(context),
                          icon: const Icon(Icons.block_rounded, size: 18),
                        ),
                      if (canDelete)
                        IconButton(
                          tooltip: context.tr('delete'),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _delete(context),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.error,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _relativeTime(BuildContext context, DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return context.tr('chat_now');
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  const _Composer({required this.controller, required this.onSend});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: context.cardColor,
        border: Border(
          top: BorderSide(color: context.hintColor.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: context.tr('chat_hint'),
                hintStyle: TextStyle(
                  color: context.textSec.withValues(alpha: 0.6),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: context.bgColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onSend,
            icon: const Icon(Icons.send_rounded, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
