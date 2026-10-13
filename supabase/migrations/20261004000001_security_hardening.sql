-- ============================================================================
-- Migration: 2026_10_04_security_hardening.sql
-- Purpose: PR #2 from the security audit — lock down places + place_photos
-- so ONLY the admin account (mohamedsabae50@gmail.com) can INSERT, UPDATE,
-- or DELETE on places; and users can only modify their OWN rows on
-- place_photos / place_chat (admins can moderate anything).
--
-- v1.0.72 fix: the `place_photos` table was missing the `user_id` column
-- entirely, so the RLS policy `user_id::text = auth.uid()::text` would
-- have thrown ERROR 42703 at policy creation. This migration first adds
-- the column (nullable for backfill), then drops the old policies, then
-- recreates them with admin gates.
--
-- IMPORTANT: edit the email literal to match the admin Supabase account
-- before running.
--
-- Run this once in Supabase SQL editor:
--   https://supabase.com/dashboard/project/tbivoxyxclwjjspwsgvc/sql/new
-- ============================================================================

-- =====================================================================
-- 0) Schema bootstrap — add the user_id columns the RLS policies need.
-- =====================================================================
ALTER TABLE public.place_photos
  ADD COLUMN IF NOT EXISTS user_id text;

ALTER TABLE public.place_chat
  ADD COLUMN IF NOT EXISTS user_id text;

-- Helpful indexes (RLS USING clauses hit these for every SELECT).
CREATE INDEX IF NOT EXISTS idx_place_photos_user_id   ON public.place_photos(user_id);
CREATE INDEX IF NOT EXISTS idx_place_chat_user_id    ON public.place_chat(user_id);

-- =====================================================================
-- 1) PLACES
-- =====================================================================
DROP POLICY IF EXISTS "Public read places"          ON public.places;
DROP POLICY IF EXISTS "admin can update places"      ON public.places;
DROP POLICY IF EXISTS "admin can delete places"      ON public.places;
DROP POLICY IF EXISTS "admin can insert places"      ON public.places;
DROP POLICY IF EXISTS "Authenticated can update"     ON public.places;
DROP POLICY IF EXISTS "Authenticated can insert"     ON public.places;
DROP POLICY IF EXISTS "Authenticated can delete"     ON public.places;

CREATE POLICY "Public read places"
  ON public.places
  FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "admin can insert places"
  ON public.places
  FOR INSERT
  TO authenticated
  WITH CHECK (
    lower(coalesce(auth.jwt() ->> 'email', '')) =
      lower('mohamedsabae50@gmail.com')
  );

CREATE POLICY "admin can update places"
  ON public.places
  FOR UPDATE
  TO authenticated
  USING (
    lower(coalesce(auth.jwt() ->> 'email', '')) =
      lower('mohamedsabae50@gmail.com')
  )
  WITH CHECK (
    lower(coalesce(auth.jwt() ->> 'email', '')) =
      lower('mohamedsabae50@gmail.com')
  );

CREATE POLICY "admin can delete places"
  ON public.places
  FOR DELETE
  TO authenticated
  USING (
    lower(coalesce(auth.jwt() ->> 'email', '')) =
      lower('mohamedsabae50@gmail.com')
  );

-- =====================================================================
-- 2) PLACE_PHOTOS
-- =====================================================================
DROP POLICY IF EXISTS "Public read place_photos"     ON public.place_photos;
DROP POLICY IF EXISTS "Owner read place_photos"       ON public.place_photos;
DROP POLICY IF EXISTS "Owner insert place_photos"    ON public.place_photos;
DROP POLICY IF EXISTS "Owner update place_photos"    ON public.place_photos;
DROP POLICY IF EXISTS "Owner delete place_photos"    ON public.place_photos;
DROP POLICY IF EXISTS "admin can select place_photos" ON public.place_photos;
DROP POLICY IF EXISTS "admin can update place_photos" ON public.place_photos;
DROP POLICY IF EXISTS "admin can delete place_photos" ON public.place_photos;

-- Public SELECT
CREATE POLICY "Public read place_photos"
  ON public.place_photos
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- Owner INSERT — user_id is captured at upload time. NULL user_id is
-- rejected so every photo has an accountable owner (admins can still
-- upload via the admin override below).
CREATE POLICY "Owner insert place_photos"
  ON public.place_photos
  FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id IS NOT NULL
    AND user_id::text = auth.uid()::text
  );

-- Owner UPDATE — only the uploader can edit their own rows.
CREATE POLICY "Owner update own place_photos"
  ON public.place_photos
  FOR UPDATE
  TO authenticated
  USING (user_id::text = auth.uid()::text)
  WITH CHECK (user_id::text = auth.uid()::text);

-- Owner DELETE — uploader can delete their own rows.
CREATE POLICY "Owner delete own place_photos"
  ON public.place_photos
  FOR DELETE
  TO authenticated
  USING (user_id::text = auth.uid()::text);

-- Admin overrides (moderation): insert/update/delete on ANY row.
CREATE POLICY "admin can insert place_photos"
  ON public.place_photos
  FOR INSERT
  TO authenticated
  WITH CHECK (
    lower(coalesce(auth.jwt() ->> 'email', '')) =
      lower('mohamedsabae50@gmail.com')
  );

CREATE POLICY "admin can update place_photos"
  ON public.place_photos
  FOR UPDATE
  TO authenticated
  USING (
    lower(coalesce(auth.jwt() ->> 'email', '')) =
      lower('mohamedsabae50@gmail.com')
  )
  WITH CHECK (
    lower(coalesce(auth.jwt() ->> 'email', '')) =
      lower('mohamedsabae50@gmail.com')
  );

CREATE POLICY "admin can delete place_photos"
  ON public.place_photos
  FOR DELETE
  TO authenticated
  USING (
    lower(coalesce(auth.jwt() ->> 'email', '')) =
      lower('mohamedsabae50@gmail.com')
  );

-- =====================================================================
-- 3) PLACE_CHAT
-- =====================================================================
DROP POLICY IF EXISTS "Public read place_chat"      ON public.place_chat;
DROP POLICY IF EXISTS "Owner insert place_chat"    ON public.place_chat;
DROP POLICY IF EXISTS "Owner delete own place_chat" ON public.place_chat;
DROP POLICY IF EXISTS "admin can delete place_chat" ON public.place_chat;
DROP POLICY IF EXISTS "admin can select place_chat" ON public.place_chat;

CREATE POLICY "Public read place_chat"
  ON public.place_chat
  FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Owner insert place_chat"
  ON public.place_chat
  FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id IS NOT NULL
    AND user_id::text = auth.uid()::text
  );

CREATE POLICY "Owner delete own place_chat"
  ON public.place_chat
  FOR DELETE
  TO authenticated
  USING (user_id::text = auth.uid()::text);

CREATE POLICY "admin can delete place_chat"
  ON public.place_chat
  FOR DELETE
  TO authenticated
  USING (
    lower(coalesce(auth.jwt() ->> 'email', '')) =
      lower('mohamedsabae50@gmail.com')
  );

-- =====================================================================
-- Sanity check
-- =====================================================================
SELECT
  c.relname AS table_name,
  p.polname AS policy_name,
  CASE p.polcmd
    WHEN 'r' THEN 'SELECT'
    WHEN 'a' THEN 'INSERT'
    WHEN 'w' THEN 'UPDATE'
    WHEN 'd' THEN 'DELETE'
    WHEN '*' THEN 'ALL'
    ELSE p.polcmd::text
  END AS verb,
  pg_get_userbyid(p.polroles[0])::text AS role
FROM pg_policy p
JOIN pg_class c ON c.oid = p.polrelid
WHERE c.relname IN ('places', 'place_photos', 'place_chat')
  AND c.relnamespace = 'public'::regnamespace
ORDER BY c.relname, verb, p.polname;