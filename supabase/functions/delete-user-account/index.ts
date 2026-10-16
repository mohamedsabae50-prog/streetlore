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
  if (approvedError) {
    throw new Error(
      `Could not load approved suggestions: ${approvedError.message}`,
    );
  }
  const published = new Set(
    (approved ?? []).map((row) =>
      storagePathFromPublicUrl(row.image_url ?? "", SUGGESTION_BUCKET)
    ),
  );
  const suggestionPaths = (await listObjects(SUGGESTION_BUCKET, userId))
    .filter((path) => !published.has(path));
  await removeObjects(SUGGESTION_BUCKET, userId, suggestionPaths);
}

async function deleteUserRows(userId: string): Promise<void> {
  const { data: photos, error: photoError } = await admin
    .from("place_photos")
    .select("image_url")
    .eq("user_id", userId);
  if (photoError) {
    throw new Error(`Could not load uploaded photos: ${photoError.message}`);
  }

  await removeUserStorage(
    userId,
    (photos ?? []).map((photo) => photo.image_url ?? ""),
  );

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
