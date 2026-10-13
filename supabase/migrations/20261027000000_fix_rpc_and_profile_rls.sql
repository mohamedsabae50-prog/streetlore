-- ============================================================================
-- 20261027000000_fix_rpc_and_profile_rls.sql
--
-- 1) get_city_leaderboard  -> 42804 "Returned type text does not match
--    expected type uuid in column 1".
--    The remote `leaderboard.user_id` / `place_checkins.user_id` columns are
--    TEXT (tables were created from the dashboard, not from migrations), so
--    any uuid-typed output column can mismatch. We DROP the function and
--    recreate it with `user_id text` and an explicit cast on EVERY output
--    column, and compare ids as text (no CAST(... AS uuid), which would also
--    throw 22P02 on legacy non-uuid ids such as guest ids).
--
-- 2) get_following_activity -> same root cause: `actor_id uuid` was fed from
--    TEXT columns (42804) and joins like `user_follows.following_id (uuid) =
--    place_checkins.user_id (text)` raise 42883 (operator does not exist).
--    Recreated with `actor_id text` and text-normalised joins. The old
--    "probe" SELECTs (which used the same broken joins) are removed.
--    Columns that may not exist on the remote (`id`, `updated_at`) are read
--    through to_jsonb(row) so a missing column can never raise 42703.
--
-- 3) profiles: username save.
--    * set_my_username now UPSERTS the profile row (previously raised
--      'Profile not found' when the signup trigger had not created it).
--    * Column-scoped INSERT/UPDATE privileges + own-row RLS policies so an
--      authenticated user can write ONLY user_id/username/updated_at on
--      their OWN row. is_pro / subscription_tier remain server-only.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) LEADERBOARD
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_city_leaderboard(text, text, integer);

CREATE FUNCTION public.get_city_leaderboard(
  p_period text DEFAULT 'week',
  p_metric text DEFAULT 'check_ins',
  p_limit integer DEFAULT 50
)
RETURNS TABLE (
  user_id text,
  user_name text,
  avatar_color_hex text,
  total_points integer,
  places_visited integer,
  reviews_posted integer,
  photos_uploaded integer,
  level text,
  badges jsonb,
  current_streak integer,
  longest_streak integer,
  total_visit_days integer,
  last_visit_date timestamptz,
  check_ins bigint,
  hidden_gems bigint,
  score bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_since timestamptz;
BEGIN
  IF p_period NOT IN ('week', 'month', 'all_time') THEN
    RAISE EXCEPTION 'Unsupported leaderboard period';
  END IF;
  IF p_metric NOT IN ('check_ins', 'longest_streak', 'hidden_gems') THEN
    RAISE EXCEPTION 'Unsupported leaderboard metric';
  END IF;

  v_since := CASE p_period
    WHEN 'week' THEN
      date_trunc('week', statement_timestamp() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC'
    WHEN 'month' THEN
      date_trunc('month', statement_timestamp() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC'
    ELSE NULL
  END;

  RETURN QUERY
  WITH checkin_rollup AS (
    SELECT
      checkins.user_id::text AS uid,
      count(*) FILTER (
        WHERE v_since IS NULL OR checkins.checked_in_at >= v_since
      ) AS check_ins,
      count(DISTINCT checkins.place_id::text) FILTER (
        WHERE places.is_hidden_gem IS TRUE
          AND (v_since IS NULL OR checkins.checked_in_at >= v_since)
      ) AS hidden_gems
    FROM public.place_checkins AS checkins
    LEFT JOIN public.places AS places
      ON places.id::text = checkins.place_id::text
    GROUP BY checkins.user_id::text
  ),
  ranked AS (
    SELECT
      lb.user_id::text                                   AS uid,
      lb.user_name::text                                 AS user_name,
      lb.avatar_color_hex::text                          AS avatar_color_hex,
      coalesce(lb.total_points, 0)::integer              AS total_points,
      coalesce(lb.places_visited, 0)::integer            AS places_visited,
      coalesce(lb.reviews_posted, 0)::integer            AS reviews_posted,
      coalesce(lb.photos_uploaded, 0)::integer           AS photos_uploaded,
      lb.level::text                                     AS level,
      coalesce(lb.badges::jsonb, '[]'::jsonb)            AS badges,
      coalesce(lb.current_streak, 0)::integer            AS current_streak,
      coalesce(lb.longest_streak, 0)::integer            AS longest_streak,
      coalesce(lb.total_visit_days, 0)::integer          AS total_visit_days,
      lb.last_visit_date::timestamptz                    AS last_visit_date,
      coalesce(cr.check_ins, 0)::bigint                  AS check_ins,
      coalesce(cr.hidden_gems, 0)::bigint                AS hidden_gems,
      (CASE p_metric
        WHEN 'check_ins'      THEN coalesce(cr.check_ins, 0)
        WHEN 'longest_streak' THEN coalesce(lb.longest_streak, 0)
        WHEN 'hidden_gems'    THEN coalesce(cr.hidden_gems, 0)
      END)::bigint                                       AS score
    FROM public.leaderboard AS lb
    LEFT JOIN checkin_rollup AS cr
      ON cr.uid = lb.user_id::text
  )
  SELECT
    ranked.uid::text,
    ranked.user_name::text,
    ranked.avatar_color_hex::text,
    ranked.total_points::integer,
    ranked.places_visited::integer,
    ranked.reviews_posted::integer,
    ranked.photos_uploaded::integer,
    ranked.level::text,
    ranked.badges::jsonb,
    ranked.current_streak::integer,
    ranked.longest_streak::integer,
    ranked.total_visit_days::integer,
    ranked.last_visit_date::timestamptz,
    ranked.check_ins::bigint,
    ranked.hidden_gems::bigint,
    ranked.score::bigint
  FROM ranked
  ORDER BY ranked.score DESC, ranked.total_points DESC, ranked.user_name
  LIMIT greatest(1, least(coalesce(p_limit, 50), 100));
END;
$$;

REVOKE ALL ON FUNCTION public.get_city_leaderboard(text, text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_city_leaderboard(text, text, integer)
  TO anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2) ACTIVITY FEED
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_following_activity(integer);

CREATE FUNCTION public.get_following_activity(p_limit integer DEFAULT 50)
RETURNS TABLE(
  event_id text,
  event_type text,
  actor_id text,
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
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH followed_users AS (
    SELECT follows.following_id::text AS uid
    FROM public.user_follows AS follows
    WHERE follows.follower_id::text = auth.uid()::text
  ),
  activities AS (
    SELECT
      ('checkin:' || coalesce(
        to_jsonb(checkins)->>'id',
        md5(checkins.user_id::text || ':' || checkins.place_id::text || ':' ||
            coalesce(checkins.checked_in_at::text, ''))
      ))::text                                            AS event_id,
      'checkin'::text                                     AS event_type,
      checkins.user_id::text                              AS actor_id,
      profile.username::text                              AS actor_username,
      checkins.place_id::text                             AS target_id,
      coalesce(places.name::text, checkins.place_id::text) AS title,
      'Checked in at a place'::text                       AS description,
      checkins.checked_in_at::timestamptz                 AS occurred_at
    FROM public.place_checkins AS checkins
    JOIN followed_users ON followed_users.uid = checkins.user_id::text
    LEFT JOIN public.profiles AS profile ON profile.user_id::text = checkins.user_id::text
    LEFT JOIN public.places   AS places  ON places.id::text = checkins.place_id::text

    UNION ALL

    SELECT
      ('badge:' || lb.user_id::text || ':' || coalesce(badge->>'id', ''))::text,
      'badge'::text,
      lb.user_id::text,
      profile.username::text,
      coalesce(badge->>'id', '')::text,
      coalesce(badge->>'name', badge->>'id', 'Achievement')::text,
      coalesce(badge->>'description', 'Unlocked an achievement')::text,
      coalesce(
        NULLIF(badge->>'earned_at', '')::timestamptz,
        NULLIF(to_jsonb(lb)->>'updated_at', '')::timestamptz
      )
    FROM public.leaderboard AS lb
    JOIN followed_users ON followed_users.uid = lb.user_id::text
    LEFT JOIN public.profiles AS profile ON profile.user_id::text = lb.user_id::text
    CROSS JOIN LATERAL jsonb_array_elements(
      CASE WHEN jsonb_typeof(coalesce(lb.badges::jsonb, '[]'::jsonb)) = 'array'
           THEN coalesce(lb.badges::jsonb, '[]'::jsonb)
           ELSE '[]'::jsonb END
    ) AS badge
    WHERE jsonb_typeof(badge) = 'object'

    UNION ALL

    SELECT
      ('suggestion:' || suggestions.id::text)::text,
      'suggestion'::text,
      suggestions.user_id::text,
      profile.username::text,
      suggestions.id::text,
      suggestions.title::text,
      suggestions.description::text,
      suggestions.created_at::timestamptz
    FROM public.suggested_places AS suggestions
    JOIN followed_users ON followed_users.uid = suggestions.user_id::text
    LEFT JOIN public.profiles AS profile ON profile.user_id::text = suggestions.user_id::text
    WHERE suggestions.status = 'approved'
  )
  SELECT
    activities.event_id::text,
    activities.event_type::text,
    activities.actor_id::text,
    activities.actor_username::text,
    activities.target_id::text,
    activities.title::text,
    activities.description::text,
    activities.occurred_at::timestamptz
  FROM activities
  ORDER BY activities.occurred_at DESC NULLS LAST
  LIMIT greatest(1, least(coalesce(p_limit, 50), 100));
END;
$$;

REVOKE ALL ON FUNCTION public.get_following_activity(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_following_activity(integer) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3) PROFILES — username save
-- ---------------------------------------------------------------------------
-- Make sure every existing auth user has a profile row.
INSERT INTO public.profiles (user_id)
SELECT id FROM auth.users
ON CONFLICT (user_id) DO NOTHING;

-- Column-scoped write privileges: users can never touch is_pro /
-- subscription_tier from the client.
REVOKE INSERT, UPDATE ON public.profiles FROM anon, authenticated;
GRANT INSERT (user_id, username, updated_at) ON public.profiles TO authenticated;
GRANT UPDATE (username, updated_at)          ON public.profiles TO authenticated;

DROP POLICY IF EXISTS "users can insert own profile" ON public.profiles;
CREATE POLICY "users can insert own profile"
  ON public.profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "users can update own profile username" ON public.profiles;
CREATE POLICY "users can update own profile username"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.set_my_username(p_username text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  clean_username text := btrim(p_username);
  current_username text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING errcode = '42501';
  END IF;

  IF clean_username !~ '^[A-Za-z0-9][A-Za-z0-9._-]{2,19}$' THEN
    RAISE EXCEPTION 'Username must be 3-20 characters and use letters, numbers, dots, underscores, or hyphens'
      USING errcode = '22023';
  END IF;

  -- Create the profile row if the signup trigger never ran for this user.
  INSERT INTO public.profiles (user_id)
  VALUES (auth.uid())
  ON CONFLICT (user_id) DO NOTHING;

  SELECT profile.username
  INTO current_username
  FROM public.profiles AS profile
  WHERE profile.user_id = auth.uid();

  IF current_username IS NOT NULL AND btrim(current_username) <> '' THEN
    IF lower(current_username) = lower(clean_username) THEN
      RETURN true;
    END IF;
    RAISE EXCEPTION 'Username has already been set' USING errcode = '22023';
  END IF;

  UPDATE public.profiles
  SET username = clean_username,
      updated_at = now()
  WHERE user_id = auth.uid();

  RETURN true;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'Username is already taken' USING errcode = '23505';
END;
$$;

REVOKE ALL ON FUNCTION public.set_my_username(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_my_username(text) TO authenticated;

NOTIFY pgrst, 'reload schema';
