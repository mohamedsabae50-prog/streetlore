CREATE OR REPLACE FUNCTION public.get_city_leaderboard(
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
      leaderboard.user_id::text AS uid,
      leaderboard.user_name::text AS user_name,
      leaderboard.avatar_color_hex::text AS avatar_color_hex,
      COALESCE(leaderboard.total_points, 0)::integer AS total_points,
      COALESCE(leaderboard.places_visited, 0)::integer AS places_visited,
      COALESCE(leaderboard.reviews_posted, 0)::integer AS reviews_posted,
      COALESCE(leaderboard.photos_uploaded, 0)::integer AS photos_uploaded,
      leaderboard.level::text AS level,
      COALESCE(leaderboard.badges::jsonb, '[]'::jsonb) AS badges,
      COALESCE(leaderboard.current_streak, 0)::integer AS current_streak,
      COALESCE(leaderboard.longest_streak, 0)::integer AS longest_streak,
      COALESCE(leaderboard.total_visit_days, 0)::integer AS total_visit_days,
      leaderboard.last_visit_date::timestamptz AS last_visit_date,
      COALESCE(checkin_rollup.check_ins, 0)::bigint AS check_ins,
      COALESCE(checkin_rollup.hidden_gems, 0)::bigint AS hidden_gems,
      (CASE p_metric
        WHEN 'check_ins' THEN COALESCE(checkin_rollup.check_ins, 0)
        WHEN 'longest_streak' THEN COALESCE(leaderboard.longest_streak, 0)
        WHEN 'hidden_gems' THEN COALESCE(checkin_rollup.hidden_gems, 0)
      END)::bigint AS score
    FROM public.leaderboard AS leaderboard
    LEFT JOIN checkin_rollup
      ON checkin_rollup.uid = leaderboard.user_id::text
    WHERE leaderboard.user_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  )
  SELECT
    ranked.uid,
    ranked.user_name,
    ranked.avatar_color_hex,
    ranked.total_points,
    ranked.places_visited,
    ranked.reviews_posted,
    ranked.photos_uploaded,
    ranked.level,
    ranked.badges,
    ranked.current_streak,
    ranked.longest_streak,
    ranked.total_visit_days,
    CASE
      WHEN public.can_view_user_activity(ranked.uid)
        THEN ranked.last_visit_date
      ELSE NULL
    END,
    ranked.check_ins,
    ranked.hidden_gems,
    ranked.score
  FROM ranked
  ORDER BY ranked.score DESC, ranked.total_points DESC, ranked.user_name
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 50), 100));
END;
$$;

REVOKE ALL ON FUNCTION public.get_city_leaderboard(text, text, integer)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_city_leaderboard(text, text, integer)
  TO anon, authenticated;
