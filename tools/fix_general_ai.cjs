const fs = require('fs');

const file = 'D:/codes/streetlore/lib/presentation/screens/general_ai_tour_guide_screen.dart';
let src = fs.readFileSync(file, 'utf-8');

// Fix 1: call site askAlexandria -> askLocalGuide
src = src.replace('askAlexandria(text)', 'askLocalGuide(text)');

// Fix 2: remove `const` from Row in title (because context.tr() isn't const)
src = src.replace(
  `        title: const Row(
          children: [
            Icon(Icons.travel_explore_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text(
              context.tr('ai_guide_general_title'),`,
  `        title: Row(
          children: [
            Icon(Icons.travel_explore_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text(
              context.tr('ai_guide_general_title'),`
);

// Fix 3: in _Composer.build, replace `hintText: _hintText,` with `hintText: context.tr('ai_guide_hint'),`
src = src.replace('hintText: _hintText,', 'hintText: context.tr(\'ai_guide_hint\'),');

// Fix 4: remove now-unused _hintText field
src = src.replace(
  `  late final String _welcomeText = context.tr('ai_guide_welcome_en');
  late final String _hintText = context.tr('ai_guide_hint');

  final List<_Msg> _messages = [];`,
  `  late final String _welcomeText = context.tr('ai_guide_welcome_en');

  final List<_Msg> _messages = [];`
);

fs.writeFileSync(file, src, 'utf-8');
console.log('Fixed general_ai_tour_guide_screen.dart');