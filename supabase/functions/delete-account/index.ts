// ============================================================================
// delete-account — v1.0.73
//
// Fully removes a user's account + data per Apple App Store and Google
// Play Store account-deletion requirements.
//
// Order of operations (all under the service_role key):
//   1. Verify the caller owns the JWT they're presenting.
//   2. Delete every row that references user_id / auth.uid() in the
//      user-owned tables: place_checkins, place_photos (only those the
//      user uploaded), place_chat, saved_places, saved_tours,
//      gamification_stats (remote cache), achievement_progress (local
//      cache), place_chat_reactions (if present).
//   3. Delete the row from `auth.users` via the admin API. This
//      automatically cascades any FKs that point at auth.users.
//   4. Return a JSON summary so the client can show "we deleted
//      12 photos, 47 reviews, ...".
//
// Auth: caller must present a Bearer access token issued for THEIR
// OWN user. The function deletes only that user's data.
//
// To deploy:
//   supabase functions deploy delete-account --no-verify-jwt --project-ref tbivoxyxclwjjspwsgvc
// ============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error(
    "delete-account: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY env vars missing",
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

function bearer(req: Request): string | null {
  const auth = req.headers.get("authorization") ?? "";
  const m = auth.match(/^Bearer\s+(.+)$/i);
  return m ? m[1] : null;
}

async function resolveUserId(token: string): Promise<string | null> {
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data?.user?.id) return null;
  return data.user.id;
}

async function deleteFrom(
  table: string,
  column: string,
  userId: string,
): Promise<number> {
  const { data, error } = await admin
    .from(table)
    .delete({ count: "exact" })
    .eq(column, userId)
    .select("id");
  if (error) {
    console.error(`delete-account: ${table} delete failed:`, error);
    return 0;
  }
  return Array.isArray(data) ? data.length : 0;
}

serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const token = bearer(req);
  if (!token) return json({ error: "missing_bearer" }, 401);

  const userId = await resolveUserId(token);
  if (!userId) return json({ error: "invalid_token" }, 401);

  // 1) drop every row that references the user
  const counts: Record<string, number> = {};
  counts.place_checkins = await deleteFrom("place_checkins", "user_id", userId);
  counts.place_photos = await deleteFrom("place_photos", "user_id", userId);
  counts.place_chat = await deleteFrom("place_chat", "user_id", userId);
  counts.saved_places = await deleteFrom("saved_places", "user_id", userId);
  counts.saved_tours = await deleteFrom("saved_tours", "user_id", userId);
  counts.gamification_stats =
    await deleteFrom("gamification_stats", "user_id", userId);
  counts.ai_quota = await deleteFrom("ai_quota", "user_id", userId);

  // 2) delete the auth.users row (cascades any FKs that point at it)
  const { error: delUserErr } = await admin.auth.admin.deleteUser(userId);
  if (delUserErr) {
    console.error("delete-account: auth.admin.deleteUser failed:", delUserErr);
    return json(
      {
        error: "delete_user_failed",
        message: delUserErr.message,
        counts,
      },
      500,
    );
  }

  return json({
    ok: true,
    user_id: userId,
    deleted_at: new Date().toISOString(),
    counts,
  });
});