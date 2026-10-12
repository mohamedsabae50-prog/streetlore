import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

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

function storagePathFromPublicUrl(imageUrl: string): string | null {
  let uri: URL;
  let supabaseHost: string;
  try {
    uri = new URL(imageUrl);
    supabaseHost = new URL(SUPABASE_URL).host;
  } catch {
    return null;
  }
  if (uri.host !== supabaseHost) return null;
  const segments = uri.pathname.split("/").filter(Boolean);
  const bucketIndex = segments.findIndex(
    (segment, index) =>
      segment === "public" && segments[index + 1] === "place-images",
  );
  if (bucketIndex < 0) return null;
  const path = segments.slice(bucketIndex + 2).join("/");
  try {
    return path ? decodeURIComponent(path) : null;
  } catch {
    return null;
  }
}

async function deleteUserRows(userId: string): Promise<void> {
  const { data: photos, error: photoError } = await admin
    .from("place_photos")
    .select("image_url")
    .eq("user_id", userId);
  if (photoError) {
    throw new Error(`Could not load uploaded photos: ${photoError.message}`);
  }

  const storagePaths = (photos ?? [])
    .map((photo) => storagePathFromPublicUrl(photo.image_url ?? ""))
    .filter((path): path is string => path !== null);
  if (storagePaths.length) {
    const { error } = await admin.storage
      .from("place-images")
      .remove(storagePaths);
    if (error) throw new Error(`Could not remove uploaded photos: ${error.message}`);
  }

  const userDataTables = [
    { table: "place_photos", column: "user_id" },
    { table: "place_chat", column: "user_id" },
    { table: "place_checkins", column: "user_id" },
    { table: "saved_places", column: "user_id" },
    { table: "saved_tours", column: "user_id" },
    { table: "leaderboard", column: "user_id" },
    { table: "ai_quota", column: "user_id" },
  ];
  for (const { table, column } of userDataTables) {
    const { error } = await admin.from(table).delete().eq(column, userId);
    if (error) {
      throw new Error(`Could not delete ${table}: ${error.message}`);
    }
  }
}

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const token = bearer(req);
  if (!token) return json({ error: "missing_bearer" }, 401);
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) return json({ error: "invalid_token" }, 401);

  try {
    await deleteUserRows(data.user.id);
  } catch (error) {
    console.error("delete-user-account: user data deletion failed:", error);
    return json({
      error: "user_data_deletion_failed",
      message: error instanceof Error ? error.message : "Unknown error",
    }, 500);
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(data.user.id);
  if (deleteError) {
    console.error("delete-user-account: Auth user deletion failed:", deleteError);
    return json({
      error: "auth_user_deletion_failed",
      message: deleteError.message,
    }, 500);
  }

  return json({ ok: true });
});
