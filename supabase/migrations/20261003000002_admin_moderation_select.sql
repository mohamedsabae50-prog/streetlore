-- ============================================================================
-- Migration: admin SELECT on place_photos + place_chat
-- Purpose: v1.0.70 — the Admin Panel Moderation section was always
-- returning 0 rows for both Chat messages and User photos even when the
-- mobile app could see them. The Flutter queries
--   .from('place_photos').select().eq('place_id', placeId)
--   .from('place_chat').select().eq('place_id', placeId)
-- were correct (place_id is text in both tables), so the issue was
-- RLS: the existing SELECT policies are owner-scoped ("user_id =
-- auth.uid()"), and the admin is signed in with a different account.
-- Without an admin-scoped SELECT policy the rows exist in the table
-- but are invisible to the admin's anon client.
--
-- This adds SELECT policies on both tables gated on the admin's JWT
-- email claim, matching the pattern we already use for the DELETE
-- policies added in v1.0.64.
--
-- Adjust the email literal below to match the admin Supabase account
-- before running.
--
-- Run this once in Supabase SQL editor:
--   https://supabase.com/dashboard/project/tbivoxyxclwjjspwsgvc/sql/new
-- ============================================================================

DROP POLICY IF EXISTS "admin can select place_photos" ON public.place_photos;
DROP POLICY IF EXISTS "admin can select place_chat"  ON public.place_chat;

CREATE POLICY "admin can select place_photos"
  ON public.place_photos
  FOR SELECT
  TO authenticated
  USING (
    lower(coalesce(auth.jwt() ->> 'email', '')) =
      lower('mohamedsabae50@gmail.com')
  );

CREATE POLICY "admin can select place_chat"
  ON public.place_chat
  FOR SELECT
  TO authenticated
  USING (
    lower(coalesce(auth.jwt() ->> 'email', '')) =
      lower('mohamedsabae50@gmail.com')
  );

-- Sanity-check the new policies.
SELECT polname, polcmd
  FROM pg_policy
 WHERE polrelid IN ('public.place_photos'::regclass, 'public.place_chat'::regclass)
   AND polcmd = 'r'
 ORDER BY polrelid::text, polname;