import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ADMIN_EMAILS = new Set([
  "mohamedsabae50@gmail.com",
  "hackty65@gmail.com",
]);

function isProtectedAdmin(email: string | undefined): boolean {
  return ADMIN_EMAILS.has((email ?? "").toLowerCase().trim());
}

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
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
    },
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
  if (isProtectedAdmin(data.user.email)) {
    return data.user;
  }

  const { data: adminRecord, error: adminError } = await admin
    .from("admin_users")
    .select("user_id")
    .eq("user_id", data.user.id)
    .maybeSingle();
  if (adminError) throw adminError;
  if (adminRecord) return data.user;

  const { data: profile, error: profileError } = await admin
    .from("profiles")
    .select("is_admin")
    .eq("user_id", data.user.id)
    .maybeSingle();
  if (profileError) throw profileError;
  if (profile?.is_admin === true) return data.user;

  return null;
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
      .filter((user) => !isProtectedAdmin(user.email))
      .map((user) => ({
        id: user.id,
        email: user.email ?? "",
        name: displayName(user),
        created_at: user.created_at,
      }));
    return { users: await includeProStatus(users), has_more: data.users.length === perPage };
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
      if (isProtectedAdmin(user.email)) continue;
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
    users: await includeProStatus(matches.slice(start, start + perPage)),
    has_more: matches.length > start + perPage,
  };
}

async function includeProStatus<T extends { id: string }>(users: T[]) {
  if (!users.length) return users;
  const { data, error } = await admin
    .from("profiles")
    .select("user_id, is_pro, subscription_tier, subscription_end_date")
    .in("user_id", users.map((user) => user.id));
  if (error) throw error;
  const statuses = new Map(
    (data ?? []).map((profile) => [
      profile.user_id,
      {
        is_pro: profile.is_pro === true,
        subscription_tier: profile.subscription_tier,
        subscription_end_date: profile.subscription_end_date,
      },
    ]),
  );
  return users.map((user) => ({
    ...user,
    ...(statuses.get(user.id) ?? {
      is_pro: false,
      subscription_tier: null,
      subscription_end_date: null,
    }),
  }));
}

async function listChatLogs(page: number, perPage: number) {
  type ChatLog = {
    id: string;
    user_id: string;
    session_id: string | null;
    user_prompt: string;
    ai_response: string;
    created_at: string;
  };
  type ChatThread = {
    id: string;
    user_id: string;
    session_id: string | null;
    created_at: string;
    last_message_at: string;
    messages: ChatLog[];
  };

  const logs: ChatLog[] = [];
  const batchSize = 1000;
  for (let from = 0; ; from += batchSize) {
    const { data, error } = await admin
      .from("ai_chat_logs")
      .select("id, user_id, session_id, user_prompt, ai_response, created_at")
      .order("created_at", { ascending: true })
      .range(from, from + batchSize - 1);
    if (error) throw error;
    logs.push(...(data ?? []) as ChatLog[]);
    if (!data || data.length < batchSize) break;
  }

  const threads: ChatThread[] = [];
  const sessionThreads = new Map<string, ChatThread>();
  const previousLegacyThread = new Map<
    string,
    { thread: ChatThread; lastMessageTime: number }
  >();
  const legacySessionGapMs = 30 * 60 * 1000;

  for (const log of logs) {
    const timestamp = new Date(log.created_at).getTime();
    let thread: ChatThread | undefined;
    if (log.session_id) {
      const sessionKey = `${log.user_id}:${log.session_id}`;
      thread = sessionThreads.get(sessionKey);
      if (!thread) {
        thread = {
          id: `session:${log.session_id}`,
          user_id: log.user_id,
          session_id: log.session_id,
          created_at: log.created_at,
          last_message_at: log.created_at,
          messages: [],
        };
        sessionThreads.set(sessionKey, thread);
        threads.push(thread);
      }
    } else {
      const previous = previousLegacyThread.get(log.user_id);
      if (
        previous &&
        timestamp - previous.lastMessageTime <= legacySessionGapMs
      ) {
        thread = previous.thread;
      } else {
        thread = {
          id: `legacy:${log.id}`,
          user_id: log.user_id,
          session_id: null,
          created_at: log.created_at,
          last_message_at: log.created_at,
          messages: [],
        };
        threads.push(thread);
      }
      previousLegacyThread.set(log.user_id, {
        thread,
        lastMessageTime: timestamp,
      });
    }
    thread.messages.push(log);
    thread.last_message_at = log.created_at;
  }

  threads.sort(
    (left, right) =>
      new Date(right.last_message_at).getTime() -
      new Date(left.last_message_at).getTime(),
  );
  const from = (page - 1) * perPage;
  const pageThreads = threads.slice(from, from + perPage);
  const pageLogs = pageThreads.flatMap((thread) =>
    thread.messages.map((log) => ({
      ...log,
      id: String(log.id),
      user_id: String(log.user_id),
      session_id: log.session_id == null ? null : String(log.session_id),
      user_prompt: String(log.user_prompt ?? ""),
      ai_response: String(log.ai_response ?? ""),
      created_at: new Date(log.created_at).toISOString(),
    }))
  );
  return {
    threads: pageThreads,
    logs: pageLogs,
    items: pageLogs,
    has_more: threads.length > from + perPage,
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
  let caller: Awaited<ReturnType<typeof requireAdmin>>;
  try {
    caller = await requireAdmin(token);
  } catch (error) {
    console.error("admin-user-management: admin verification failed:", error);
    return json({ error: "admin_verification_failed" }, 500);
  }
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

  if (body.action === "chat_logs") {
    const requestedPage = Number(body.page);
    const page = Number.isInteger(requestedPage) && requestedPage > 0
      ? requestedPage
      : 1;
    const requestedPerPage = Number(body.per_page);
    const perPage = Number.isInteger(requestedPerPage)
      ? Math.min(Math.max(requestedPerPage, 1), 100)
      : 50;
    try {
      return json(await listChatLogs(page, perPage));
    } catch (error) {
      console.error("admin-user-management: list chat logs failed:", error);
      return json({ error: "list_chat_logs_failed" }, 500);
    }
  }

  if (body.action === "set_plan" || body.action === "set_pro") {
    const userId = typeof body.user_id === "string" ? body.user_id.trim() : "";
    if (!userId) return json({ error: "user_id_required" }, 400);
    if (userId === caller.id) {
      return json({ error: "cannot_change_own_admin_account" }, 400);
    }
    const { data: target, error: targetError } =
      await admin.auth.admin.getUserById(userId);
    if (targetError || !target.user) {
      return json({ error: "user_not_found" }, 404);
    }
    if (isProtectedAdmin(target.user.email)) {
      return json({ error: "cannot_change_admin_account" }, 400);
    }

    const plan = body.action === "set_pro"
      ? (body.is_pro === true ? "monthly" : "free")
      : body.plan;
    if (
      plan !== "weekly" &&
      plan !== "monthly" &&
      plan !== "lifetime" &&
      plan !== "free"
    ) {
      return json({ error: "invalid_plan" }, 400);
    }

    const isPro = plan !== "free";
    const endDate = plan === "weekly"
      ? new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString()
      : plan === "monthly"
      ? new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString()
      : null;
    const { error } = await admin.from("profiles").upsert({
      user_id: userId,
      is_pro: isPro,
      subscription_tier: plan,
      subscription_end_date: endDate,
      updated_at: new Date().toISOString(),
    }, { onConflict: "user_id" });
    if (error) {
      console.error("admin-user-management: update subscription plan failed:", error);
      return json({ error: "update_subscription_plan_failed" }, 500);
    }
    return json({
      ok: true,
      user_id: userId,
      is_pro: isPro,
      subscription_tier: plan,
      subscription_end_date: endDate,
    });
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
    if (isProtectedAdmin(target.user.email)) {
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
