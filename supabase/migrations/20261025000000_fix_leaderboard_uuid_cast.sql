CREATE OR REPLACE FUNCTION public.get_city_leaderboard(
  p_period text DEFAULT 'week',
  p_metric text DEFAULT 'check_ins',
  p_limit integer DEFAULT 50
)
RETURNS TABLE (
  user_id uuid,
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
      checkins.user_id,
      count(*) FILTER (
        WHERE v_since IS NULL OR checkins.checked_in_at >= v_since
      ) AS check_ins,
      count(DISTINCT checkins.place_id) FILTER (
        WHERE places.is_hidden_gem IS TRUE
          AND (v_since IS NULL OR checkins.checked_in_at >= v_since)
      ) AS hidden_gems
    FROM public.place_checkins AS checkins
    LEFT JOIN public.places AS places
      ON places.id = checkins.place_id
    GROUP BY checkins.user_id
  ),
  ranked AS (
    SELECT
      leaderboard.user_id,
      leaderboard.user_name,
      leaderboard.avatar_color_hex,
      leaderboard.total_points,
      leaderboard.places_visited,
      leaderboard.reviews_posted,
      leaderboard.photos_uploaded,
      leaderboard.level,
      coalesce(leaderboard.badges, '[]'::jsonb) AS badges,
      leaderboard.current_streak,
      leaderboard.longest_streak,
      leaderboard.total_visit_days,
      leaderboard.last_visit_date,
      coalesce(checkin_rollup.check_ins, 0) AS check_ins,
      coalesce(checkin_rollup.hidden_gems, 0) AS hidden_gems,
      CASE p_metric
        WHEN 'check_ins' THEN coalesce(checkin_rollup.check_ins, 0)
        WHEN 'longest_streak' THEN coalesce(leaderboard.longest_streak, 0)
        WHEN 'hidden_gems' THEN coalesce(checkin_rollup.hidden_gems, 0)
      END AS score
    FROM public.leaderboard AS leaderboard
    LEFT JOIN checkin_rollup
      ON checkin_rollup.user_id::text = leaderboard.user_id::text
  )
  SELECT
    ranked.user_id,
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
    ranked.last_visit_date,
    ranked.check_ins,
    ranked.hidden_gems,
    ranked.score
  FROM ranked
  ORDER BY ranked.score DESC, ranked.total_points DESC, ranked.user_name
  LIMIT greatest(1, least(coalesce(p_limit, 50), 100));
END;
$$;

REVOKE ALL ON FUNCTION public.get_city_leaderboard(text, text, integer)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_city_leaderboard(text, text, integer)
  TO anon, authenticated;
