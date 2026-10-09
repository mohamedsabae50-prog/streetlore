import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ADMIN_EMAIL = (Deno.env.get("ADMIN_EMAIL") ??
  "mohamedsabae50@gmail.com").toLowerCase().trim();

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error(
    "admin-user-management: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY missing",
  );
}

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
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function bearer(req: Request): string | null {
  const auth = req.headers.get("authorization") ?? "";
  const match = auth.match(/^Bearer\s+(.+)$/i);
  return match ? match[1] : null;
}

function displayName(user: {
  email?: string;
  id: string;
  user_metadata?: Record<string, unknown>;
}): string {
  const metadata = user.user_metadata ?? {};
  for (const key of ["name", "full_name", "display_name", "username"]) {
    const value = metadata[key];
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  return user.email?.split("@")[0] || "Unnamed user";
}

async function requireAdmin(token: string) {
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) return null;
  if ((data.user.email ?? "").toLowerCase().trim() !== ADMIN_EMAIL) return null;
  return data.user;
}

async function listUsers(query: string, page: number, perPage: number) {
  const normalizedQuery = query.trim().toLowerCase();
  if (!normalizedQuery) {
    const { data, error } = await admin.auth.admin.listUsers({
      page,
      perPage,
    });
    if (error) throw error;
    const users = data.users
      .filter((user) => (user.email ?? "").toLowerCase() !== ADMIN_EMAIL)
      .map((user) => ({
        id: user.id,
        email: user.email ?? "",
        name: displayName(user),
        created_at: user.created_at,
      }));
    return { users, has_more: data.users.length === perPage };
  }

  const matches: Array<{
    id: string;
    email: string;
    name: string;
    created_at: string;
  }> = [];
  const batchSize = 1000;
  for (let currentPage = 1; ; currentPage++) {
    const { data, error } = await admin.auth.admin.listUsers({
      page: currentPage,
      perPage: batchSize,
    });
    if (error) throw error;
    for (const user of data.users) {
      if ((user.email ?? "").toLowerCase() === ADMIN_EMAIL) continue;
      const name = displayName(user);
      const email = user.email ?? "";
      if (
        name.toLowerCase().includes(normalizedQuery) ||
        email.toLowerCase().includes(normalizedQuery)
      ) {
        matches.push({
          id: user.id,
          email,
          name,
          created_at: user.created_at,
        });
      }
    }
    if (data.users.length < batchSize) break;
  }

  const start = (page - 1) * perPage;
  return {
    users: matches.slice(start, start + perPage),
    has_more: matches.length > start + perPage,
  };
}

async function deleteRows(table: string, column: string, userId: string) {
  const { error } = await admin.from(table).delete().eq(column, userId);
  if (error) {
    throw new Error(`Could not clean ${table} for user ${userId}: ${error.message}`);
  }
}

function storagePathFromPublicUrl(imageUrl: string): string | null {
  let uri: URL;
  try {
    uri = new URL(imageUrl);
  } catch {
    return null;
  }
  let supabaseHost: string;
  try {
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
  return path ? decodeURIComponent(path) : null;
}

async function removeUserData(userId: string) {
  const { data: photos, error: photosError } = await admin
    .from("place_photos")
    .select("image_url")
    .eq("user_id", userId);
  if (photosError) {
    throw new Error(`Could not load user photos: ${photosError.message}`);
  }

  const storagePaths = (photos ?? [])
    .map((photo) => storagePathFromPublicUrl(photo.image_url ?? ""))
    .filter((path): path is string => path !== null);
  if (storagePaths.length) {
    const { error } = await admin.storage
      .from("place-images")
      .remove(storagePaths);
    if (error) throw new Error(`Could not remove user photo files: ${error.message}`);
  }

  for (const table of [
    "place_photos",
    "place_chat",
    "place_checkins",
    "saved_places",
    "saved_tours",
    "leaderboard",
    "ai_quota",
  ]) {
    await deleteRows(table, "user_id", userId);
  }
}

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const token = bearer(req);
  if (!token) return json({ error: "missing_bearer" }, 401);
  const caller = await requireAdmin(token);
  if (!caller) return json({ error: "forbidden" }, 403);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  if (body.action === "list") {
    const query = typeof body.query === "string" ? body.query : "";
    const requestedPage = Number(body.page);
    const page = Number.isInteger(requestedPage) && requestedPage > 0
      ? requestedPage
      : 1;
    const requestedPerPage = Number(body.per_page);
    const perPage = Number.isInteger(requestedPerPage)
      ? Math.min(Math.max(requestedPerPage, 1), 100)
      : 50;
    try {
      return json(await listUsers(query, page, perPage));
    } catch (error) {
      console.error("admin-user-management: list users failed:", error);
      return json({ error: "list_users_failed" }, 500);
    }
  }

  if (body.action === "delete") {
    const userId = typeof body.user_id === "string" ? body.user_id.trim() : "";
    if (!userId) return json({ error: "user_id_required" }, 400);
    if (userId === caller.id) {
      return json({ error: "cannot_delete_own_admin_account" }, 400);
    }
    const { data: target, error: targetError } =
      await admin.auth.admin.getUserById(userId);
    if (targetError || !target.user) {
      return json({ error: "user_not_found" }, 404);
    }
    if ((target.user.email ?? "").toLowerCase().trim() === ADMIN_EMAIL) {
      return json({ error: "cannot_delete_admin_account" }, 400);
    }

    try {
      await removeUserData(userId);
      const { error } = await admin.auth.admin.deleteUser(userId);
      if (error) throw new Error(`Could not delete Auth user: ${error.message}`);
      return json({ ok: true, user_id: userId });
    } catch (error) {
      console.error("admin-user-management: delete user failed:", error);
      return json({
        error: "delete_user_failed",
        message: error instanceof Error ? error.message : "Unknown error",
      }, 500);
    }
  }

  return json({ error: "unknown_action" }, 400);
});
