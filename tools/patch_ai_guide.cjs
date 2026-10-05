const fs = require('fs');
const path = require('path');

const filePath = 'D:/codes/streetlore/lib/presentation/screens/general_ai_tour_guide_screen.dart';
let src = fs.readFileSync(filePath, 'utf-8');

// 1. Add app_strings import
src = src.replace(
  "import '../../core/services/ai_tour_guide_service.dart';\n\n\n\n\n\nclass GeneralAITourGuideScreen extends StatefulWidget {",
  "import '../../core/services/ai_tour_guide_service.dart';\nimport '../../l10n/app_strings.dart';\n\n\n\n\nclass GeneralAITourGuideScreen extends StatefulWidget {"
);

// 2. Replace the hardcoded welcome message with localized init
src = src.replace(
  `  final List<_Msg> _messages = [
    _Msg(
      role: _Role.bot,
      text:
          "Hi! I'm your Alexandria tourism expert. Ask me anything about "
          'places to visit, food, history, hidden gems, or tips for getting '
          'around the city.',
    ),
  ];
  bool _busy = false;`,
  `  late final String _welcomeText = context.tr('ai_guide_welcome_en');
  late final String _hintText = context.tr('ai_guide_hint');

  final List<_Msg> _messages = [];

  @override
  void initState() {
    super.initState();
    _messages.add(_Msg(role: _Role.bot, text: _welcomeText));
  }

  bool _busy = false;`
);

// 3. Replace title 'Alexandria AI Guide' with localized key
src = src.replace(
  `            Text(
              'Alexandria AI Guide',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),`,
  `            Text(
              context.tr('ai_guide_general_title'),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),`
);

// 4. Replace 'Thinking about Alexandria...' with localized key
src = src.replace(
  `                  Text(
                    'Thinking about Alexandria...',
                    style: TextStyle(
                      color: context.textSec,
                      fontSize: 12,
                    ),
                  ),`,
  `                  Text(
                    context.tr('ai_guide_thinking'),
                    style: TextStyle(
                      color: context.textSec,
                      fontSize: 12,
                    ),
                  ),`
);

// 5. Replace 'Ask about Alexandria — places, food, history...' hint with localized
src = src.replace(
  `                hintText:
                    'Ask about Alexandria — places, food, history...',`,
  `                hintText: _hintText,`
);

fs.writeFileSync(filePath, src, 'utf-8');
console.log('Patched general_ai_tour_guide_screen.dart');