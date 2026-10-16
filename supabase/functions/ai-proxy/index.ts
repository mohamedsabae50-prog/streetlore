// ============================================================================
// ai-proxy — v1.0.74
//
// Secure Gemini proxy. Gemini credentials live in function secrets and
// are never sent to the client.
//
// Request shape (POST JSON):
//   {
//     "contents": [ { "role": "user", "parts": [ { "text": "..." } ] } ],
//     "systemInstruction": { "parts": [ { "text": "..." } ] },   // optional
//     "generationConfig": { ... optional, whitelisted ... },
//     "model": "gemini-2.5-flash",   // optional, allowlisted (see below)
//     "stream": true,                // optional
//     "session_id": "<uuid>",        // optional, for chat logs
//     "log_prompt": "..."            // optional, logged (max 2000 chars)
//   }
//
// The client is NOT trusted. The upstream Gemini body is rebuilt from a
// whitelist, so a signed-in user cannot turn this function into an open
// Gemini relay:
//   - model:             must be in ALLOWED_MODELS; anything else is replaced
//                        by the default MODEL (no error, no oracle).
//   - contents:          text parts only, roles user/model, last turn must be
//                        "user". Only the newest MAX_TURNS turns are kept and
//                        the oldest are dropped until the upstream body fits
//                        MAX_UPSTREAM_BODY_BYTES (long chats keep working).
//   - systemInstruction: text parts only, <= MAX_SYSTEM_INSTRUCTION_CHARS.
//   - generationConfig:  only temperature / topP / topK / maxOutputTokens
//                        (clamped to MAX_OUTPUT_TOKENS) / responseMimeType;
//                        candidateCount is forced to 1.
//   - dropped always:    tools, toolConfig, cachedContent, thinkingConfig,
//                        safetySettings and every unknown field.
//
// Response: Gemini JSON by default, Gemini Server-Sent Events when
//   "stream": true, OR a JSON error:
//   { "error": "...", "code": "DAILY_LIMIT_EXCEEDED" | "UNAUTHORIZED" |
//     "BAD_REQUEST" | "UPSTREAM_UNAVAILABLE" | "UPSTREAM_ERROR" }
//   Upstream error bodies are never forwarded; they are logged server-side.
//
// Quota enforcement:
//   - 3 calls per Africa/Cairo calendar day for free users and 50 for Pro
//     (enforced in SQL).
//   - Admins (auth.users.email = ADMIN_EMAIL) bypass the quota.
//   - public.consume_ai_quota(p_user_id text) returns whether a call is allowed.
//   - The body is parsed and validated BEFORE the quota is consumed, so a
//     malformed request (HTTP 400) costs nothing.
//   - If no 2xx answer could be produced (every model failed, or the upstream
//     rejected the request) the unit is handed back with
//     public.refund_ai_quota(p_user_id text) — at most once per request.
//
// To deploy:
//   supabase functions deploy ai-proxy --no-verify-jwt --project-ref tbivoxyxclwjjspwsgvc
//   supabase secrets set GEMINI_SERVICE_ACCOUNT_JSON='<SERVICE_ACCOUNT_JSON>' --project-ref tbivoxyxclwjjspwsgvc
// (migration 20261105000002_ai_quota_refund.sql must be applied first.)
// ============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const ADMIN_EMAIL = (Deno.env.get("ADMIN_EMAIL") ?? "mohamedsabae50@gmail.com")
  .toLowerCase()
  .trim();

const MODEL = "gemini-2.5-flash";
// Models the app may use. The app itself only asks for MODEL; the other two
// are the server-side fallback chain (cheaper models). gemini-1.5-flash is
// retired and intentionally absent.
const MODEL_FALLBACK_CHAIN = [
  MODEL,
  "gemini-2.5-flash-lite",
  "gemini-2.0-flash",
];
const ALLOWED_MODELS = new Set(MODEL_FALLBACK_CHAIN);
// Upstream statuses that make us try the next model in the chain.
// 404 = model not found / retired.
const FALLBACK_STATUSES = [404, 429, 500, 503];

// Request limits (the client is untrusted — see the header comment).
const MAX_REQUEST_BYTES = 256 * 1024; // raw HTTP body, rejected above this
const MAX_UPSTREAM_BODY_BYTES = 64 * 1024; // rebuilt Gemini body
const MAX_TURNS = 40;
const MAX_SYSTEM_INSTRUCTION_CHARS = 8000;
const MAX_OUTPUT_TOKENS = 2048; // app uses 800 / 1024 / 2048
const DEFAULT_MAX_OUTPUT_TOKENS = 1024;
const MAX_LOG_PROMPT_CHARS = 2000;
const RESPONSE_MIME_TYPES = new Set(["text/plain", "application/json"]);
const SESSION_ID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const GEMINI_ENDPOINT_BASE =
  "https://generativelanguage.googleapis.com/v1beta/models";
const GOOGLE_TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token";
const GEMINI_SCOPE = "https://www.googleapis.com/auth/generative-language";
const OAUTH_ACCESS_TOKEN = Deno.env.get("GEMINI_OAUTH_ACCESS_TOKEN") ?? "";
const SERVICE_ACCOUNT_JSON = Deno.env.get("GEMINI_SERVICE_ACCOUNT_JSON") ?? "";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error(
    "ai-proxy: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY env vars missing",
  );
}

const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

type CachedAccessToken = {
  value: string;
  expiresAt: number;
};

let cachedAccessToken: CachedAccessToken | null = null;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

async function userIdFromAuthHeader(req: Request): Promise<string | null> {
  const auth = req.headers.get("authorization") ?? req.headers.get("Authorization");
  if (!auth) return null;
  const m = auth.match(/^Bearer\s+(.+)$/i);
  if (!m) return null;

  const { data, error } = await admin.auth.getUser(m[1]);
  if (error || !data.user) return null;
  return data.user.id;
}

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

async function serviceAccountAccessToken(): Promise<string> {
  if (cachedAccessToken && cachedAccessToken.expiresAt > Date.now() + 60_000) {
    return cachedAccessToken.value;
  }

  let serviceAccount: {
    client_email?: string;
    private_key?: string;
    token_uri?: string;
  };
  try {
    serviceAccount = JSON.parse(SERVICE_ACCOUNT_JSON);
  } catch {
    throw new Error("GEMINI_SERVICE_ACCOUNT_JSON is not valid JSON");
  }

  const { client_email, private_key } = serviceAccount;
  if (!client_email || !private_key) {
    throw new Error(
      "GEMINI_SERVICE_ACCOUNT_JSON must include client_email and private_key",
    );
  }

  const now = Math.floor(Date.now() / 1000);
  const encodeJson = (value: unknown) =>
    base64UrlEncode(new TextEncoder().encode(JSON.stringify(value)));
  const unsignedToken = [
    encodeJson({ alg: "RS256", typ: "JWT" }),
    encodeJson({
      iss: client_email,
      scope: GEMINI_SCOPE,
      aud: serviceAccount.token_uri ?? GOOGLE_TOKEN_ENDPOINT,
      iat: now,
      exp: now + 3600,
    }),
  ].join(".");
  const pem = private_key
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");
  const keyBytes = Uint8Array.from(atob(pem), (char) => char.charCodeAt(0));
  const signingKey = await crypto.subtle.importKey(
    "pkcs8",
    keyBytes,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    signingKey,
    new TextEncoder().encode(unsignedToken),
  );
  const assertion = `${unsignedToken}.${base64UrlEncode(
    new Uint8Array(signature),
  )}`;
  const tokenUri = serviceAccount.token_uri ?? GOOGLE_TOKEN_ENDPOINT;
  const response = await fetch(tokenUri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) {
    throw new Error(`Google OAuth token exchange failed (${response.status})`);
  }

  const tokenResponse = await response.json();
  if (
    typeof tokenResponse.access_token !== "string" ||
    typeof tokenResponse.expires_in !== "number"
  ) {
    throw new Error("Google OAuth response did not include a valid access token");
  }
  cachedAccessToken = {
    value: tokenResponse.access_token,
    expiresAt: Date.now() + tokenResponse.expires_in * 1000,
  };
  return cachedAccessToken.value;
}

async function geminiAuthHeaders(): Promise<Record<string, string>> {
  if (SERVICE_ACCOUNT_JSON) {
    return {
      Authorization: `Bearer ${await serviceAccountAccessToken()}`,
    };
  }
  if (OAUTH_ACCESS_TOKEN) {
    return { Authorization: `Bearer ${OAUTH_ACCESS_TOKEN}` };
  }
  if (GEMINI_API_KEY) {
    return { "x-goog-api-key": GEMINI_API_KEY };
  }
  throw new Error(
    "Configure GEMINI_SERVICE_ACCOUNT_JSON, GEMINI_OAUTH_ACCESS_TOKEN, or GEMINI_API_KEY",
  );
}

async function consumeQuota(userId: string): Promise<boolean | null> {
  const { data, error } = await admin.rpc("consume_ai_quota", {
    p_user_id: userId,
  });
  if (error) {
    console.error("ai-proxy: consume_ai_quota RPC failed:", error);
    return null;
  }
  return data === true;
}

// Hands back the unit taken by consumeQuota when no answer was produced.
// Never throws: a failed refund must not mask the real error response.
async function refundQuota(userId: string): Promise<void> {
  try {
    const { error } = await admin.rpc("refund_ai_quota", {
      p_user_id: userId,
    });
    if (error) console.error("ai-proxy: refund_ai_quota RPC failed:", error);
  } catch (error) {
    console.error("ai-proxy: refund_ai_quota threw:", error);
  }
}

async function isAdmin(userId: string): Promise<boolean> {
  const { data, error } = await admin.auth.admin.getUserById(userId);
  if (error || !data?.user) return false;
  return ((data.user.email ?? "").toLowerCase().trim()) === ADMIN_EMAIL;
}

// ---------------------------------------------------------------------------
// Request parsing + validation. Everything here runs BEFORE the quota is
// consumed, so an invalid request never costs the user a unit.
// ---------------------------------------------------------------------------

type GeminiTextPart = { text: string };
type GeminiContent = { role: "user" | "model"; parts: GeminiTextPart[] };
type GeminiBody = {
  contents: GeminiContent[];
  systemInstruction?: { parts: GeminiTextPart[] };
  generationConfig: Record<string, unknown>;
};
type ValidRequest = {
  model: string;
  streaming: boolean;
  sessionId: string | null;
  logPrompt: string;
  body: GeminiBody;
};
type ParseResult =
  | { ok: true; value: ValidRequest }
  | { ok: false; error: string };

const utf8 = new TextEncoder();

function byteLength(value: string): number {
  return utf8.encode(value).length;
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function truncate(value: string, max: number): string {
  if (value.length <= max) return value;
  const cut = value.slice(0, max);
  // Do not leave half of a surrogate pair at the end.
  const last = cut.charCodeAt(cut.length - 1);
  return last >= 0xd800 && last <= 0xdbff ? cut.slice(0, -1) : cut;
}

// Reads the request body, giving up as soon as it exceeds MAX_REQUEST_BYTES.
// Returns null when the body is too large.
async function readBodyText(req: Request): Promise<string | null> {
  const declared = Number(req.headers.get("content-length"));
  if (Number.isFinite(declared) && declared > MAX_REQUEST_BYTES) return null;
  if (!req.body) return "";
  const reader = req.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > MAX_REQUEST_BYTES) {
      await reader.cancel().catch(() => {});
      return null;
    }
    chunks.push(value);
  }
  const merged = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    merged.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder().decode(merged);
}

// Text-only parts. Anything else (inlineData, fileData, functionCall, ...) is
// rejected rather than silently dropped, so the caller learns about it.
function textParts(value: unknown): GeminiTextPart[] | null {
  if (!Array.isArray(value) || value.length === 0) return null;
  const parts: GeminiTextPart[] = [];
  for (const part of value) {
    if (!isPlainObject(part) || typeof part.text !== "string") return null;
    parts.push({ text: part.text });
  }
  return parts;
}

function sanitizeContents(value: unknown): GeminiContent[] | string {
  if (!Array.isArray(value) || value.length === 0) return "invalid_contents";
  const turns: GeminiContent[] = [];
  for (const entry of value) {
    if (!isPlainObject(entry)) return "invalid_contents";
    const role = entry.role ?? "user";
    if (role !== "user" && role !== "model") return "invalid_contents";
    const parts = textParts(entry.parts);
    if (!parts) return "invalid_contents";
    turns.push({ role: role as GeminiContent["role"], parts });
  }
  if (turns[turns.length - 1].role !== "user") return "invalid_contents";
  return turns;
}

function sanitizeSystemInstruction(
  value: unknown,
): { parts: GeminiTextPart[] } | undefined | string {
  if (value === undefined || value === null) return undefined;
  if (!isPlainObject(value)) return "invalid_system_instruction";
  const parts = textParts(value.parts);
  if (!parts) return "invalid_system_instruction";
  const chars = parts.reduce((sum, part) => sum + part.text.length, 0);
  if (chars > MAX_SYSTEM_INSTRUCTION_CHARS) {
    return "system_instruction_too_large";
  }
  return chars === 0 ? undefined : { parts };
}

function clampNumber(value: unknown, min: number, max: number): number | undefined {
  return typeof value === "number" && Number.isFinite(value)
    ? Math.min(Math.max(value, min), max)
    : undefined;
}

function sanitizeGenerationConfig(
  value: unknown,
): Record<string, unknown> | string {
  if (value !== undefined && value !== null && !isPlainObject(value)) {
    return "invalid_generation_config";
  }
  const input = (value ?? {}) as Record<string, unknown>;
  const config: Record<string, unknown> = {};
  const temperature = clampNumber(input.temperature, 0, 2);
  if (temperature !== undefined) config.temperature = temperature;
  const topP = clampNumber(input.topP, 0, 1);
  if (topP !== undefined) config.topP = topP;
  const topK = clampNumber(input.topK, 1, 64);
  if (topK !== undefined) config.topK = Math.floor(topK);
  const requestedTokens = clampNumber(input.maxOutputTokens, 1, MAX_OUTPUT_TOKENS);
  config.maxOutputTokens = requestedTokens === undefined
    ? DEFAULT_MAX_OUTPUT_TOKENS
    : Math.floor(requestedTokens);
  if (
    typeof input.responseMimeType === "string" &&
    RESPONSE_MIME_TYPES.has(input.responseMimeType)
  ) {
    config.responseMimeType = input.responseMimeType;
  }
  config.candidateCount = 1;
  return config;
}

// Keeps the newest turns that fit MAX_TURNS and MAX_UPSTREAM_BODY_BYTES.
// Returns null when even the newest turn alone does not fit. (The app's own
// chat history already opens with a "model" welcome turn, so a leading model
// turn is not treated as invalid.)
function fitContents(
  turns: GeminiContent[],
  rest: Omit<GeminiBody, "contents">,
): GeminiContent[] | null {
  let kept = turns.slice(-MAX_TURNS);
  while (byteLength(JSON.stringify({ ...rest, contents: kept })) >
    MAX_UPSTREAM_BODY_BYTES) {
    if (kept.length <= 1) return null;
    kept = kept.slice(1);
  }
  return kept;
}

function promptFromContents(contents: GeminiContent[]): string {
  const last = contents[contents.length - 1];
  return last.parts.map((part) => part.text).join("\n").trim();
}

async function parseRequest(req: Request): Promise<ParseResult> {
  const text = await readBodyText(req);
  if (text === null) return { ok: false, error: "body_too_large" };
  let raw: unknown;
  try {
    raw = JSON.parse(text);
  } catch {
    return { ok: false, error: "invalid_json" };
  }
  // `null`, arrays and scalars are valid JSON but not a request.
  if (!isPlainObject(raw)) return { ok: false, error: "invalid_body" };

  const requestedSessionId = raw.session_id;
  if (
    requestedSessionId !== undefined &&
    (typeof requestedSessionId !== "string" ||
      !SESSION_ID_PATTERN.test(requestedSessionId))
  ) {
    return { ok: false, error: "invalid_session_id" };
  }

  const turns = sanitizeContents(raw.contents);
  if (typeof turns === "string") return { ok: false, error: turns };
  const systemInstruction = sanitizeSystemInstruction(raw.systemInstruction);
  if (typeof systemInstruction === "string") {
    return { ok: false, error: systemInstruction };
  }
  const generationConfig = sanitizeGenerationConfig(raw.generationConfig);
  if (typeof generationConfig === "string") {
    return { ok: false, error: generationConfig };
  }

  const rest: Omit<GeminiBody, "contents"> = {
    ...(systemInstruction ? { systemInstruction } : {}),
    generationConfig,
  };
  const contents = fitContents(turns, rest);
  if (!contents) return { ok: false, error: "payload_too_large" };

  const requestedModel = typeof raw.model === "string" ? raw.model : MODEL;
  let model = requestedModel;
  if (!ALLOWED_MODELS.has(requestedModel)) {
    console.warn(
      `ai-proxy: model "${truncate(requestedModel, 80)}" is not allowed; using ${MODEL}`,
    );
    model = MODEL;
  }

  const logPrompt = truncate(
    (typeof raw.log_prompt === "string" ? raw.log_prompt.trim() : "") ||
      promptFromContents(contents),
    MAX_LOG_PROMPT_CHARS,
  );

  return {
    ok: true,
    value: {
      model,
      streaming: raw.stream === true,
      sessionId: typeof requestedSessionId === "string"
        ? requestedSessionId
        : null,
      logPrompt,
      body: { contents, ...rest },
    },
  };
}

function responseText(value: unknown): string {
  if (!value || typeof value !== "object") return "";
  const candidates = (value as {
    candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
  }).candidates;
  return candidates
    ?.flatMap((candidate) =>
      candidate.content?.parts?.map((part) => part.text ?? "") ?? []
    )
    .join("") ?? "";
}

function responseTextFromStream(streamText: string): string {
  const chunks: string[] = [];
  for (const line of streamText.split(/\r?\n/)) {
    if (!line.startsWith("data:")) continue;
    const data = line.slice(5).trim();
    if (!data || data === "[DONE]") continue;
    try {
      chunks.push(responseText(JSON.parse(data)));
    } catch (error) {
      console.error("ai-proxy: could not parse streamed response for logging", error);
    }
  }
  return chunks.join("");
}

async function logInteraction(
  userId: string,
  prompt: string,
  response: string,
  sessionId: string | null,
): Promise<void> {
  const { error } = await admin.from("ai_chat_logs").insert({
    user_id: userId,
    session_id: sessionId,
    user_prompt: prompt,
    ai_response: response,
  });
  if (error) console.error("ai-proxy: failed to log chat interaction:", error);
}

const UPSTREAM_UNAVAILABLE_MESSAGE =
  "The AI guide is temporarily unavailable. Please try again.";

function upstreamUnavailable(): Response {
  return json({
    error: "ai_unavailable",
    code: "UPSTREAM_UNAVAILABLE",
    message: UPSTREAM_UNAVAILABLE_MESSAGE,
  }, 503);
}

// Calls Gemini (walking the fallback chain) and builds the response. Any
// non-2xx outcome returns a generic error and hands the quota unit back via
// `refund`; upstream error bodies are logged here and never sent to the client.
async function generate(
  userId: string,
  request: ValidRequest,
  refund: () => Promise<void>,
): Promise<Response> {
  const { model, streaming, sessionId, logPrompt: prompt } = request;
  const upstreamBody = JSON.stringify(request.body);
  const endpoint = streaming ? "streamGenerateContent?alt=sse" : "generateContent";
  const models = [...new Set([model, ...MODEL_FALLBACK_CHAIN])];
  let upstream: Response | null = null;
  let selectedModel = model;
  let fetchFailure: unknown;
  for (let index = 0; index < models.length; index++) {
    selectedModel = models[index];
    const url =
      `${GEMINI_ENDPOINT_BASE}/${encodeURIComponent(selectedModel)}:${endpoint}`;
    try {
      upstream = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...await geminiAuthHeaders(),
        },
        body: upstreamBody,
      });
    } catch (error) {
      upstream = null;
      fetchFailure = error;
      console.error(`ai-proxy: fetch failed for ${selectedModel}:`, error);
      if (index < models.length - 1) {
        await new Promise((resolve) => setTimeout(resolve, 250));
        continue;
      }
      break;
    }
    if (upstream.ok || !FALLBACK_STATUSES.includes(upstream.status)) break;
    if (index < models.length - 1) {
      console.warn(
        `ai-proxy: model ${selectedModel} returned ${upstream.status}; trying fallback`,
      );
      await new Promise((resolve) => setTimeout(resolve, 250));
    }
  }

  if (!upstream) {
    console.error("ai-proxy: all upstream requests failed:", fetchFailure);
    await refund();
    await logInteraction(userId, prompt, "AI service temporarily unavailable.", sessionId);
    return upstreamUnavailable();
  }
  if (!upstream.ok) {
    const detail = await upstream.text().catch(() => "");
    console.error(
      `ai-proxy: model ${selectedModel} returned ${upstream.status}:`,
      truncate(detail, 1000),
    );
    await refund();
    if (FALLBACK_STATUSES.includes(upstream.status)) {
      await logInteraction(userId, prompt, "AI service temporarily unavailable.", sessionId);
      return upstreamUnavailable();
    }
    // A 4xx the chain cannot fix (bad argument, auth/config problem): do not
    // leak Gemini's message (project ids, quota details, ...) to the client.
    await logInteraction(userId, prompt, "AI request failed.", sessionId);
    return json({
      error: "ai_request_failed",
      code: "UPSTREAM_ERROR",
      message: "The AI guide could not answer this request.",
    }, 502);
  }

  if (streaming) {
    const responseForLogging = upstream.clone();
    const logging = responseForLogging.text().then((text) =>
      logInteraction(userId, prompt, responseTextFromStream(text), sessionId)
    ).catch((error) => {
      console.error("ai-proxy: failed to read streamed response for logging:", error);
    });
    EdgeRuntime.waitUntil(logging);
    return new Response(upstream.body, {
      status: upstream.status,
      headers: {
        "Content-Type": "text/event-stream; charset=utf-8",
        "Cache-Control": "no-cache",
        "Connection": "keep-alive",
        ...CORS_HEADERS,
      },
    });
  }

  const text = await upstream.text();
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    parsed = { raw: text };
  }
  const aiResponse = typeof parsed === "object" && parsed !== null
    ? responseText(parsed)
    : "";
  await logInteraction(userId, prompt, aiResponse, sessionId);
  return new Response(JSON.stringify(parsed), {
    status: upstream.status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const userId = await userIdFromAuthHeader(req);
  if (!userId) return json({ error: "unauthorized" }, 401);

  // Validate first: a malformed request must not cost the user a quota unit.
  const parsed = await parseRequest(req);
  if (!parsed.ok) return json({ error: parsed.error, code: "BAD_REQUEST" }, 400);

  const adminUser = await isAdmin(userId);
  let charged = false;
  if (!adminUser) {
    const ok = await consumeQuota(userId);
    if (ok === null) {
      return json({ error: "quota_unavailable", code: "BAD_REQUEST" }, 503);
    }
    if (!ok) {
      return json({
        error: "daily_limit_exceeded",
        code: "DAILY_LIMIT_EXCEEDED",
        message: "You have reached your daily limit, please come back tomorrow.",
      }, 429);
    }
    charged = true;
  }

  // At most one refund per request, and only if a unit was actually taken
  // (admins never consume, so they never get a refund either).
  let refunded = false;
  const refund = async () => {
    if (!charged || refunded) return;
    refunded = true;
    await refundQuota(userId);
  };

  try {
    return await generate(userId, parsed.value, refund);
  } catch (error) {
    console.error("ai-proxy: unexpected failure:", error);
    await refund();
    return upstreamUnavailable();
  }
});
