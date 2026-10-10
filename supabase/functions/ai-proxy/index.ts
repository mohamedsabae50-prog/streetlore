// ============================================================================
// ai-proxy — v1.0.73
//
// Secure Gemini proxy. Gemini credentials live in function secrets and
// are never sent to the client.
//
// Request shape (POST JSON):
//   {
//     "contents": [ { "parts": [ { "text": "..." } ] } ],
//     "generationConfig": { ... optional ... },
//     "model": "gemini-2.5-flash"   // optional override
//   }
//
// Response: Gemini JSON by default, Gemini Server-Sent Events when
//   "stream": true, OR a JSON error:
//   { "error": "...", "code": "DAILY_LIMIT_EXCEEDED" | "UNAUTHORIZED" | "BAD_REQUEST" }
//
// Quota enforcement:
//   - 15 calls / 24h per user (capped by ai_quota.daily_limit).
//   - Admins (auth.jwt()->email = admin email) bypass the quota.
//   - The database RPC atomically tracks requests in a rolling 24-hour window.
//
// To deploy:
//   supabase functions deploy ai-proxy --no-verify-jwt --project-ref tbivoxyxclwjjspwsgvc
//   supabase secrets set GEMINI_SERVICE_ACCOUNT_JSON='<SERVICE_ACCOUNT_JSON>' --project-ref tbivoxyxclwjjspwsgvc
// ============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const ADMIN_EMAIL = (Deno.env.get("ADMIN_EMAIL") ?? "mohamedsabae50@gmail.com")
  .toLowerCase()
  .trim();

const DEFAULT_DAILY_LIMIT = 15;
const MODEL = "gemini-2.5-flash";
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
    p_daily_limit: DEFAULT_DAILY_LIMIT,
  });
  if (error) {
    console.error("ai-proxy: consume_ai_quota RPC failed:", error);
    return null;
  }
  return data === true;
}

async function isAdmin(userId: string): Promise<boolean> {
  const { data, error } = await admin.auth.admin.getUserById(userId);
  if (error || !data?.user) return false;
  return ((data.user.email ?? "").toLowerCase().trim()) === ADMIN_EMAIL;
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

  const adminUser = await isAdmin(userId);
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
  }

  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json", code: "BAD_REQUEST" }, 400);
  }
  const model = (body.model as string | undefined) ?? MODEL;
  const streaming = body.stream === true;
  delete body.model;
  delete body.stream;

  const endpoint = streaming ? "streamGenerateContent?alt=sse" : "generateContent";
  const url =
    `${GEMINI_ENDPOINT_BASE}/${encodeURIComponent(model)}:${endpoint}`;
  let upstream: Response;
  try {
    upstream = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...await geminiAuthHeaders(),
      },
      body: JSON.stringify(body),
    });
  } catch (e) {
    console.error("ai-proxy: upstream authentication or fetch failed:", e);
    return json({ error: "upstream_unreachable", code: "BAD_REQUEST" }, 502);
  }

  if (upstream.ok && streaming) {
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
  return new Response(JSON.stringify(parsed), {
    status: upstream.status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
});