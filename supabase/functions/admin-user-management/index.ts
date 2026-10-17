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

function warnMissingTable(table: string, error: {
  code?: string;
  message?: string;
  details?: string;
  hint?: string;
}): void {
  console.warn(
    `admin-user-management: skipping cleanup for missing table public.${table}:`,
    error,
  );
}

async function deleteRows(table: string, column: string, userId: string) {
  const { error } = await admin.from(table).delete().eq(column, userId);
  if (error) {
    if (isMissingTableError(error)) {
      warnMissingTable(table, error);
      return;
    }
    throw new Error(`Could not clean ${table} for user ${userId}: ${error.message}`);
  }
}

const PHOTO_BUCKET = "place-images";
const SUGGESTION_BUCKET = "suggestions";
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const LIST_PAGE_SIZE = 100;
const REMOVE_BATCH_SIZE = 100;

// Storage path behind one of this project's public bucket URLs, else null.
function storagePathFromPublicUrl(
  imageUrl: string,
  bucket: string,
): string | null {
  let uri: URL;
  let supabaseHost: string;
  try {
    uri = new URL(imageUrl);
    supabaseHost = new URL(SUPABASE_URL).host;
  } catch {
    return null;
  }
  if (uri.host !== supabaseHost) return null;
  const marker = `/storage/v1/object/public/${bucket}/`;
  if (!uri.pathname.startsWith(marker)) return null;
  try {
    return decodeURIComponent(uri.pathname.slice(marker.length));
  } catch {
    return null;
  }
}

// True only for a path strictly inside `folder`, with no empty, "." or ".."
// segments.
function isInsideFolder(path: string, folder: string): boolean {
  const prefix = `${folder}/`;
  if (!path.startsWith(prefix)) return false;
  return path
    .slice(prefix.length)
    .split("/")
    .every((segment) => segment !== "" && segment !== "." && segment !== "..");
}

// Every object under `folder`, following sub-folders and paging through
// each listing. Storage reports a sub-folder as an entry without an id.
async function listObjects(bucket: string, folder: string): Promise<string[]> {
  const files: string[] = [];
  const pending = [folder];
  while (pending.length) {
    const current = pending.pop() as string;
    for (let offset = 0;; offset += LIST_PAGE_SIZE) {
      const { data, error } = await admin.storage.from(bucket).list(current, {
        limit: LIST_PAGE_SIZE,
        offset,
        sortBy: { column: "name", order: "asc" },
      });
      if (error) {
        if (/bucket not found/i.test(error.message)) return files;
        throw new Error(`Could not list ${bucket}/${current}: ${error.message}`);
      }
      for (const entry of data ?? []) {
        const path = `${current}/${entry.name}`;
        if (entry.id === null) pending.push(path);
        else files.push(path);
      }
      if ((data ?? []).length < LIST_PAGE_SIZE) break;
    }
  }
  return files;
}

async function removeObjects(
  bucket: string,
  folder: string,
  paths: string[],
): Promise<void> {
  // Last line of defense: nothing outside the user's own folder is ever
  // handed to storage.remove.
  if (!paths.every((path) => isInsideFolder(path, folder))) {
    throw new Error(`Refusing to remove files outside ${bucket}/${folder}`);
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

// Removes the user's files from both buckets: everything under
// `place-images/user-photos/<userId>/` (plus anything their place_photos rows
// point at inside that folder) and everything under `suggestions/<userId>/`.
// Paths outside those two folders are never removed, whatever a row says.
async function removeUserStorage(
  userId: string,
  photoUrls: string[],
): Promise<void> {
  if (!UUID_PATTERN.test(userId)) {
    throw new Error("Refusing storage cleanup for a non-UUID user id");
  }

  const photoFolder = `user-photos/${userId}`;
  const photoPaths = new Set<string>();
  for (const url of photoUrls) {
    const path = storagePathFromPublicUrl(url, PHOTO_BUCKET);
    if (path !== null && isInsideFolder(path, photoFolder)) {
      photoPaths.add(path);
    }
  }
  for (const path of await listObjects(PHOTO_BUCKET, photoFolder)) {
    photoPaths.add(path);
  }
  await removeObjects(PHOTO_BUCKET, photoFolder, [...photoPaths]);

  // An approved suggestion's image URL is copied into public.places, so its
  // file is part of the published place and has to stay.
  const { data: approved, error: approvedError } = await admin
    .from("suggested_places")
    .select("image_url")
    .eq("user_id", userId)
    .eq("status", "approved");
  if (approvedError && !isMissingTableError(approvedError)) {
    throw new Error(
      `Could not load approved suggestions: ${approvedError.message}`,
    );
  }
  if (approvedError) warnMissingTable("suggested_places", approvedError);
  const published = new Set(
    (approved ?? []).map((row) =>
      storagePathFromPublicUrl(row.image_url ?? "", SUGGESTION_BUCKET)
    ),
  );
  const suggestionPaths = (await listObjects(SUGGESTION_BUCKET, userId))
    .filter((path) => !published.has(path));
  await removeObjects(SUGGESTION_BUCKET, userId, suggestionPaths);
}

async function removeUserData(userId: string) {
  const { data: photos, error: photosError } = await admin
    .from("place_photos")
    .select("image_url")
    .eq("user_id", userId);
  if (photosError && !isMissingTableError(photosError)) {
    throw new Error(`Could not load user photos: ${photosError.message}`);
  }
  if (photosError) warnMissingTable("place_photos", photosError);

  await removeUserStorage(
    userId,
    (photos ?? []).map((photo) => photo.image_url ?? ""),
  );

  for (const [table, column] of [
    ["place_photos", "user_id"],
    ["place_chat", "user_id"],
    ["place_checkins", "user_id"],
    ["saved_places", "user_id"],
    ["saved_tours", "user_id"],
    ["leaderboard", "user_id"],
    ["ai_quota", "user_id"],
    ["ai_chat_logs", "user_id"],
    ["suggested_places", "user_id"],
    ["squad_members", "user_id"],
    ["friendships", "requester_id"],
    ["friendships", "recipient_id"],
    ["friend_privacy_settings", "user_id"],
    ["friend_privacy_settings", "friend_id"],
    ["photo_reports", "reporter_id"],
    ["photo_reports", "uploader_id"],
    ["reports", "reporter_id"],
    ["user_follows", "follower_id"],
    ["user_follows", "following_id"],
    ["blocked_users", "blocker_id"],
    ["blocked_users", "blocked_user_id"],
  ]) {
    await deleteRows(table, column, userId);
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
      plan !== "annual" &&
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
      : plan === "annual"
      ? new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString()
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
