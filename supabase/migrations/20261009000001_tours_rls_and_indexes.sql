-- ============================================================================
-- Migration: 2026_10_09_tours_rls_and_indexes.sql
-- Purpose: Tighten RLS on tours + tour_places (admin-only write) and add
--          the missing performance indexes.
-- ============================================================================

-- =====================================================================
-- 1) RLS — tours + tour_places (admin-only write, public read)
-- =====================================================================

DROP POLICY IF EXISTS "auth write tours"       ON public.tours;
DROP POLICY IF EXISTS "auth write tour_places" ON public.tour_places;

-- Replace the loose `auth.role() = 'authenticated'` policies that let
-- ANY signed-in user INSERT/UPDATE/DELETE tours + tour_places.

CREATE POLICY "admin can insert tours"
  ON public.tours
  FOR INSERT
  TO authenticated
  WITH CHECK (
    lower(coalesce(auth.jwt() ->> 'email', '')) =
      lower('mohamedsabae50@gmail.com')
  );

CREATE POLICY "admin can update tours"
  ON public.tours
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

CREATE POLICY "admin can delete tours"
  ON public.tours
  FOR DELETE
  TO authenticated
  USING (
    lower(coalesce(auth.jwt() ->> 'email', '')) =
      lower('mohamedsabae50@gmail.com')
  );

CREATE POLICY "admin can insert tour_places"
  ON public.tour_places
  FOR INSERT
  TO authenticated
  WITH CHECK (
    lower(coalesce(auth.jwt() ->> 'email', '')) =
      lower('mohamedsabae50@gmail.com')
  );

CREATE POLICY "admin can update tour_places"
  ON public.tour_places
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

CREATE POLICY "admin can delete tour_places"
  ON public.tour_places
  FOR DELETE
  TO authenticated
  USING (
    lower(coalesce(auth.jwt() ->> 'email', '')) =
      lower('mohamedsabae50@gmail.com')
  );

-- Public SELECT stays as-is (already correct in supabase_setup.sql).

-- =====================================================================
-- 2) Indexes — performance fixes
-- =====================================================================

-- Reverse lookup: "which tours include this place?"
-- (used by FK navigation + any future 'places-with-tours' query)
CREATE INDEX IF NOT EXISTS idx_tour_places_place_id
  ON public.tour_places(place_id);

-- Composite covering index for the tours_with_places view
-- (WHERE tp.tour_id = t.id ORDER BY tp.position)
CREATE INDEX IF NOT EXISTS idx_tour_places_tour_position
  ON public.tour_places(tour_id, position);

-- Filter tours by category (frequently shown as a filter chip in the UI)
CREATE INDEX IF NOT EXISTS idx_tours_category
  ON public.tours(category)
  WHERE category IS NOT NULL;

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
  END AS verb
FROM pg_policy p
JOIN pg_class c ON c.oid = p.polrelid
WHERE c.relname IN ('tours', 'tour_places')
  AND c.relnamespace = 'public'::regnamespace
ORDER BY c.relname, verb, p.polname;

SELECT indexname, tablename
  FROM pg_indexes
 WHERE schemaname = 'public'
   AND tablename IN ('tours', 'tour_places')
   AND indexname IN (
     'idx_tour_places_place_id',
     'idx_tour_places_tour_position',
     'idx_tours_category'
   )
ORDER BY tablename, indexname;
