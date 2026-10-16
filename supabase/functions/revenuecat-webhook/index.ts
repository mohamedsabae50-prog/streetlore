import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import {
  allowSandboxFromEnv,
  deriveProfileState,
  fetchSubscriber,
  parseProductTiers,
  type PaidTier,
  secretsMatch,
} from "../_shared/subscription.ts";

// Deploy with --no-verify-jwt and set REVENUECAT_WEBHOOK_SECRET in Supabase.
// Configure that exact secret as the RevenueCat webhook Authorization value.
//
// The event is only a trigger. For every Supabase user id it mentions, the
// current state is re-read from the RevenueCat REST API and written with the
// same rules as `sync-subscription`. That makes replayed, out-of-order or
// missed events harmless (the write is idempotent), revokes entitlements on
// TRANSFER / refunds / expirations, and keeps sandbox purchases out.
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const REVENUECAT_WEBHOOK_SECRET =
  Deno.env.get("REVENUECAT_WEBHOOK_SECRET") ?? "";
const REVENUECAT_SECRET_API_KEY =
  Deno.env.get("REVENUECAT_SECRET_API_KEY") ?? "";
const PRO_ENTITLEMENT_ID =
  Deno.env.get("REVENUECAT_PRO_ENTITLEMENT_ID") ?? "pro";
// Opt-in for the owner's own sandbox / Test Store testing. Default: reject.
const ALLOW_SANDBOX = allowSandboxFromEnv(
  Deno.env.get("REVENUECAT_ALLOW_SANDBOX"),
);

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error("revenuecat-webhook: Supabase service configuration is missing");
}
if (!REVENUECAT_WEBHOOK_SECRET) {
  console.error("revenuecat-webhook: REVENUECAT_WEBHOOK_SECRET is missing");
}
if (ALLOW_SANDBOX) {
  console.warn("revenuecat-webhook: REVENUECAT_ALLOW_SANDBOX is enabled");
}

const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

// Event types that can change what a user is entitled to.
const ENTITLEMENT_EVENTS = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "PRODUCT_CHANGE",
  "UNCANCELLATION",
  "NON_RENEWING_PURCHASE",
  "CANCELLATION", // includes refunds
  "EXPIRATION",
  "BILLING_ISSUE",
  "SUBSCRIPTION_PAUSED",
  "SUBSCRIPTION_EXTENDED",
  "REFUND_REVERSED",
  "TEMPORARY_ENTITLEMENT_GRANT",
  "TRANSFER",
]);
const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const MAX_USERS_PER_EVENT = 10;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function stringList(value: unknown): string[] {
  return Array.isArray(value)
    ? value.filter((item): item is string => typeof item === "string")
    : [];
}

serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }
  if (!REVENUECAT_WEBHOOK_SECRET) {
    return json({ error: "webhook_not_configured" }, 503);
  }
  if (
    !await secretsMatch(
      req.headers.get("authorization"),
      REVENUECAT_WEBHOOK_SECRET,
    )
  ) {
    return json({ error: "unauthorized" }, 401);
  }

  let payload: {
    event?: {
      type?: string;
      environment?: string;
      app_user_id?: string;
      original_app_user_id?: string;
      transferred_from?: string[];
      transferred_to?: string[];
    };
  };
  try {
    payload = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const event = payload.event;
  const eventType = event?.type;
  if (!event || !eventType) {
    return json({ error: "invalid_event" }, 400);
  }

  // Sandbox / Test Store events are acknowledged (200, so RevenueCat does not
  // retry) but never touch a profile. TRANSFER only sometimes carries the
  // field; sandbox purchases are filtered again when state is re-read below.
  const environment = typeof event.environment === "string"
    ? event.environment.toUpperCase()
    : null;
  if (
    !ALLOW_SANDBOX &&
    environment !== "PRODUCTION" &&
    !(eventType === "TRANSFER" && environment === null)
  ) {
    return json({ ok: true, ignored: true, reason: "non_production_event" });
  }
  if (!ENTITLEMENT_EVENTS.has(eventType)) {
    return json({ ok: true, ignored: true, reason: "unsupported_event_type" });
  }

  const mentioned = [
    event.app_user_id,
    event.original_app_user_id,
    ...(eventType === "TRANSFER"
      ? [...stringList(event.transferred_from), ...stringList(event.transferred_to)]
      : []),
  ].filter((id): id is string => typeof id === "string" && id.length > 0);
  if (!mentioned.length) {
    return json({ error: "invalid_event" }, 400);
  }
  // Anonymous RevenueCat ids ($RCAnonymousID:...) have no profile to update.
  const userIds = [...new Set(mentioned.filter((id) => UUID.test(id)))]
    .map((id) => id.toLowerCase())
    .slice(0, MAX_USERS_PER_EVENT);
  if (!userIds.length) {
    return json({ ok: true, ignored: true, reason: "no_supabase_user_id" });
  }

  if (!REVENUECAT_SECRET_API_KEY) {
    console.error("revenuecat-webhook: REVENUECAT_SECRET_API_KEY is missing");
    return json({ error: "webhook_not_configured" }, 503);
  }
  let tiers: Map<string, PaidTier>;
  try {
    tiers = parseProductTiers(
      Deno.env.get("REVENUECAT_PRODUCT_TIERS") ?? "",
    );
  } catch (error) {
    console.error("revenuecat-webhook: product tier map is invalid:", error);
    return json({ error: "subscription_tier_mapping_not_configured" }, 503);
  }

  // Every user is attempted even if one fails; a non-2xx response makes
  // RevenueCat retry the (idempotent) event.
  let failure: { status: number; error: string } | null = null;
  let synced = 0;
  for (const userId of userIds) {
    const lookup = await fetchSubscriber(userId, REVENUECAT_SECRET_API_KEY);
    if (!lookup.ok) {
      failure ??= lookup;
      continue;
    }
    const derived = deriveProfileState(lookup.subscriber, {
      tiers,
      entitlementId: PRO_ENTITLEMENT_ID,
      allowSandbox: ALLOW_SANDBOX,
    });
    if (!derived.ok) {
      console.error("revenuecat-webhook: cannot derive profile state:", {
        userId,
        error: derived.error,
      });
      failure ??= derived;
      continue;
    }
    if (derived.reason?.startsWith("non_production")) {
      console.warn("revenuecat-webhook: ignored non-production purchase:", {
        userId,
        reason: derived.reason,
      });
    }

    const { error } = await admin
      .from("profiles")
      .upsert({
        user_id: userId,
        ...derived.state,
        updated_at: new Date().toISOString(),
      }, { onConflict: "user_id" });
    if (error?.code === "23503") {
      // No such auth user (deleted account): nothing to sync, retrying won't help.
      console.warn("revenuecat-webhook: no auth user for app user id:", userId);
      continue;
    }
    if (error) {
      console.error("revenuecat-webhook: profile entitlement sync failed:", error);
      failure ??= { status: 500, error: "profile_sync_failed" };
      continue;
    }
    synced++;
  }
  if (failure) return json({ error: failure.error }, failure.status);
  return json({ ok: true, synced });
});
