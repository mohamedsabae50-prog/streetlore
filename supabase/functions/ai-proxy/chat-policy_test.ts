import {
  conversationalReply,
  isSubstantiveAnswer,
  prepareResponse,
} from "./chat-policy.ts";
import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.test("Arabic greetings and check-ins get a warm local-guide reply", () => {
  for (
    const prompt of [
      "عامل اي",
      "عامل ايه",
      "ازيك",
      "اهلا",
      "مرحبا",
      "سلام عليكم",
      "انت مين",
      "بتعمل ايه",
      "بايظ",
      "شغال",
      "خوفت",
      "صاحبي كان مفكر انك بايظ",
    ]
  ) {
    const reply = conversationalReply(prompt);
    assert(reply !== null, `Expected a reply to: ${prompt}`);
    assert(reply.includes("أماكن") || reply.includes("مصر"));
    assert(!reply.includes("يمكنني فقط مساعدتك"));
  }
});

Deno.test("English greetings and bot check-ins get a warm local-guide reply", () => {
  for (
    const prompt of [
      "hi",
      "hello",
      "hey",
      "how are you",
      "who are you",
      "are you working",
    ]
  ) {
    const reply = conversationalReply(prompt);
    assert(reply !== null, `Expected a reply to: ${prompt}`);
    assert(reply.includes("Egypt"));
  }
});

Deno.test("unrelated questions are not treated as small talk", () => {
  assertEquals(
    conversationalReply("How do I write a sorting algorithm?"),
    null,
  );
  assertEquals(conversationalReply("عامل ايه مواعيد قلعة قايتباي"), null);
});

Deno.test("Arabic output leads with Arabic and isolates the Latin brand", () => {
  assertEquals(
    prepareResponse("EgyptLore أنا دليلك المحلي."),
    "أكيد، \u2066EgyptLore\u2069 أنا دليلك المحلي.",
  );
  assertEquals(
    prepareResponse("أهلاً من EgyptLore"),
    "أهلاً من \u2066EgyptLore\u2069",
  );
});

Deno.test("empty and guardrail responses do not consume quota", () => {
  assertEquals(isSubstantiveAnswer(""), false);
  assertEquals(isSubstantiveAnswer("..."), false);
  assertEquals(isSubstantiveAnswer("[OUT_OF_SCOPE] خارج النطاق"), false);
  assertEquals(
    isSubstantiveAnswer(
      "أنا دليلك المحلي في EgyptLore — يمكنني فقط مساعدتك في أمور السفر.",
    ),
    false,
  );
  assertEquals(
    isSubstantiveAnswer(
      "I'm your local EgyptLore guide — I can only help with travel.",
    ),
    false,
  );
  assertEquals(isSubstantiveAnswer("إليك تاريخ قلعة قايتباي."), true);
});
