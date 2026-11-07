import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streetlore/presentation/widgets/chat_text_direction.dart';

void main() {
  testWidgets('Arabic chat text is right aligned and laid out RTL', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ChatMessageText(text: 'أهلاً بيك! 😊 عامل إيه؟')),
      ),
    );

    final text = tester.widget<Text>(find.text('أهلاً بيك! 😊 عامل إيه؟'));
    expect(text.textAlign, TextAlign.right);
    expect(
      tester
          .widget<Directionality>(
            find
                .ancestor(
                  of: find.text('أهلاً بيك! 😊 عامل إيه؟'),
                  matching: find.byType(Directionality),
                )
                .first,
          )
          .textDirection,
      TextDirection.rtl,
    );
  });
}
