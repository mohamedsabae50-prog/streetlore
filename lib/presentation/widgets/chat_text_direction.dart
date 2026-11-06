import 'package:flutter/material.dart';

bool containsArabicCharacters(String text) =>
    RegExp(r'[\u0600-\u06FF]').hasMatch(text);

class ChatMessageText extends StatelessWidget {
  const ChatMessageText({super.key, required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final hasArabic = containsArabicCharacters(text);
    return Directionality(
      textDirection: hasArabic ? TextDirection.rtl : Directionality.of(context),
      child: Text(
        text,
        textAlign: hasArabic ? TextAlign.right : null,
        style: style,
      ),
    );
  }
}
