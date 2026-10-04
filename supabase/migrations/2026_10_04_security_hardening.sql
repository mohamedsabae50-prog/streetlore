-- ============================================================================
-- Migration: 2026_10_04_security_hardening.sql
-- Purpose: PR #2 from the security audit — lock down places + place_photos
-- so ONLY the admin account (mohamedsabae50@gmail.com) can INSERT, UPDATE,
-- or DELETE rows. Public/anon keep full SELECT.
--
-- Background: the existing RLS policies on `places` and `place_photos`
-- are owner-scoped (user_id = auth.uid() for photos; INSERT/UPDATE/DELETE
-- on places allowed for any authenticated user). Any signed-in mobile
-- user could in principle modify the catalog. This migration:
--   1. DROPS every non-admin write policy on places + place_photos.
--   2. CREATES admin-only INSERT/UPDATE/DELETE policies, gated on
--      auth.jwt()->>'email' matching the admin email.
--   3. RECREATES the public SELECT policy so the mobile anon client
--      can still read everything.
--
-- IMPORTANT: edit the email literal to match the admin Supabase account
-- before running. Also confirm your `places` and `place_photos` tables
-- actually have RLS enabled (`ALTER TABLE ... ENABLE ROW LEVEL SECURITY;`)
-- — this migration only manages policies, not the enable flag.
--
-- Run this once in Supabase SQL editor:
--   https://supabase.com/dashboard/project/tbivoxyxclwjjspwsgvc/sql/new
-- ============================================================================

-- =====================================================================
-- 1) PLACES
-- =====================================================================

-- Drop the old owner/admin policies so we don't end up with duplicates.
DROP POLICY IF EXISTS "Public read places"         ON public.places;
DROP POLICY IF EXISTS "admin can update places"     ON public.places;
DROP POLICY IF EXISTS "admin can delete places"     ON public.places;
DROP POLICY IF EXISTS "Authenticated can update"    ON public.places;
DROP POLICY IF EXISTS "Authenticated can insert"    ON public.places;
DROP POLICY IF EXISTS "Authenticated can delete"    ON public.places;

-- Public SELECT — anon + authenticated can read every row.
CREATE POLICY "Public read places"
  ON public.places
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- Admin-only INSERT.
CREATE POLICY "admin can insert places"
  ON public.places
  FOR INSERT
  TO authenticated
  WITH CHECK (
    lower(coalesce(auth.jwt() ->> 'email', '')) =
      lower('mohamedsabae50@gmail.com')
  );

-- Admin-only UPDATE.
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

-- Admin-only DELETE.
CREATE POLICY "admin can delete places"
  ON public.places
  FOR DELETE
  TO authenticated
  USING (
    lower(coalesce(auth.jwt() ->> 'email', '')) =
      lower('mohamedsabae50@gmail.com')
  );

-- =====================================================================
-- 2) PLACE_PHOTOS (user uploads + admin-managed catalog photos)
-- =====================================================================

-- Drop any old policies.
DROP POLICY IF EXISTS "Public read place_photos"      ON public.place_photos;
DROP POLICY IF EXISTS "Owner read place_photos"        ON public.place_photos;
DROP POLICY IF EXISTS "Owner insert place_photos"     ON public.place_photos;
DROP POLICY IF EXISTS "Owner update place_photos"     ON public.place_photos;
DROP POLICY IF EXISTS "Owner delete place_photos"     ON public.place_photos;
DROP POLICY IF EXISTS "admin can select place_photos"  ON public.place_photos;
DROP POLICY IF EXISTS "admin can delete place_photos"  ON public.place_photos;

-- Public SELECT — anon + authenticated can read every photo.
CREATE POLICY "Public read place_photos"
  ON public.place_photos
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- Owner INSERT — the signed-in user can attach their own photos. user_id
-- must match auth.uid().
CREATE POLICY "Owner insert place_photos"
  ON public.place_photos
  FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id::text = auth.uid()::text
  );

-- Owner can update their OWN rows only.
CREATE POLICY "Owner update own place_photos"
  ON public.place_photos
  FOR UPDATE
  TO authenticated
  USING (user_id::text = auth.uid()::text)
  WITH CHECK (user_id::text = auth.uid()::text);

-- Owner can delete their OWN rows.
CREATE POLICY "Owner delete own place_photos"
  ON public.place_photos
  FOR DELETE
  TO authenticated
  USING (user_id::text = auth.uid()::text);

-- Admin overrides on every operation (for moderation).
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
-- 3) PLACE_CHAT — public read, owner write, admin moderation.
-- =====================================================================

DROP POLICY IF EXISTS "Public read place_chat"       ON public.place_chat;
DROP POLICY IF EXISTS "Owner insert place_chat"     ON public.place_chat;
DROP POLICY IF EXISTS "Owner update own place_chat"  ON public.place_chat;
DROP POLICY IF EXISTS "Owner delete own place_chat"  ON public.place_chat;
DROP POLICY IF EXISTS "admin can select place_chat"  ON public.place_chat;
DROP POLICY IF EXISTS "admin can delete place_chat"  ON public.place_chat;

CREATE POLICY "Public read place_chat"
  ON public.place_chat
  FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "Owner insert place_chat"
  ON public.place_chat
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id::text = auth.uid()::text);

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
-- Sanity check: list every policy now in place.
-- =====================================================================
SELECT
  c.relname AS table_name,
  p.polname AS policy_name,
  p.polcmd AS command,
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
ORDER BY c.relname, p.polcmd, p.polname;