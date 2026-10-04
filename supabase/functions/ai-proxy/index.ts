// ============================================================================
// ai-proxy — v1.0.73
//
// Secure Gemini proxy. All Gemini API calls from the Streetlore mobile
// app route through this function. The real GEMINI_API_KEY lives in
// the function's encrypted secrets and is never sent to the client.
//
// Request shape (POST JSON):
//   {
//     "contents": [ { "parts": [ { "text": "..." } ] } ],
//     "generationConfig": { ... optional ... },
//     "model": "gemini-2.0-flash"   // optional override
//   }
//
// Response: identical to the Gemini REST API response, OR
//   { "error": "...", "code": "QUOTA_EXCEEDED" | "UNAUTHORIZED" | "BAD_REQUEST" }
//
// Quota enforcement:
//   - 60 calls / 24h per user (configurable per-row in ai_quota.daily_limit).
//   - Admins (auth.jwt()->email = admin email) bypass the quota.
//   - Daily window resets when the Edge Function notices the row's
//     window_start is older than 24h.
//
// To deploy:
//   supabase functions deploy ai-proxy --no-verify-jwt --project-ref tbivoxyxclwjjspwsgvc
//   supabase secrets set GEMINI_API_KEY=<NEW_KEY>  --project-ref tbivoxyxclwjjspwsgvc
// ============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const ADMIN_EMAIL = (Deno.env.get("ADMIN_EMAIL") ?? "mohamedsabae50@gmail.com")
  .toLowerCase()
  .trim();

const DEFAULT_DAILY_LIMIT = 60;
const MODEL = "gemini-2.0-flash";
const GEMINI_ENDPOINT_BASE =
  "https://generativelanguage.googleapis.com/v1beta/models";

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

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function userIdFromAuthHeader(req: Request): string | null {
  const auth = req.headers.get("authorization") ?? req.headers.get("Authorization");
  if (!auth) return null;
  const m = auth.match(/^Bearer\s+(.+)$/i);
  if (!m) return null;
  try {
    const payload = JSON.parse(
      atob(m[1].split(".")[1].replace(/-/g, "+").replace(/_/g, "/")),
    );
    return (payload.sub as string | undefined) ?? null;
  } catch {
    return null;
  }
}

async function consumeQuota(userId: string): Promise<boolean> {
  const { data: row, error } = await admin
    .from("ai_quota")
    .select("*")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) {
    console.error("ai-proxy: ai_quota select failed:", error);
    return false;
  }
  const now = new Date();
  const windowStart = row?.window_start ? new Date(row.window_start) : now;
  const elapsedH = (now.getTime() - windowStart.getTime()) / (1000 * 60 * 60);
  const used = elapsedH >= 24 ? 0 : (row?.used_today ?? 0);
  const limit = row?.daily_limit ?? DEFAULT_DAILY_LIMIT;
  if (used >= limit) return false;
  const newCount = used + 1;
  const patch = {
    user_id: userId,
    used_today: newCount,
    window_start: elapsedH >= 24 ? now.toISOString() : windowStart.toISOString(),
    updated_at: now.toISOString(),
  };
  const { error: upsertErr } = await admin
    .from("ai_quota")
    .upsert(patch, { onConflict: "user_id" });
  if (upsertErr) {
    console.error("ai-proxy: ai_quota upsert failed:", upsertErr);
    return false;
  }
  return true;
}

async function isAdmin(userId: string): Promise<boolean> {
  const { data, error } = await admin.auth.admin.getUserById(userId);
  if (error || !data?.user) return false;
  return ((data.user.email ?? "").toLowerCase().trim()) === ADMIN_EMAIL;
}

serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const userId = userIdFromAuthHeader(req);
  if (!userId) return json({ error: "unauthorized" }, 401);

  const adminUser = await isAdmin(userId);
  if (!adminUser) {
    const ok = await consumeQuota(userId);
    if (!ok) return json({ error: "quota_exceeded", code: "QUOTA_EXCEEDED" }, 429);
  }

  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json", code: "BAD_REQUEST" }, 400);
  }
  const model = (body.model as string | undefined) ?? MODEL;
  delete body.model;

  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    console.error("ai-proxy: GEMINI_API_KEY not set");
    return json({ error: "server_misconfigured", code: "BAD_REQUEST" }, 500);
  }

  const url = `${GEMINI_ENDPOINT_BASE}/${encodeURIComponent(model)}:generateContent`;
  let upstream: Response;
  try {
    upstream = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": apiKey,
      },
      body: JSON.stringify(body),
    });
  } catch (e) {
    console.error("ai-proxy: upstream fetch failed:", e);
    return json({ error: "upstream_unreachable", code: "BAD_REQUEST" }, 502);
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
    headers: { "Content-Type": "application/json" },
  });
});