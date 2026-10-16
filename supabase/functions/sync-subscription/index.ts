import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import {
  allowSandboxFromEnv,
  createRateLimiter,
  deriveProfileState,
  fetchSubscriber,
  parseProductTiers,
  type PaidTier,
} from "../_shared/subscription.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const REVENUECAT_SECRET_API_KEY =
  Deno.env.get("REVENUECAT_SECRET_API_KEY") ?? "";
const REVENUECAT_PRODUCT_TIERS =
  Deno.env.get("REVENUECAT_PRODUCT_TIERS") ?? "";
const PRO_ENTITLEMENT_ID =
  Deno.env.get("REVENUECAT_PRO_ENTITLEMENT_ID") ?? "pro";
// Sandbox / RevenueCat Test Store purchases never grant Pro unless the owner
// explicitly opts in (e.g. on a development project): REVENUECAT_ALLOW_SANDBOX=true.
const ALLOW_SANDBOX = allowSandboxFromEnv(
  Deno.env.get("REVENUECAT_ALLOW_SANDBOX"),
);
// Best-effort burst guard per user (per instance, no table): a real purchase or
// restore needs one or two syncs, so 6 per 30 s never touches the happy path.
const syncAllowance = createRateLimiter(6, 30_000);

const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(
  body: unknown,
  status = 200,
  extraHeaders: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
      ...extraHeaders,
    },
  });
}

function bearer(req: Request): string | null {
  const match = (req.headers.get("authorization") ?? "")
    .match(/^Bearer\s+(.+)$/i);
  return match?.[1] ?? null;
}

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const token = bearer(req);
  if (!token) return json({ error: "missing_bearer" }, 401);
  const { data: authData, error: authError } = await admin.auth.getUser(token);
  if (authError || !authData.user) return json({ error: "unauthorized" }, 401);

  if (!REVENUECAT_SECRET_API_KEY) {
    console.error("sync-subscription: REVENUECAT_SECRET_API_KEY is missing");
    return json({ error: "subscription_sync_not_configured" }, 503);
  }

  const retryAfter = syncAllowance(authData.user.id);
  if (retryAfter > 0) {
    return json({ error: "rate_limited" }, 429, {
      "Retry-After": String(retryAfter),
    });
  }

  let tiers: Map<string, PaidTier>;
  try {
    tiers = parseProductTiers(REVENUECAT_PRODUCT_TIERS);
  } catch (error) {
    console.error("sync-subscription: invalid RevenueCat product tier map:", error);
    return json({ error: "subscription_sync_not_configured" }, 503);
  }

  const lookup = await fetchSubscriber(
    authData.user.id,
    REVENUECAT_SECRET_API_KEY,
  );
  if (!lookup.ok) return json({ error: lookup.error }, lookup.status);

  const derived = deriveProfileState(lookup.subscriber, {
    tiers,
    entitlementId: PRO_ENTITLEMENT_ID,
    allowSandbox: ALLOW_SANDBOX,
  });
  if (!derived.ok) {
    console.error("sync-subscription: cannot derive profile state:", {
      userId: authData.user.id,
      error: derived.error,
    });
    return json({ error: derived.error }, derived.status);
  }
  const { is_pro: active, subscription_tier: plan, subscription_end_date: endDate } =
    derived.state;
  if (derived.reason?.startsWith("non_production")) {
    console.warn("sync-subscription: ignored non-production purchase:", {
      userId: authData.user.id,
      reason: derived.reason,
    });
  }

  const { error: updateError } = await admin.from("profiles").upsert({
    user_id: authData.user.id,
    is_pro: active,
    subscription_tier: plan,
    subscription_end_date: endDate,
    updated_at: new Date().toISOString(),
  }, { onConflict: "user_id" });
  if (updateError) {
    console.error("sync-subscription: profile update failed:", updateError);
    return json({ error: "profile_sync_failed" }, 500);
  }

  return json({
    ok: true,
    is_pro: active,
    subscription_tier: plan,
    subscription_end_date: endDate,
    ...(derived.reason ? { ignored_reason: derived.reason } : {}),
  });
});
