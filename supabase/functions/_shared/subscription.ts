// Shared RevenueCat -> profiles logic for `sync-subscription` and
// `revenuecat-webhook`. Pure helpers only: nothing here reads the environment
// or talks to Supabase at import time, so both functions derive a user's
// entitlement through exactly the same rules.
//
// RevenueCat REST v1 subscriber object (field names):
//   https://www.revenuecat.com/docs/api-v1/customer-info-model
//   subscriber.entitlements[id]   { expires_date, grace_period_expires_date,
//                                   product_identifier, purchase_date }
//   subscriber.subscriptions[productId]      { is_sandbox, store, expires_date, ... }
//   subscriber.non_subscriptions[productId]  [ { id, is_sandbox, store, purchase_date } ]
// Entitlements carry no sandbox flag themselves, so the purchase that backs the
// entitlement is looked up by product identifier.
// Webhook payload (environment: SANDBOX | PRODUCTION, store incl. TEST_STORE):
//   https://www.revenuecat.com/docs/integrations/webhooks/event-types-and-fields

export const PAID_TIERS = ["weekly", "monthly", "annual", "lifetime"] as const;
export type PaidTier = typeof PAID_TIERS[number];

export interface ProfileState {
  is_pro: boolean;
  subscription_tier: PaidTier | "free";
  subscription_end_date: string | null;
}

interface PurchaseRecord {
  is_sandbox?: boolean;
  store?: string;
}

export interface Subscriber {
  entitlements?: Record<string, {
    expires_date?: string | null;
    product_identifier?: string;
  }>;
  subscriptions?: Record<string, PurchaseRecord>;
  non_subscriptions?: Record<string, PurchaseRecord[]>;
}

export type Derivation =
  | { ok: true; state: ProfileState; reason?: string }
  | { ok: false; status: number; error: string };

const FREE: ProfileState = {
  is_pro: false,
  subscription_tier: "free",
  subscription_end_date: null,
};

export function parseProductTiers(raw: string): Map<string, PaidTier> {
  let value: unknown;
  try {
    value = JSON.parse(raw);
  } catch {
    throw new Error("REVENUECAT_PRODUCT_TIERS must be a JSON object");
  }
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("REVENUECAT_PRODUCT_TIERS must be a JSON object");
  }
  const tiers = new Map<string, PaidTier>();
  for (const [productId, tier] of Object.entries(value)) {
    if (!(PAID_TIERS as readonly unknown[]).includes(tier)) {
      throw new Error(
        `Invalid tier configured for RevenueCat product ${productId}`,
      );
    }
    tiers.set(productId, tier as PaidTier);
  }
  if (!tiers.size) throw new Error("REVENUECAT_PRODUCT_TIERS is empty");
  return tiers;
}

/** Opt-in switch for the owner's own sandbox / Test Store testing. Default off. */
export function allowSandboxFromEnv(raw: string | undefined): boolean {
  return (raw ?? "").trim().toLowerCase() === "true";
}

function isSandboxRecord(record: PurchaseRecord): boolean {
  return record.is_sandbox !== false ||
    String(record.store ?? "").toLowerCase() === "test_store";
}

/**
 * "production" only when RevenueCat reports a real, non-sandbox, non-Test-Store
 * purchase for the product. Missing data fails closed ("unknown").
 */
export function purchaseOrigin(
  subscriber: Subscriber,
  productId: string,
): "production" | "sandbox" | "unknown" {
  const records: PurchaseRecord[] = [];
  const subscription = subscriber.subscriptions?.[productId];
  if (subscription && typeof subscription === "object") {
    records.push(subscription);
  }
  const nonSubscriptions = subscriber.non_subscriptions?.[productId];
  if (Array.isArray(nonSubscriptions)) {
    for (const record of nonSubscriptions) {
      if (record && typeof record === "object") records.push(record);
    }
  }
  if (!records.length) return "unknown";
  return records.some((record) => !isSandboxRecord(record))
    ? "production"
    : "sandbox";
}

export function deriveProfileState(
  subscriber: Subscriber | undefined,
  options: {
    tiers: Map<string, PaidTier>;
    entitlementId: string;
    allowSandbox: boolean;
    now?: number;
  },
): Derivation {
  const now = options.now ?? Date.now();
  const entitlement = subscriber?.entitlements?.[options.entitlementId];
  if (entitlement === undefined || entitlement === null) {
    return { ok: true, state: FREE };
  }

  const expiration = entitlement.expires_date ?? null;
  if (expiration !== null && !Number.isFinite(Date.parse(expiration))) {
    return { ok: false, status: 502, error: "invalid_revenuecat_expiration" };
  }
  if (expiration !== null && Date.parse(expiration) <= now) {
    return { ok: true, state: FREE, reason: "expired" };
  }

  const productId = entitlement.product_identifier;
  if (!options.allowSandbox) {
    const origin = productId ? purchaseOrigin(subscriber!, productId) : "unknown";
    if (origin !== "production") {
      return { ok: true, state: FREE, reason: `non_production_${origin}` };
    }
  }

  const tier = productId ? options.tiers.get(productId) : undefined;
  if (!productId || !tier) {
    return { ok: false, status: 409, error: "unmapped_revenuecat_product" };
  }
  if (tier === "lifetime" && expiration !== null) {
    return { ok: false, status: 409, error: "invalid_lifetime_expiration" };
  }
  if (tier !== "lifetime" && expiration === null) {
    return { ok: false, status: 409, error: "missing_subscription_expiration" };
  }
  return {
    ok: true,
    state: {
      is_pro: true,
      subscription_tier: tier,
      subscription_end_date: expiration === null
        ? null
        : new Date(expiration).toISOString(),
    },
  };
}

export type SubscriberLookup =
  | { ok: true; subscriber: Subscriber }
  | { ok: false; status: number; error: string };

export async function fetchSubscriber(
  appUserId: string,
  secretApiKey: string,
): Promise<SubscriberLookup> {
  let response: Response;
  try {
    response = await globalThis.fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}`,
      {
        headers: {
          Authorization: `Bearer ${secretApiKey}`,
          Accept: "application/json",
        },
        signal: AbortSignal.timeout(8000),
      },
    );
  } catch (error) {
    console.error("subscription: RevenueCat request failed:", error);
    return { ok: false, status: 502, error: "revenuecat_unavailable" };
  }
  if (!response.ok) {
    console.error(`subscription: RevenueCat returned HTTP ${response.status}`);
    return { ok: false, status: 502, error: "revenuecat_lookup_failed" };
  }
  try {
    const payload = await response.json();
    const subscriber = payload?.subscriber;
    if (!subscriber || typeof subscriber !== "object") {
      throw new Error("missing subscriber object");
    }
    return { ok: true, subscriber };
  } catch (error) {
    console.error("subscription: invalid RevenueCat response:", error);
    return { ok: false, status: 502, error: "invalid_revenuecat_response" };
  }
}

/**
 * Constant-time secret comparison. Both sides are hashed first so the compare
 * time depends neither on the content nor on the length of the supplied value.
 */
export async function secretsMatch(
  provided: string | null,
  expected: string,
): Promise<boolean> {
  if (provided === null || !expected) return false;
  const encoder = new TextEncoder();
  const [a, b] = await Promise.all([
    crypto.subtle.digest("SHA-256", encoder.encode(provided)),
    crypto.subtle.digest("SHA-256", encoder.encode(expected)),
  ]);
  const left = new Uint8Array(a);
  const right = new Uint8Array(b);
  let diff = 0;
  for (let i = 0; i < left.length; i++) diff |= left[i] ^ right[i];
  return diff === 0;
}

/**
 * Best-effort in-memory sliding-window limiter (per function instance; no
 * table). Returns 0 when the call is allowed, otherwise the seconds to wait.
 */
export function createRateLimiter(maxCalls: number, windowMs: number) {
  const calls = new Map<string, number[]>();
  return (key: string, now = Date.now()): number => {
    const recent = (calls.get(key) ?? []).filter((t) => now - t < windowMs);
    if (recent.length >= maxCalls) {
      calls.set(key, recent);
      return Math.max(1, Math.ceil((recent[0] + windowMs - now) / 1000));
    }
    recent.push(now);
    calls.set(key, recent);
    if (calls.size > 5000) {
      for (const [k, v] of calls) {
        if (v.every((t) => now - t >= windowMs)) calls.delete(k);
      }
    }
    return 0;
  };
}
