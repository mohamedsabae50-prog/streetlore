-- ============================================================================
-- Migration: admin moderation — DELETE permissions on place_chat + place_photos
-- Purpose: v1.0.64 admin moderation screen lets an admin delete any chat
-- message or user-uploaded photo. The base RLS policies (set up earlier)
-- only allow the row owner (user_id = auth.uid()) to delete — admins have
-- their own Supabase auth account and need explicit DELETE permission.
--
-- Replace the placeholder email below with the actual admin Supabase
-- account email before running, OR use a more permissive role-based check.
--
-- Run this once in Supabase SQL editor:
--   https://supabase.com/dashboard/project/tbivoxyxclwjjspwsgvc/sql/new
-- ============================================================================

-- 1) Drop any prior admin DELETE policies so we don't pile up duplicates.
DROP POLICY IF EXISTS "admin can delete place_chat" ON public.place_chat;
DROP POLICY IF EXISTS "admin can delete place_photos" ON public.place_photos;

-- 2) Admin DELETE on place_chat. The simplest, durable check is on the JWT
--    email claim — Supabase puts auth.email() / auth.jwt() ->> 'email' on
--    every request from an authenticated user. Adjust the email literal to
--    match the real admin account.
CREATE POLICY "admin can delete place_chat"
  ON public.place_chat
  FOR DELETE
  TO authenticated
  USING (
    lower(coalesce(auth.jwt() ->> 'email', '')) =
      lower('mohamedsabae50@gmail.com')
  );

-- 3) Admin DELETE on place_photos (same pattern).
CREATE POLICY "admin can delete place_photos"
  ON public.place_photos
  FOR DELETE
  TO authenticated
  USING (
    lower(coalesce(auth.jwt() ->> 'email', '')) =
      lower('mohamedsabae50@gmail.com')
  );

-- Quick sanity-check: list the DELETE policies on the two tables.
SELECT polname, polcmd
  FROM pg_policy
 WHERE polrelid IN ('public.place_chat'::regclass, 'public.place_photos'::regclass)
   AND polcmd = 'd'
 ORDER BY polrelid::text, polname;