-- ============================================================================
-- Migration: admin UPDATE on places (drag-and-drop display_order fix)
-- Purpose: v1.0.65 — Admin Panel drag-and-drop was silently failing
-- because the Supabase client uses the anon key (no service_role on client),
-- and the existing places RLS policies only allow public SELECT — UPDATE was
-- silently rejected (Postgrest returns 0 rows affected without throwing).
--
-- This adds UPDATE/DELETE policies on places for authenticated users whose
-- JWT email claim matches the admin email. The mobile anon client still
-- has no UPDATE rights (good — only the signed-in admin can reorder /
-- edit / delete places).
--
-- IMPORTANT: edit the email literal below to match the admin Supabase
-- account before running, OR replace it with a more permissive role check
-- (e.g. auth.jwt() ->> 'role' = 'service_role').
--
-- Run this once in Supabase SQL editor:
--   https://supabase.com/dashboard/project/tbivoxyxclwjjspwsgvc/sql/new
-- ============================================================================

DROP POLICY IF EXISTS "admin can update places" ON public.places;
DROP POLICY IF EXISTS "admin can delete places" ON public.places;

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

-- Sanity check: list the new policies.
SELECT polname, polcmd
  FROM pg_policy
 WHERE polrelid = 'public.places'::regclass
 ORDER BY polcmd, polname;