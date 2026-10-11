import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

// Deploy with --no-verify-jwt and set REVENUECAT_WEBHOOK_SECRET in Supabase.
// Configure that exact secret as the RevenueCat webhook Authorization value.
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const REVENUECAT_WEBHOOK_SECRET =
  Deno.env.get("REVENUECAT_WEBHOOK_SECRET") ?? "";
const PRO_ENTITLEMENT_ID =
  Deno.env.get("REVENUECAT_PRO_ENTITLEMENT_ID") ?? "pro";

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error("revenuecat-webhook: Supabase service configuration is missing");
}
if (!REVENUECAT_WEBHOOK_SECRET) {
  console.error("revenuecat-webhook: REVENUECAT_WEBHOOK_SECRET is missing");
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

serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }
  if (!REVENUECAT_WEBHOOK_SECRET) {
    return json({ error: "webhook_not_configured" }, 503);
  }
  if (req.headers.get("authorization") !== REVENUECAT_WEBHOOK_SECRET) {
    return json({ error: "unauthorized" }, 401);
  }

  let payload: {
    event?: {
      type?: string;
      app_user_id?: string;
      entitlement_ids?: string[] | null;
    };
  };
  try {
    payload = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const event = payload.event;
  const userId = event?.app_user_id;
  const eventType = event?.type;
  if (!userId || !eventType) {
    return json({ error: "invalid_event" }, 400);
  }
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
    .test(userId)) {
    return json({ error: "invalid_app_user_id" }, 400);
  }

  const entitled = event.entitlement_ids?.includes(PRO_ENTITLEMENT_ID) ?? false;
  let isPro: boolean | null = null;
  if (entitled && [
    "INITIAL_PURCHASE",
    "RENEWAL",
    "PRODUCT_CHANGE",
    "UNCANCELLATION",
    "NON_RENEWING_PURCHASE",
  ].includes(eventType)) {
    isPro = true;
  } else if (entitled && eventType === "EXPIRATION") {
    isPro = false;
  }
  if (isPro === null) {
    return json({ ok: true, ignored: true });
  }

  const { error } = await admin
    .from("profiles")
    .upsert({ user_id: userId, is_pro: isPro }, { onConflict: "user_id" });
  if (error) {
    console.error("revenuecat-webhook: profile entitlement sync failed:", error);
    return json({ error: "profile_sync_failed" }, 500);
  }
  return json({ ok: true });
});
