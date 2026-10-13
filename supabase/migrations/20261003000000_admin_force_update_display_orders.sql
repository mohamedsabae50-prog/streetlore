-- ============================================================================
-- Migration: force_update_display_orders() — SECURITY DEFINER RPC (v1.0.68)
--
-- v1.0.67 assumed `places.id` was a UUID column. It is NOT — older rows
-- use short text/integer ids like '10' (Abu Abbas al-Mursi) or '11'
-- (Alexandria National Museum). The RPC crashed on `invalid input syntax
-- for type uuid: "11"`. This rewrite accepts text[] end-to-end and casts
-- only at the boundary, with the same admin-email gate + atomic UPDATE
-- semantics as v1.0.67.
--
-- Adjust the email literal below to match the admin Supabase account
-- before running.
--
-- Run this once in Supabase SQL editor:
--   https://supabase.com/dashboard/project/tbivoxyxclwjjspwsgvc/sql/new
-- ============================================================================

DROP FUNCTION IF EXISTS public.force_update_display_orders(uuid[], int[]);
DROP FUNCTION IF EXISTS public.force_update_display_orders(text[], int[]);

CREATE OR REPLACE FUNCTION public.force_update_display_orders(
  p_place_ids text[],
  p_new_orders int[]
)
RETURNS TABLE (updated_id text, updated_order int)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller_email text;
  v_expected_count int;
  v_actual_count int;
  v_missing_ids text[];
BEGIN
  -- ----------------------------------------------------------------
  -- 1) Strict admin auth gate. RAISE EXCEPTION is a hard error that
  --    surfaces to PostgREST as a 4xx — the Flutter client cannot
  --    mistake it for success.
  -- ----------------------------------------------------------------
  v_caller_email := lower(coalesce(auth.jwt() ->> 'email', ''));
  IF v_caller_email <> lower('mohamedsabae50@gmail.com') THEN
    RAISE EXCEPTION 'Unauthorized: admin email mismatch (got "%")',
      v_caller_email
      USING ERRCODE = '42501';  -- insufficient_privilege
  END IF;

  -- ----------------------------------------------------------------
  -- 2) Argument validation. Same length, no empties.
  -- ----------------------------------------------------------------
  v_expected_count := array_length(p_place_ids, 1);
  IF v_expected_count IS NULL OR v_expected_count = 0 THEN
    RAISE EXCEPTION 'force_update_display_orders: place_ids is empty'
      USING ERRCODE = '22023';
  END IF;
  IF v_expected_count <> array_length(p_new_orders, 1) THEN
    RAISE EXCEPTION
      'force_update_display_orders: array length mismatch (ids=%, orders=%)',
      v_expected_count, array_length(p_new_orders, 1)
      USING ERRCODE = '22023';
  END IF;

  -- ----------------------------------------------------------------
  -- 3) Atomic update via UPDATE ... FROM (unnest(arr1, arr2)).
  --    Runs as the function owner so RLS is bypassed.
  -- ----------------------------------------------------------------
  WITH input AS (
    SELECT id_value, new_order
      FROM unnest(p_place_ids, p_new_orders)
        AS u(id_value, new_order)
  ),
  upd AS (
    UPDATE public.places p
       SET display_order = input.new_order
      FROM input
     WHERE p.id = input.id_value
    RETURNING p.id, p.display_order
  )
  SELECT count(*) INTO v_actual_count FROM upd;

  IF v_actual_count <> v_expected_count THEN
    SELECT array_agg(p_place_ids[i])
      INTO v_missing_ids
      FROM generate_subscripts(p_place_ids, 1) AS i
     WHERE NOT EXISTS (
       SELECT 1 FROM upd WHERE upd.id = p_place_ids[i]
     );
    RAISE EXCEPTION
      'force_update_display_orders: only % of % rows were updated (missing ids: %)',
      v_actual_count, v_expected_count, v_missing_ids
      USING ERRCODE = 'P0002';
  END IF;

  -- ----------------------------------------------------------------
  -- 4) Return the rows we just wrote so the client can verify
  --    the atomic outcome in one round-trip.
  -- ----------------------------------------------------------------
  RETURN QUERY
    SELECT p.id, p.display_order
      FROM public.places p
     WHERE p.id = ANY(p_place_ids)
     ORDER BY array_position(p_place_ids, p.id);
END;
$$;

REVOKE ALL ON FUNCTION public.force_update_display_orders(text[], int[])
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.force_update_display_orders(text[], int[])
  TO authenticated;

SELECT
  proname,
  prosecdef AS is_security_definer,
  pg_get_function_arguments(oid) AS args
  FROM pg_proc
 WHERE proname = 'force_update_display_orders'
   AND pronamespace = 'public'::regnamespace;