const ARABIC_CHARACTERS = /[\u0600-\u06FF]/;

const ARABIC_CONVERSATIONAL_PATTERNS = [
  /^(?:عامل\s+ايه?|ازيك|اهلا|أهلا|مرحبا|مرحباً|السلام\s+عليكم|سلام\s+عليكم)(?:\s+يا\s+.{1,24})?$/,
  /^(?:انت|إنت)\s+مين$/,
  /^بتعمل\s+(?:ايه|إيه)$/,
  /^(?:صاحبي\s+كان\s+مفكر\s+انك\s+بايظ|(?:انت|إنت)\s+بايظ|بايظ|(?:انت|إنت)\s+شغال|شغال|خوفت)$/,
];

const ENGLISH_CONVERSATIONAL_MESSAGES = new Set([
  "hi",
  "hello",
  "hey",
  "how are you",
  "who are you",
  "are you working",
]);

export function conversationalReply(prompt: string): string | null {
  const normalized = prompt
    .toLowerCase()
    .replace(/[?!.,،؛:؟!]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();

  if (ENGLISH_CONVERSATIONAL_MESSAGES.has(normalized)) {
    if (normalized === "who are you") {
      return "I'm your friendly local guide to Egypt and Alexandria. Ask me about places, history, food, or tours!";
    }
    if (normalized === "are you working") {
      return "I'm here and ready to help 😊 Ask me about places, history, food, or tours in Egypt.";
    }
    return "Hi! I'm here and ready to help 😊 What would you like to discover about Egypt — places, history, food, or tours?";
  }

  if (
    !ARABIC_CONVERSATIONAL_PATTERNS.some((pattern) => pattern.test(normalized))
  ) {
    return null;
  }
  if (/بايظ|شغال|خوفت/.test(normalized)) {
    return "أنا معاك وشغال 😊 اسألني عن أماكن مصر والإسكندرية أو تاريخها وأكلها وجولاتها.";
  }
  if (/(?:انت|إنت)\s+مين|بتعمل\s+(?:ايه|إيه)/.test(normalized)) {
    return "أنا دليلك المحلي لمصر والإسكندرية 😊 أقدر أساعدك في الأماكن والتاريخ والأكل والجولات. تحب تعرف إيه؟";
  }
  return "أهلاً بيك! 😊 عامل إيه؟ أقدر أساعدك تكتشف أماكن مصر والإسكندرية وتاريخها وأكلها وجولاتها.";
}

export function prepareResponse(text: string): string {
  const cleanText = text.replace(/^\s*\[OUT_OF_SCOPE\]\s*/i, "").trim();
  if (!ARABIC_CHARACTERS.test(cleanText)) return cleanText;
  const response = cleanText
    .replace(/EgyptLore/gi, "\u2066EgyptLore\u2069");
  return /^[\s\u0600-\u06FF]/.test(response) ? response : `أكيد، ${response}`;
}

export function isSubstantiveAnswer(text: string): boolean {
  const normalized = text.trim();
  if (
    normalized.length < 2 ||
    /^(?:\.\.\.|…|no answer|empty response)$/i.test(normalized)
  ) return false;
  return !/^\[OUT_OF_SCOPE\]/i.test(normalized) &&
    !/(?:يمكنني فقط مساعدتك|دليلك المحلي.{0,30}يمكنني فقط|i(?:'m| am) your local (?:egyptlore )?guide.{0,80}only help|i can only help with)/i
      .test(normalized);
}
