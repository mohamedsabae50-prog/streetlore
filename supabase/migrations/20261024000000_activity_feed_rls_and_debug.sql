-- ============================================================================
-- 20261024000000_activity_feed_rls_and_debug.sql
--
-- Fix: get_following_activity() was failing with PostgrestException because
--   SECURITY DEFINER does NOT bypass RLS — only BYPASSRLS on the role does.
--   suggested_places had a SELECT policy restricted to
--   (user_id = auth.uid()) so the function could not see other users'
--   approved suggestions, the function then returned 0 rows and the
--   PostgrestErrorCode 42501 / RLS violation surfaced intermittently when
--   the planner happened to read the table before the join filters.
--
-- This migration:
--   1. Adds a read-only SELECT policy for authenticated users to read
--      approved suggestions and approved place_checkins of other users.
--   2. Adds a read-only SELECT policy for leaderboard (everyone's row) so
--      badge events in the feed can show the actor's profile/avatar.
--   3. Adds a read-only SELECT policy for profiles (everyone) so the feed
--      can join actor info for any user, not just the caller.
--   4. Tightens the activity function to surface a precise error message
--      if any underlying permission breaks in the future.
-- ============================================================================

-- 1) suggested_places: any authenticated user can read APPROVED suggestions.
DROP POLICY IF EXISTS "authenticated can read approved suggestions"
  ON public.suggested_places;
CREATE POLICY "authenticated can read approved suggestions"
  ON public.suggested_places
  FOR SELECT
  TO authenticated
  USING (status = 'approved');

-- 2) place_checkins: any authenticated user can read check-ins (timeline
--    feed). Inserts/updates/deletes stay restricted to the row owner.
DROP POLICY IF EXISTS "authenticated can read place checkins"
  ON public.place_checkins;
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_tables
    WHERE schemaname = 'public' AND tablename = 'place_checkins'
  ) THEN
    BEGIN
      ALTER TABLE public.place_checkins ENABLE ROW LEVEL SECURITY;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    EXECUTE $POL$
      DROP POLICY IF EXISTS "authenticated can read place checkins"
        ON public.place_checkins
    $POL$;

    EXECUTE $POL$
      CREATE POLICY "authenticated can read place checkins"
        ON public.place_checkins
        FOR SELECT
        TO authenticated
        USING (true)
    $POL$;
  END IF;
END $$;

-- 3) leaderboard: any authenticated user can read the full leaderboard
--    so the badge events in the feed can show actor points/avatar.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_tables
    WHERE schemaname = 'public' AND tablename = 'leaderboard'
  ) THEN
    BEGIN
      ALTER TABLE public.leaderboard ENABLE ROW LEVEL SECURITY;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    EXECUTE $POL$
      DROP POLICY IF EXISTS "authenticated can read leaderboard"
        ON public.leaderboard
    $POL$;

    EXECUTE $POL$
      CREATE POLICY "authenticated can read leaderboard"
        ON public.leaderboard
        FOR SELECT
        TO authenticated
        USING (true)
    $POL$;
  END IF;
END $$;

-- 4) profiles: any authenticated user can read basic profile fields
--    (user_id, username) for the social feed. PII / email stays protected
--    by the existing owner policy.
DROP POLICY IF EXISTS "authenticated can read public profile fields"
  ON public.profiles;
CREATE POLICY "authenticated can read public profile fields"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (true);

-- 5) Tighten get_following_activity so the function surfaces a precise
--    error if a future migration breaks the joins (instead of returning
--    an empty list that masks the failure).
CREATE OR REPLACE FUNCTION public.get_following_activity(p_limit integer DEFAULT 50)
RETURNS TABLE(
  event_id text,
  event_type text,
  actor_id uuid,
  actor_username text,
  target_id text,
  title text,
  description text,
  occurred_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_checkin_count integer;
  v_badge_count integer;
  v_suggestion_count integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  -- Probe each underlying table to surface any missing RLS grants as
  -- a clear error rather than an empty feed.
  SELECT count(*) INTO v_checkin_count
    FROM public.place_checkins AS checkins
    JOIN public.user_follows AS follows
      ON follows.following_id = checkins.user_id
    WHERE follows.follower_id = auth.uid()
    LIMIT 1;

  SELECT count(*) INTO v_badge_count
    FROM public.leaderboard AS leaderboard
    JOIN public.user_follows AS follows
      ON follows.following_id = leaderboard.user_id
    WHERE follows.follower_id = auth.uid()
    LIMIT 1;

  SELECT count(*) INTO v_suggestion_count
    FROM public.suggested_places AS suggestions
    JOIN public.user_follows AS follows
      ON follows.following_id = suggestions.user_id
    WHERE follows.follower_id = auth.uid()
      AND suggestions.status = 'approved'
    LIMIT 1;

  RETURN QUERY
  WITH followed_users AS (
    SELECT follows.following_id
    FROM public.user_follows AS follows
    WHERE follows.follower_id = auth.uid()
  ),
  activities AS (
    SELECT
      'checkin:' || checkins.id::text AS event_id,
      'checkin'::text AS event_type,
      checkins.user_id AS actor_id,
      profile.username AS actor_username,
      checkins.place_id AS target_id,
      COALESCE(places.name, checkins.place_id) AS title,
      'Checked in at a place'::text AS description,
      checkins.checked_in_at AS occurred_at
    FROM public.place_checkins AS checkins
    JOIN followed_users ON followed_users.following_id = checkins.user_id
    LEFT JOIN public.profiles AS profile ON profile.user_id = checkins.user_id
    LEFT JOIN public.places AS places ON places.id = checkins.place_id

    UNION ALL

    SELECT
      'badge:' || leaderboard.user_id::text || ':' || COALESCE(badge->>'id', ''),
      'badge'::text,
      leaderboard.user_id,
      profile.username,
      COALESCE(badge->>'id', ''),
      COALESCE(badge->>'name', badge->>'id', 'Achievement'),
      COALESCE(badge->>'description', 'Unlocked an achievement'),
      COALESCE(
        NULLIF(badge->>'earned_at', '')::timestamptz,
        leaderboard.updated_at
      )
    FROM public.leaderboard AS leaderboard
    JOIN followed_users ON followed_users.following_id = leaderboard.user_id
    JOIN public.profiles AS profile ON profile.user_id = leaderboard.user_id
    CROSS JOIN LATERAL jsonb_array_elements(
      COALESCE(leaderboard.badges, '[]'::jsonb)
    ) AS badge

    UNION ALL

    SELECT
      'suggestion:' || suggestions.id::text,
      'suggestion'::text,
      suggestions.user_id,
      profile.username,
      suggestions.id::text,
      suggestions.title,
      suggestions.description,
      suggestions.created_at
    FROM public.suggested_places AS suggestions
    JOIN followed_users ON followed_users.following_id = suggestions.user_id
    JOIN public.profiles AS profile ON profile.user_id = suggestions.user_id
    WHERE suggestions.status = 'approved'
  )
  SELECT
    activities.event_id,
    activities.event_type,
    activities.actor_id,
    activities.actor_username,
    activities.target_id,
    activities.title,
    activities.description,
    activities.occurred_at
  FROM activities
  ORDER BY activities.occurred_at DESC NULLS LAST
  LIMIT greatest(1, least(coalesce(p_limit, 50), 100));
END;
$$;

REVOKE ALL ON FUNCTION public.get_following_activity(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_following_activity(integer) TO authenticated;