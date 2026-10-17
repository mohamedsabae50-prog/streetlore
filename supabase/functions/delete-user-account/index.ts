import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
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

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const REMOVE_BATCH_SIZE = 100;

function isMissingTableError(error: {
  code?: string;
  message?: string;
  details?: string;
  hint?: string;
}): boolean {
  return error.code === "42P01" ||
    error.code === "PGRST205" ||
    /could not find the table/i.test(
      `${error.message ?? ""} ${error.details ?? ""} ${error.hint ?? ""}`,
    );
}

async function removeObjects(
  bucket: string,
  paths: string[],
): Promise<void> {
  if (
    !paths.every((path) =>
      path.split("/").every((segment) =>
        segment !== "" && segment !== "." && segment !== ".."
      )
    )
  ) {
    throw new Error(`Refusing to remove an invalid path from ${bucket}`);
  }
  for (let i = 0; i < paths.length; i += REMOVE_BATCH_SIZE) {
    const { error } = await admin.storage
      .from(bucket)
      .remove(paths.slice(i, i + REMOVE_BATCH_SIZE));
    if (error) {
      throw new Error(`Could not remove files from ${bucket}: ${error.message}`);
    }
  }
}

async function removeUserStorage(
  userId: string,
  token: string,
): Promise<void> {
  if (!UUID_PATTERN.test(userId)) {
    throw new Error("Refusing storage cleanup for a non-UUID user id");
  }

  if (!SUPABASE_ANON_KEY) {
    throw new Error("SUPABASE_ANON_KEY is not configured.");
  }
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: ownedObjects, error: ownedObjectsError } = await userClient
    .rpc("get_my_storage_objects");
  if (ownedObjectsError) {
    throw new Error(
      `Could not enumerate owned Storage objects: ${ownedObjectsError.message}`,
    );
  }
  const pathsByBucket = new Map<string, Set<string>>();
  for (const object of ownedObjects ?? []) {
    if (
      typeof object.bucket_id !== "string" ||
      typeof object.name !== "string" ||
      !object.name ||
      object.name.split("/").some((segment: string) =>
        segment === "" || segment === "." || segment === ".."
      )
    ) {
      throw new Error("Storage ownership RPC returned an invalid object path.");
    }
    const paths = pathsByBucket.get(object.bucket_id) ?? new Set<string>();
    paths.add(object.name);
    pathsByBucket.set(object.bucket_id, paths);
  }
  for (const [bucket, paths] of pathsByBucket) {
    await removeObjects(bucket, [...paths]);
  }
}

async function deleteUserRows(userId: string, token: string): Promise<void> {
  await removeUserStorage(userId, token);

  const userDataRows = [
    { table: "place_photos", column: "user_id" },
    { table: "place_chat", column: "user_id" },
    { table: "place_checkins", column: "user_id" },
    { table: "saved_places", column: "user_id" },
    { table: "saved_tours", column: "user_id" },
    { table: "leaderboard", column: "user_id" },
    { table: "ai_quota", column: "user_id" },
    { table: "ai_chat_logs", column: "user_id" },
    { table: "suggested_places", column: "user_id" },
    { table: "squad_members", column: "user_id" },
    { table: "friendships", column: "requester_id" },
    { table: "friendships", column: "recipient_id" },
    { table: "friend_privacy_settings", column: "user_id" },
    { table: "friend_privacy_settings", column: "friend_id" },
    { table: "photo_reports", column: "reporter_id" },
    { table: "photo_reports", column: "uploader_id" },
    { table: "reports", column: "reporter_id" },
    { table: "user_follows", column: "follower_id" },
    { table: "user_follows", column: "following_id" },
    { table: "blocked_users", column: "blocker_id" },
    { table: "blocked_users", column: "blocked_user_id" },
  ];
  for (const { table, column } of userDataRows) {
    const { error } = await admin.from(table).delete().eq(column, userId);
    if (error) {
      if (isMissingTableError(error)) {
        console.warn(
          `delete-user-account: skipping cleanup for missing table public.${table}:`,
          error,
        );
        continue;
      }
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
    await deleteUserRows(data.user.id, token);
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
