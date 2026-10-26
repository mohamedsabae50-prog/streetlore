class ProfanityFilter {
  ProfanityFilter._();

  static const Set<String> _englishTerms = {
    'asshole',
    'bastard',
    'bitch',
    'damn',
    'fuck',
    'fucker',
    'shit',
    'slut',
    'whore',
  };

  static const Set<String> _arabicTerms = {
    'احا',
    'اخرس',
    'حمار',
    'خرا',
    'شرموط',
    'شرموطة',
    'كس',
    'كلب',
    'منيوك',
    'منيوكة',
    'وسخ',
    'ياحيوان',
  };

  static bool containsProfanity(String text) {
    final normalized = _normalize(text);
    if (normalized.isEmpty) return false;
    final words = normalized
        .replaceAll(RegExp(r'[\s.,!?;:()\[\]{}"_-]+'), ' ')
        .split(' ');
    return words.any((word) => _englishTerms.contains(word)) ||
        words.any((word) => _arabicTerms.contains(word));
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'(.)\1{2,}'), r'$1$1')
      .trim();
}
