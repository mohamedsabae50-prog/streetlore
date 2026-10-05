const fs = require('fs');

const replacements = [
  {
    file: 'D:/codes/streetlore/lib/l10n/app_strings.dart',
    pairs: [
      {
        old: "'ai_planner_sub': {\n      'en': \"Describe your ideal Alexandria trip and we'll plan it.\",\n      'ar': 'صف رحلتك المثالية في إسكندرية وهنخططها لك.',\n    },",
        new: "'ai_planner_sub': {\n      'en': \"Describe your ideal trip and we'll plan it.\",\n      'ar': 'صف رحلتك المثالية وهنخططها لك.',\n    },",
      },
      {
        old: "'ai_sugg_1': {\n      'en': 'Two days in Alexandria, mid-budget, love history and seafood',\n      'ar': 'يومين في إسكندرية، ميزانية متوسطة، بحب التاريخ والسي فود',\n    },",
        new: "'ai_sugg_1': {\n      'en': 'Two days, mid-budget, love history and seafood',\n      'ar': 'يومين، ميزانية متوسطة، بحب التاريخ والسي فود',\n    },",
      },
      {
        old: "'ai_prompt_hint': {\n      'en': 'e.g. two days in Alexandria, mid-budget, love history',\n      'ar': 'مثال: يومين في إسكندرية، ميزانية متوسطة، بحب التاريخ',\n    },",
        new: "'ai_prompt_hint': {\n      'en': 'e.g. two days, mid-budget, love history',\n      'ar': 'مثال: يومين، ميزانية متوسطة، بحب التاريخ',\n    },",
      },
    ],
  },
  {
    file: 'D:/codes/streetlore/lib/core/services/ai_service.dart',
    pairs: [
      {
        old: "title: (json['title'] as String?) ?? 'Your Alexandria Adventure',",
        new: "title: (json['title'] as String?) ?? 'Your Local Adventure',",
      },
    ],
  },
  {
    file: 'D:/codes/streetlore/lib/l10n/app_en.arb',
    pairs: [
      {
        old: '"ai_prompt_hint": "e.g. two days in Alexandria, mid-budget, love history",',
        new: '"ai_prompt_hint": "e.g. two days, mid-budget, love history",',
      },
      {
        old: '"ai_sugg_1": "Two days in Alexandria, mid-budget, love history and seafood",',
        new: '"ai_sugg_1": "Two days, mid-budget, love history and seafood",',
      },
    ],
  },
  {
    file: 'D:/codes/streetlore/lib/l10n/app_ar.arb',
    pairs: [
      {
        old: '"ai_prompt_hint": "مثال: يومين في إسكندرية، ميزانية متوسطة، بحب التاريخ",',
        new: '"ai_prompt_hint": "مثال: يومين، ميزانية متوسطة، بحب التاريخ",',
      },
      {
        old: '"ai_sugg_1": "يومين في إسكندرية، ميزانية متوسطة، بحب التاريخ والسي فود",',
        new: '"ai_sugg_1": "يومين، ميزانية متوسطة، بحب التاريخ والسي فود",',
      },
      {
        old: '"ai_planner_sub": "صف رحلتك المثالية في إسكندرية وهنخططها لك.",',
        new: '"ai_planner_sub": "صف رحلتك المثالية وهنخططها لك.",',
      },
    ],
  },
];

for (const r of replacements) {
  let src = fs.readFileSync(r.file, 'utf-8');
  for (const p of r.pairs) {
    if (!src.includes(p.old)) {
      console.error('NOT FOUND in', r.file, '-', p.old.slice(0, 80));
      process.exit(1);
    }
    src = src.replace(p.old, p.new);
  }
  fs.writeFileSync(r.file, src, 'utf-8');
  console.log('Patched', r.file, '(' + r.pairs.length + ' replacements)');
}