import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const REVENUECAT_SECRET_API_KEY =
  Deno.env.get("REVENUECAT_SECRET_API_KEY") ?? "";
const REVENUECAT_PRODUCT_TIERS =
  Deno.env.get("REVENUECAT_PRODUCT_TIERS") ?? "";
const PRO_ENTITLEMENT_ID =
  Deno.env.get("REVENUECAT_PRO_ENTITLEMENT_ID") ?? "pro";

const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
    },
  });
}

function bearer(req: Request): string | null {
  const match = (req.headers.get("authorization") ?? "")
    .match(/^Bearer\s+(.+)$/i);
  return match?.[1] ?? null;
}

function productTierMap(): Map<string, string> {
  let value: unknown;
  try {
    value = JSON.parse(REVENUECAT_PRODUCT_TIERS);
  } catch {
    throw new Error("REVENUECAT_PRODUCT_TIERS must be a JSON object");
  }
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("REVENUECAT_PRODUCT_TIERS must be a JSON object");
  }
  const tiers = new Map<string, string>();
  for (const [productId, tier] of Object.entries(value)) {
    if (
      tier !== "weekly" &&
      tier !== "monthly" &&
      tier !== "lifetime"
    ) {
      throw new Error(`Invalid tier configured for RevenueCat product ${productId}`);
    }
    tiers.set(productId, tier);
  }
  if (!tiers.size) throw new Error("REVENUECAT_PRODUCT_TIERS is empty");
  return tiers;
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

  let tiers: Map<string, string>;
  try {
    tiers = productTierMap();
  } catch (error) {
    console.error("sync-subscription: invalid RevenueCat product tier map:", error);
    return json({ error: "subscription_sync_not_configured" }, 503);
  }

  let response: Response;
  try {
    response = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(authData.user.id)}`,
      {
        headers: {
          Authorization: `Bearer ${REVENUECAT_SECRET_API_KEY}`,
          Accept: "application/json",
        },
      },
    );
  } catch (error) {
    console.error("sync-subscription: RevenueCat request failed:", error);
    return json({ error: "revenuecat_unavailable" }, 502);
  }
  if (!response.ok) {
    console.error(
      `sync-subscription: RevenueCat returned HTTP ${response.status}`,
    );
    return json({ error: "revenuecat_lookup_failed" }, 502);
  }

  let payload: {
    subscriber?: {
      entitlements?: Record<string, {
        expires_date?: string | null;
        product_identifier?: string;
      }>;
    };
  };
  try {
    payload = await response.json();
  } catch (error) {
    console.error("sync-subscription: invalid RevenueCat response:", error);
    return json({ error: "invalid_revenuecat_response" }, 502);
  }

  const entitlement = payload.subscriber?.entitlements?.[PRO_ENTITLEMENT_ID];
  const expiration = entitlement?.expires_date ?? null;
  if (
    entitlement !== undefined &&
    expiration !== null &&
    !Number.isFinite(Date.parse(expiration))
  ) {
    return json({ error: "invalid_revenuecat_expiration" }, 502);
  }
  const active = entitlement !== undefined &&
    (expiration === null || Date.parse(expiration) > Date.now());
  let plan = "free";
  let endDate: string | null = null;

  if (active) {
    const productId = entitlement.product_identifier;
    const mappedPlan = productId ? tiers.get(productId) : undefined;
    if (!productId || !mappedPlan) {
      console.error(
        "sync-subscription: active RevenueCat product has no configured tier",
        { userId: authData.user.id, productId },
      );
      return json({ error: "unmapped_revenuecat_product" }, 409);
    }
    if (mappedPlan === "lifetime" && expiration !== null) {
      console.error(
        "sync-subscription: lifetime product has an expiration date",
        { productId, expiration },
      );
      return json({ error: "invalid_lifetime_expiration" }, 409);
    }
    if (mappedPlan !== "lifetime" && expiration === null) {
      console.error(
        "sync-subscription: recurring product has no expiration date",
        { productId },
      );
      return json({ error: "missing_subscription_expiration" }, 409);
    }
    plan = mappedPlan;
    endDate = expiration;
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
  });
});
